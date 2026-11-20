import SwiftUI

/// Tampilan Compact saat Island berada dalam kondisi istirahat:
/// - Menggunakan arsitektur "Dua Sayap" dengan tinggi presisi (32.0pt) sejajar garis menu bar
/// - Zona tengah dikosongkan secara presisi untuk modul kamera fisik notch MacBook
public struct CompactIslandView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var themeManager: ThemeManager
    
    public init(viewModel: IslandViewModel, themeManager: ThemeManager) {
        self.viewModel = viewModel
        self.themeManager = themeManager
    }
    
    private var metrics: IslandLayoutMetrics {
        viewModel.screenDetector.currentMetrics
    }
    
    public var body: some View {
        Group {
            if metrics.hasHardwareNotch {
                // Layout Dua Sayap untuk MacBook Pro / Air dengan Notch
                HStack(spacing: 0) {
                    // Sayap Kiri: Ikon Musik + Live Equalizer Deterministik
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "music.note")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(themeManager.accentColor)
                        
                        if viewModel.mediaProvider.isPlaying {
                            DeterministicEqualizerView(color: themeManager.accentColor, barCount: 3)
                        }
                    }
                    .frame(width: metrics.earWidth, alignment: .center)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Pemutar media aktif")
                    
                    // Zona Tengah: Dikosongkan khusus untuk modul kamera fisik MacBook
                    Color.clear
                        .frame(width: metrics.notchWidth)
                        .accessibilityHidden(true)
                    
                    // Sayap Kanan: Persentase Baterai & Status Pengisian Daya
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Text("\(viewModel.batteryProvider.percentage)%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                        
                        Image(systemName: viewModel.batteryProvider.isCharging ? "bolt.fill" : "battery.100")
                            .font(.system(size: 11))
                            .foregroundColor(viewModel.batteryProvider.percentage > 20 ? .green : .red)
                    }
                    .frame(width: metrics.earWidth, alignment: .center)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Baterai \(viewModel.batteryProvider.percentage) persen\(viewModel.batteryProvider.isCharging ? ", sedang mengisi daya" : "")")
                }
            } else {
                // Layout Kapsul Melayang (Floating Pill) untuk Mac tanpa notch
                HStack(spacing: DesignTokens.Spacing.sm) {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "music.note")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeManager.accentColor)
                        
                        if viewModel.mediaProvider.isPlaying {
                            DeterministicEqualizerView(color: themeManager.accentColor, barCount: 3)
                        }
                    }
                    .padding(.leading, DesignTokens.Spacing.lg)
                    
                    Spacer()
                    
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Text("\(viewModel.batteryProvider.percentage)%")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.88))
                        
                        Image(systemName: viewModel.batteryProvider.isCharging ? "bolt.fill" : "battery.100")
                            .font(.system(size: 11))
                            .foregroundColor(viewModel.batteryProvider.percentage > 20 ? .green : .red)
                    }
                    .padding(.trailing, DesignTokens.Spacing.lg)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.toggleLockOpen()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Klik untuk memperluas Dynamic Island")
        .transition(.opacity)
    }
}
