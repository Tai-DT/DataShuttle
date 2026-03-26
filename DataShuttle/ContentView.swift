import SwiftUI
import SwiftData

/// Main navigation view with sidebar
struct ContentView: View {
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
    @State private var selectedTab: SidebarTab = .dashboard
    
    enum SidebarTab: String, CaseIterable, Identifiable {
        case dashboard = "dashboard"
        case shuttle = "shuttle"
        case importView = "import"
        case bookmarks = "bookmarks"
        case syncProfiles = "profiles"
        case cloud = "cloud"
        case healthCheck = "healthCheck"
        case analytics = "analytics"
        case settings = "settings"
        
        var id: String { rawValue }
        
        func title(languageCode: String) -> String {
            switch self {
            case .dashboard: return L10n.tr("Tổng quan", languageCode: languageCode)
            case .shuttle: return L10n.tr("Shuttle", languageCode: languageCode)
            case .importView: return L10n.tr("Import", languageCode: languageCode)
            case .bookmarks: return L10n.tr("Ghi nhớ", languageCode: languageCode)
            case .syncProfiles: return L10n.tr("Tác vụ nhóm", languageCode: languageCode)
            case .cloud: return L10n.tr("Cloud", languageCode: languageCode)
            case .healthCheck: return L10n.tr("Health Check", languageCode: languageCode)
            case .analytics: return L10n.tr("Phân tích", languageCode: languageCode)
            case .settings: return L10n.tr("Cài đặt", languageCode: languageCode)
            }
        }
        
        func subtitle(languageCode: String) -> String {
            switch self {
            case .dashboard: return L10n.tr("Bắt đầu từ các luồng chính", languageCode: languageCode)
            case .shuttle: return L10n.tr("Đẩy dữ liệu sang ổ phụ hoặc cloud", languageCode: languageCode)
            case .importView: return L10n.tr("Đưa dữ liệu về lại máy chính", languageCode: languageCode)
            case .bookmarks: return L10n.tr("Lối tắt cho thư mục hay dùng", languageCode: languageCode)
            case .syncProfiles: return L10n.tr("Chạy theo nhóm thư mục", languageCode: languageCode)
            case .cloud: return L10n.tr("Phát hiện đích đồng bộ đám mây", languageCode: languageCode)
            case .healthCheck: return L10n.tr("Kiểm tra symlink và ổ đĩa", languageCode: languageCode)
            case .analytics: return L10n.tr("Theo dõi hiệu quả lưu trữ", languageCode: languageCode)
            case .settings: return L10n.tr("Tùy chỉnh hành vi ứng dụng", languageCode: languageCode)
            }
        }
        
        var icon: String {
            switch self {
            case .dashboard: return "gauge.with.dots.needle.33percent"
            case .shuttle: return "arrow.right.circle.fill"
            case .importView: return "arrow.left.circle.fill"
            case .bookmarks: return "bookmark.fill"
            case .syncProfiles: return "rectangle.stack.fill"
            case .cloud: return "icloud.fill"
            case .healthCheck: return "stethoscope"
            case .analytics: return "chart.bar.fill"
            case .settings: return "gearshape.fill"
            }
        }
        
        var gradient: [Color] {
            switch self {
            case .dashboard: return [.blue, .cyan]
            case .shuttle: return [.purple, .indigo]
            case .importView: return [.orange, .yellow]
            case .bookmarks: return [.pink, .red]
            case .syncProfiles: return [.teal, .mint]
            case .cloud: return [.blue, .indigo]
            case .healthCheck: return [.green, .mint]
            case .analytics: return [.orange, .pink]
            case .settings: return [.gray, .secondary]
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 300)
        } detail: {
            detailView
        }
        .frame(minWidth: 1120, minHeight: 700)
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            // App branding
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .blue.opacity(0.3), radius: 8, y: 2)
                
