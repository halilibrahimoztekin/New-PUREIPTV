import SwiftUI

public struct TVOnboardingQRView: View {
    public let onDismiss: () -> Void

    @State private var qrImage: Image?
    @State private var isPaired: Bool = false
    private let manager = TVOnboardingManager.shared

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 28) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("QR Kod ile Anında Kurulum")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Apple TV'de kumandayla uzun linkler ve şifreler yazmaya son!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // QR Code Container
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .frame(width: 220, height: 220)
                    .shadow(color: .black.opacity(0.3), radius: 12)

                if let img = qrImage {
                    img
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190, height: 190)
                } else {
                    ProgressView()
                }
            }

            // Instructions Steps
            VStack(alignment: .leading, spacing: 10) {
                stepRow(number: "1", text: "iPhone veya iPad kameranızı açıp QR kodu tarayın.")
                stepRow(number: "2", text: "PureIPTV bildirimine dokunarak playlistinizi seçin.")
                stepRow(number: "3", text: "Kurulum Apple TV'ye anında aktarılacaktır.")
            }
            .frame(maxWidth: 420)
            .padding(.horizontal)

            // Session Code Pill
            HStack(spacing: 8) {
                Circle()
                    .fill(isPaired ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(isPaired ? "Eşleşti, aktarılıyor..." : "Oturum Kodu: \(manager.sessionID) (Bağlantı Bekleniyor)")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08), in: Capsule())

            Button("Kapat", action: onDismiss)
                .font(.body.bold())
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .onAppear {
            qrImage = manager.generateQRCodeImage(from: manager.pairingURLString)
        }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}
