import SwiftUI
import AppKit

/// Transfer progress indicator view with real-time file tracking
struct TransferProgressView: View {
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
    let job: TransferJob
    var onCancel: (() -> Void)?

    private func t(_ key: String) -> String {
        L10n.tr(key, languageCode: appLanguage)
    }
    
    var statusColor: Color {
        switch job.status {
        case .pending: return .gray
        case .inProgress: return .blue
        case .creatingSymlink: return .purple
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header row
            HStack {
                Image(systemName: job.status.iconName)
                    .font(.title3)
                    .foregroundStyle(statusColor)
                    .symbolEffect(.pulse, isActive: job.status == .inProgress)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.folderName)
                        .font(.callout)
                        .fontWeight(.medium)
                    
                    Text(job.statusDetail ?? (job.isRestore ? t("Đang khôi phục") : t("Đang chuyển")))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Cancel button (only when in progress)
                if job.status == .inProgress || job.status == .pending {
                    Button {
                        onCancel?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help(t("Hủy chuyển"))
                }
                
                // Reveal in Finder (when completed)
                if job.status == .completed {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([
                            URL(fileURLWithPath: job.destinationPath)
                        ])
                    } label: {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(t("Hiện trong Finder"))
                }
                
                Text(job.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
                
                Text("\(job.progressPercentage)%")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(statusColor)
                    .frame(width: 52, alignment: .trailing)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor.opacity(0.15))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [statusColor, statusColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * job.progress)
                        .animation(.spring(response: 0.3), value: job.progress)
                }
            }
            .frame(height: 8)
            
            // Detail row
            HStack {
                // Bytes transferred
                Text("\(job.transferredBytes.formattedBytes) / \(job.totalBytes.formattedBytes)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Current file being copied
                if let currentFile = job.currentFile {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.fill")
                            .font(.caption2)
                        Text(currentFile)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: 300, alignment: .trailing)
                }
            }
            
            // Path info
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue.opacity(0.6))
                    Text(job.sourcePath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.green.opacity(0.6))
                    Text(job.destinationPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            
            // Error message
            if let error = job.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .strokeBorder(statusColor.opacity(0.2), lineWidth: 1)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TransferProgressView(
            job: {
                let job = TransferJob(
                    sourcePath: "/Users/tai/Developer",
                    destinationPath: "/Volumes/External/MyData/Developer",
                    folderName: "Developer",
                    totalBytes: 5_000_000_000
                )
                job.transferredBytes = 2_500_000_000
                job.status = .inProgress
                job.statusDetail = "Đang sao chép file..."
                job.currentFile = "project/src/App.swift"
                return job
            }()
        )
        
        TransferProgressView(
            job: {
                let job = TransferJob(
                    sourcePath: "/Users/tai/Movies",
                    destinationPath: "/Volumes/External/Backup/Movies",
                    folderName: "Movies",
                    totalBytes: 10_000_000_000
                )
                job.transferredBytes = 10_000_000_000
                job.status = .completed
                job.statusDetail = "Hoàn thành!"
                return job
            }()
        )
    }
    .padding()
    .frame(width: 650)
}
