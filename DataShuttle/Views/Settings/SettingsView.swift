import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
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
                        Text(L10n.tr("Cài đặt", languageCode: appLanguage))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(L10n.tr("Tùy chỉnh DataShuttle", languageCode: appLanguage))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                settingsSection(title: L10n.tr("Ngôn ngữ", languageCode: appLanguage), icon: "globe") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.tr("Chọn ngôn ngữ hiển thị cho ứng dụng", languageCode: appLanguage))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker(L10n.tr("Ngôn ngữ", languageCode: appLanguage), selection: $appLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName)
                                    .tag(language.rawValue)
                            }
                        }
                        .labelsHidden()

                        Text(L10n.tr("Ngôn ngữ sẽ được áp dụng ngay lập tức trên các màn hình đã hỗ trợ.", languageCode: appLanguage))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }

                // General settings
                settingsSection(title: L10n.tr("Chung", languageCode: appLanguage), icon: "gearshape.fill") {
                    settingsToggle(
                        title: L10n.tr("Xác nhận trước khi chuyển", languageCode: appLanguage),
                        subtitle: L10n.tr("Hiện hộp thoại xác nhận trước mỗi thao tác", languageCode: appLanguage),
                        isOn: $confirmBeforeShuttle
                    )
                    
                    Divider()
                    
                    settingsToggle(
                        title: L10n.tr("Tự động làm mới ổ đĩa", languageCode: appLanguage),
                        subtitle: L10n.tr("Tự động phát hiện ổ đĩa mới kết nối", languageCode: appLanguage),
                        isOn: $autoRefreshVolumes
                    )
                    
                    Divider()
                    
                    settingsToggle(
                        title: L10n.tr("Hiện file ẩn", languageCode: appLanguage),
                        subtitle: L10n.tr("Hiển thị các thư mục bắt đầu bằng dấu chấm (.)", languageCode: appLanguage),
                        isOn: $showHiddenFiles
                    )
                }
                
                // Safety settings
                settingsSection(title: L10n.tr("An toàn", languageCode: appLanguage), icon: "shield.fill") {
                    settingsToggle(
                        title: L10n.tr("Tạo bản sao trước khi chuyển", languageCode: appLanguage),
                        subtitle: L10n.tr("Đảm bảo an toàn dữ liệu khi di chuyển", languageCode: appLanguage),
                        isOn: $createBackup
                    )
                }
                
                // About section
                settingsSection(title: L10n.tr("Về DataShuttle", languageCode: appLanguage), icon: "info.circle.fill") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DataShuttle")
                                .font(.headline)
                            Text("\(L10n.tr("Phiên bản", languageCode: appLanguage)) 1.0.0")
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
                        Text(L10n.tr("DataShuttle giúp bạn tối ưu dung lượng ổ đĩa chính bằng cách di chuyển thư mục sang ổ phụ và tạo symlink để các ứng dụng vẫn hoạt động bình thường.", languageCode: appLanguage))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(L10n.tr("⚡ Tận dụng hiệu năng SSD chính cho hệ thống", languageCode: appLanguage))
                            .font(.caption)
                        Text(L10n.tr("💾 Lưu trữ dữ liệu lớn trên ổ phụ", languageCode: appLanguage))
                            .font(.caption)
                        Text(L10n.tr("🔗 Symlink giữ mọi thứ hoạt động bình thường", languageCode: appLanguage))
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
