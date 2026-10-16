import SwiftUI

/// tvOS ve iOS oynatıcı arayüzünde uzun süre hareketsiz kalındığında veya yayın duraklatıldığında
/// ekranı kademeli olarak karartarak göz yorgunluğunu ve OLED panellerdeki piksel yanmasını (burn-in) önleyen katman.
public struct OLEDDimmerOverlay: View {
    let dimLevel: Double
    let isDeepDimmed: Bool

    // Anti-burn-in için mikroskobik piksel kaydırma (Pixel-Shift)
    @State private var pixelShiftX: CGFloat = 0
    @State private var pixelShiftY: CGFloat = 0

    public init(dimLevel: Double, isDeepDimmed: Bool) {
        self.dimLevel = dimLevel
        self.isDeepDimmed = isDeepDimmed
    }

    public var body: some View {
        ZStack {
            if dimLevel > 0 {
                // Kademeli Karartma Perdesi
                Color.black
                    .opacity(dimLevel)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Derin OLED Koruma Göstergesi (Statik kalmaması için periyodik hafif ofsetli)
                if isDeepDimmed {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(hex: "#5E5CE6"))

                            Text(AppStrings.Player.oledDarkRoomMode)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial.opacity(0.35), in: Capsule())
                        .offset(x: pixelShiftX, y: pixelShiftY)
                        .padding(.bottom, 32)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                            pixelShiftX = 3.0
                            pixelShiftY = -2.0
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.75), value: dimLevel)
        .animation(.easeInOut(duration: 0.4), value: isDeepDimmed)
    }
}
