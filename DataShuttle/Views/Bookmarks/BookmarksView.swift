import SwiftUI
import SwiftData

/// View for managing bookmarked folders for quick shuttle/import
struct BookmarksView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
    @Query(sort: \BookmarkItem.useCount, order: .reverse) private var bookmarks: [BookmarkItem]
    
    @State private var viewModel = ShuttleViewModel()
    @State private var showAddBookmark = false
    @State private var newBookmarkPath: String = ""
    @State private var newBookmarkName: String = ""
    @State private var newBookmarkDirection: BookmarkDirection = .shuttle
    @State private var newBookmarkDestination: String = ""
    @State private var newBookmarkColor: String = "blue"
    
    private let colorOptions: [(String, Color)] = [
        ("blue", .blue), ("purple", .purple), ("orange", .orange),
        ("green", .green), ("pink", .pink), ("cyan", .cyan)
    ]

    private func t(_ key: String) -> String {
        L10n.tr(key, languageCode: appLanguage)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    if bookmarks.isEmpty {
                        emptyState
                    } else {
                        // Quick actions - most used
                        let frequent = bookmarks.filter { $0.useCount > 0 }.prefix(3)
                        if !frequent.isEmpty {
                            quickActionsSection(Array(frequent))
                        }
                        
                        // All bookmarks
                        allBookmarksSection
                    }
                }
                .padding(24)
            }
        }
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showAddBookmark) {
            addBookmarkSheet
        }
        .alert(t("Lỗi"), isPresented: $viewModel.showError) {
            Button(t("OK")) {}
        } message: {
            Text(viewModel.errorMessage ?? t("Đã xảy ra lỗi"))
        }
        .alert(t("Thành công"), isPresented: $viewModel.showSuccess) {
            Button(t("OK")) {}
        } message: {
            Text(viewModel.successMessage ?? t("Hoàn thành"))
        }
        .onAppear {
            viewModel.volumeManager.refreshVolumes()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Ghi nhớ"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(t("Thư mục hay dùng — chuyển nhanh 1 chạm"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                resetAddForm()
                showAddBookmark = true
            } label: {
                Label(t("Thêm"), systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
    
    // MARK: - Quick Actions
    
    private func quickActionsSection(_ items: [BookmarkItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("Hay dùng nhất"), systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(.yellow)
            
            HStack(spacing: 12) {
                ForEach(items) { bookmark in
                    QuickBookmarkCard(bookmark: bookmark) {
                        executeBookmark(bookmark)
                    }
                }
            }
        }
    }
    
    // MARK: - All Bookmarks
    
    private var allBookmarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(t("Tất cả"), systemImage: "bookmark.fill")
                    .font(.headline)
                
                Spacer()
                
                Text("\(bookmarks.count) \(t("mục"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 6) {
                ForEach(bookmarks) { bookmark in
                    BookmarkRow(
                        bookmark: bookmark,
                        onExecute: { executeBookmark(bookmark) },
                        onDelete: { deleteBookmark(bookmark) }
                    )
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            
            Text(t("Chưa có ghi nhớ nào"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(t("Thêm thư mục hay dùng để chuyển nhanh giữa các ổ đĩa"))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            
            Button {
                resetAddForm()
                showAddBookmark = true
            } label: {
                Label(t("Thêm ghi nhớ đầu tiên"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }
    
    // MARK: - Add Bookmark Sheet
    
    private var addBookmarkSheet: some View {
        VStack(spacing: 20) {
            Text(t("Thêm Ghi Nhớ"))
                .font(.title2)
                .fontWeight(.bold)
            
            // Folder path
            VStack(alignment: .leading, spacing: 6) {
                Text(t("Thư mục"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    TextField(t("Đường dẫn thư mục"), text: $newBookmarkPath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(t("Chọn")) {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK, let url = panel.url {
                            newBookmarkPath = url.path
                            if newBookmarkName.isEmpty {
                                newBookmarkName = url.lastPathComponent
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Display name
            VStack(alignment: .leading, spacing: 6) {
                Text(t("Tên hiển thị"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField(t("Ví dụ: Ảnh cá nhân"), text: $newBookmarkName)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Direction
            VStack(alignment: .leading, spacing: 6) {
                Text(t("Hướng chuyển"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker(t("Hướng"), selection: $newBookmarkDirection) {
                    ForEach(BookmarkDirection.allCases, id: \.self) { dir in
                        Label(dir.displayName, systemImage: dir.icon)
                            .tag(dir)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Preferred destination
            VStack(alignment: .leading, spacing: 6) {
                Text(t("Đích mặc định (tuỳ chọn)"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    TextField(t("Đường dẫn đích"), text: $newBookmarkDestination)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(t("Chọn")) {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK, let url = panel.url {
                            newBookmarkDestination = url.path
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Color tag
            VStack(alignment: .leading, spacing: 6) {
                Text(t("Màu nhãn"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    ForEach(colorOptions, id: \.0) { name, color in
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if newBookmarkColor == name {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture {
                                newBookmarkColor = name
                            }
                    }
                }
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button(t("Hủy")) {
                    showAddBookmark = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(t("Lưu")) {
                    saveBookmark()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newBookmarkPath.isEmpty || newBookmarkName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480, height: 520)
    }
    
    // MARK: - Actions
    
    private func resetAddForm() {
        newBookmarkPath = ""
        newBookmarkName = ""
        newBookmarkDirection = .shuttle
        newBookmarkDestination = ""
        newBookmarkColor = "blue"
    }
    
    private func saveBookmark() {
        let bookmark = BookmarkItem(
            path: newBookmarkPath,
            name: newBookmarkName,
            preferredDestination: newBookmarkDestination.isEmpty ? nil : newBookmarkDestination,
            direction: newBookmarkDirection,
            volumeName: viewModel.volumeManager.getVolume(for: newBookmarkPath)?.name ?? "",
            colorTag: newBookmarkColor
        )
        
        modelContext.insert(bookmark)
        try? modelContext.save()
        showAddBookmark = false
    }
    
    private func deleteBookmark(_ bookmark: BookmarkItem) {
        modelContext.delete(bookmark)
        try? modelContext.save()
    }
    
    private func executeBookmark(_ bookmark: BookmarkItem) {
        bookmark.useCount += 1
        bookmark.lastUsed = Date()
        try? modelContext.save()
        
        // Execute based on direction
        Task {
            let sourcePath = NSString(string: bookmark.path).expandingTildeInPath
            
            switch bookmark.direction {
            case .shuttle:
                if let dest = bookmark.preferredDestination {
                    let destinationPath = NSString(string: dest).expandingTildeInPath
                    viewModel.volumeManager.refreshVolumes()
                    
                    guard let destinationVolume = viewModel.volumeManager.getVolume(for: destinationPath) else {
                        viewModel.errorMessage = t("Không tìm thấy ổ chứa đích. Hãy kiểm tra kết nối hoặc cập nhật ghi nhớ.")
                        viewModel.showError = true
                        return
                    }
                    
                    viewModel.selectedDestinationVolume = destinationVolume
                    viewModel.shuttleDestinationPath = destinationPath
                    await viewModel.shuttleFolder(atPath: sourcePath, modelContext: modelContext)
                } else {
                    viewModel.errorMessage = t("Chưa có đích mặc định. Hãy chỉnh sửa ghi nhớ.")
                    viewModel.showError = true
                }
            case .importToMain:
                if let dest = bookmark.preferredDestination {
                    viewModel.importDestinationPath = NSString(string: dest).expandingTildeInPath
                    await viewModel.importFolder(atPath: sourcePath, deleteSource: true)
                } else {
                    viewModel.errorMessage = t("Chưa có đích mặc định. Hãy chỉnh sửa ghi nhớ.")
                    viewModel.showError = true
                }
            }
        }
    }
}

// MARK: - Quick Bookmark Card

struct QuickBookmarkCard: View {
    let bookmark: BookmarkItem
    let onExecute: () -> Void
    
    @State private var isHovered = false
    
    private var tagColor: Color {
        switch bookmark.colorTag {
        case "purple": return .purple
        case "orange": return .orange
        case "green": return .green
        case "pink": return .pink
        case "cyan": return .cyan
        default: return .blue
        }
    }
    
    var body: some View {
        Button(action: onExecute) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: bookmark.direction.icon)
                        .foregroundStyle(tagColor)
                    
                    Spacer()
                    
                    Text("×\(bookmark.useCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tagColor.opacity(0.15))
                        .foregroundStyle(tagColor)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.name)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(bookmark.direction.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if let lastUsed = bookmark.lastUsed {
                    Text(lastUsed.relativeString)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .shadow(color: tagColor.opacity(isHovered ? 0.2 : 0), radius: 10, y: 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tagColor.opacity(isHovered ? 0.4 : 0.15), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Bookmark Row

struct BookmarkRow: View {
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
    let bookmark: BookmarkItem
    let onExecute: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var showDeleteConfirm = false
    
    private var tagColor: Color {
        switch bookmark.colorTag {
        case "purple": return .purple
        case "orange": return .orange
        case "green": return .green
        case "pink": return .pink
        case "cyan": return .cyan
        default: return .blue
        }
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, languageCode: appLanguage)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Color tag bar
            RoundedRectangle(cornerRadius: 2)
                .fill(tagColor)
                .frame(width: 4, height: 40)
            
            // Direction icon
            Image(systemName: bookmark.direction.icon)
                .font(.title3)
                .foregroundStyle(tagColor)
                .frame(width: 28)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(bookmark.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // Use count
            if bookmark.useCount > 0 {
                Text("×\(bookmark.useCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            // Direction badge
            Text(bookmark.direction.displayName)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tagColor.opacity(0.1))
                .foregroundStyle(tagColor)
                .clipShape(Capsule())
            
            // Execute button
            Button(action: onExecute) {
                Label(t("Chuyển"), systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(tagColor)
            .controlSize(.small)
            
            // Delete button
            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        }
        .background {
            if isHovered {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tagColor.opacity(0.03))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(tagColor.opacity(isHovered ? 0.15 : 0.05), lineWidth: 1)
        }
        .onHover { hovering in isHovered = hovering }
        .confirmationDialog(t("Xóa ghi nhớ?"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(t("Xóa"), role: .destructive) { onDelete() }
            Button(t("Hủy"), role: .cancel) {}
        } message: {
            Text("\(t("Ghi nhớ")) \"\(bookmark.name)\" \(t("sẽ bị xóa. Dữ liệu gốc không bị ảnh hưởng."))")
        }
    }
}

#Preview {
    BookmarksView()
        .modelContainer(for: [ShuttleItem.self, BookmarkItem.self], inMemory: true)
        .frame(width: 900, height: 700)
}
