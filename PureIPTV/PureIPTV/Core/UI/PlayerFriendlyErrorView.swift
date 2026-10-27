import SwiftUI

public enum PlayerDiagnosticCategory: Sendable {
    case authExpired
    case streamNotFound
    case serverUnresponsive
    case connectionLimitExceeded
    case codecOrFormatUnsupported
    case generic(String)

    public static func diagnose(error: String) -> PlayerDiagnosticCategory {
        let lower = error.lowercased()
        if lower.contains("401") || lower.contains("403") || lower.contains("unauthorized") || lower.contains("forbidden") {
            return .authExpired
        } else if lower.contains("404") || lower.contains("not found") {
            return .streamNotFound
        } else if lower.contains("limit") || lower.contains("connection") && lower.contains("exceed") {
            return .connectionLimitExceeded
        } else if lower.contains("timeout") || lower.contains("unreachable") || lower.contains("network") {
            return .serverUnresponsive
        } else if lower.contains("codec") || lower.contains("demux") || lower.contains("format") {
            return .codecOrFormatUnsupported
        } else {
            return .generic(error)
        }
    }

    public var title: String {
        switch self {
        case .authExpired: "Yetkilendirme Hatası"
        case .streamNotFound: "Yayın Bulunamadı (404)"
        case .serverUnresponsive: "Sunucu Yanıt Vermiyor"
        case .connectionLimitExceeded: "Bağlantı Sınırı Aşıldı"
        case .codecOrFormatUnsupported: "Yayın Formatı Uyumsuz"
        case .generic: "Yayın Hatası"
        }
    }

    public var explanation: String {
        switch self {
        case .authExpired:
            "IPTV sağlayıcınız bu yayına erişimi kısıtladı veya abonelik süreniz dolmuş olabilir. VPN kullanıyorsanız kapatıp/açmayı veya hesap bilgilerinizi kontrol etmeyi deneyin."
        case .streamNotFound:
            "Bu kanal şu anda yayın yapmıyor veya sunucu üzerindeki yayın bağlantısı güncellenmiş. Lütfen kanal listesini yenileyin."
        case .serverUnresponsive:
            "IPTV sunucusuna bağlanırken zaman aşımı oluştu. İnternet bağlantınızı veya sunucu hız testinizi kontrol edebilirsiniz."
        case .connectionLimitExceeded:
            "IPTV paketinizin izin verdiği eşzamanlı cihaz limitine (örn. 1/1 veya 2/2) ulaşılmış olabilir. Diğer cihazlardaki yayını kapatıp tekrar deneyin."
        case .codecOrFormatUnsupported:
            "Bu yayın biçimi mevcut oynatıcıyla uyumsuz olabilir. Oynatıcı seçimi destekleniyorsa hata kartında diğer yerleşik oynatıcıyı deneyebilirsiniz."
        case let .generic(msg):
            msg
        }
    }

    public var iconName: String {
        switch self {
        case .authExpired: "lock.shield.fill"
        case .streamNotFound: "antenna.radiowaves.left.and.right.slash"
        case .serverUnresponsive: "wifi.exclamationmark"
        case .connectionLimitExceeded: "person.2.slash.fill"
        case .codecOrFormatUnsupported: "film.stack.fill"
        case .generic: "exclamationmark.triangle.fill"
        }
    }
}

public struct PlayerFriendlyErrorView: View {
    public let errorMessage: String
    public let onRetry: () -> Void
    public let onSwitchToBackup: (() -> Void)?
    public let backupChannelName: String?
    public let onSwitchPlaybackEngine: (() -> Void)?
    public let playbackEngineTitle: String?
    public let positionRecoveryHint: String?
    public let onOpenSpeedTest: (() -> Void)?
    public let onRequestXtreamLiveOutputFormats: (() -> Void)?
    public let onSelectXtreamLiveOutputFormat: ((XtreamLiveOutputFormat) -> Void)?
    public let xtreamLiveOutputFormatOptions: [XtreamLiveOutputFormat]
    public let didRequestXtreamLiveOutputFormats: Bool
    public let isLoadingXtreamLiveOutputFormats: Bool
    public let xtreamLiveOutputFormatError: String?
    public let onDismiss: () -> Void

