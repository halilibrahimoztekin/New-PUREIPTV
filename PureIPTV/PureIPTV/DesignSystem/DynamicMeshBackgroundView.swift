import CoreGraphics
import Foundation
import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Dynamic Mesh Palette

public struct DynamicMeshPalette: Equatable, Sendable {
    public let primary: Color
    public let secondary: Color
    public let accent: Color
    public let background: Color

    public nonisolated init(
        primary: Color,
        secondary: Color,
        accent: Color,
        background: Color = Color(hex: "#06060A")
    ) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.background = background
    }

    public nonisolated static let `default` = DynamicMeshPalette(
        primary: Color(hex: "#0A84FF").opacity(0.38),
        secondary: Color(hex: "#5E5CE6").opacity(0.28),
        accent: Color(hex: "#30D158").opacity(0.20),
        background: Color(hex: "#06060A")
    )

    /// Deterministic fallback palette from string (e.g. channel or movie title)
    public nonisolated static func fromSeed(_ seed: String) -> DynamicMeshPalette {
        let hash = abs(seed.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = Double((hash / 360) % 360) / 360.0
        let hue3 = Double((hash / 720) % 360) / 360.0

        return DynamicMeshPalette(
            primary: Color(hue: hue1, saturation: 0.65, brightness: 0.45).opacity(0.4),
            secondary: Color(hue: hue2, saturation: 0.55, brightness: 0.35).opacity(0.3),
            accent: Color(hue: hue3, saturation: 0.70, brightness: 0.40).opacity(0.22),
            background: Color(hex: "#06060A")
        )
    }
}

// MARK: - Dominant Color Extractor Service

public actor DominantColorExtractor {
    public static let shared = DominantColorExtractor()

    private var cache: [URL: DynamicMeshPalette] = [:]

    private init() {}

    /// Asynchronously extracts a rich atmospheric mesh palette from an image URL
    public func extractPalette(from url: URL?, fallbackTitle: String = "PureIPTV") async -> DynamicMeshPalette {
        guard let url else {
            return DynamicMeshPalette.fromSeed(fallbackTitle)
        }

        if let cached = cache[url] {
            return cached
        }

        #if canImport(UIKit)
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data),
                      let cgImage = image.cgImage
                else {
                    let fallback = DynamicMeshPalette.fromSeed(fallbackTitle)
                    cache[url] = fallback
                    return fallback
                }

                let palette = extractColors(from: cgImage)
                cache[url] = palette
                return palette
            } catch {
                let fallback = DynamicMeshPalette.fromSeed(fallbackTitle)
                cache[url] = fallback
                return fallback
            }
        #else
            return DynamicMeshPalette.fromSeed(fallbackTitle)
        #endif
    }

    #if canImport(UIKit)
        private func extractColors(from cgImage: CGImage) -> DynamicMeshPalette {
            let width = 16
            let height = 16
            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * width
            var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

            guard let context = CGContext(
                data: &rawData,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return .default
            }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            var sampledColors: [(r: Double, g: Double, b: Double, sat: Double)] = []

            for y in 0 ..< height {
                for x in 0 ..< width {
                    let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                    let r = Double(rawData[offset]) / 255.0
                    let g = Double(rawData[offset + 1]) / 255.0
                    let b = Double(rawData[offset + 2]) / 255.0
                    let a = Double(rawData[offset + 3]) / 255.0

                    guard a > 0.5 else { continue }

                    let maxC = max(r, max(g, b))
                    let minC = min(r, min(g, b))
                    let sat = maxC > 0 ? (maxC - minC) / maxC : 0.0

                    // Filter out near-black or near-white pixels
                    if maxC > 0.15, maxC < 0.95 {
                        sampledColors.append((r, g, b, sat))
                    }
                }
            }

            // Sort by saturation to prioritize vibrant, rich cinematic tones
            let vibrant = sampledColors.sorted { $0.sat > $1.sat }

            let primaryC = vibrant.first ?? (r: 0.04, g: 0.52, b: 1.0, sat: 0.8)
            let secondaryC = vibrant.dropFirst().first ?? (r: 0.37, g: 0.36, b: 0.90, sat: 0.6)
            let accentC = vibrant.dropFirst(2).first ?? (r: 0.19, g: 0.82, b: 0.35, sat: 0.7)

            return DynamicMeshPalette(
                primary: Color(red: primaryC.r, green: primaryC.g, blue: primaryC.b).opacity(0.42),
                secondary: Color(red: secondaryC.r, green: secondaryC.g, blue: secondaryC.b).opacity(0.32),
                accent: Color(red: accentC.r, green: accentC.g, blue: accentC.b).opacity(0.24),
                background: Color(hex: "#06060A")
            )
        }
    #endif
}

// MARK: - Dynamic Mesh Background View

public struct DynamicMeshBackgroundView: View {
    let imageURL: URL?
    let titleSeed: String

    @State private var currentPalette: DynamicMeshPalette = .default

    public init(imageURL: URL? = nil, titleSeed: String = "PureIPTV") {
        self.imageURL = imageURL
        self.titleSeed = titleSeed
    }

    public var body: some View {
        ZStack {
            // True Black Base
            Color(hex: "#06060A")
                .ignoresSafeArea()

            // Mesh or Gradient Layer
            meshLayer
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.85), value: currentPalette)

            // Cinematic Dark Vignette & Atmospheric Fog
            LinearGradient(
                colors: [
                    Color.black.opacity(0.25),
                    Color.black.opacity(0.65),
                    Color.black.opacity(0.92),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .task(id: imageURL) {
            let palette = await DominantColorExtractor.shared.extractPalette(from: imageURL, fallbackTitle: titleSeed)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.85)) {
                    currentPalette = palette
                }
            }
        }
    }

    @ViewBuilder
    private var meshLayer: some View {
        if #available(tvOS 18.0, iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
                ],
                colors: [
                    currentPalette.primary, currentPalette.secondary, currentPalette.background,
                    currentPalette.background, currentPalette.accent, currentPalette.primary.opacity(0.5),
                    currentPalette.background, currentPalette.background, currentPalette.secondary,
                ]
            )
        } else {
            // Multi-Color Radial Mesh Fallback for earlier versions
            ZStack {
                currentPalette.background

                RadialGradient(
                    colors: [currentPalette.primary, .clear],
                    center: .topLeading,
                    startRadius: 60,
                    endRadius: 750
                )

                RadialGradient(
                    colors: [currentPalette.secondary, .clear],
                    center: .topTrailing,
                    startRadius: 80,
                    endRadius: 850
                )

                RadialGradient(
                    colors: [currentPalette.accent, .clear],
                    center: .center,
                    startRadius: 100,
                    endRadius: 900
                )
            }
            .blur(radius: 70)
        }
    }
}

// MARK: - View Extension

public extension View {
    func dynamicMeshBackground(imageURL: URL?, titleSeed: String = "PureIPTV") -> some View {
        background(
            DynamicMeshBackgroundView(imageURL: imageURL, titleSeed: titleSeed)
        )
    }
}
