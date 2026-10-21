import ComposableArchitecture
import CoreImage.CIFilterBuiltins
import SwiftUI

// MARK: - Trakt Device Code Auth Modal

public struct TraktAuthView: View {
    @Bindable var store: StoreOf<TraktFeature>
    var onClose: () -> Void

    public init(store: StoreOf<TraktFeature>, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: "#0B0E14").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "tv.badge.wifi")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(Color(hex: "#ED1C24"))

                                Text("Trakt.tv Bağlantısı")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                            Text("İzlediğiniz film ve dizileri tüm cihazlarınızla anında eşitleyin.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 20)

                        if store.isAuthorizing, let codeInfo = store.deviceCodeInfo {
                            // Active Code Presentation Card
                            VStack(spacing: 24) {
                                Text("AŞAĞIDAKİ ADRESİ AÇIN VE KODU GİRİN")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .tracking(1.2)

                                // QR Code
                                if let qrImage = generateQRCode(from: codeInfo.verificationURL) {
                                    Image(uiImage: qrImage)
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 150, height: 150)
                                        .padding(12)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .shadow(color: Color(hex: "#ED1C24").opacity(0.3), radius: 20, x: 0, y: 8)
                                }

                                Link(destination: URL(string: codeInfo.verificationURL)!) {
                                    HStack(spacing: 6) {
                                        Text(codeInfo.verificationURL)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(Color(hex: "#0A84FF"))

                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color(hex: "#0A84FF"))
                                    }
                                }

                                // High-Visibility User Code
                                VStack(spacing: 6) {
                                    Text("EŞLEŞTİRME KODU")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color(hex: "#ED1C24"))
                                        .tracking(1.0)

                                    Text(codeInfo.userCode)
                                        .font(.system(size: 34, weight: .black, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .tracking(4.0)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color.white.opacity(0.08))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .stroke(Color(hex: "#ED1C24").opacity(0.6), lineWidth: 1.5)
                                                )
                                        )
                                }

                                // Status Indicator
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#ED1C24")))
                                        .scaleEffect(0.85)

                                    Text("Trakt.tv üzerinden onay bekleniyor...")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.75))
                                }
                                .padding(.top, 4)

                                #if !os(tvOS)
                                    Button {
                                        UIPasteboard.general.string = codeInfo.userCode
                                        HapticManager.shared.trigger(.success)
                                    } label: {
                                        Label("Kodu Kopyala", systemImage: "doc.on.doc.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Capsule().fill(Color.white.opacity(0.12)))
                                    }
                                    .buttonStyle(.plain)
                                #endif
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                                    .background(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                        } else if let error = store.authError {
                            // Error State Card
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color(hex: "#FF453A"))

                                Text("Bağlantı Kurulamadı")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)

                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)

                                Button {
                                    store.send(.startDeviceAuth)
                                } label: {
                                    Text("Yeniden Dene")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Capsule().fill(Color(hex: "#ED1C24")))
                                }
                                #if os(tvOS)
                                .buttonStyle(TVTraktButtonStyle())
                                #else
                                .buttonStyle(.plain)
                                #endif
                            }
                            .padding(28)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                                    .background(.ultraThinMaterial)
                            )
                            .padding(.horizontal, 20)
                        } else {
                            // Initial State Button
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#ED1C24")))
                                    .scaleEffect(1.2)

                                Text("Eşleştirme kodu alınıyor...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(40)
                        }

                        Button("Kapat") {
                            store.send(.cancelAuth)
                            onClose()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 24)
                    }
                }
            }
            .onAppear {
                if !store.isAuthenticated {
                    store.send(.startDeviceAuth)
                }
            }
            #if !os(tvOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.cancelAuth)
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            #endif
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let filter = CIFilter(name: "CIQRCodeGenerator")
        let data = string.data(using: .ascii)
        filter?.setValue(data, forKey: "inputMessage")
        guard let outputImage = filter?.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)) else {
            return nil
        }
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - tvOS Button Style for Trakt

#if os(tvOS)
    public struct TVTraktButtonStyle: ButtonStyle {
        @FocusState private var isFocused: Bool

        public init() {}

        public func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .focused($isFocused)
                .scaleEffect(isFocused ? 1.08 : 1.0)
                .shadow(color: isFocused ? Color(hex: "#ED1C24").opacity(0.6) : .clear, radius: 14)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        }
    }
#endif
