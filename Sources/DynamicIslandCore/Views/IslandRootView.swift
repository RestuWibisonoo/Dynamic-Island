import SwiftUI

/// Kontainer Utama Dynamic Island:
/// - Terikat dengan ThemeManager (memperbaiki bug Color.black hardcoded)
/// - Menghilangkan shadow pada mode compact
/// - Menghilangkan border pada mode compact agar menyatu 100% dengan bezel
public struct IslandRootView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var themeManager: ThemeManager = .shared
    
    public init(viewModel: IslandViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Offset vertikal hanya untuk Mac tanpa notch agar menjadi floating pill melayang
            if !viewModel.screenDetector.currentMetrics.hasHardwareNotch {
                Spacer().frame(height: 6)
            }
            
            ZStack {
                // Background Pulau (Menggunakan ThemeManager, bukan Color.black statis)
                FlushNotchShape(
                    cornerRadius: viewModel.state.isExpanded ? DesignTokens.CornerRadius.expandedCard : DesignTokens.CornerRadius.compactNotchBottom,
                    hasHardwareNotch: viewModel.screenDetector.currentMetrics.hasHardwareNotch,
                    isExpanded: viewModel.state.isExpanded
                )
                .fill(themeManager.containerBackgroundColor)
                .overlay(
                    // Garis tepi specular halus HANYA saat expanded
                    Group {
                        if viewModel.state.isExpanded {
                            FlushNotchShape(
                                cornerRadius: DesignTokens.CornerRadius.expandedCard,
                                hasHardwareNotch: viewModel.screenDetector.currentMetrics.hasHardwareNotch,
                                isExpanded: true
                            )
                            .stroke(themeManager.borderGradient, lineWidth: 0.75)
                        }
                    }
                )
                
                // Konten Dinamis berdasarkan State
                Group {
                    if viewModel.state.isExpanded {
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
