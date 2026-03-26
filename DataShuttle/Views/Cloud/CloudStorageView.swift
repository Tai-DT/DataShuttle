import SwiftUI
import AppKit

/// Cloud storage integration view
struct CloudStorageView: View {
    @State private var cloudManager = CloudStorageManager()
    @State private var selectedService: CloudStorageManager.CloudService?
    @State private var cloudAnalysis: [DiskAnalyzer.FolderAnalysis] = []
    @State private var isAnalyzing = false
    @State private var itemsToDelete: [DiskAnalyzer.FolderAnalysis] = []
    @State private var showDeleteConfirm = false
    @State private var isSelectionMode = false
    @State private var selectedItems: Set<String> = []
    @State private var copiedPath = false
    @State private var deleteError: String?
    @State private var showDeleteError = false
    @State private var evictMessage: String?
    @State private var showEvictAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    if cloudManager.isScanning {
                        ProgressView("Đang quét dịch vụ cloud...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else if cloudManager.detectedServices.isEmpty {
                        emptyState
                    } else {
                        detectedServicesSection
                        
                        if let selected = selectedService {
                            if selected.isAvailable {
                                cloudCleanupSection(selected)
                            } else {
                                unavailableServiceSection(selected)
                            }
                        }
                        
                        howItWorksSection
                    }
                }
                .padding(24)
            }
        }
        .background(Color(.windowBackgroundColor))
        .task {
            await cloudManager.detectCloudServices()
            if selectedService == nil {
                selectedService = cloudManager.detectedServices.first
            }
        }
        .confirmationDialog(
            "Xóa vĩnh viễn?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Xóa ngay", role: .destructive) {
                var deleteErrors: [String] = []
                for item in itemsToDelete {
                    do {
                        try cloudManager.deleteItem(at: item.path)
                    } catch {
                        deleteErrors.append("\(item.name): \(error.localizedDescription)")
                    }
                }
                
                if !deleteErrors.isEmpty {
                    deleteError = "Không thể xóa một số file:\n" + deleteErrors.joined(separator: "\n")
                    showDeleteError = true
                }
                
                // Refresh analysis after delete
                if let selected = selectedService {
                    Task {
                        cloudAnalysis = await cloudManager.analyzeCloudContents(at: selected.localPath)
                        selectedItems.removeAll()
                        isSelectionMode = false
                    }
                }
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            if itemsToDelete.count == 1 {
                Text("Mục \"\(itemsToDelete.first?.name ?? "")\" sẽ bị xóa vĩnh viễn khỏi Cloud.")
            } else {
                Text("\(itemsToDelete.count) mục đã chọn sẽ bị xóa vĩnh viễn khỏi Cloud.")
            }
        }
        .alert("Lỗi xóa file", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "Đã xảy ra lỗi không xác định.")
        }
        .alert("Thông báo", isPresented: $showEvictAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(evictMessage ?? "")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cloud Storage")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Quản lý & dọn dẹp dịch vụ lưu trữ đám mây")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                Task {
                    let selectedID = selectedService?.id
                    await cloudManager.detectCloudServices()
                    selectedService = cloudManager.detectedServices.first(where: { $0.id == selectedID }) ?? cloudManager.detectedServices.first
                }
            } label: {
                Label("Quét lại", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
    }
    
    // MARK: - Detected Services
    
    private var detectedServicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Trạng thái dịch vụ cloud", systemImage: "checkmark.icloud.fill")
                .font(.headline)
                .foregroundStyle(.blue)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(cloudManager.detectedServices) { service in
                    CloudServiceCard(
                        service: service,
                        isSelected: selectedService?.id == service.id
                    ) {
                        selectedService = service
                        cloudAnalysis = [] // Reset analysis when switching
                    }
                }
            }
        }
    }
    
    private func unavailableServiceSection(_ service: CloudStorageManager.CloudService) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
            
            Label("Kiểm tra kết nối: \(service.name)", systemImage: "exclamationmark.icloud.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 10) {
                Text(service.statusTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(service.statusDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                serviceSignalsSection(service)
                
                if !service.localPath.isEmpty {
                    Text("Đường dẫn dự kiến")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                if !service.localPath.isEmpty {
                    Text(service.localPath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.quaternary.opacity(0.4))
                        }
                }
                
                Text("Lưu ý: app chỉ kiểm tra thư mục sync local, tiến trình đồng bộ và app desktop trên macOS; không đọc trạng thái server của nhà cung cấp.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            HStack(spacing: 12) {
                if !service.isAvailable {
                    if service.id == "icloud" {
                        Button {
                            // Mở System Settings -> Apple ID
                            if let url = URL(string: "x-apple.systempreferences:com.apple.AppleIDSettings") {
                                NSWorkspace.shared.open(url)
                            } else if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.AppleID") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("Đăng nhập iCloud", systemImage: "person.crop.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    } else if service.isDesktopAppInstalled {
                        Button {
                            // Mở ứng dụng gốc để kích hoạt màn hình đăng nhập
                            NSWorkspace.shared.launchApplication(service.name)
                        } label: {
                            Label("Mở \(service.name) để Đăng nhập", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    } else if let downloadUrl = urlForDownloading(service.id) {
                        Button {
                            NSWorkspace.shared.open(downloadUrl)
                        } label: {
                            Label("Cài đặt \(service.name)", systemImage: "icloud.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                
                Button {
                    Task {
                        await cloudManager.detectCloudServices()
                        if let refreshed = cloudManager.detectedServices.first(where: { $0.id == service.id }) {
                            selectedService = refreshed
                        }
                    }
                } label: {
                    Label("Kiểm tra lại", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Users/\(NSUserName())/Library/CloudStorage"))
                } label: {
                    Label("Mở thư mục CloudStorage", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
        }
    }
    
    private func serviceSignalsSection(_ service: CloudStorageManager.CloudService) -> some View {
        VStack(spacing: 10) {
            SignalRow(
                title: "App desktop",
                value: service.isDesktopAppInstalled ? "Đã phát hiện" : "Chưa thấy",
                icon: service.isDesktopAppInstalled ? "app.badge.checkmark" : "app.dashed",
                tint: service.isDesktopAppInstalled ? .green : .orange
            )
            
            SignalRow(
                title: "Tiến trình sync",
                value: service.isSyncProcessRunning ? "Đang chạy" : "Không thấy",
                icon: service.isSyncProcessRunning ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle",
                tint: service.isSyncProcessRunning ? .green : .orange
            )
            
            SignalRow(
                title: "Thư mục sync local",
                value: service.isAvailable ? "Sẵn sàng" : service.doesSyncFolderExist ? "Có nhưng không đọc được" : "Chưa phát hiện",
                icon: service.isAvailable ? "folder.badge.checkmark" : service.doesSyncFolderExist ? "folder.badge.questionmark" : "folder.badge.minus",
                tint: service.isAvailable ? .green : .orange
            )
        }
    }
    
    // MARK: - Cleanup Section
    
    private func cloudCleanupSection(_ service: CloudStorageManager.CloudService) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
            
            HStack {
                Label("Dọn dẹp & Phân tích: \(service.name)", systemImage: "trash.fill")
                    .font(.headline)
                
                Spacer()
                
                if !cloudAnalysis.isEmpty {
                    Text("\(cloudAnalysis.count) mục")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.quaternary))
                }
                
                Button {
                    Task { @MainActor in
                        isAnalyzing = true
                        let results = await cloudManager.analyzeCloudContents(at: service.localPath)
                        cloudAnalysis = results
                        isAnalyzing = false
                    }
                } label: {
                    if isAnalyzing {
                        ProgressView().controlSize(.small).padding(.trailing, 4)
                        Text("Đang phân tích...")
                    } else {
                        Label("Phân tích Cloud", systemImage: "magnifyingglass")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAnalyzing)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Label(service.statusTitle, systemImage: service.statusSymbol)
                    .font(.subheadline)
                    .foregroundStyle(statusColor(for: service))
                
                Text(service.statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                serviceSignalsSection(service)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary.opacity(0.18))
            }
            
            if !cloudAnalysis.isEmpty {
                let sorted = Array(cloudAnalysis.sorted(by: { $0.sizeBytes > $1.sizeBytes }).prefix(15))
                
                // Total size summary
                let totalBytes = cloudAnalysis.reduce(Int64(0)) { $0 + $1.sizeBytes }
                HStack {
                    Label("Tổng dung lượng", systemImage: "chart.pie.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(totalBytes.formattedBytes)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.blue.opacity(0.08))
                }
                
                // Selection Toolbar
                HStack {
                    Label("Các thư mục chiếm dụng", systemImage: "folder.badge.minus")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSelectionMode.toggle()
                            selectedItems.removeAll()
                        }
                    } label: {
                        Text(isSelectionMode ? "Hủy chọn" : "Chọn nhiều")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    
                    if isSelectionMode {
                        Button {
                            if selectedItems.count == sorted.count {
                                selectedItems.removeAll()
                            } else {
                                selectedItems = Set(sorted.map { $0.path })
                            }
                        } label: {
                            Text(selectedItems.count == sorted.count ? "Bỏ chọn tất cả" : "Chọn tất cả")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)
                
                if isSelectionMode && !selectedItems.isEmpty {
                    VStack(spacing: 8) {
                        Button(role: .destructive) {
                            itemsToDelete = cloudAnalysis.filter { selectedItems.contains($0.path) }
                            showDeleteConfirm = true
                        } label: {
                            Label("Xóa vĩnh viễn \(selectedItems.count) mục", systemImage: "trash.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                        
                        Button {
                            let itemsToEvict = cloudAnalysis.filter { selectedItems.contains($0.path) }
                            var successCount = 0
                            var errorCount = 0
                            for item in itemsToEvict {
                                do {
                                    try cloudManager.evictItem(at: item.path)
                                    successCount += 1
                                } catch {
                                    errorCount += 1
                                }
                            }
                            if errorCount > 0 {
                                evictMessage = "Đã yêu cầu đẩy \(successCount) mục lên online. Có \(errorCount) mục thất bại (có thể chưa tải xong hoặc file không hợp lệ)."
                            } else {
                                evictMessage = "Đã yêu cầu OS đẩy \(successCount) mục lên online thành công. Bạn sẽ thấy biểu tượng đám mây xuất hiện ở Finder."
                            }
                            showEvictAlert = true
                        } label: {
                            Label("Tải lên Online (Free up space)", systemImage: "icloud.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        Button {
                            let itemsToDownload = cloudAnalysis.filter { selectedItems.contains($0.path) }
                            var successCount = 0
                            var errorCount = 0
                            for item in itemsToDownload {
                                do {
                                    try cloudManager.downloadItem(at: item.path)
                                    successCount += 1
                                } catch {
                                    errorCount += 1
                                }
                            }
                            if errorCount > 0 {
                                evictMessage = "Yêu cầu tải về \(successCount) mục. Có \(errorCount) mục thất bại."
                            } else {
                                evictMessage = "Đã yêu cầu OS tải về \(successCount) mục để lưu Offline."
                            }
                            showEvictAlert = true
                        } label: {
                            Label("Tải về máy (Keep Offline)", systemImage: "icloud.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(.green)
                    }
                    .padding(.vertical, 4)
                }
                
                VStack(spacing: 8) {
                    ForEach(sorted) { item in
                        CloudItemRow(
                            item: item,
                            isSelectionMode: isSelectionMode,
                            isSelected: selectedItems.contains(item.path),
                            onToggleSelect: {
                                if selectedItems.contains(item.path) {
                                    selectedItems.remove(item.path)
                                } else {
                                    selectedItems.insert(item.path)
                                }
                            },
                            onEvict: {
                                do {
                                    try cloudManager.evictItem(at: item.path)
                                    evictMessage = "Đã yêu cầu OS đẩy mục này lên online.\nXin chờ 1 chút để Finder cập nhật trạng thái."
                                } catch {
                                    evictMessage = "Không thể đẩy lên online: \(error.localizedDescription)"
                                }
                                showEvictAlert = true
                            },
                            onDownload: {
                                do {
                                    try cloudManager.downloadItem(at: item.path)
                                    evictMessage = "Đã yêu cầu OS tải mục này về lưu Offline.\nXin chờ 1 chút để dữ liệu được tải xong."
                                } catch {
                                    evictMessage = "Không thể tải về: \(error.localizedDescription)"
                                }
                                showEvictAlert = true
                            },
                            onDelete: {
                                itemsToDelete = [item]
                                showDeleteConfirm = true
                            }
                        )
                    }
                }
                .padding(4)
            } else if !isAnalyzing {
                Text("Nhấn 'Phân tích Cloud' để tìm các thư mục lớn đang chiếm chỗ trên \(service.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.quaternary, style: StrokeStyle(dash: [5]))
                    }
            }
            
            HStack(spacing: 12) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(service.localPath, forType: .string)
                    copiedPath = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedPath = false }
                } label: {
                    Label(copiedPath ? "Đã dán!" : "Copy đường dẫn", systemImage: copiedPath ? "checkmark.circle.fill" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: service.localPath))
                } label: {
                    Label("Mở trong Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            
            Text("Không tìm thấy dịch vụ cloud")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Hãy cài đặt iCloud Drive, Google Drive, Dropbox hoặc OneDrive để sử dụng tính năng này")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    // MARK: - How It Works
    
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Cách hoạt động", systemImage: "questionmark.circle")
                .font(.headline)
            
            VStack(spacing: 0) {
                StepRow(number: 1, text: "DataShuttle phát hiện thư mục sync local của cloud", icon: "magnifyingglass")
                Divider().padding(.leading, 48)
                StepRow(number: 2, text: "Shuttle thư mục vào đó (giống shuttle sang ổ ngoài)", icon: "arrow.right.circle")
                Divider().padding(.leading, 48)
                StepRow(number: 3, text: "Cloud tự đồng bộ lên server → truy cập mọi nơi", icon: "icloud.and.arrow.up")
                Divider().padding(.leading, 48)
                StepRow(number: 4, text: "Symlink giữ app hoạt động bình thường trên máy", icon: "link")
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            }
        }
    }
    
    // MARK: - Helpers
    
    // MARK: - Helpers
    
    private func urlForDownloading(_ serviceID: String) -> URL? {
        switch serviceID.lowercased() {
        case "googledrive", "gdrive": return URL(string: "https://www.google.com/drive/download/")
        case "dropbox": return URL(string: "https://www.dropbox.com/install")
        case "onedrive": return URL(string: "macappstore://apps.apple.com/app/onedrive/id823766827")
        default: return nil
        }
    }
    
    private func statusColor(for service: CloudStorageManager.CloudService) -> Color {
        switch service.status {
        case .connected:
            return .green
        case .syncFolderDetected:
            return .orange
        case .appDetected:
            return .yellow
        case .permissionIssue:
            return .red
        case .unavailable:
            return .gray
        }
    }
}

// MARK: - Cloud Service Card

struct CloudServiceCard: View {
    let service: CloudStorageManager.CloudService
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    private var serviceColor: Color {
        switch service.color {
        case "blue": return .blue
        case "green": return .green
        case "cyan": return .cyan
        case "purple": return .purple
        default: return .gray
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(serviceColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: service.icon)
                        .font(.title3)
                        .foregroundStyle(serviceColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .font(.callout)
                        .fontWeight(.semibold)
                    
                    Text(service.statusTitle)
                        .font(.caption)
                        .foregroundStyle(service.isAvailable ? .green : .orange)
                }
                
                Spacer()
                
                if service.isAvailable {
                    Text(service.usedBytes.formattedBytes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(serviceColor)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            }
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(serviceColor.opacity(0.08))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? serviceColor.opacity(0.3) : serviceColor.opacity(isHovered ? 0.15 : 0.05),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Helper Views

struct SignalRow: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(tint)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }
}

struct CloudItemRow: View {
    let item: DiskAnalyzer.FolderAnalysis
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelect: (() -> Void)? = nil
    var onEvict: (() -> Void)? = nil
    var onDownload: (() -> Void)? = nil
    let onDelete: () -> Void
    
    private var isDirectory: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir) && isDir.boolValue
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Button {
                    onToggleSelect?()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.blue : Color.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Image(systemName: isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(isDirectory ? .blue : .secondary)
                .frame(width: 24)
            
            Text(item.name)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer()
            
            Text(item.sizeBytes.formattedBytes)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            
            if !isSelectionMode {
                Button {
                    onDownload?()
                } label: {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.green)
                .padding(6)
                .background(.green.opacity(0.1))
                .clipShape(Circle())
                .help("Tải về máy (Keep Offline)")
                
                Button {
                    onEvict?()
                } label: {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .padding(6)
                .background(.blue.opacity(0.1))
                .clipShape(Circle())
                .help("Giải phóng dung lượng (Online-only)")
                
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .padding(6)
                .background(.red.opacity(0.1))
                .clipShape(Circle())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary.opacity(0.3))
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

struct StepRow: View {
    let number: Int
    let text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    CloudStorageView()
        .frame(width: 900, height: 700)
}
