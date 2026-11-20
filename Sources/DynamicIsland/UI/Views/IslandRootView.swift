import SwiftUI

/// Kontainer Utama Dynamic Island:
/// - Nol Shadow (Zero Shadow baik saat idle maupun saat hover/expanded)
/// - Nol Border pada compact mode agar menyatu sempurna dengan layar fullscreen
public struct IslandRootView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var themeManager: ThemeManager = .shared
    
    public init(viewModel: IslandViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Offset vertikal hanya untuk Mac tanpa notch agar menjadi floating pill melayang
            if !viewModel.screenDetector.hasHardwareNotch {
                Spacer().frame(height: 6)
            }
            
            ZStack {
                // Background Pulau (Pure Black khas bezel Apple)
                FlushNotchShape(
                    cornerRadius: viewModel.state == .expanded ? 26 : (viewModel.screenDetector.hasHardwareNotch ? 12 : 16),
                    hasHardwareNotch: viewModel.screenDetector.hasHardwareNotch,
                    isExpanded: viewModel.state == .expanded
                )
                .fill(Color.black)
                .overlay(
                    // Garis tepi sangat halus HANYA saat expanded agar kartu terpisah rapi dari background
                    Group {
                        if viewModel.state == .expanded {
                            FlushNotchShape(
                                cornerRadius: 26,
                                hasHardwareNotch: viewModel.screenDetector.hasHardwareNotch,
                                isExpanded: true
                            )
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                        }
                    }
                )
                // SHADOW DIHILANGKAN TOTAL (Zero Shadow baik saat idle maupun saat hover/expanded)
                // Tidak ada lagi bayangan abu-abu yang menimpa aplikasi lain!
                
                // Konten Dinamis
                Group {
                    if viewModel.state == .expanded {
                        ExpandedIslandView(viewModel: viewModel, themeManager: themeManager)
                    } else {
                        CompactIslandView(viewModel: viewModel, themeManager: themeManager)
                    }
                }
            }
            .frame(width: viewModel.currentWidth, height: viewModel.currentHeight)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    viewModel.onHoverChanged(true)
                case .ended:
                    viewModel.onHoverChanged(false)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