                Text("DataShuttle")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(L10n.tr("Điều phối dữ liệu giữa SSD, ổ ngoài và cloud", languageCode: appLanguage))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 20)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Navigation items
            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    // Main section
                    SidebarSectionHeader(title: L10n.tr("CHÍNH", languageCode: appLanguage))
                    SidebarButton(tab: .dashboard, languageCode: appLanguage, isSelected: selectedTab == .dashboard) {
                        withAnimation(.spring(response: 0.3)) { selectedTab = .dashboard }
                    }
                    
                    // Transfer section
                    SidebarSectionHeader(title: L10n.tr("CHUYỂN DỮ LIỆU", languageCode: appLanguage))
                    SidebarButton(tab: .shuttle, languageCode: appLanguage, isSelected: selectedTab == .shuttle) {
                        withAnimation(.spring(response: 0.3)) { selectedTab = .shuttle }
                    }
                    SidebarButton(tab: .importView, languageCode: appLanguage, isSelected: selectedTab == .importView) {
                        withAnimation(.spring(response: 0.3)) { selectedTab = .importView }
                    }
                    SidebarButton(tab: .bookmarks, languageCode: appLanguage, isSelected: selectedTab == .bookmarks) {
                        withAnimation(.spring(response: 0.3)) { selectedTab = .bookmarks }
                    }
                    SidebarButton(tab: .syncProfiles, languageCode: appLanguage, isSelected: selectedTab == .syncProfiles) {
                        withAnimation(.spring(response: 0.3)) { selectedTab = .syncProfiles }
                    }
                    
                    // Cloud & Storage
                    SidebarSectionHeader(title: L10n.tr("LƯU TRỮ", languageCode: appLanguage))
                    SidebarButton(tab: .cloud, languageCode: appLanguage, isSelected: selectedTab == .cloud) {
                        withAnimation(.spring(response: 0.3)) { selectedTab = .cloud }
                    }
                    SidebarButton(tab: .analytics, languageCode: appLanguage, isSelected: selectedTab == .analytics) {
                        withAnimation(.spring(response: 0.3)) { selectedTab = .analytics }
                    }
                    
                    // System section
                    SidebarSectionHeader(title: L10n.tr("HỆ THỐNG", languageCode: appLanguage))
                    SidebarButton(tab: .healthCheck, languageCode: appLanguage, isSelected: selectedTab == .healthCheck) {
                        withAnimation(.spring(response: 0.3)) { selectedTab = .healthCheck }
                    }
                    SidebarButton(tab: .settings, languageCode: appLanguage, isSelected: selectedTab == .settings) {
                        withAnimation(.spring(response: 0.3)) { selectedTab = .settings }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
            
            Spacer()
            
            // Version info
            VStack(spacing: 4) {
                Divider()
                    .padding(.horizontal, 16)
                
                VStack(spacing: 2) {
                    Text("v1.1.0")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                    Text(L10n.tr("Luồng chính ưu tiên tốc độ thao tác", languageCode: appLanguage))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(.windowBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Detail View
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView(
                onOpenShuttle: { withAnimation(.spring(response: 0.3)) { selectedTab = .shuttle } },
                onOpenImport: { withAnimation(.spring(response: 0.3)) { selectedTab = .importView } },
                onOpenHealthCheck: { withAnimation(.spring(response: 0.3)) { selectedTab = .healthCheck } },
                onOpenCloud: { withAnimation(.spring(response: 0.3)) { selectedTab = .cloud } },
                onOpenAnalytics: { withAnimation(.spring(response: 0.3)) { selectedTab = .analytics } }
            )
        case .shuttle:
            ShuttleView()
        case .importView:
            ImportView()
        case .bookmarks:
            BookmarksView()
        case .syncProfiles:
            SyncProfilesView()
        case .cloud:
            CloudStorageView()
        case .healthCheck:
            HealthCheckView()
        case .analytics:
            StorageAnalyticsView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Sidebar Section Header

struct SidebarSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
}

// MARK: - Sidebar Button

struct SidebarButton: View {
    let tab: ContentView.SidebarTab
    let languageCode: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            isSelected
                            ? LinearGradient(colors: tab.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [.secondary.opacity(isHovered ? 0.16 : 0.08)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: tab.icon)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.title(languageCode: languageCode))
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                    
                    Text(tab.subtitle(languageCode: languageCode))
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .secondary : .tertiary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(tab.gradient[0])
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected
                        ? tab.gradient[0].opacity(0.12)
                        : isHovered ? Color.secondary.opacity(0.08) : .clear
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? tab.gradient[0].opacity(0.18) : .clear,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ShuttleItem.self, BookmarkItem.self, SyncProfile.self, StorageSnapshot.self], inMemory: true)
}
