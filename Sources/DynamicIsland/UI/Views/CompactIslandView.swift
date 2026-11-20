import SwiftUI

/// Tampilan Compact saat Island berada dalam kondisi istirahat:
/// - Menggunakan arsitektur "Dua Sayap" dengan tinggi presisi 37pt (menutupi tompel fisik MacBook sepenuhnya)
/// - Mengklik island dalam keadaan compact akan membuka dan menguncinya
public struct CompactIslandView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var themeManager: ThemeManager
    
    public var body: some View {
        Group {
            if viewModel.screenDetector.hasHardwareNotch {
                // Layout Dua Sayap untuk MacBook Pro / Air dengan Notch
                HStack(spacing: 0) {
                    // Sayap Kiri: Ikon Musik + Live Equalizer
                    HStack(spacing: 5) {
                        Image(systemName: "music.note")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(themeManager.accentColor)
                        
                        if viewModel.isPlayingMedia {
                            CompactWaveform(color: themeManager.accentColor)
                        }
                    }
                    .frame(width: viewModel.screenDetector.earWidth, alignment: .center)
                    
                    // Zona Tengah: Dikosongkan khusus untuk modul kamera fisik MacBook (~185pt)
                    Color.clear
                        .frame(width: viewModel.screenDetector.notchWidth)
                    
                    // Sayap Kanan: Persentase Baterai & Status Pengisian Daya
                    HStack(spacing: 4) {
                        Text("\(viewModel.batteryPercentage)%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                        
                        Image(systemName: viewModel.isCharging ? "bolt.fill" : "battery.100")
                            .font(.system(size: 11))
                            .foregroundColor(viewModel.batteryPercentage > 20 ? .green : .red)
                    }
                    .frame(width: viewModel.screenDetector.earWidth, alignment: .center)
                }
            } else {
                // Layout Kapsul Melayang (Floating Pill) untuk Mac tanpa notch
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeManager.accentColor)
                        
                        if viewModel.isPlayingMedia {
                            CompactWaveform(color: themeManager.accentColor)
                        }
                    }
                    .padding(.leading, 12)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("\(viewModel.batteryPercentage)%")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.88))
                        
                        Image(systemName: viewModel.isCharging ? "bolt.fill" : "battery.100")
                            .font(.system(size: 11))
                            .foregroundColor(viewModel.batteryPercentage > 20 ? .green : .red)
                    }
                    .padding(.trailing, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                viewModel.toggleLockOpen()
            }
        }
        .transition(.opacity)
    }
}

/// Mini waveform bar animasi sederhana di sayap kiri
struct CompactWaveform: View {
    let color: Color
    @State private var animating: Bool = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2, height: animating ? CGFloat.random(in: 4...12) : 5)
                    .animation(
                        .easeInOut(duration: 0.45)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}
