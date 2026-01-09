import SwiftUI

extension View {
    func liquidGlass(cornerRadius: CGFloat = 18) -> some View {
        liquidGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func liquidGlass<S: Shape>(in shape: S) -> some View {
        background(shape.fill(.ultraThinMaterial))
            .overlay(
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.18),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
    }
}
