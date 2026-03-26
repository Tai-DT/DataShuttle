import SwiftUI
import SwiftData

/// Health check view — scan and fix broken symlinks
struct HealthCheckView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<ShuttleItem> { $0.statusRaw == "shuttled" })
    private var shuttledItems: [ShuttleItem]
    
    @State private var healthService = HealthCheckService()
    @State private var fixingId: UUID?
    @State private var showFixResult = false
    @State private var fixResultMessage = ""
    @State private var fixResultIsError = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    statusOverviewCard
                    
                    if !healthService.results.isEmpty {
                        resultsSection
                    } else if !healthService.isScanning {
                        emptyState
                    }
                }
                .padding(24)
            }
        }
        .background(Color(.windowBackgroundColor))
        .alert(fixResultIsError ? "Lỗi" : "Thành công", isPresented: $showFixResult) {
            Button("OK") {}
        } message: {
            Text(fixResultMessage)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Health Check")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Kiểm tra tình trạng symlink và ổ đĩa")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                Task { await healthService.scan(items: shuttledItems) }
            } label: {
                Label(healthService.isScanning ? "Đang quét..." : "Quét ngay", systemImage: "stethoscope")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(healthService.isScanning)
        }
        .padding(24)
    }
    
    // MARK: - Status Overview
    
    private var statusOverviewCard: some View {
        HStack(spacing: 16) {
            HealthStatCard(
                title: "Tổng symlink",
                value: "\(healthService.results.count)",
                icon: "link.circle.fill",
                color: .blue
            )
            
            HealthStatCard(
                title: "Hoạt động",
                value: "\(healthService.healthyCount)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            HealthStatCard(
                title: "Hỏng",
                value: "\(healthService.brokenCount)",
                icon: "exclamationmark.triangle.fill",
                color: healthService.brokenCount > 0 ? .red : .gray
            )
            
            HealthStatCard(
                title: "Ổ ngắt",
                value: "\(healthService.unmountedCount)",
                icon: "externaldrive.fill.badge.xmark",
                color: healthService.unmountedCount > 0 ? .orange : .gray
            )
        }
    }
    
    // MARK: - Results
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Kết quả quét", systemImage: "list.bullet.clipboard")
                    .font(.headline)
                
                Spacer()
                
                if let date = healthService.lastScanDate {
                    Text("Lần quét: \(date.relativeString)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Broken items first
            let broken = healthService.results.filter { $0.isBroken }
            let healthy = healthService.results.filter { !$0.isBroken }
            
            if !broken.isEmpty {
                VStack(spacing: 6) {
                    ForEach(broken) { item in
                        SymlinkStatusRow(
                            status: item,
                            isFixing: fixingId == item.id,
                            onFix: { fixSymlink(item) }
                        )
                    }
                }
            }
            
            if !healthy.isEmpty {
                Text("Hoạt động bình thường")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                    .padding(.top, 8)
                
                VStack(spacing: 6) {
                    ForEach(healthy) { item in
                        SymlinkStatusRow(
                            status: item,
                            isFixing: false,
                            onFix: nil
                        )
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "stethoscope")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            
            Text("Nhấn \"Quét ngay\" để kiểm tra")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("DataShuttle sẽ kiểm tra \(shuttledItems.count) symlink đang quản lý")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    private func fixSymlink(_ status: HealthCheckService.SymlinkStatus) {
        fixingId = status.id
        do {
            try healthService.fixSymlink(for: status)
            fixResultMessage = "Đã sửa symlink cho \"\(status.folderName)\" thành công!"
            fixResultIsError = false
            Task { await healthService.scan(items: shuttledItems) }
        } catch {
            fixResultMessage = error.localizedDescription
            fixResultIsError = true
        }
        fixingId = nil
        showFixResult = true
    }
}

// MARK: - Health Stat Card

struct HealthStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        }
    }
}

// MARK: - Symlink Status Row

struct SymlinkStatusRow: View {
    let status: HealthCheckService.SymlinkStatus
    let isFixing: Bool
    let onFix: (() -> Void)?
    
    var statusColor: Color {
        if status.isBroken && !status.isTargetMounted { return .orange }
        if status.isBroken { return .red }
        return .green
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.isBroken ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(statusColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(status.folderName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("\(status.originalPath) → \(status.volumeName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Text(status.statusLabel)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.1))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
            
            if status.isBroken, let onFix = onFix {
                Button {
                    onFix()
                } label: {
                    Label("Sửa", systemImage: "wrench.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
                .disabled(isFixing || (!status.isTargetMounted))
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(status.isBroken ? statusColor.opacity(0.03) : .clear)
                .strokeBorder(statusColor.opacity(0.1), lineWidth: 1)
        }
    }
}

#Preview {
    HealthCheckView()
        .modelContainer(for: [ShuttleItem.self], inMemory: true)
        .frame(width: 900, height: 700)
}
