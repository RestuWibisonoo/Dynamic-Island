import SwiftUI

/// Tampilan Diperluas (Expanded) dengan desain mewah khas macOS Sonoma / Sequoia:
/// - Area atas memiliki clearance presisi untuk modul kamera fisik notch MacBook (~185x37pt)
/// - Tombol Pin/Kunci memiliki target klik mandiri yang responsif tanpa bentrok gesture
/// - Hero Media Player dengan artwork ambient glow, interactive progress bar, dan live equalizer
/// - Drop Shelf Hub & System Monitor di bagian bawah
public struct ExpandedIslandView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var themeManager: ThemeManager
    
    public var body: some View {
        VStack(spacing: 10) {
            // ==========================================
            // 1. HEADER SECTION (Clearance Notch Kamera)
            // ==========================================
            HStack(alignment: .center, spacing: 0) {
                // Sisi Kiri: Badge Sumber Pemutar
                HStack(spacing: 5) {
                    Circle()
                        .fill(viewModel.isPlayingMedia ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                        .shadow(color: viewModel.isPlayingMedia ? Color.green.opacity(0.8) : Color.clear, radius: 4)
                    
                    Text("Now Playing")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                
                Spacer()
                
                // Zona Tengah Khusus: Safe Clearance untuk Kamera Fisik Notch MacBook
                if viewModel.screenDetector.hasHardwareNotch {
                    Color.clear
                        .frame(width: viewModel.screenDetector.notchWidth, height: viewModel.screenDetector.notchHeight - 5)
                    Spacer()
                }
                
                // Sisi Kanan: Pin/Lock Button, Close Button, & Baterai
                HStack(spacing: 6) {
                    // Tombol Kunci (Pin) dengan target klik presisi
                    Button(action: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                            viewModel.toggleLockOpen()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.isLockedOpen ? "pin.fill" : "pin")
                                .font(.system(size: 9, weight: .bold))
                            Text(viewModel.isLockedOpen ? "Terkunci" : "Kunci")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(viewModel.isLockedOpen ? .black : .white.opacity(0.85))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(viewModel.isLockedOpen ? Color.white : Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    // Tombol Tutup Cepat (Close X)
                    if viewModel.isLockedOpen {
                        Button(action: {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                                viewModel.dismissLock()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(5)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Status Baterai
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isCharging ? "bolt.fill" : "battery.100")
                            .font(.system(size: 10))
                            .foregroundColor(viewModel.batteryPercentage > 20 ? .green : .red)
                        Text("\(viewModel.batteryPercentage)%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, viewModel.screenDetector.hasHardwareNotch ? 6 : 10)
            
            // ==========================================
            // 2. HERO MEDIA PLAYER CARD
            // ==========================================
            VStack(spacing: 9) {
                // Baris Atas: Artwork + Info Lagu + Kontrol Playback
                HStack(spacing: 12) {
                    // Album Artwork dengan Ambient Glow
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(themeManager.accentColor.opacity(0.4))
                            .frame(width: 50, height: 50)
                            .blur(radius: 8)
                        
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.accentColor,
                                        Color(red: 0.55, green: 0.15, blue: 0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                    
                    // Info Judul & Artis
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(viewModel.currentTrackTitle)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            if viewModel.isPlayingMedia {
                                LiveEqualizerBars(color: themeManager.accentColor)
                            }
                        }
                        
                        Text(viewModel.currentArtist)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.70))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Tombol Kontrol Playback
                    HStack(spacing: 14) {
                        Button(action: {}) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                                viewModel.togglePlayback()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 32, height: 32)
                                    .shadow(color: Color.white.opacity(0.25), radius: 6)
                                
                                Image(systemName: viewModel.isPlayingMedia ? "pause.fill" : "play.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                                    .offset(x: viewModel.isPlayingMedia ? 0 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {}) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Baris Bawah: Interactive Progress Scrubber Bar
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [themeManager.accentColor, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(geo.size.width * CGFloat(viewModel.trackProgress), 4), height: 4)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 9, height: 9)
                                .shadow(color: Color.black.opacity(0.5), radius: 3)
                                .offset(x: max(geo.size.width * CGFloat(viewModel.trackProgress) - 4.5, 0))
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    viewModel.isScrubbing = true
                                    let progress = min(max(value.location.x / geo.size.width, 0.0), 1.0)
                                    viewModel.trackProgress = Double(progress)
                                }
                                .onEnded { _ in
                                    viewModel.isScrubbing = false
                                }
                        )
                    }
                    .frame(height: 10)
                    
                    HStack {
                        Text(viewModel.currentTimeFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                        Spacer()
                        Text(viewModel.remainingTimeFormatted)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            
            // ==========================================
            // 3. DROP SHELF & QUICK STATS DOCK (Bottom)
            // ==========================================
            HStack(spacing: 8) {
                // Drop Shelf Target Area
                HStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.accentColor)
                    
                    Text("Drop Shelf")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("Tarik file ke sini")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.12),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                )
                
                Spacer()
                
                // System Stats Pills (CPU & RAM)
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "cpu")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(viewModel.cpuUsage)%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.3))
                    
                    HStack(spacing: 3) {
                        Image(systemName: "memorychip")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(viewModel.ramUsage)%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }
}

/// 4-bar Animated Audio Frequency Equalizer
struct LiveEqualizerBars: View {
    let color: Color
    @State private var animating: Bool = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2, height: animating ? CGFloat.random(in: 4...13) : 5)
                    .animation(
                        .easeInOut(duration: 0.40)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.12),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

