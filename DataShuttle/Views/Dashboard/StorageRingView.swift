import SwiftUI

/// Animated ring chart showing storage usage
struct StorageRingView: View {
    @AppStorage(L10n.languageStorageKey) private var appLanguage: String = AppLanguage.system.rawValue
    let usedBytes: Int64
    let totalBytes: Int64
    let volumeName: String
    let accentColor: Color
    
    @State private var animatedProgress: Double = 0
    
    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
    
    var availableBytes: Int64 {
        totalBytes - usedBytes
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, languageCode: appLanguage)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(
                        accentColor.opacity(0.15),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                accentColor,
                                accentColor.opacity(0.8),
                                accentColor
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.2, dampingFraction: 0.8), value: animatedProgress)
                
                // Center content
                VStack(spacing: 4) {
                    Text("\(Int(animatedProgress * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .contentTransition(.numericText())
                    
                    Text(t("đã dùng"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)
            
            VStack(spacing: 4) {
                Text(volumeName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 16) {
                    Label {
                        Text(usedBytes.formattedBytes)
                            .font(.caption)
                    } icon: {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 8, height: 8)
                    }
                    
                    Label {
                        Text(availableBytes.formattedBytes)
                            .font(.caption)
                    } icon: {
                        Circle()
                            .fill(accentColor.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.3)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

#Preview {
    StorageRingView(
        usedBytes: 350_000_000_000,
        totalBytes: 500_000_000_000,
        volumeName: "Macintosh HD",
        accentColor: .blue
    )
    .padding()
}
