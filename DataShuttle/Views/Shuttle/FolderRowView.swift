import SwiftUI

/// Row view for each folder in the analysis list
struct FolderRowView: View {
    let analysis: DiskAnalyzer.FolderAnalysis
    let canShuttle: Bool
    let isShuttling: Bool
    let onShuttle: () -> Void
    
    @State private var isHovered = false
    @State private var showConfirm = false
    
    var sizeColor: Color {
        if analysis.sizeBytes > 5_000_000_000 { return .red }       // > 5GB
        if analysis.sizeBytes > 1_000_000_000 { return .orange }    // > 1GB
        if analysis.sizeBytes > 500_000_000 { return .yellow }      // > 500MB
        return .green
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Folder icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(analysis.isSymlink ? .purple.opacity(0.1) : .blue.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: analysis.isSymlink ? "link.circle.fill" : "folder.fill")
                    .font(.body)
                    .foregroundStyle(analysis.isSymlink ? .purple : .blue)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(analysis.name)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if analysis.isSymlink {
                        Text("SYMLINK")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.purple.opacity(0.15))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                    
                    if analysis.isLargeFolder {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                HStack(spacing: 12) {
                    Label("\(analysis.fileCount) files", systemImage: "doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let target = analysis.symlinkTarget {
                        Label(target, systemImage: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.purple.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    if let modified = analysis.lastModified {
                        Label(modified.relativeString, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Spacer()
            
            // Size bar
            VStack(alignment: .trailing, spacing: 4) {
                Text(analysis.sizeBytes.formattedBytes)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(sizeColor)
                
                // Mini bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(sizeColor.opacity(0.15))
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(sizeColor)
                            .frame(width: min(geo.size.width, max(4, geo.size.width * sizeBarProgress)))
                    }
                }
                .frame(width: 60, height: 4)
            }
            
            // Shuttle button
            if canShuttle && !analysis.isSymlink {
                Button {
                    showConfirm = true
                } label: {
                    Label("Chuyển", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isShuttling)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? .blue.opacity(0.03) : .clear)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .confirmationDialog(
            "Chuyển thư mục \"\(analysis.name)\"?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Chuyển (\(analysis.sizeBytes.formattedBytes))") {
                onShuttle()
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Thư mục sẽ được copy sang ổ phụ và tạo symlink tại vị trí gốc. Các ứng dụng vẫn hoạt động bình thường.")
        }
    }
    
    private var sizeBarProgress: Double {
        // Normalize: max ~10GB for visual
        return min(1.0, Double(analysis.sizeBytes) / 10_000_000_000.0)
    }
}

#Preview {
    VStack {
        FolderRowView(
            analysis: DiskAnalyzer.FolderAnalysis(
                path: "/Users/tai/Developer",
                name: "Developer",
                sizeBytes: 2_500_000_000,
                fileCount: 12500,
                lastModified: Date().addingTimeInterval(-86400),
                isSymlink: false,
                symlinkTarget: nil
            ),
            canShuttle: true,
            isShuttling: false
        ) {}
        
        FolderRowView(
            analysis: DiskAnalyzer.FolderAnalysis(
                path: "/Users/tai/Movies",
                name: "Movies",
                sizeBytes: 8_000_000_000,
                fileCount: 45,
                lastModified: Date().addingTimeInterval(-3600),
                isSymlink: true,
                symlinkTarget: "/Volumes/External/DataShuttle/Movies"
            ),
            canShuttle: false,
            isShuttling: false
        ) {}
    }
    .padding()
    .frame(width: 700)
}
