import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @AppStorage("defaultSourcePath") private var defaultSourcePath: String = "~"
    @AppStorage("createBackupBeforeShuttle") private var createBackup: Bool = true
    @AppStorage("showHiddenFiles") private var showHiddenFiles: Bool = false
    @AppStorage("confirmBeforeShuttle") private var confirmBeforeShuttle: Bool = true
    @AppStorage("autoRefreshVolumes") private var autoRefreshVolumes: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cài đặt")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Tùy chỉnh DataShuttle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                // General settings
                settingsSection(title: "Chung", icon: "gearshape.fill") {
                    settingsToggle(
                        title: "Xác nhận trước khi chuyển",
                        subtitle: "Hiện hộp thoại xác nhận trước mỗi thao tác",
                        isOn: $confirmBeforeShuttle
                    )
                    
                    Divider()
                    
                    settingsToggle(
                        title: "Tự động làm mới ổ đĩa",
                        subtitle: "Tự động phát hiện ổ đĩa mới kết nối",
                        isOn: $autoRefreshVolumes
                    )
                    
                    Divider()
                    
                    settingsToggle(
                        title: "Hiện file ẩn",
                        subtitle: "Hiển thị các thư mục bắt đầu bằng dấu chấm (.)",
                        isOn: $showHiddenFiles
                    )
                }
                
                // Safety settings
                settingsSection(title: "An toàn", icon: "shield.fill") {
                    settingsToggle(
                        title: "Tạo bản sao trước khi chuyển",
                        subtitle: "Đảm bảo an toàn dữ liệu khi di chuyển",
                        isOn: $createBackup
                    )
                }
                
                // About section
                settingsSection(title: "Về DataShuttle", icon: "info.circle.fill") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DataShuttle")
                                .font(.headline)
                            Text("Phiên bản 1.0.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DataShuttle giúp bạn tối ưu dung lượng ổ đĩa chính bằng cách di chuyển thư mục sang ổ phụ và tạo symlink để các ứng dụng vẫn hoạt động bình thường.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("⚡ Tận dụng hiệu năng SSD chính cho hệ thống")
                            .font(.caption)
                        Text("💾 Lưu trữ dữ liệu lớn trên ổ phụ")
                            .font(.caption)
                        Text("🔗 Symlink giữ mọi thứ hoạt động bình thường")
                            .font(.caption)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Components
    
    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
            
            VStack(spacing: 0) {
                content()
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            }
        }
    }
    
    private func settingsToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .frame(width: 600, height: 700)
}
