import Foundation
import SwiftData
import AppKit

/// ViewModel for shuttle operations
@MainActor
@Observable
class ShuttleViewModel {
    var fileShuttleService = FileShuttleService()
    var diskAnalyzer = DiskAnalyzer()
    var volumeManager = VolumeManager()
    
    var folderAnalysis: [DiskAnalyzer.FolderAnalysis] = []
    var isAnalyzing = false
    var isShuttling = false
    var currentJob: TransferJob?
    var errorMessage: String?
    var showError = false
    var showSuccess = false
    var successMessage: String?
    
    var selectedDestinationVolume: VolumeInfo?
    
    /// Custom destination path on the external drive
    var shuttleDestinationPath: String?
    
    // Import-related state
    var importFolderAnalysis: [DiskAnalyzer.FolderAnalysis] = []
    var isImporting = false
    var selectedImportSourceVolume: VolumeInfo?
    var importDestinationPath: String?

    private var appLanguageCode: String {
        UserDefaults.standard.string(forKey: L10n.languageStorageKey) ?? AppLanguage.system.rawValue
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, languageCode: appLanguageCode)
    }
    
    /// Open folder picker and return selected path
    func pickFolder() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = t("Chọn thư mục để chuyển sang ổ phụ")
        panel.prompt = t("Chọn")
        
        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        
        return url.path
    }
    
    /// Open folder picker for secondary drive source
    func pickImportSource() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = t("Chọn thư mục từ ổ phụ để chuyển vào ổ chính")
        panel.prompt = t("Chọn")
        
        // Start from Volumes if possible
        if let volume = selectedImportSourceVolume {
            panel.directoryURL = URL(fileURLWithPath: volume.mountPoint)
        } else {
            panel.directoryURL = URL(fileURLWithPath: "/Volumes")
        }
        
        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        
        return url.path
    }
    
    /// Pick destination folder on main drive
    func pickImportDestination() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = t("Chọn vị trí đích trên ổ chính")
        panel.prompt = t("Chọn")
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        
        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        
        return url.path
    }
    
    /// Pick destination folder on the external drive for shuttle
    func pickShuttleDestination() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = t("Chọn vị trí đích trên ổ phụ")
        panel.prompt = t("Chọn")
        
        if let volume = selectedDestinationVolume {
            panel.directoryURL = URL(fileURLWithPath: volume.mountPoint)
        } else {
            panel.directoryURL = URL(fileURLWithPath: "/Volumes")
        }
        
        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        
        return url.path
    }
    
    /// Analyze folders in a directory
    func analyzeFolders(at path: String, showHidden: Bool = false) async {
        isAnalyzing = true
        folderAnalysis = await diskAnalyzer.analyzeFolders(at: path, showHidden: showHidden)
        isAnalyzing = false
    }
    
    /// Analyze folders on external drive for import
    func analyzeImportFolders(at path: String) async {
        isAnalyzing = true
        importFolderAnalysis = await diskAnalyzer.analyzeFolders(at: path)
        isAnalyzing = false
    }
    
    /// Shuttle a folder to the selected destination
    /// Uses shuttleDestinationPath if set, otherwise uses DataShuttle folder on volume root
    func shuttleFolder(atPath path: String, modelContext: ModelContext) async {
        guard let destination = selectedDestinationVolume else {
            errorMessage = t("Vui lòng chọn ổ đích")
            showError = true
            return
        }
        
        let destPath = shuttleDestinationPath ?? {
            let base = URL(fileURLWithPath: destination.mountPoint)
                .appendingPathComponent("DataShuttle")
            return base.path
        }()
        
        isShuttling = true
        
        do {
            let item = try await fileShuttleService.shuttle(
                sourcePath: path,
                destinationBasePath: destPath,
                onProgress: { [weak self] job in
                    self?.currentJob = job
                }
            )
            
            modelContext.insert(item)
            try modelContext.save()
            
            successMessage = "\(t("Đã chuyển")) \(item.folderName) \(t("thành công!"))"
            showSuccess = true
            NotificationManager.shared.sendTransferComplete(folderName: item.folderName, direction: t("shuttle sang ổ phụ"))
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            NotificationManager.shared.sendTransferFailed(folderName: URL(fileURLWithPath: path).lastPathComponent, error: error.localizedDescription)
        }
        
        isShuttling = false
    }
    
    /// Import a folder from secondary drive to main drive
    func importFolder(atPath sourcePath: String, deleteSource: Bool) async {
        guard let destination = importDestinationPath else {
            errorMessage = t("Vui lòng chọn thư mục đích trên ổ chính")
            showError = true
            return
        }
        
        isImporting = true
        
        do {
            try await fileShuttleService.importToMain(
                sourcePath: sourcePath,
                destinationPath: destination,
                deleteSource: deleteSource,
                onProgress: { [weak self] job in
                    self?.currentJob = job
                }
            )
            
            let folderName = URL(fileURLWithPath: sourcePath).lastPathComponent
            let action = deleteSource ? t("Di chuyển") : t("Sao chép")
            successMessage = "\(action) \(folderName) \(t("về ổ chính thành công!"))"
            showSuccess = true
            NotificationManager.shared.sendTransferComplete(folderName: folderName, direction: t("import về ổ chính"))
            
            // Refresh analysis
            if let volume = selectedImportSourceVolume {
                await analyzeImportFolders(at: volume.mountPoint)
            }
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            NotificationManager.shared.sendTransferFailed(folderName: URL(fileURLWithPath: sourcePath).lastPathComponent, error: error.localizedDescription)
        }
        
        isImporting = false
    }
    
    /// Restore a shuttled item back to original location
    func restoreItem(_ item: ShuttleItem, modelContext: ModelContext) async {
        isShuttling = true
        
        do {
            try await fileShuttleService.restore(item: item) { [weak self] job in
                self?.currentJob = job
            }
            
            try modelContext.save()
            
            successMessage = "\(t("Đã khôi phục")) \(item.folderName) \(t("thành công!"))"
            showSuccess = true
            NotificationManager.shared.sendTransferComplete(folderName: item.folderName, direction: t("khôi phục về ổ chính"))
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            NotificationManager.shared.sendTransferFailed(folderName: item.folderName, error: error.localizedDescription)
        }
        
        isShuttling = false
    }
}
