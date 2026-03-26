import SwiftUI
import SwiftData

/// Sync profiles — batch shuttle/import for grouped directories
struct SyncProfilesView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
    @Query(sort: \SyncProfile.createdAt, order: .reverse) private var profiles: [SyncProfile]
    
    @State private var shuttleService = FileShuttleService()
    @State private var executingProfileId: PersistentIdentifier?
    @State private var executionProgress: String?
    
    @State private var showAddProfile = false
    @State private var newName = ""
    @State private var newItems: [String] = []
    @State private var newDestination = ""
    @State private var newDirection = "shuttle"
    @State private var newTriggerVolume = ""
    @State private var newColor = "blue"
    
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
                VStack(spacing: 20) {
                    if profiles.isEmpty {
                        emptyState
                    } else {
                        ForEach(profiles) { profile in
                            ProfileCard(
                                profile: profile,
                                isExecuting: executingProfileId == profile.persistentModelID,
                                executionProgress: executingProfileId == profile.persistentModelID ? executionProgress : nil,
                                onExecute: { executeProfile(profile) },
                                onDelete: { deleteProfile(profile) }
                            )
                        }
                    }
                }
                .padding(24)
            }
        }
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showAddProfile) {
            addProfileSheet
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Sync Profiles"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(t("Nhóm thư mục — shuttle cả nhóm 1 click"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                resetForm()
                showAddProfile = true
            } label: {
                Label(t("Tạo Profile"), systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            
            Text(t("Chưa có profile nào"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(t("Tạo profile để nhóm nhiều thư mục và shuttle tất cả cùng lúc"))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(t("Ví dụ:"))
                    .font(.caption)
                    .fontWeight(.medium)
                
                ProfileExample(name: "Developer", items: ["~/Developer", "~/node_modules", "~/.cocoapods"])
                ProfileExample(name: "Media", items: ["~/Movies", "~/Music", "~/Pictures"])
                ProfileExample(name: "Creative", items: ["~/Figma", "~/Adobe", "~/Blender"])
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.opacity(0.03))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Add Profile Sheet
    
    private var addProfileSheet: some View {
        VStack(spacing: 20) {
            Text(t("Tạo Sync Profile"))
                .font(.title2)
                .fontWeight(.bold)
            
            // Name
            VStack(alignment: .leading, spacing: 6) {
                Text(t("Tên profile"))
                    .font(.subheadline).fontWeight(.medium)
                TextField(t("Ví dụ: Developer"), text: $newName)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Direction
            VStack(alignment: .leading, spacing: 6) {
                Text(t("Hướng chuyển"))
                    .font(.subheadline).fontWeight(.medium)
                Picker("", selection: $newDirection) {
                    Text(t("Chính → Phụ (Shuttle)")).tag("shuttle")
                    Text(t("Phụ → Chính (Import)")).tag("import")
                }
                .pickerStyle(.segmented)
            }
            
            // Items
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(t("Thư mục")) (\(newItems.count))")
                        .font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Button {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = true
                        panel.message = t("Chọn thư mục để thêm vào profile")
                        if panel.runModal() == .OK {
                            for url in panel.urls {
                                if !newItems.contains(url.path) {
                                    newItems.append(url.path)
                                }
                            }
                        }
                    } label: {
                        Label(t("Thêm"), systemImage: "plus")
                    }
                    .controlSize(.small)
                }
                
                if newItems.isEmpty {
                    Text(t("Chưa có thư mục nào"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                } else {
                    VStack(spacing: 4) {
                        ForEach(newItems, id: \.self) { item in
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                                Text(item)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button { newItems.removeAll { $0 == item } } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                        }
                    }
                }
            }
            
            // Destination
            VStack(alignment: .leading, spacing: 6) {
                Text(t("Đích mặc định"))
                    .font(.subheadline).fontWeight(.medium)
                HStack {
                    TextField(t("Đường dẫn đích"), text: $newDestination)
                        .textFieldStyle(.roundedBorder)
                    Button(t("Chọn")) {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK, let url = panel.url {
                            newDestination = url.path
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Auto trigger
            VStack(alignment: .leading, spacing: 6) {
                Text(t("Tự động khi cắm ổ (tuỳ chọn)"))
                    .font(.subheadline).fontWeight(.medium)
                TextField(t("Tên ổ đĩa, ví dụ: Backup"), text: $newTriggerVolume)
                    .textFieldStyle(.roundedBorder)
                Text(t("Profile sẽ tự chạy khi ổ này được cắm vào"))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            
            // Color
            HStack(spacing: 8) {
                Text(t("Màu:")).font(.subheadline)
                ForEach(colorOptions, id: \.0) { name, color in
                    Circle().fill(color).frame(width: 24, height: 24)
                        .overlay {
                            if newColor == name {
                                Image(systemName: "checkmark")
                                    .font(.caption2).fontWeight(.bold).foregroundStyle(.white)
                            }
                        }
                        .onTapGesture { newColor = name }
                }
            }
            
            Spacer()
            
            HStack {
                Button(t("Hủy")) { showAddProfile = false }
                    .buttonStyle(.bordered)
                Spacer()
                Button(t("Tạo")) { saveProfile() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.isEmpty || newItems.isEmpty || newDestination.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520, height: 640)
    }
    
    // MARK: - Actions
    
    private func resetForm() {
        newName = ""
        newItems = []
        newDestination = ""
        newDirection = "shuttle"
        newTriggerVolume = ""
        newColor = "blue"
    }
    
    private func saveProfile() {
        let profile = SyncProfile(
            name: newName,
            items: newItems,
            destinationPath: newDestination,
            direction: newDirection,
            triggerVolumeName: newTriggerVolume.isEmpty ? nil : newTriggerVolume,
            colorTag: newColor
        )
        modelContext.insert(profile)
        try? modelContext.save()
        showAddProfile = false
    }
    
    private func deleteProfile(_ profile: SyncProfile) {
        modelContext.delete(profile)
        try? modelContext.save()
    }
    
    private func executeProfile(_ profile: SyncProfile) {
        guard executingProfileId == nil else { return }
        executingProfileId = profile.persistentModelID
        
        Task {
            let result = await shuttleService.executeProfile(profile, modelContext: modelContext) { progress in
                executionProgress = progress
            }
            
            NotificationManager.shared.send(
                title: "\(t("Profile")) \"\(profile.name)\" \(t("hoàn tất"))",
                body: "\(result.totalCount) \(t("thư mục")): \(result.summary)",
                identifier: "profile-exec-\(profile.name)"
            )
            
            executingProfileId = nil
            executionProgress = nil
        }
    }
}

// MARK: - Profile Card

struct ProfileCard: View {
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
    let profile: SyncProfile
    var isExecuting: Bool = false
    var executionProgress: String?
    var onExecute: (() -> Void)?
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var showDeleteConfirm = false
    
    private var tagColor: Color {
        switch profile.colorTag {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(tagColor)
                    .frame(width: 6, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.headline)
                    Text(profile.directionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let trigger = profile.triggerVolumeName {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                        Text("\(t("Auto")): \(trigger)")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tagColor.opacity(0.1))
                    .foregroundStyle(tagColor)
                    .clipShape(Capsule())
                }
                
                Text("\(profile.itemCount) \(t("thư mục"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let onExecute = onExecute {
                    Button {
                        onExecute()
                    } label: {
                        if isExecuting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(t("Chạy"), systemImage: "play.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(tagColor)
                    .controlSize(.small)
                    .disabled(isExecuting)
                }
                
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.5))
                .disabled(isExecuting)
            }
            
            // Execution progress
            if let progress = executionProgress {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(progress)
                        .font(.caption)
                        .foregroundStyle(tagColor)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tagColor.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Items list
            VStack(spacing: 4) {
                ForEach(profile.items, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.caption)
                            .foregroundStyle(tagColor.opacity(0.6))
                        Text(item)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                }
            }
            
            HStack {
                Image(systemName: "arrow.right")
                    .font(.caption).foregroundStyle(.secondary)
                Text(profile.destinationPath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .strokeBorder(tagColor.opacity(isHovered ? 0.2 : 0.08), lineWidth: 1)
        }
        .onHover { hovering in isHovered = hovering }
        .confirmationDialog(t("Xóa profile?"), isPresented: $showDeleteConfirm) {
            Button(t("Xóa"), role: .destructive) { onDelete() }
            Button(t("Hủy"), role: .cancel) {}
        }
    }
}

// MARK: - Profile Example

struct ProfileExample: View {
    let name: String
    let items: [String]
    
    var body: some View {
        HStack {
            Text("📁 \(name):")
                .font(.caption)
                .fontWeight(.medium)
            Text(items.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SyncProfilesView()
        .modelContainer(for: [SyncProfile.self], inMemory: true)
        .frame(width: 900, height: 700)
}
