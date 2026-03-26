import SwiftUI
import SwiftData
import Charts

/// Storage analytics view with charts
struct StorageAnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StorageSnapshot.date, order: .reverse) private var snapshots: [StorageSnapshot]
    @Query(filter: #Predicate<ShuttleItem> { $0.statusRaw == "shuttled" })
    private var shuttledItems: [ShuttleItem]
    
    @State private var volumeManager = VolumeManager()
    
    var totalSaved: Int64 {
        shuttledItems.reduce(0) { $0 + $1.sizeBytes }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    savingsOverview
                    storageBreakdownChart
                    shuttledItemsChart
                    volumeComparisonChart
                }
                .padding(24)
            }
        }
        .background(Color(.windowBackgroundColor))
        .onAppear {
            volumeManager.refreshVolumes()
            recordSnapshot()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Phân tích")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Thống kê dung lượng và hiệu quả")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                recordSnapshot()
            } label: {
                Label("Ghi nhận", systemImage: "camera.fill")
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
    }
    
    // MARK: - Savings Overview
    
    private var savingsOverview: some View {
        HStack(spacing: 16) {
            AnalyticsCard(
                title: "Đã tiết kiệm",
                value: totalSaved.formattedBytes,
                subtitle: "dung lượng ổ chính",
                icon: "arrow.down.heart.fill",
                gradient: [.green, .mint]
            )
            
            AnalyticsCard(
                title: "Thư mục đã chuyển",
                value: "\(shuttledItems.count)",
                subtitle: "đang quản lý",
                icon: "folder.fill.badge.gearshape",
                gradient: [.blue, .cyan]
            )
            
            AnalyticsCard(
                title: "Ổ đĩa",
                value: "\(volumeManager.volumes.count)",
                subtitle: "đang kết nối",
                icon: "externaldrive.fill",
                gradient: [.purple, .indigo]
            )
            
            AnalyticsCard(
                title: "Snapshots",
                value: "\(snapshots.count)",
                subtitle: "đã ghi nhận",
                icon: "chart.line.uptrend.xyaxis",
                gradient: [.orange, .yellow]
            )
        }
    }
    
    // MARK: - Storage Breakdown Chart
    
    private var storageBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Dung lượng theo ổ đĩa", systemImage: "chart.bar.fill")
                .font(.headline)
            
            if volumeManager.volumes.isEmpty {
                Text("Không có dữ liệu")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(volumeManager.volumes) { volume in
                    BarMark(
                        x: .value("Ổ đĩa", volume.name),
                        y: .value("Đã dùng", Double(volume.usedBytes) / 1_073_741_824)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(6)
                    
                    BarMark(
                        x: .value("Ổ đĩa", volume.name),
                        y: .value("Trống", Double(volume.availableBytes) / 1_073_741_824)
                    )
                    .foregroundStyle(.green.opacity(0.3).gradient)
                    .cornerRadius(6)
                }
                .chartYAxisLabel("GB")
                .frame(height: 250)
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                }
            }
        }
    }
    
    // MARK: - Shuttled Items by Size
    
    private var shuttledItemsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Thư mục đã shuttle (theo dung lượng)", systemImage: "chart.pie.fill")
                .font(.headline)
            
            if shuttledItems.isEmpty {
                Text("Chưa có thư mục nào được shuttle")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(shuttledItems) { item in
                    SectorMark(
                        angle: .value("Size", item.sizeBytes),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Folder", item.folderName))
                    .cornerRadius(4)
                }
                .frame(height: 280)
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                }
            }
        }
    }
    
    // MARK: - Volume comparison
    
    private var volumeComparisonChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tỷ lệ sử dụng", systemImage: "gauge.with.dots.needle.bottom.50percent")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(volumeManager.volumes) { volume in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: volume.volumeIcon)
                                .foregroundStyle(volume.isMainDrive ? .blue : .purple)
                            Text(volume.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(Int(volume.usagePercentage * 100))%")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(volume.usagePercentage > 0.9 ? .red : volume.usagePercentage > 0.7 ? .orange : .green)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.quaternary)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: volume.usagePercentage > 0.9 ? [.red, .orange] :
                                                    volume.usagePercentage > 0.7 ? [.orange, .yellow] :
                                                    [.green, .mint],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * volume.usagePercentage)
                            }
                        }
                        .frame(height: 8)
                        
                        HStack {
                            Text("Đã dùng: \(volume.usedBytes.formattedBytes)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Trống: \(volume.availableBytes.formattedBytes)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            }
        }
    }
    
    // MARK: - Record Snapshot
    
    private func recordSnapshot() {
        for volume in volumeManager.volumes {
            let snapshot = StorageSnapshot(
                volumeName: volume.name,
                totalBytes: volume.totalBytes,
                usedBytes: volume.usedBytes,
                availableBytes: volume.availableBytes,
                shuttledBytes: totalSaved
            )
            modelContext.insert(snapshot)
        }
        try? modelContext.save()
    }
}

// MARK: - Analytics Card

struct AnalyticsCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            Spacer()
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .shadow(color: gradient[0].opacity(isHovered ? 0.15 : 0), radius: 8, y: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(gradient[0].opacity(isHovered ? 0.2 : 0.08), lineWidth: 1)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in isHovered = hovering }
    }
}

#Preview {
    StorageAnalyticsView()
        .modelContainer(for: [ShuttleItem.self, StorageSnapshot.self], inMemory: true)
        .frame(width: 900, height: 800)
}
