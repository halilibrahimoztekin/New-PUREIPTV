#if os(tvOS)
    import SwiftUI

    // MARK: - tvOS Siri Remote Hızlı Kaydırma (Fast-Scrubbing Index) - Madde #2

    /// tvOS için Siri Remote touchpad kenarından hızlı kaydırma yaparken ekranda beliren
    /// dikey alfabetik indeks çubuğu (A-Z) ve anlık harf büyüteç HUD kartı.
    /// Infuse ve Apple TV kütüphane standardında cam efektli, parıltılı ve akıcı geçişli.
    public struct TVAlphabetScrubberOverlay: View {
        public static let standardAlphabet: [String] = ["#"] + (65 ... 90).map { String(UnicodeScalar($0)) }

        public let currentLetter: String
        public let isVisible: Bool
        public let availableLetters: Set<String>
        public let onSelectLetter: ((String) -> Void)?

        public init(
            currentLetter: String,
            isVisible: Bool,
            availableLetters: Set<String> = [],
            onSelectLetter: ((String) -> Void)? = nil
        ) {
            self.currentLetter = currentLetter
            self.isVisible = isVisible
            self.availableLetters = availableLetters
            self.onSelectLetter = onSelectLetter
        }

        public var body: some View {
            if isVisible, !currentLetter.isEmpty {
                HStack(alignment: .center, spacing: 24) {
                    Spacer()

                    // Center-Right Floating Letter Magnifier HUD
                    magnifierCard

                    // Right-Edge Vertical Alphabet Rail (A-Z)
                    alphabetRail
                }
                .padding(.trailing, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isVisible)
                .allowsHitTesting(false)
            }
        }

        // MARK: - Floating Letter Magnifier Card

        private var magnifierCard: some View {
            VStack {
                Text(currentLetter.uppercased())
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color(hex: "#0A84FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 124, height: 124)
                    .background(
                        ZStack {
                            Color.black.opacity(0.85)
                            Rectangle().fill(.ultraThinMaterial)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color(hex: "#0A84FF").opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.65), radius: 24, x: 0, y: 12)
                    .shadow(color: Color(hex: "#0A84FF").opacity(0.4), radius: 20, x: 0, y: 0)
                    .scaleEffect(isVisible ? 1.0 : 0.8)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: currentLetter)
            }
        }

        // MARK: - Vertical Alphabet Rail (A-Z)

        private var alphabetRail: some View {
            VStack(spacing: 2) {
                ForEach(Self.standardAlphabet, id: \.self) { letter in
                    let isSelected = letter.uppercased() == currentLetter.uppercased()
                    let isAvailable = availableLetters.isEmpty || availableLetters.contains(letter)

                    Text(letter)
                        .font(.system(
                            size: isSelected ? 13 : 10,
                            weight: isSelected ? .black : (isAvailable ? .semibold : .regular),
                            design: .rounded
                        ))
                        .foregroundStyle(
                            isSelected
                                ? Color.white
                                : (isAvailable ? Color.white.opacity(0.85) : Color.white.opacity(0.22))
                        )
                        .frame(width: isSelected ? 24 : 18, height: isSelected ? 22 : 16)
                        .background(
                            Group {
                                if isSelected {
                                    Capsule()
                                        .fill(Color(hex: "#0A84FF"))
                                        .shadow(color: Color(hex: "#0A84FF").opacity(0.6), radius: 6, x: 0, y: 0)
                                } else {
                                    Color.clear
                                }
                            }
                        )
                        .scaleEffect(isSelected ? 1.25 : 1.0)
                        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isSelected)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(
                ZStack {
                    Color.black.opacity(0.75)
                    Capsule().fill(.ultraThinMaterial)
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 14, x: 0, y: 6)
        }
    }
#endif
