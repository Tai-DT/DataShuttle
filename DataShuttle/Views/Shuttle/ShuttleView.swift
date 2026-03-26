import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Main shuttle view for moving directories between drives
struct ShuttleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShuttleItem.shuttledAt, order: .reverse) private var allItems: [ShuttleItem]
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
    
    @AppStorage("confirmBeforeShuttle") private var confirmBeforeShuttle: Bool = true
    @AppStorage("showHiddenFiles") private var showHiddenFiles: Bool = false
    
    @State private var viewModel = ShuttleViewModel()
    @State private var cloudManager = CloudStorageManager()
    @State private var selectedTab: ShuttleTab = .shuttle
    @State private var selectedFolderPath: String?
    @State private var showingFolderPicker = false
    @State private var isDragTargeted = false
    @State private var isCloudDestination = false
    
    enum ShuttleTab: String, CaseIterable {
        case shuttle = "Chuyển"
        case managed = "Đang quản lý"
        case history = "Lịch sử"
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, languageCode: appLanguage)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Tab content
            Group {
                switch selectedTab {
                case .shuttle:
                    shuttleTabContent
                case .managed:
                    managedTabContent
                case .history:
                    historyTabContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.windowBackgroundColor))
        .alert(t("Lỗi"), isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? t("Đã xảy ra lỗi"))
        }
        .alert(t("Thành công"), isPresented: $viewModel.showSuccess) {
            Button("OK") {}
        } message: {
            Text(viewModel.successMessage ?? t("Hoàn thành"))
        }
        .onAppear {
            viewModel.volumeManager.refreshVolumes()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Shuttle"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(t("Chuyển thư mục giữa các ổ đĩa"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Tab bar
            HStack(spacing: 0) {
                ForEach(ShuttleTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(t(tab.rawValue))
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background {
                                if selectedTab == tab {
                                    Capsule()
                                        .fill(.blue.opacity(0.15))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background {
                Capsule()
                    .fill(.quaternary)
            }
        }
        .padding(24)
    }
    
    // MARK: - Shuttle Tab
    
    private var shuttleTabContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                shuttleReadinessCard
                sourceSelectionCard
                destinationSelectionCard
                if !viewModel.folderAnalysis.isEmpty {
                    folderAnalysisSection
                }
                if !viewModel.fileShuttleService.activeJobs.isEmpty {
                    activeTransfersSection
                }
            }
            .padding(24)
        }
        .overlay {
            if isDragTargeted {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.blue, style: StrokeStyle(lineWidth: 3, dash: [10]))
                    .background(RoundedRectangle(cornerRadius: 16).fill(.blue.opacity(0.08)))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.largeTitle)
                            Text(t("Thả thư mục vào đây"))
                                .font(.headline)
                        }
                        .foregroundStyle(.blue)
                    }
                    .padding(8)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return }
                Task { @MainActor in
                    self.selectedFolderPath = url.path
                    await self.viewModel.analyzeFolders(at: url.path, showHidden: self.showHiddenFiles)
                }
            }
            return true
        }
    }
    
    private var shuttleReadinessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Luồng Shuttle"))
                        .font(.headline)
                    Text(t("Chọn thư mục gốc, chọn đích lưu, rồi shuttle từng thư mục con được đề xuất."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(viewModel.selectedDestinationVolume == nil ? t("Chưa sẵn sàng") : t("Sẵn sàng phân tích"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((viewModel.selectedDestinationVolume == nil ? Color.orange : Color.green).opacity(0.12))
                    .foregroundStyle(viewModel.selectedDestinationVolume == nil ? .orange : .green)
                    .clipShape(Capsule())
            }
            
            HStack(spacing: 12) {
                ShuttleCheckpoint(
                    title: t("Nguồn"),
                    detail: selectedFolderPath == nil ? t("Chưa chọn thư mục gốc") : t("Đã chọn thư mục để phân tích"),
                    icon: "folder.fill",
                    isComplete: selectedFolderPath != nil,
                    tint: .blue
                )
                
                ShuttleCheckpoint(
                    title: t("Đích lưu"),
                    detail: viewModel.selectedDestinationVolume?.name ?? t("Chưa chọn ổ hoặc cloud path"),
                    icon: "externaldrive.fill",
                    isComplete: viewModel.selectedDestinationVolume != nil,
                    tint: .purple
                )
                
                ShuttleCheckpoint(
                    title: t("Danh sách đề xuất"),
                    detail: viewModel.folderAnalysis.isEmpty ? t("Chưa có thư mục con để shuttle") : "\(viewModel.folderAnalysis.count) \(t("mục sẵn sàng xử lý"))",
                    icon: "list.bullet.rectangle",
                    isComplete: !viewModel.folderAnalysis.isEmpty,
                    tint: .green
                )
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
        }
    }
    
    private var sourceSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("Bước 1: Chọn thư mục gốc"), systemImage: "1.circle.fill")
                .font(.headline)
                .foregroundStyle(.blue)
            
            Text(t("DataShuttle sẽ phân tích các thư mục con cấp đầu để bạn chọn chính xác phần nào nên chuyển đi."))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                if let path = selectedFolderPath {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                        
                        Text(path)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.blue.opacity(0.05))
                            .strokeBorder(.blue.opacity(0.2), lineWidth: 1)
                    }
                } else {
                    Text(t("Chưa chọn thư mục"))
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.quaternary)
                        }
                }
                
                Button {
                    if let path = viewModel.pickFolder() {
                        selectedFolderPath = path
                        Task {
                            await viewModel.analyzeFolders(at: path, showHidden: showHiddenFiles)
                        }
                    }
                } label: {
                    Label(t("Chọn"), systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Quick suggestions
            Text(t("Gợi ý:"))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(AppConstants.suggestedDirectories, id: \.self) { dir in
                    let expandedPath = NSString(string: dir).expandingTildeInPath
                    Button {
                        selectedFolderPath = expandedPath
                        Task {
                            await viewModel.analyzeFolders(at: expandedPath, showHidden: showHiddenFiles)
                        }
                    } label: {
                        Text(dir.replacingOccurrences(of: "~/", with: ""))
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
    
    private var destinationSelectionCard: some View {
        let availableCloudServices = cloudManager.detectedServices.filter(\.isAvailable)
        
        return VStack(alignment: .leading, spacing: 12) {
            Label(t("Bước 2: Chọn đích lưu"), systemImage: "2.circle.fill")
                .font(.headline)
                .foregroundStyle(.purple)
            
            Text(t("Dùng ổ ngoài, ổ phụ, hoặc thư mục cloud (iCloud, Google Drive...) làm đích."))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // --- Ổ đĩa phụ ---
            if !viewModel.volumeManager.secondaryVolumes.isEmpty {
                Text(t("Ổ đĩa"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    ForEach(viewModel.volumeManager.secondaryVolumes) { volume in
                        DestinationVolumeButton(
                            volume: volume,
                            isSelected: viewModel.selectedDestinationVolume?.id == volume.id && !isCloudDestination
                        ) {
                            viewModel.selectedDestinationVolume = volume
                            viewModel.shuttleDestinationPath = nil
                            isCloudDestination = false
                        }
                    }
                }
            }
            
            // --- Cloud Storage ---
            if !availableCloudServices.isEmpty {
                Text(t("Cloud"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                
                HStack(spacing: 12) {
                    ForEach(availableCloudServices) { service in
                        CloudDestinationButton(
                            service: service,
                            isSelected: isCloudDestination && viewModel.shuttleDestinationPath?.contains(service.localPath) == true
                        ) {
                            // Tạo virtual VolumeInfo cho cloud
                            let cloudVolume = VolumeInfo(
                                id: service.localPath,
                                name: service.name,
                                mountPoint: service.localPath,
                                totalBytes: 0,
                                availableBytes: 0,
                                isRemovable: false,
                                isInternal: false
                            )
                            viewModel.selectedDestinationVolume = cloudVolume
                            viewModel.shuttleDestinationPath = service.localPath + "/DataShuttle"
                            isCloudDestination = true
                        }
                    }
                }
            }
            
            // Trường hợp không có gì
            if viewModel.volumeManager.secondaryVolumes.isEmpty && availableCloudServices.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    
                    Text(t("Không tìm thấy ổ phụ hay cloud. Kết nối ổ ngoài hoặc cài cloud storage."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.orange.opacity(0.1))
                }
            }
            
            // Custom destination path
            if viewModel.selectedDestinationVolume != nil {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(isCloudDestination ? t("Thư mục đích trên cloud") : t("Thư mục đích trên ổ phụ"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        HStack {
                            Image(systemName: isCloudDestination ? "icloud.fill" : "folder.fill")
                                .foregroundStyle(isCloudDestination ? .cyan : .purple)
                            
                            if let customPath = viewModel.shuttleDestinationPath {
                                Text(customPath)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            } else {
                                let defaultPath = viewModel.selectedDestinationVolume.map {
                                    URL(fileURLWithPath: $0.mountPoint)
                                        .appendingPathComponent("DataShuttle").path
                                } ?? ""
                                Text("\(defaultPath) (\(t("mặc định")))")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill((isCloudDestination ? Color.cyan : .purple).opacity(0.05))
                                .strokeBorder((isCloudDestination ? Color.cyan : .purple).opacity(0.15), lineWidth: 1)
                        }
                        
                        Button {
                            if let path = viewModel.pickShuttleDestination() {
                                viewModel.shuttleDestinationPath = path
                            }
                        } label: {
                            Label(t("Chọn"), systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .tint(isCloudDestination ? .cyan : .purple)
                        
                        if viewModel.shuttleDestinationPath != nil {
                            Button {
                                viewModel.shuttleDestinationPath = nil
                                isCloudDestination = false
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .buttonStyle(.bordered)
                            .help(t("Đặt lại về mặc định"))
                        }
                    }
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
        .task {
            await cloudManager.detectCloudServices()
        }
    }
    
    private var folderAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(t("Bước 3: Chọn thư mục cần shuttle"), systemImage: "3.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                
                Spacer()
                
                if viewModel.isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                }
                
                Text("\(viewModel.folderAnalysis.count) \(t("thư mục"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(t("Mỗi thao tác sẽ copy sang đích lưu rồi thay thư mục gốc bằng symlink, nên app cũ vẫn hoạt động như bình thường."))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 4) {
                ForEach(viewModel.folderAnalysis) { folder in
                    FolderRowView(
                        analysis: folder,
                        canShuttle: viewModel.selectedDestinationVolume != nil && !folder.isSymlink,
                        isShuttling: viewModel.isShuttling
                    ) {
                        Task {
                            await viewModel.shuttleFolder(atPath: folder.path, modelContext: modelContext)
                            // Refresh analysis
                            if let path = selectedFolderPath {
                                await viewModel.analyzeFolders(at: path, showHidden: showHiddenFiles)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
    
    private var activeTransfersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("Theo dõi tiến trình"), systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
            
            ForEach(viewModel.fileShuttleService.activeJobs) { job in
                TransferProgressView(job: job) {
                    viewModel.fileShuttleService.cancelJob(job)
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
    
    // MARK: - Managed Tab
    
    private var managedTabContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                let activeItems = allItems.filter { $0.status == .shuttled }
                
                if activeItems.isEmpty {
                    emptyStateView(
                        icon: "folder.badge.gearshape",
                        title: t("Chưa có thư mục nào"),
                        subtitle: t("Chuyển thư mục sang ổ phụ để quản lý tại đây")
                    )
                } else {
                    ForEach(activeItems) { item in
                        ManagedItemRow(item: item) {
                            Task {
                                await viewModel.restoreItem(item, modelContext: modelContext)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - History Tab
    
    private var historyTabContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                if allItems.isEmpty {
                    emptyStateView(
                        icon: "clock",
                        title: t("Chưa có lịch sử"),
                        subtitle: t("Các thao tác chuyển đổi sẽ hiển thị tại đây")
                    )
                } else {
                    ForEach(allItems) { item in
                        HistoryItemRow(item: item)
                    }
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Empty State
    
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

struct ShuttleCheckpoint: View {
    let title: String
    let detail: String
    let icon: String
    let isComplete: Bool
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Spacer()
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(isComplete ? .green : Color.secondary.opacity(0.4))
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.windowBackgroundColor).opacity(0.65))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(tint.opacity(0.12), lineWidth: 1)
        }
    }
}

// MARK: - Destination Volume Button

struct DestinationVolumeButton: View {
    let volume: VolumeInfo
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: volume.volumeIcon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .blue)
                
                Text(volume.name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text("Trống: \(volume.availableBytes.formattedBytes)")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .blue : .blue.opacity(isHovered ? 0.1 : 0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? .blue : .blue.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Cloud Destination Button

struct CloudDestinationButton: View {
    let service: CloudStorageManager.CloudService
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    private var serviceColor: Color {
        switch service.color {
        case "blue": return .cyan
        case "green": return .green
        case "cyan": return .teal
        case "purple": return .purple
        default: return .blue
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: service.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : serviceColor)
                
                Text(service.name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                if service.usedBytes > 0 {
                    Text(service.usedBytes.formattedBytes)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                } else {
                    Text("Cloud sync")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? serviceColor : serviceColor.opacity(isHovered ? 0.12 : 0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? serviceColor : serviceColor.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Managed Item Row

struct ManagedItemRow: View {
    let item: ShuttleItem
    let onRestore: () -> Void
    
    @State private var isHovered = false
    @State private var showConfirmRestore = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.folderName)
                    .font(.body)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    Text(item.destinationPath)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text(item.originalPath)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.sizeBytes.formattedBytes)
                    .font(.callout)
                    .fontWeight(.medium)
                
                Text(item.shuttledAt.relativeString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([
                    URL(fileURLWithPath: item.destinationPath)
                ])
            } label: {
                Label("Finder", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button {
                showConfirmRestore = true
            } label: {
                Label("Khôi phục", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.orange)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(isHovered ? 0.08 : 0.03), radius: 6, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.blue.opacity(isHovered ? 0.2 : 0.05), lineWidth: 1)
        }
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .confirmationDialog(
            "Khôi phục thư mục?",
            isPresented: $showConfirmRestore,
            titleVisibility: .visible
        ) {
            Button("Khôi phục", role: .destructive) {
                onRestore()
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Thư mục \"\(item.folderName)\" sẽ được chuyển từ ổ phụ về vị trí gốc.")
        }
    }
}

// MARK: - History Item Row

struct HistoryItemRow: View {
    let item: ShuttleItem
    
    var statusColor: Color {
        switch item.status {
        case .shuttled: return .green
        case .restored: return .blue
        case .transferring: return .orange
        case .error: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.status.iconName)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.folderName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("\(item.originalPath) → \(item.destinationVolume)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Text(item.sizeBytes.formattedBytes)
                .font(.callout)
                .foregroundStyle(.secondary)
            
            Text(item.status.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.1))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
            
            Text(item.shuttledAt.relativeString)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], sizes: [CGSize], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            
            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        
        return (positions, sizes, CGSize(width: maxX, height: y + rowHeight))
    }
}

#Preview {
    ShuttleView()
        .modelContainer(for: ShuttleItem.self, inMemory: true)
        .frame(width: 900, height: 700)
}
