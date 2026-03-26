import SwiftUI
import AppKit

/// Cloud storage integration view
struct CloudStorageView: View {
    @State private var cloudManager = CloudStorageManager()
    @State private var selectedService: CloudStorageManager.CloudService?
    @State private var cloudAnalysis: [DiskAnalyzer.FolderAnalysis] = []
    @State private var isAnalyzing = false
    @State private var itemToDelete: DiskAnalyzer.FolderAnalysis?
    @State private var showDeleteConfirm = false
    @State private var copiedPath = false
    
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
                            cloudCleanupSection(selected)
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
        }
        .confirmationDialog(
            "Xóa vĩnh viễn?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Xóa ngay", role: .destructive) {
                if let item = itemToDelete {
                    try? cloudManager.deleteItem(at: item.path)
                    // Refresh analysis after delete
                    if let selected = selectedService {
                        Task {
                            cloudAnalysis = await cloudManager.analyzeCloudContents(at: selected.localPath)
                        }
                    }
                }
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Mục \"\(itemToDelete?.name ?? "")\" sẽ bị xóa vĩnh viễn khỏi Cloud.")
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
                    await cloudManager.detectCloudServices()
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
            Label("Dịch vụ đã phát hiện", systemImage: "checkmark.icloud.fill")
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
            
            if !cloudAnalysis.isEmpty {
                let sorted = Array(cloudAnalysis.sorted(by: { $0.sizeBytes > $1.sizeBytes }).prefix(15))
                VStack(spacing: 8) {
                    ForEach(sorted) { item in
                        CloudItemRow(item: item) {
                            itemToDelete = item
                            showDeleteConfirm = true
                        }
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
                    
                    Text(service.isAvailable ? "Đã kết nối" : "Không khả dụng")
                        .font(.caption)
                        .foregroundStyle(service.isAvailable ? .green : .red)
                }
                
                Spacer()
                
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

struct CloudItemRow: View {
    let item: DiskAnalyzer.FolderAnalysis
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(item.name)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer()
            
            Text(item.sizeBytes.formattedBytes)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            
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
