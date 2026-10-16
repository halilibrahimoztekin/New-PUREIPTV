#if os(tvOS)
    import SwiftUI

    /// tvOS için Siri Remote ile hızlı kaydırma yaparken ekranda beliren alfabetik harf HUD göstergesi.
    /// Infuse ve Apple TV kütüphane standardında cam efektli ve ölçekleme animasyonlu.
    public struct TVAlphabetScrubberOverlay: View {
        let currentLetter: String
        let isVisible: Bool

        public init(currentLetter: String, isVisible: Bool) {
            self.currentLetter = currentLetter
            self.isVisible = isVisible
        }

        public var body: some View {
            if isVisible, !currentLetter.isEmpty {
                VStack {
                    Text(currentLetter.uppercased())
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Color(hex: "#0A84FF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.6), radius: 24, x: 0, y: 12)
                        .shadow(color: Color(hex: "#0A84FF").opacity(0.3), radius: 16, x: 0, y: 0)
                        .scaleEffect(isVisible ? 1.0 : 0.8)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
                .padding(.trailing, 60)
                .padding(.top, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .allowsHitTesting(false)
            }
        }
    }
#endif
