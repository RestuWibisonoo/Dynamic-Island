import SwiftUI

/// Tampilan Diperluas (Expanded) dengan visual hierarchy yang bersih, kontrol yang berfungsi nyata, dan a11y lengkap
public struct ExpandedIslandView: View {
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
        VStack(spacing: DesignTokens.Spacing.md) {
            // ==========================================
            // 1. HEADER SECTION (Clearance Notch Kamera)
            // ==========================================
            HStack(alignment: .center, spacing: 0) {
                // Sisi Kiri: Badge Sumber Pemutar
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Circle()
                        .fill(viewModel.mediaProvider.isPlaying ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    
                    Text(viewModel.mediaProvider.sourceType == .mock ? "Now Playing (Demo)" : "Now Playing")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .accessibilityLabel("Status pemutar: \(viewModel.mediaProvider.isPlaying ? "Memutar" : "Jeda")")
                
                Spacer()
                
                // Zona Tengah Khusus: Safe Clearance untuk Kamera Fisik Notch MacBook
                if metrics.hasHardwareNotch {
                    Color.clear
                        .frame(width: metrics.notchWidth, height: metrics.notchHeight - 6)
                        .accessibilityHidden(true)
                    Spacer()
                }
                
                // Sisi Kanan: Pin/Lock Button, Close Button, & Baterai
                HStack(spacing: DesignTokens.Spacing.xs) {
                    // Tombol Kunci (Pin)
                    Button(action: {
                        viewModel.toggleLockOpen()
                    }) {
                        HStack(spacing: DesignTokens.Spacing.xxs) {
                            Image(systemName: viewModel.state.isLocked ? "pin.fill" : "pin")
                                .font(.system(size: 9, weight: .bold))
                            Text(viewModel.state.isLocked ? "Terkunci" : "Kunci")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(viewModel.state.isLocked ? .black : .white.opacity(0.85))
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(viewModel.state.isLocked ? Color.white : Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.state.isLocked ? "Buka kunci pulau" : "Kunci pulau agar tetap terbuka")
                    
                    // Tombol Tutup Cepat (Close X)
                    if viewModel.state.isLocked {
                        Button(action: {
                            viewModel.dismissLock()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(5)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Tutup Dynamic Island")
                    }
                    
                    // Status Baterai
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: viewModel.batteryProvider.isCharging ? "bolt.fill" : "battery.100")
                            .font(.system(size: 10))
                            .foregroundColor(viewModel.batteryProvider.percentage > 20 ? .green : .red)
                        Text("\(viewModel.batteryProvider.percentage)%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .accessibilityLabel("Baterai \(viewModel.batteryProvider.percentage) persen")
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.top, metrics.hasHardwareNotch ? 6 : 10)
            
            // ==========================================
            // 2. HERO MEDIA PLAYER CARD
            // ==========================================
            VStack(spacing: DesignTokens.Spacing.sm) {
                // Baris Atas: Artwork + Info Lagu + Kontrol Playback
                HStack(spacing: DesignTokens.Spacing.lg) {
                    // Album Artwork dengan Ambient Glow
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.artwork, style: .continuous)
                            .fill(themeManager.accentColor.opacity(0.35))
                            .frame(width: 48, height: 48)
                            .blur(radius: 8)
                        
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.artwork, style: .continuous)
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
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.artwork, style: .continuous)
                                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
                            )
                    }
                    .accessibilityHidden(true)
                    
                    // Info Judul & Artis
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Text(viewModel.mediaProvider.currentTrack?.title ?? "Tidak Ada Musik")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            if viewModel.mediaProvider.isPlaying {
                                DeterministicEqualizerView(color: themeManager.accentColor, barCount: 4)
                            }
                        }
                        
                        Text(viewModel.mediaProvider.currentTrack?.artist ?? "Pilih lagu untuk memutar")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.68))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Tombol Kontrol Playback yang Berfungsi Nyata
                    HStack(spacing: DesignTokens.Spacing.xl) {
                        Button(action: {
                            viewModel.mediaProvider.previousTrack()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Lagu sebelumnya")
                        
                        Button(action: {
                            viewModel.mediaProvider.togglePlayback()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: viewModel.mediaProvider.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                                    .offset(x: viewModel.mediaProvider.isPlaying ? 0 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(viewModel.mediaProvider.isPlaying ? "Jeda lagu" : "Putar lagu")
                        
                        Button(action: {
                            viewModel.mediaProvider.nextTrack()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Lagu berikutnya")
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
                                .frame(
                                    width: max(geo.size.width * CGFloat(viewModel.mediaProvider.playbackProgress), 4),
                                    height: 4
                                )
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 9, height: 9)
                                .offset(x: max(geo.size.width * CGFloat(viewModel.mediaProvider.playbackProgress) - 4.5, 0))
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let progress = min(max(value.location.x / geo.size.width, 0.0), 1.0)
                                    viewModel.mediaProvider.seek(to: Double(progress))
                                }
                        )
                    }
                    .frame(height: 10)
                    .accessibilityElement()
                    .accessibilityLabel("Posisi pemutaran")
                    .accessibilityValue("\(Int(viewModel.mediaProvider.playbackProgress * 100)) persen")
                    
                    HStack {
                        Text(formatDuration(
                            (viewModel.mediaProvider.currentTrack?.duration ?? 0) * viewModel.mediaProvider.playbackProgress
                        ))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                        
                        Spacer()
                        
                        Text("-" + formatDuration(
                            (viewModel.mediaProvider.currentTrack?.duration ?? 0) * (1.0 - viewModel.mediaProvider.playbackProgress)
                        ))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.innerCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.innerCard, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .padding(.horizontal, DesignTokens.Spacing.lg)
            
            // ==========================================
            // 3. DROP SHELF & QUICK STATS DOCK (Bottom)
            // ==========================================
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Drop Shelf Target Area (Mock Ready)
                HStack(spacing: DesignTokens.Spacing.xs) {
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
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.12),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                )
                .accessibilityLabel("Drop shelf, area penampungan berkas sementara")
                
                Spacer()
                
                // System Stats Pills (CPU & RAM dari SystemProvider)
                HStack(spacing: DesignTokens.Spacing.xs) {
                    HStack(spacing: 3) {
                        Image(systemName: "cpu")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(viewModel.systemProvider.cpuUsage)%")
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
                        Text("\(viewModel.systemProvider.ramUsage)%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Penggunaan sistem: CPU \(viewModel.systemProvider.cpuUsage) persen, Memori \(viewModel.systemProvider.ramUsage) persen")
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.bottom, DesignTokens.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
