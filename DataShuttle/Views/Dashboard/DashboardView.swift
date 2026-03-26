import SwiftUI
import SwiftData

/// Main dashboard view showing storage overview
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<ShuttleItem> { $0.statusRaw == "shuttled" })
    private var shuttledItems: [ShuttleItem]
    
    var onOpenShuttle: (() -> Void)? = nil
    var onOpenImport: (() -> Void)? = nil
    var onOpenHealthCheck: (() -> Void)? = nil
    var onOpenCloud: (() -> Void)? = nil
    var onOpenAnalytics: (() -> Void)? = nil
    
    @State private var viewModel = DashboardViewModel()
    
    private let volumeColors: [Color] = [
        .blue, .purple, .orange, .green, .pink, .cyan
    ]
    
    private var secondaryVolumeCount: Int {
        viewModel.volumeManager.secondaryVolumes.count
    }
    
    private var totalSavedBytes: Int64 {
        shuttledItems.reduce(0) { $0 + $1.sizeBytes }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                statusBannerSection
                workflowSection
                quickStatsSection
                volumesSection
                if !shuttledItems.isEmpty {
                    recentShuttledSection
                }
            }
            .padding(24)
        }
        .background(Color(.windowBackgroundColor))
        .onAppear {
            viewModel.refresh()
            viewModel.updateStats(items: shuttledItems)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Trung tâm điều phối")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Bắt đầu nhanh với shuttle, import và kiểm tra trạng thái lưu trữ.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    DashboardHeaderPill(
                        title: secondaryVolumeCount == 0 ? "Chưa có ổ phụ" : "\(secondaryVolumeCount) ổ phụ sẵn sàng",
                        icon: secondaryVolumeCount == 0 ? "externaldrive.badge.minus" : "externaldrive.fill",
                        color: secondaryVolumeCount == 0 ? .orange : .blue
                    )
                    
                    DashboardHeaderPill(
                        title: "\(shuttledItems.count) thư mục đang quản lý",
                        icon: "folder.fill.badge.gearshape",
                        color: .green
                    )
                }
            }
            
            Spacer()
            
            Button {
                viewModel.refresh()
            } label: {
                Label("Làm mới", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Status Banner
    
    private var statusBannerSection: some View {
        Group {
            if secondaryVolumeCount == 0 {
                DashboardStatusBanner(
                    title: "Chưa có đích lưu trữ ngoài máy",
                    message: "Kết nối ổ ngoài hoặc dùng thư mục cloud để bắt đầu shuttle dữ liệu lớn khỏi SSD chính.",
                    icon: "externaldrive.badge.plus",
                    gradient: [.orange, .yellow],
                    actionTitle: "Mở Cloud",
                    action: onOpenCloud
                )
            } else if shuttledItems.isEmpty {
                DashboardStatusBanner(
                    title: "Hệ thống đã sẵn sàng để shuttle",
                    message: "Bạn đã có đích lưu trữ. Bước tiếp theo là chọn thư mục lớn như Downloads, Movies hoặc Library/Developer.",
                    icon: "arrow.right.circle.fill",
                    gradient: [.blue, .cyan],
                    actionTitle: "Mở Shuttle",
                    action: onOpenShuttle
                )
            } else {
                DashboardStatusBanner(
                    title: "Luồng lưu trữ đang hoạt động ổn định",
                    message: "Bạn đang giải phóng \(totalSavedBytes.formattedBytes) trên ổ chính. Hãy kiểm tra Health Check định kỳ để giữ symlink luôn lành.",
                    icon: "checkmark.seal.fill",
                    gradient: [.green, .mint],
                    actionTitle: "Mở Health Check",
                    action: onOpenHealthCheck
                )
            }
        }
    }
    
    // MARK: - Workflow
    
    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Bắt đầu nhanh")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Luồng cốt lõi")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                WorkflowActionCard(
                    title: "Đưa dữ liệu ra ổ phụ",
                    detail: "Phân tích thư mục lớn và shuttle có kiểm soát.",
                    icon: "arrow.right.circle.fill",
                    gradient: [.purple, .indigo],
                    actionTitle: "Mở Shuttle",
                    action: onOpenShuttle
                )
                
                WorkflowActionCard(
                    title: "Nhập dữ liệu về máy",
                    detail: "Kéo dữ liệu từ ổ phụ về SSD và chọn giữ hay xoá nguồn.",
                    icon: "arrow.left.circle.fill",
                    gradient: [.orange, .yellow],
                    actionTitle: "Mở Import",
                    action: onOpenImport
                )
                
                WorkflowActionCard(
                    title: "Kiểm tra liên kết",
                    detail: "Quét symlink hỏng, phát hiện ổ bị ngắt và sửa nhanh.",
                    icon: "stethoscope",
                    gradient: [.green, .mint],
                    actionTitle: "Mở Health Check",
                    action: onOpenHealthCheck
                )
                
                WorkflowActionCard(
                    title: "Dùng đích cloud",
                    detail: "Phát hiện thư mục sync local để shuttle trực tiếp vào cloud.",
                    icon: "icloud.fill",
                    gradient: [.blue, .cyan],
                    actionTitle: "Mở Cloud",
                    action: onOpenCloud
                )
            }
        }
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Đã chuyển",
                value: "\(shuttledItems.count)",
                subtitle: "thư mục",
                icon: "folder.fill.badge.gearshape",
                gradient: [.blue, .cyan],
                actionTitle: "Mở Shuttle",
                action: onOpenShuttle
            )
            
            StatCard(
                title: "Tiết kiệm",
                value: totalSavedBytes.formattedBytes,
                subtitle: "dung lượng ổ chính",
                icon: "arrow.down.circle.fill",
                gradient: [.green, .mint],
                actionTitle: "Mở Phân tích",
                action: onOpenAnalytics
            )
            
            StatCard(
                title: "Ổ đĩa",
                value: "\(viewModel.volumeManager.volumes.count)",
                subtitle: "đang kết nối",
                icon: "externaldrive.fill",
                gradient: [.purple, .indigo],
                actionTitle: "Mở Cloud",
                action: onOpenCloud
            )
        }
    }
    
    // MARK: - Volumes
    
    private var volumesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ổ đĩa")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(Array(viewModel.volumeManager.volumes.enumerated()), id: \.element.id) { index, volume in
                    VolumeCard(
                        volume: volume,
                        accentColor: volumeColors[index % volumeColors.count],
                        actionTitle: "Mở Phân tích",
                        action: onOpenAnalytics
                    )
                }
            }
        }
    }
    
    // MARK: - Recent Shuttled
    
    private var recentShuttledSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Đã chuyển gần đây")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(shuttledItems.count) thư mục")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 8) {
                ForEach(shuttledItems.prefix(5)) { item in
                    ShuttledItemRow(item: item)
                }
            }
        }
    }
}

