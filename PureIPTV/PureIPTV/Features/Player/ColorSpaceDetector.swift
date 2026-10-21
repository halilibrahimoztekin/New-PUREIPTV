import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

// MARK: - VideoDynamicRange

/// Represents the high dynamic range / standard dynamic range format of a video stream.
public enum VideoDynamicRange: String, CaseIterable, Equatable, Hashable, Sendable, Codable {
    case dolbyVision
    case hdr10Plus
    case hdr10
    case hlg
    case sdr
    case unknown

    public var displayName: String {
        switch self {
        case .dolbyVision:
            "Dolby Vision"
        case .hdr10Plus:
            "HDR10+"
        case .hdr10:
            "HDR10"
        case .hlg:
            "HLG HDR"
        case .sdr:
            "SDR"
        case .unknown:
            "Standart (SDR)"
        }
    }

    public var badgeTitle: String {
        switch self {
        case .dolbyVision:
            "DOLBY VISION"
        case .hdr10Plus:
            "HDR10+"
        case .hdr10:
            "HDR10"
        case .hlg:
            "HLG"
        case .sdr:
            "SDR"
        case .unknown:
            "SDR"
        }
    }

    public var shortBadge: String {
        switch self {
        case .dolbyVision:
            "DV"
        case .hdr10Plus:
            "HDR10+"
        case .hdr10:
            "HDR"
        case .hlg:
            "HLG"
        case .sdr:
            "SDR"
        case .unknown:
            "SDR"
        }
    }

    public var iconName: String {
        switch self {
        case .dolbyVision:
            "sparkles.tv"
        case .hdr10Plus, .hdr10:
            "sun.max.fill"
        case .hlg:
            "tv.badge.wifi.fill"
        case .sdr, .unknown:
            "tv"
        }
    }

    public var primaryColorHex: String {
        switch self {
        case .dolbyVision:
            "#BF5AF2" // Neon Purple / Dolby Magenta
        case .hdr10Plus, .hdr10:
            "#FFD60A" // Cinematic Gold
        case .hlg:
            "#30D158" // Apple Vibrant Green
        case .sdr, .unknown:
            "#8E8E93" // System Gray
        }
    }

    public var gradientHexes: [String] {
        switch self {
        case .dolbyVision:
            ["#BF5AF2", "#FF9F0A"] // Purple to Amber
        case .hdr10Plus, .hdr10:
            ["#FFD60A", "#FF9F0A"] // Gold to Amber
        case .hlg:
            ["#30D158", "#0A84FF"] // Green to Electric Blue
        case .sdr, .unknown:
            ["#636366", "#48484A"]
        }
    }

    public var isHDR: Bool {
        switch self {
        case .dolbyVision, .hdr10Plus, .hdr10, .hlg:
            true
        case .sdr, .unknown:
            false
        }
    }

    public var colorGamut: String {
        switch self {
        case .dolbyVision:
            "BT.2020 / DCI-P3 Geniş Renk Gamı"
        case .hdr10Plus, .hdr10, .hlg:
            "BT.2020 Geniş Renk Gamı"
        case .sdr, .unknown:
            "BT.709 Standart Gam"
        }
    }

    public var bitDepth: Int {
        switch self {
        case .dolbyVision:
            12
        case .hdr10Plus, .hdr10, .hlg:
            10
        case .sdr, .unknown:
            8
        }
    }

    public var transferFunction: String {
        switch self {
        case .dolbyVision:
            "SMPTE ST 2084 (PQ) Dinamik Metadata"
        case .hdr10Plus:
            "SMPTE ST 2084 (PQ) Dinamik HDR10+"
        case .hdr10:
            "SMPTE ST 2084 (PQ) Statik HDR10"
        case .hlg:
            "ARIB STD-B67 (HLG)"
        case .sdr, .unknown:
            "BT.709 OETF Standart Gamma"
        }
    }

    public var peakLuminanceDescription: String {
        switch self {
        case .dolbyVision, .hdr10Plus:
            "4000 nits Maksimum Parlaklık"
        case .hdr10, .hlg:
            "1000 nits Maksimum Parlaklık"
        case .sdr, .unknown:
            "100 nits Standart Dinamik Aralık"
        }
    }
}

// MARK: - DynamicRangeInfo

/// Detailed diagnostic info regarding the video color space, transfer function and display capabilities.
public struct DynamicRangeInfo: Equatable, Hashable, Sendable, Codable {
    public let range: VideoDynamicRange
    public let colorGamut: String
    public let bitDepth: Int
    public let transferFunction: String
    public let peakLuminanceDescription: String
    public let isDisplayHDRCapable: Bool
    public let detectedResolution: String?

    public init(
        range: VideoDynamicRange,
        colorGamut: String? = nil,
        bitDepth: Int? = nil,
        transferFunction: String? = nil,
        peakLuminanceDescription: String? = nil,
        isDisplayHDRCapable: Bool = true,
        detectedResolution: String? = nil
    ) {
        self.range = range
        self.colorGamut = colorGamut ?? range.colorGamut
        self.bitDepth = bitDepth ?? range.bitDepth
        self.transferFunction = transferFunction ?? range.transferFunction
        self.peakLuminanceDescription = peakLuminanceDescription ?? range.peakLuminanceDescription
        self.isDisplayHDRCapable = isDisplayHDRCapable
        self.detectedResolution = detectedResolution
    }
}

// MARK: - ColorSpaceDetector

