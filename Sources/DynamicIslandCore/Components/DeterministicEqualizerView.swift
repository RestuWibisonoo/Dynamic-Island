import SwiftUI

/// Equalizer audio animasi DETERMINISTIK murni tanpa memanggil `CGFloat.random` di dalam siklus rendering SwiftUI
public struct DeterministicEqualizerView: View {
    public let color: Color
    public let barCount: Int
    
    @State private var phase: CGFloat = 0.0
    
    // Nilai tinggi deterministik (terprogram) untuk setiap bar (bukan random)
    private let barMinHeights: [CGFloat] = [4, 5, 4, 6]
    private let barMaxHeights: [CGFloat] = [12, 10, 13, 9]
    private let barSpeedMultipliers: [Double] = [1.0, 1.3, 0.9, 1.2]
    
    public init(color: Color, barCount: Int = 4) {
        self.color = color
        self.barCount = barCount
    }
    
    public var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<min(barCount, 4), id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(
                        width: 2,
                        height: computeHeight(for: index)
                    )
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.55)
                .repeatForever(autoreverses: true)
            ) {
                phase = 1.0
            }
        }
        .accessibilityHidden(true)
    }
    
    private func computeHeight(for index: Int) -> CGFloat {
        let minH = barMinHeights[index % barMinHeights.count]
        let maxH = barMaxHeights[index % barMaxHeights.count]
        let factor = (index % 2 == 0) ? phase : (1.0 - phase)
        return minH + (maxH - minH) * factor
    }
}