// MARK: - Stat Card

struct DashboardHeaderPill: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.caption)
        .fontWeight(.medium)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

struct DashboardStatusBanner: View {
    let title: String
    let message: String
    let icon: String
    let gradient: [Color]
    let actionTitle: String?
    let action: (() -> Void)?
    
    private var hasAction: Bool {
        actionTitle != nil && action != nil
    }
    
    var body: some View {
        Group {
            if let actionTitle, let action {
                Button(action: action) {
                    bannerContent(actionTitle: actionTitle)
                }
                .buttonStyle(.plain)
            } else {
                bannerContent(actionTitle: nil)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func bannerContent(actionTitle: String?) -> some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 62, height: 62)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let actionTitle {
                HStack(spacing: 8) {
                    Text(actionTitle)
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.16))
                .foregroundStyle(.primary)
                .clipShape(Capsule())
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(gradient[0].opacity(0.18), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

struct WorkflowActionCard: View {
    let title: String
    let detail: String
    let icon: String
    let gradient: [Color]
    let actionTitle: String
    let action: (() -> Void)?
    
    @State private var isHovered = false
    
    private var hasAction: Bool {
        action != nil
    }
    
    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .scaleEffect(isHovered && hasAction ? 1.01 : 1.0)
        .animation(.spring(response: 0.28), value: isHovered)
        .onHover { hovering in
            isHovered = hasAction && hovering
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: icon)
                        .foregroundStyle(.white)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if hasAction {
                HStack(spacing: 8) {
                    Text(actionTitle)
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(gradient[0].opacity(0.12))
                .foregroundStyle(gradient[0])
                .clipShape(Capsule())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .shadow(color: gradient[0].opacity(isHovered ? 0.16 : 0), radius: 12, y: 4)
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(gradient[0].opacity(isHovered ? 0.22 : 0.1), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let actionTitle: String?
    let action: (() -> Void)?
    
    @State private var isHovered = false
    
    private var hasAction: Bool {
        actionTitle != nil && action != nil
    }
    
    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isHovered && hasAction ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hasAction && hovering
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                Spacer()
                
                if hasAction {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let actionTitle {
                Text(actionTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(gradient[0])
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: gradient[0].opacity(isHovered ? 0.2 : 0), radius: 12, y: 4)
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(gradient[0].opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Volume Card

struct VolumeCard: View {
    let volume: VolumeInfo
    let accentColor: Color
    let actionTitle: String?
    let action: (() -> Void)?
    
    @State private var isHovered = false
    
    private var hasAction: Bool {
        actionTitle != nil && action != nil
    }
    
    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isHovered && hasAction ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hasAction && hovering
        }
    }
    
    private var cardContent: some View {
        VStack(spacing: 16) {
            StorageRingView(
                usedBytes: volume.usedBytes,
                totalBytes: volume.totalBytes,
                volumeName: volume.name,
                accentColor: accentColor
            )
            
            HStack {
                Image(systemName: volume.volumeIcon)
                    .foregroundStyle(accentColor)
                
                Text(volume.displayType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("Tổng: \(volume.totalBytes.formattedBytes)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("Trống: \(volume.availableBytes.formattedBytes)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            if let actionTitle {
                HStack(spacing: 6) {
                    Text(actionTitle)
                    Image(systemName: "arrow.right")
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(accentColor)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: 8, y: 2)
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Shuttled Item Row

struct ShuttledItemRow: View {
    let item: ShuttleItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.folderName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(item.originalPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.sizeBytes.formattedBytes)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Text(item.shuttledAt.relativeString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(.green)
            
            Text(item.destinationVolume)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.green.opacity(0.1))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: ShuttleItem.self, inMemory: true)
        .frame(width: 900, height: 700)
}