    @FocusState private var focusedAction: FocusedAction?
    @AccessibilityFocusState private var accessibilityFocusedAction: FocusedAction?

    private enum FocusedAction: Hashable {
        case retry
        case backup
        case playbackEngine
        case speedTest
        case outputFormatRequest
        case outputFormat(XtreamLiveOutputFormat)
        case dismiss
    }

    public init(
        errorMessage: String,
        onRetry: @escaping () -> Void,
        onSwitchToBackup: (() -> Void)? = nil,
        backupChannelName: String? = nil,
        onSwitchPlaybackEngine: (() -> Void)? = nil,
        playbackEngineTitle: String? = nil,
        positionRecoveryHint: String? = nil,
        onOpenSpeedTest: (() -> Void)? = nil,
        onRequestXtreamLiveOutputFormats: (() -> Void)? = nil,
        onSelectXtreamLiveOutputFormat: ((XtreamLiveOutputFormat) -> Void)? = nil,
        xtreamLiveOutputFormatOptions: [XtreamLiveOutputFormat] = [],
        didRequestXtreamLiveOutputFormats: Bool = false,
        isLoadingXtreamLiveOutputFormats: Bool = false,
        xtreamLiveOutputFormatError: String? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.errorMessage = errorMessage
        self.onRetry = onRetry
        self.onSwitchToBackup = onSwitchToBackup
        self.backupChannelName = backupChannelName
        self.onSwitchPlaybackEngine = onSwitchPlaybackEngine
        self.playbackEngineTitle = playbackEngineTitle
        self.positionRecoveryHint = positionRecoveryHint
        self.onOpenSpeedTest = onOpenSpeedTest
        self.onRequestXtreamLiveOutputFormats = onRequestXtreamLiveOutputFormats
        self.onSelectXtreamLiveOutputFormat = onSelectXtreamLiveOutputFormat
        self.xtreamLiveOutputFormatOptions = xtreamLiveOutputFormatOptions
        self.didRequestXtreamLiveOutputFormats = didRequestXtreamLiveOutputFormats
        self.isLoadingXtreamLiveOutputFormats = isLoadingXtreamLiveOutputFormats
        self.xtreamLiveOutputFormatError = xtreamLiveOutputFormatError
        self.onDismiss = onDismiss
    }

    private var maximumCardWidth: CGFloat {
        #if os(tvOS)
            620
        #else
            440
        #endif
    }

