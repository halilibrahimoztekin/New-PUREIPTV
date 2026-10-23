import CoreImage.CIFilterBuiltins
import Foundation
import SwiftUI

public final class TVOnboardingManager: @unchecked Sendable {
    public static let shared = TVOnboardingManager()

    public let sessionID: String = UUID().uuidString.prefix(8).uppercased()

    private init() {}

    public var pairingURLString: String {
        "pureiptv://setup?session=\(sessionID)&device=AppleTV"
    }

    public func generateQRCodeImage(from string: String) -> Image? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                #if os(iOS)
                    return Image(uiImage: UIImage(cgImage: cgImage))
                #else
                    return Image(uiImage: UIImage(cgImage: cgImage))
                #endif
            }
        }
        return nil
    }
}
