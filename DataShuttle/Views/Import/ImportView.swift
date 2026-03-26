import SwiftUI
import SwiftData

/// View for importing files from secondary drive to main drive
struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
    
    @State private var viewModel = ShuttleViewModel()
    @State private var selectedSourcePath: String?
    @State private var deleteSourceAfterImport = true

    private func t(_ key: String) -> String {
        L10n.tr(key, languageCode: appLanguage)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    importReadinessCard
                    sourceVolumeCard
                    sourceSelectionCard
                    destinationCard
                    optionsCard
                    if !viewModel.importFolderAnalysis.isEmpty {
                        importFolderListSection
                    }
                    if !viewModel.fileShuttleService.activeJobs.isEmpty {
                        activeJobsSection
                    }
                }
                .padding(24)
            }
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
    
    private var importReadinessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Luồng Import"))
                        .font(.headline)
                    Text(t("Chọn ổ nguồn, chọn thư mục hoặc duyệt tay, rồi đưa dữ liệu về đúng vị trí trên máy chính."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(viewModel.importDestinationPath == nil ? t("Thiếu đích") : t("Sẵn sàng import"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((viewModel.importDestinationPath == nil ? Color.orange : Color.green).opacity(0.12))
                    .foregroundStyle(viewModel.importDestinationPath == nil ? .orange : .green)
                    .clipShape(Capsule())
            }
            
            HStack(spacing: 12) {
                ImportCheckpoint(
                    title: t("Ổ nguồn"),
                    detail: viewModel.selectedImportSourceVolume?.name ?? t("Chưa chọn ổ phụ"),
                    icon: "externaldrive.fill",
                    isComplete: viewModel.selectedImportSourceVolume != nil,
                    tint: .orange
                )
                
                ImportCheckpoint(
                    title: t("Thư mục import"),
                    detail: selectedSourcePath ?? (viewModel.importFolderAnalysis.isEmpty ? t("Chọn tay hoặc từ danh sách quét") : t("Có thể chọn nhanh từ danh sách bên dưới")),
                    icon: "folder.fill",
                    isComplete: selectedSourcePath != nil || !viewModel.importFolderAnalysis.isEmpty,
                    tint: .blue
                )
                
                ImportCheckpoint(
                    title: t("Đích trên máy"),
                    detail: viewModel.importDestinationPath ?? t("Chưa chọn vị trí đích"),
                    icon: "internaldrive.fill",
                    isComplete: viewModel.importDestinationPath != nil,
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
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Import"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(t("Chuyển thư mục từ ổ phụ về ổ chính"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Direction indicator
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.fill")
                    .foregroundStyle(.orange)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                Image(systemName: "internaldrive.fill")
                    .foregroundStyle(.blue)
            }
            .font(.title3)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(.blue.opacity(0.08))
            }
        }
        .padding(24)
    }
    
    // MARK: - Source Volume
    
    private var sourceVolumeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("Bước 1: Chọn ổ nguồn"), systemImage: "1.circle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            
            if viewModel.volumeManager.secondaryVolumes.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(t("Không tìm thấy ổ phụ. Hãy kết nối ổ đĩa ngoài."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.orange.opacity(0.1))
                }
            } else {
                HStack(spacing: 12) {
                    ForEach(viewModel.volumeManager.secondaryVolumes) { volume in
                        ImportVolumeButton(
                            volume: volume,
                            isSelected: viewModel.selectedImportSourceVolume?.id == volume.id
                        ) {
                            viewModel.selectedImportSourceVolume = volume
                            Task {
                                await viewModel.analyzeImportFolders(at: volume.mountPoint)
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
    
    // MARK: - Source Selection
    
    private var sourceSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("Bước 2: Chọn thư mục nguồn"), systemImage: "2.circle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            
            Text(t("Bạn có thể duyệt tay một thư mục cụ thể, hoặc chọn nhanh từ danh sách quét bên dưới."))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                if let path = selectedSourcePath {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.orange)
                        Text(path)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.orange.opacity(0.05))
                            .strokeBorder(.orange.opacity(0.2), lineWidth: 1)
                    }
                    
                    Button {
                        selectedSourcePath = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(t("Chọn thư mục từ ổ phụ hoặc nhấp \"Chuyển\" bên dưới"))
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.quaternary)
                        }
                }
                
                Button {
                    if let path = viewModel.pickImportSource() {
                        selectedSourcePath = path
                    }
                } label: {
                    Label(t("Duyệt"), systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            
            if let selectedSourcePath {
                HStack {
                    Text(deleteSourceAfterImport ? t("Thư mục đã chọn sẽ được di chuyển về máy chính.") : t("Thư mục đã chọn sẽ được sao chép về máy chính."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        Task {
                            await viewModel.importFolder(
                                atPath: selectedSourcePath,
                                deleteSource: deleteSourceAfterImport
                            )
                        }
                    } label: {
                        Label(
                            deleteSourceAfterImport ? t("Di chuyển ngay") : t("Sao chép ngay"),
                            systemImage: deleteSourceAfterImport ? "arrow.right.circle.fill" : "doc.on.doc.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(viewModel.importDestinationPath == nil || viewModel.isImporting)
                }
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.orange.opacity(0.06))
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
    
    // MARK: - Destination
    
    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("Bước 3: Chọn vị trí đích trên ổ chính"), systemImage: "3.circle.fill")
                .font(.headline)
                .foregroundStyle(.blue)
            
            HStack {
                if let path = viewModel.importDestinationPath {
                    HStack {
                        Image(systemName: "internaldrive.fill")
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
                    Text(t("Chưa chọn vị trí đích"))
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.quaternary)
                        }
                }
                
                Button {
                    if let path = viewModel.pickImportDestination() {
                        viewModel.importDestinationPath = path
                    }
                } label: {
                    Label(t("Chọn"), systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Quick destination shortcuts
            Text(t("Gợi ý:"))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(["~/Desktop", "~/Documents", "~/Downloads"], id: \.self) { dir in
                    let expandedPath = NSString(string: dir).expandingTildeInPath
                    Button {
                        viewModel.importDestinationPath = expandedPath
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
    
    // MARK: - Options
    
    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("Bước 4: Tùy chọn import"), systemImage: "4.circle.fill")
                .font(.headline)
                .foregroundStyle(.blue)
            
            Toggle(isOn: $deleteSourceAfterImport) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Xóa nguồn sau khi chuyển"))
                        .font(.body)
                    Text(deleteSourceAfterImport
                         ? t("⚠️ File gốc trên ổ phụ sẽ bị XÓA sau khi copy xong (Di chuyển)")
                         : t("File gốc trên ổ phụ sẽ được GIỮ NGUYÊN (Sao chép)"))
                        .font(.caption)
                        .foregroundStyle(deleteSourceAfterImport ? .orange : .secondary)
                }
            }
            .toggleStyle(.switch)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
    
    // MARK: - Import Folder List
    
    private var importFolderListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(t("Bước 5: Chọn nhanh từ danh sách quét"), systemImage: "5.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                
                Spacer()
                
                if viewModel.isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                }
                
                Text("\(viewModel.importFolderAnalysis.count) \(t("thư mục"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(t("Danh sách này giúp xử lý nhanh nhiều thư mục trên ổ phụ mà không cần duyệt tay từng lần."))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 4) {
                ForEach(viewModel.importFolderAnalysis) { folder in
                    ImportFolderRow(
                        analysis: folder,
                        canImport: viewModel.importDestinationPath != nil,
                        isImporting: viewModel.isImporting,
                        deleteSource: deleteSourceAfterImport
                    ) {
                        selectedSourcePath = folder.path
                        Task {
                            await viewModel.importFolder(
                                atPath: folder.path,
                                deleteSource: deleteSourceAfterImport
                            )
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
    
    // MARK: - Active Jobs
    
    private var activeJobsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("Đang chuyển"), systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
            
            ForEach(viewModel.fileShuttleService.activeJobs) { job in
                TransferProgressView(job: job)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
}

struct ImportCheckpoint: View {
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

// MARK: - Import Volume Button

struct ImportVolumeButton: View {
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
    let volume: VolumeInfo
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false

    private func t(_ key: String) -> String {
        L10n.tr(key, languageCode: appLanguage)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: volume.volumeIcon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .orange)
                
                Text(volume.name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text("\(t("Dung lượng")): \(volume.usedBytes.formattedBytes)")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .orange : .orange.opacity(isHovered ? 0.1 : 0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? .orange : .orange.opacity(0.2), lineWidth: isSelected ? 2 : 1)
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

// MARK: - Import Folder Row

struct ImportFolderRow: View {
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
    let analysis: DiskAnalyzer.FolderAnalysis
    let canImport: Bool
    let isImporting: Bool
    let deleteSource: Bool
    let onImport: () -> Void
    
    @State private var isHovered = false
    @State private var showConfirm = false
    
    var sizeColor: Color {
        if analysis.sizeBytes > 5_000_000_000 { return .red }
        if analysis.sizeBytes > 1_000_000_000 { return .orange }
        if analysis.sizeBytes > 500_000_000 { return .yellow }
        return .green
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, languageCode: appLanguage)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.orange.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "folder.fill")
                    .font(.body)
                    .foregroundStyle(.orange)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(analysis.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    Label("\(analysis.fileCount) files", systemImage: "doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let modified = analysis.lastModified {
                        Label(modified.relativeString, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Spacer()
            
            // Size
            Text(analysis.sizeBytes.formattedBytes)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(sizeColor)
            
            // Import button
            if canImport {
                Button {
                    showConfirm = true
                } label: {
                    Label(
                        deleteSource ? t("Di chuyển") : t("Sao chép"),
                        systemImage: deleteSource ? "arrow.right.circle" : "doc.on.doc"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
                .disabled(isImporting)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? .orange.opacity(0.03) : .clear)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .confirmationDialog(
            "\(deleteSource ? t("Di chuyển") : t("Sao chép")) \(t("thư mục")) \"\(analysis.name)\"?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("\(deleteSource ? t("Di chuyển") : t("Sao chép")) (\(analysis.sizeBytes.formattedBytes))") {
                onImport()
            }
            Button(t("Hủy"), role: .cancel) {}
        } message: {
            if deleteSource {
                Text(t("Thư mục sẽ được chuyển từ ổ phụ sang ổ chính. File gốc trên ổ phụ sẽ bị xóa."))
            } else {
                Text(t("Thư mục sẽ được sao chép từ ổ phụ sang ổ chính. File gốc vẫn giữ nguyên."))
            }
        }
    }
}

#Preview {
    ImportView()
        .modelContainer(for: ShuttleItem.self, inMemory: true)
        .frame(width: 900, height: 700)
}
