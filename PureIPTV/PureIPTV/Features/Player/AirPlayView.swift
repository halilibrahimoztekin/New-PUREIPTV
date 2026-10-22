import AVKit
import SwiftUI

public struct AirPlayView: UIViewRepresentable {
    public var activeTintColor: UIColor = .systemBlue
    public var tintColor: UIColor = .white
    public var prioritizesVideoDevices: Bool = true

    public init(activeTintColor: UIColor = .systemBlue, tintColor: UIColor = .white, prioritizesVideoDevices: Bool = true) {
        self.activeTintColor = activeTintColor
        self.tintColor = tintColor
        self.prioritizesVideoDevices = prioritizesVideoDevices
    }

    public func makeUIView(context _: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.activeTintColor = activeTintColor
        routePickerView.tintColor = tintColor
        routePickerView.backgroundColor = .clear
        routePickerView.prioritizesVideoDevices = prioritizesVideoDevices
        return routePickerView
    }

    public func updateUIView(_ uiView: AVRoutePickerView, context _: Context) {
        uiView.activeTintColor = activeTintColor
        uiView.tintColor = tintColor
        uiView.prioritizesVideoDevices = prioritizesVideoDevices
    }
}

/// A sleek circular glass AirPlay button designed for video player HUDs
public struct AirPlayButton: View {
    public var size: CGFloat = 38

    public init(size: CGFloat = 38) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .frame(width: size, height: size)

            AirPlayView(activeTintColor: .systemBlue, tintColor: .white, prioritizesVideoDevices: true)
                .frame(width: size - 8, height: size - 8)
        }
        .frame(width: size, height: size)
    }
}

/// A sleek custom glass audio router button that presents the native AirPlay route picker
public struct GlassAudioRouteButton: View {
    public let currentRoute: AudioRouteInfo
    public var onTapped: (() -> Void)?

    public init(currentRoute: AudioRouteInfo, onTapped: (() -> Void)? = nil) {
        self.currentRoute = currentRoute
        self.onTapped = onTapped
    }

    private var accentColor: Color {
        switch currentRoute.type {
        case .airPlay:
            .blue
        case .airPods:
            .green
        case .bluetooth:
            .orange
        case .wired:
            .purple
        case .speaker, .unknown:
            .white
        }
    }

    public var body: some View {
        ZStack {
            // Background Visual Representation
            if currentRoute.isExternal {
                HStack(spacing: 6) {
                    Image(systemName: currentRoute.iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accentColor)

                    Text(currentRoute.name)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: 100)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(accentColor.opacity(0.6), lineWidth: 1)
                        )
                )
            } else {
                Image(systemName: "airplayaudio")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(AnyShapeStyle(.ultraThinMaterial), in: Circle())
            }

            // Transparent Native AVRoutePickerView directly on top for 100% native gesture handling
            AirPlayView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(0.015)
        }
        .fixedSize()
    }
}
