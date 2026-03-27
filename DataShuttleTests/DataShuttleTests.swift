import Foundation
import Testing
@testable import DataShuttle

struct DataShuttleTests {

    @Test
    func localization_listsOnlyLanguagesWithActualTranslations() {
        let languages = AppLanguage.selectableCases.map(\.rawValue)

        #expect(languages == ["system", "vi", "en", "es", "fr", "de", "pt-BR", "ru", "zh-Hans", "ja", "ko", "hi", "ar"])
    }

    @Test
    func localization_translatesEnglishKeys() {
        #expect(L10n.tr("Cài đặt", languageCode: "en") == "Settings")
        #expect(L10n.tr("Tổng quan", languageCode: "en") == "Overview")
        #expect(L10n.tr("Ngôn ngữ", languageCode: "en") == "Language")
    }

    @Test
    func localization_translatesAdvertisedLanguages() {
        let expectedSettings = [
            "es": "Configuración",
            "fr": "Paramètres",
            "de": "Einstellungen",
            "pt-BR": "Configurações",
            "ru": "Настройки",
            "zh-Hans": "设置",
            "ja": "設定",
            "ko": "설정",
            "hi": "सेटिंग्स",
            "ar": "الإعدادات",
        ]

        for (languageCode, expectedValue) in expectedSettings {
            #expect(L10n.tr("Cài đặt", languageCode: languageCode) == expectedValue)
        }
    }

    @Test
    func localization_formattersFollowSavedAppLanguage() {
        let defaults = UserDefaults.standard
        let previousLanguage = defaults.string(forKey: L10n.languageStorageKey)
        defer {
            if let previousLanguage {
                defaults.set(previousLanguage, forKey: L10n.languageStorageKey)
            } else {
                defaults.removeObject(forKey: L10n.languageStorageKey)
            }
        }

        defaults.set("en", forKey: L10n.languageStorageKey)
        let englishRelative = Date().addingTimeInterval(-3600).relativeString.lowercased()

        defaults.set("vi", forKey: L10n.languageStorageKey)
        let vietnameseRelative = Date().addingTimeInterval(-3600).relativeString.lowercased()

        #expect(englishRelative != vietnameseRelative)
    }

    @Test
    @MainActor
    func detectCloudServices_listsKnownProvidersAndFindsGoogleDrive() async throws {
        let fileManager = FileManager.default
        let homeDirectory = try makeTemporaryDirectory(named: "cloud-home")
        defer { try? fileManager.removeItem(at: homeDirectory) }
        
        let googleDrivePath = homeDirectory
            .appendingPathComponent("Library/CloudStorage", isDirectory: true)
            .appendingPathComponent("GoogleDrive-test@example.com", isDirectory: true)
        let projectPath = googleDrivePath.appendingPathComponent("Project", isDirectory: true)
        
        try fileManager.createDirectory(at: projectPath, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: projectPath.appendingPathComponent("file.txt"))
        
        let manager = CloudStorageManager(
            homeDirectoryPath: homeDirectory.path,
            processListProvider: { ["webdavfs_agent \(googleDrivePath.path)"] },
            applicationPathResolver: { candidates in
                candidates.first?.contains("Google Drive.app") == true ? "/Applications/Google Drive.app" : nil
            }
        )
        await manager.detectCloudServices()
        
        let googleDrive = try #require(manager.detectedServices.first { $0.id == "googledrive" })
        #expect(googleDrive.isAvailable)
        #expect(googleDrive.localPath == googleDrivePath.path)
        #expect(googleDrive.isDesktopAppInstalled)
        #expect(googleDrive.isSyncProcessRunning)
        #expect(googleDrive.status == .connected)
        
        let dropbox = try #require(manager.detectedServices.first { $0.id == "dropbox" })
        #expect(dropbox.isAvailable == false)
    }
    
    @Test
    @MainActor
    func healthCheck_detectsAndRepairsBrokenSymlink() async throws {
        let fileManager = FileManager.default
        let rootDirectory = try makeTemporaryDirectory(named: "health-check")
        defer { try? fileManager.removeItem(at: rootDirectory) }
        
        let originalPath = rootDirectory.appendingPathComponent("Original", isDirectory: true)
        let targetPath = rootDirectory
            .appendingPathComponent("External", isDirectory: true)
            .appendingPathComponent("Original", isDirectory: true)
        
        try fileManager.createDirectory(at: targetPath, withIntermediateDirectories: true)
        try Data("123".utf8).write(to: targetPath.appendingPathComponent("data.txt"))
        try fileManager.createSymbolicLink(atPath: originalPath.path, withDestinationPath: targetPath.path)
        
        let shuttleItem = ShuttleItem(
            originalPath: originalPath.path,
            destinationPath: targetPath.path,
            folderName: "Original",
            sizeBytes: 3,
            destinationVolume: "Test"
        )
        let healthService = HealthCheckService()
        
        await healthService.scan(items: [shuttleItem])
        let healthyStatus = try #require(healthService.results.first)
        #expect(healthyStatus.isBroken == false)
        
        try fileManager.removeItem(at: targetPath)
        
        await healthService.scan(items: [shuttleItem])
        let brokenStatus = try #require(healthService.results.first)
        #expect(brokenStatus.isBroken)
        
        try fileManager.createDirectory(at: targetPath, withIntermediateDirectories: true)
        try Data("456".utf8).write(to: targetPath.appendingPathComponent("data.txt"))
        
        try healthService.fixSymlink(for: brokenStatus)
        
        await healthService.scan(items: [shuttleItem])
        let repairedStatus = try #require(healthService.results.first)
        #expect(repairedStatus.isBroken == false)
    }
    
    private func makeTemporaryDirectory(named prefix: String) throws -> URL {
        let baseDirectory = FileManager.default.temporaryDirectory
        let directory = baseDirectory.appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
