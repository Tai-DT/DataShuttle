import SwiftUI
import SwiftData
import AppKit

@main
struct DataShuttleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
    @State private var driveMonitor = DriveMonitor()
    @State private var scheduledProfileService = FileShuttleService()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ShuttleItem.self,
            BookmarkItem.self,
            SyncProfile.self,
            StorageSnapshot.self,
        ])

        do {
            let storeURL = try makeStoreURL()
            let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, L10n.locale(for: appLanguage))
                .onAppear {
                    NotificationManager.shared.configureAuthorizationIfNeeded()
                    driveMonitor.startMonitoring()
                    setupScheduledShuttle()
                }
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 750)
        
        // Menu Bar Widget
        MenuBarExtra("DataShuttle", systemImage: "arrow.left.arrow.right.circle.fill") {
            MenuBarView()
                .environment(\.locale, L10n.locale(for: appLanguage))
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)
    }
    
    private static func makeStoreURL() throws -> URL {
        let fileManager = FileManager.default
        
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        
        let storeDirectoryURL = applicationSupportURL.appendingPathComponent("DataShuttleDB", isDirectory: true)
        
        try fileManager.createDirectory(
            at: storeDirectoryURL,
            withIntermediateDirectories: true
        )
        
        return storeDirectoryURL.appendingPathComponent("DataShuttle.sqlite", isDirectory: false)
    }
    
    private func setupScheduledShuttle() {
        driveMonitor.onDriveMount = { volumeName, _ in
            // Check for auto-trigger profiles
            let context = sharedModelContainer.mainContext
            let descriptor = FetchDescriptor<SyncProfile>()
            
            guard let profiles = try? context.fetch(descriptor) else { return }
            
            let matching = profiles.filter {
                $0.isEnabled && $0.triggerVolumeName == volumeName
            }
            
            guard !matching.isEmpty else { return }
            
            Task {
                for profile in matching {
                    let autoStartTitle = String(
                        format: L10n.tr("⚡ Auto Shuttle: %@", languageCode: appLanguage),
                        profile.name
                    )
                    let autoStartBody = String(
                        format: L10n.tr("Ổ \"%@\" đã cắm — đang chạy profile tự động.", languageCode: appLanguage),
                        volumeName
                    )

                    NotificationManager.shared.send(
                        title: autoStartTitle,
                        body: autoStartBody,
                        identifier: "auto-shuttle-start-\(profile.name)"
                    )
                    
                    let result = await scheduledProfileService.executeProfile(
                        profile,
                        modelContext: context
                    )
                    
                    let autoCompleteTitle = String(
                        format: L10n.tr("✅ Auto Shuttle xong: %@", languageCode: appLanguage),
                        profile.name
                    )
                    let autoCompleteBody = String(
                        format: L10n.tr("%d thư mục: %@", languageCode: appLanguage),
                        result.totalCount,
                        result.summary
                    )

                    NotificationManager.shared.send(
                        title: autoCompleteTitle,
                        body: autoCompleteBody,
                        identifier: "auto-shuttle-complete-\(profile.name)-\(UUID().uuidString)"
                    )
                }
            }
        }
    }
}

// MARK: - Menu Bar Widget View

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
    @Query(filter: #Predicate<ShuttleItem> { $0.statusRaw == "shuttled" })
    private var shuttledItems: [ShuttleItem]
    
    @State private var volumeManager = VolumeManager()
    
    var totalSaved: Int64 {
        shuttledItems.reduce(0) { $0 + $1.sizeBytes }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .foregroundStyle(.blue)
                Text("DataShuttle")
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            // Quick stats
            VStack(spacing: 8) {
                MenuBarStatRow(icon: "folder.fill", label: L10n.tr("Đang quản lý", languageCode: appLanguage), value: "\(shuttledItems.count) thư mục")
                MenuBarStatRow(icon: "arrow.down.heart.fill", label: L10n.tr("Đã tiết kiệm", languageCode: appLanguage), value: totalSaved.formattedBytes)
                MenuBarStatRow(icon: "externaldrive.fill", label: L10n.tr("Ổ kết nối", languageCode: appLanguage), value: "\(volumeManager.volumes.count)")
            }
            
            Divider()
            
            // Volumes
            if !volumeManager.volumes.isEmpty {
                Text(L10n.tr("Ổ đĩa", languageCode: appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(volumeManager.volumes.prefix(4)) { volume in
                    HStack {
                        Image(systemName: volume.volumeIcon)
                            .font(.caption)
                            .foregroundStyle(volume.isMainDrive ? .blue : .purple)
                        Text(volume.name)
                            .font(.caption)
                        Spacer()
                        Text("\(Int(volume.usagePercentage * 100))%")
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(volume.usagePercentage > 0.9 ? .red : .green)
                    }
                }
            }
            
            Divider()
            
            // Open main window
            Button {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title.contains("DataShuttle") || $0.isKeyWindow == false }) {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                Label(L10n.tr("Mở DataShuttle", languageCode: appLanguage), systemImage: "macwindow")
            }
            
            Button {
                NSApp.terminate(nil)
            } label: {
                Label(L10n.tr("Thoát", languageCode: appLanguage), systemImage: "power")
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            volumeManager.refreshVolumes()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        false
    }
    
    func application(_ application: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        false
    }
}

struct MenuBarStatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}
