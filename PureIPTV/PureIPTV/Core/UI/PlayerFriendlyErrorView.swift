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
            "Yayın kodlayıcısı mevcut oynatıcı motorunda çözümlenemedi. Harici oynatıcı (VLC/Infuse) ile açmayı deneyebilirsiniz."
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
    public let onOpenSpeedTest: (() -> Void)?
    public let onDismiss: () -> Void

    public init(
        errorMessage: String,
        onRetry: @escaping () -> Void,
        onSwitchToBackup: (() -> Void)? = nil,
        backupChannelName: String? = nil,
        onOpenSpeedTest: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.errorMessage = errorMessage
        self.onRetry = onRetry
        self.onSwitchToBackup = onSwitchToBackup
        self.backupChannelName = backupChannelName
        self.onOpenSpeedTest = onOpenSpeedTest
        self.onDismiss = onDismiss
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

            // Action Buttons
            VStack(spacing: 10) {
                if let onSwitchToBackup {
                    Button {
                        onSwitchToBackup()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.swap")
                            Text(backupChannelName != nil ? "\(AppStrings.Player.switchToBackup) (\(backupChannelName!))" : AppStrings.Player.switchToBackup)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#0A84FF"))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onRetry()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Yeniden Bağlan")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

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
                    .buttonStyle(.plain)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Kapat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .buttonStyle(.plain)
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
        .frame(maxWidth: 440)
        .shadow(color: Color.black.opacity(0.6), radius: 16, y: 8)
    }
}