    public var body: some View {
        let diagnosis = PlayerDiagnosticCategory.diagnose(error: errorMessage)

        VStack(spacing: 18) {
            Image(systemName: diagnosis.iconName)
                .font(.system(size: 42))
                .foregroundStyle(.orange)
                .padding(14)
                .background(Color.orange.opacity(0.16))
                .clipShape(Circle())

            VStack(spacing: 6) {
                Text(diagnosis.title)
                    .font(.headline.bold())
                    .foregroundStyle(.white)

                Text(diagnosis.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 10) {
                Button(action: onRetry) {
                    VStack(spacing: 3) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text(AppStrings.Player.retrySameStream)
                                .fontWeight(.semibold)
                        }
                        if let positionRecoveryHint {
                            Text(positionRecoveryHint)
                                .font(.caption)
                                .fontWeight(.regular)
                                .foregroundStyle(.white.opacity(0.84))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .font(.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#0A84FF"))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlayerErrorActionButtonStyle())
                .focused($focusedAction, equals: .retry)
                .accessibilityFocused($accessibilityFocusedAction, equals: .retry)
                .accessibilityHint(positionRecoveryHint ?? AppStrings.Player.retrySameStreamHint)

                if let onSwitchPlaybackEngine, let playbackEngineTitle {
                    Button(action: onSwitchPlaybackEngine) {
                        VStack(spacing: 3) {
                            HStack(spacing: 8) {
                                Image(systemName: "cpu")
                                Text(playbackEngineTitle)
                                    .fontWeight(.semibold)
                            }
                            if let positionRecoveryHint {
                                Text(positionRecoveryHint)
                                    .font(.caption)
                                    .fontWeight(.regular)
                                    .foregroundStyle(.white.opacity(0.84))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.14))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlayerErrorActionButtonStyle())
                    .focused($focusedAction, equals: .playbackEngine)
                    .accessibilityFocused($accessibilityFocusedAction, equals: .playbackEngine)
                    .accessibilityHint(positionRecoveryHint ?? AppStrings.Player.tryOtherPlaybackEngineHint)
                }

                if let onSwitchToBackup {
                    Button(action: onSwitchToBackup) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.swap")
                            Text(backupChannelName.map { "\(AppStrings.Player.switchToBackup) (\($0))" } ?? AppStrings.Player.switchToBackup)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#0A84FF"))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlayerErrorActionButtonStyle())
                    .focused($focusedAction, equals: .backup)
                    .accessibilityFocused($accessibilityFocusedAction, equals: .backup)
                    .accessibilityHint(AppStrings.Player.backupLiveSourceHint)
                }

                if let onOpenSpeedTest {
                    Button {
                        onOpenSpeedTest()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "speedometer")
                            Text("Sunucu Hızını Test Et")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlayerErrorActionButtonStyle())
                    .focused($focusedAction, equals: .speedTest)
                    .accessibilityFocused($accessibilityFocusedAction, equals: .speedTest)
                    .accessibilityHint(AppStrings.Player.serverSpeedTestHint)
                }

                if let onRequestXtreamLiveOutputFormats {
                    Button {
                        guard !isLoadingXtreamLiveOutputFormats else { return }
                        onRequestXtreamLiveOutputFormats()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.on.rectangle.angled")
                            Text("Sağlayıcı biçimlerini göster")
                                .fontWeight(.semibold)
                            if isLoadingXtreamLiveOutputFormats {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlayerErrorActionButtonStyle())
                    .focused($focusedAction, equals: .outputFormatRequest)
                    .accessibilityFocused($accessibilityFocusedAction, equals: .outputFormatRequest)
                    .accessibilityHint("Sağlayıcının bu kanal için ilan ettiği alternatifleri ister.")

                    if isLoadingXtreamLiveOutputFormats {
                        Text("Sağlayıcı biçimleri yükleniyor…")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .accessibilityAddTraits(.updatesFrequently)
                    } else if let xtreamLiveOutputFormatError {
                        Text(xtreamLiveOutputFormatError)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityAddTraits(.isStaticText)
                    } else if didRequestXtreamLiveOutputFormats, xtreamLiveOutputFormatOptions.isEmpty {
                        Text("Sağlayıcı başka bir canlı biçim ilan etmedi.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .accessibilityAddTraits(.isStaticText)
                    }

                    if let onSelectXtreamLiveOutputFormat {
                        ForEach(xtreamLiveOutputFormatOptions) { format in
                            Button {
                                onSelectXtreamLiveOutputFormat(format)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.rectangle")
                                    Text(format.displayName)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(hex: "#0A84FF"))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PlayerErrorActionButtonStyle())
                            .focused($focusedAction, equals: .outputFormat(format))
                            .accessibilityFocused($accessibilityFocusedAction, equals: .outputFormat(format))
                            .accessibilityLabel("\(format.displayName) canlı biçimini seç")
                            .accessibilityHint("Seçilen biçimi bu playlist için kaydeder ve kanalı yeniden açar.")
                        }
                    }
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Kapat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .buttonStyle(PlayerErrorActionButtonStyle())
                .focused($focusedAction, equals: .dismiss)
                .accessibilityFocused($accessibilityFocusedAction, equals: .dismiss)
                .accessibilityHint(AppStrings.Player.closePlayerHint)
            }
            .padding(.top, 6)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(white: 0.12).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .frame(maxWidth: maximumCardWidth)
        .shadow(color: Color.black.opacity(0.6), radius: 16, y: 8)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            focusedAction = .retry
            accessibilityFocusedAction = .retry
        }
    }
}

private struct PlayerErrorActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FocusableButton(configuration: configuration)
    }

    private struct FocusableButton: View {
        @Environment(\.isFocused) private var isFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        let configuration: ButtonStyle.Configuration

        var body: some View {
            configuration.label
                .overlay {
                    Capsule()
                        .strokeBorder(isFocused ? Color.white : .clear, lineWidth: 3)
                        .padding(2)
                }
                .scaleEffect(configuration.isPressed ? 0.98 : (isFocused && !reduceMotion ? 1.035 : 1))
                .shadow(color: isFocused ? Color.white.opacity(0.24) : .clear, radius: isFocused ? 10 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isFocused)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}