/// Intelligent video stream color space, transfer function and dynamic range analyzer.
/// Inspects stream title, stream URL parameters and underlying AVAsset video track characteristics.
public enum ColorSpaceDetector {
    /// Pre-compiled regex patterns for maximum efficiency
    private static let dolbyVisionRegex = try? NSRegularExpression(
        pattern: #"\b(dolby\s*vision|dovi|dvh1|dvhe|profile\s*[578]|dv\b)"#,
        options: .caseInsensitive
    )

    private static let hdr10PlusRegex = try? NSRegularExpression(
        pattern: #"\b(hdr10\+|hdr10plus|hdr\s*10\+)(?!\w)"#,
        options: .caseInsensitive
    )

    private static let hdr10Regex = try? NSRegularExpression(
        pattern: #"\b(hdr10|hdr|bt2020|bt\.2020|rec2020|smpte\s*2084|st2084|10bit|10-bit)\b"#,
        options: .caseInsensitive
    )

    private static let hlgRegex = try? NSRegularExpression(
        pattern: #"\b(hlg|hybrid\s*log\s*gamma|arib)\b"#,
        options: .caseInsensitive
    )

    private static let sdrRegex = try? NSRegularExpression(
        pattern: #"\b(sdr|bt709|bt\.709|rec709|8bit|8-bit)\b"#,
        options: .caseInsensitive
    )

    private static let uhd4KRegex = try? NSRegularExpression(
        pattern: #"\b(4k|2160p|uhd|4k-uhd)\b"#,
        options: .caseInsensitive
    )

    private static let fhd1080Regex = try? NSRegularExpression(
        pattern: #"\b(1080p|fhd|fullhd)\b"#,
        options: .caseInsensitive
    )

    /// Analyzes stream title and stream URL string to detect the video's dynamic range.
    public static func detectFromText(title: String, urlString: String? = nil) -> DynamicRangeInfo {
        let combined = "\(title) \(urlString ?? "")"
        let range = NSRange(location: 0, length: combined.utf16.count)

        // 1. Check for Dolby Vision
        if let regex = dolbyVisionRegex, regex.firstMatch(in: combined, options: [], range: range) != nil {
            return DynamicRangeInfo(
                range: .dolbyVision,
                detectedResolution: detectResolution(in: combined, range: range)
            )
        }

        // 2. Check for HDR10+
        if let regex = hdr10PlusRegex, regex.firstMatch(in: combined, options: [], range: range) != nil {
            return DynamicRangeInfo(
                range: .hdr10Plus,
                detectedResolution: detectResolution(in: combined, range: range)
            )
        }

        // 3. Check for HLG
        if let regex = hlgRegex, regex.firstMatch(in: combined, options: [], range: range) != nil {
            return DynamicRangeInfo(
                range: .hlg,
                detectedResolution: detectResolution(in: combined, range: range)
            )
        }

        // 4. Check for HDR10 / General HDR
        if let regex = hdr10Regex, regex.firstMatch(in: combined, options: [], range: range) != nil {
            return DynamicRangeInfo(
                range: .hdr10,
                detectedResolution: detectResolution(in: combined, range: range)
            )
        }

        // 5. Check for explicit SDR
        if let regex = sdrRegex, regex.firstMatch(in: combined, options: [], range: range) != nil {
            return DynamicRangeInfo(
                range: .sdr,
                detectedResolution: detectResolution(in: combined, range: range)
            )
        }

        // Fallback default
        return DynamicRangeInfo(
            range: .sdr,
            detectedResolution: detectResolution(in: combined, range: range)
        )
    }

    private static func detectResolution(in text: String, range: NSRange) -> String? {
        if let regex = uhd4KRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            return "4K UHD"
        }
        if let regex = fhd1080Regex, regex.firstMatch(in: text, options: [], range: range) != nil {
            return "1080p FHD"
        }
        return nil
    }

    /// Asynchronously inspects AVAsset video tracks to detect native HDR characteristics.
    public static func detectFromAsset(asset: AVAsset) async -> DynamicRangeInfo? {
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let videoTrack = tracks.first else { return nil }

            #if os(iOS) || os(tvOS)
                if #available(iOS 14.0, tvOS 14.0, *) {
                    let hasHDR = videoTrack.hasMediaCharacteristic(.containsHDRVideo)
                    if hasHDR {
                        return DynamicRangeInfo(range: .hdr10)
                    }
                }
            #endif

            // Inspect CMFormatDescription if available
            let formatDescriptions = try await videoTrack.load(.formatDescriptions)
            for desc in formatDescriptions {
                if let extensions = CMFormatDescriptionGetExtensions(desc) as? [String: Any] {
                    // Check Color Primaries
                    if let primaries = extensions[kCVImageBufferColorPrimariesKey as String] as? String {
                        if primaries == (kCVImageBufferColorPrimaries_ITU_R_2020 as String) {
                            // Check Transfer Function
                            if let transfer = extensions[kCVImageBufferTransferFunctionKey as String] as? String {
                                if transfer == (kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String) {
                                    return DynamicRangeInfo(range: .hdr10)
                                } else if transfer == (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String) {
                                    return DynamicRangeInfo(range: .hlg)
                                }
                            }
                            return DynamicRangeInfo(range: .hdr10)
                        }
                    }
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    /// Evaluates display hardware capabilities for HDR playback.
    @MainActor
    public static func checkDisplayCapabilities() -> (isCapable: Bool, maxEDR: Double) {
        #if canImport(UIKit)
            let maxEDR = Double(UIScreen.main.potentialEDRHeadroom)
            let isP3 = UIScreen.main.traitCollection.displayGamut == .P3
            let isCapable = maxEDR > 1.0 || isP3
            return (isCapable, maxEDR)
        #else
            return (true, 1.0)
        #endif
    }
}
