import AVKit
import SwiftUI

public struct AirPlayView: UIViewRepresentable {
    public var activeTintColor: UIColor = .systemBlue
    public var tintColor: UIColor = .white

    public init(activeTintColor: UIColor = .systemBlue, tintColor: UIColor = .white) {
        self.activeTintColor = activeTintColor
        self.tintColor = tintColor
    }

    public func makeUIView(context _: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.activeTintColor = activeTintColor
        routePickerView.tintColor = tintColor
        routePickerView.backgroundColor = .clear
        return routePickerView
    }

    public func updateUIView(_ uiView: AVRoutePickerView, context _: Context) {
        uiView.activeTintColor = activeTintColor
        uiView.tintColor = tintColor
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
