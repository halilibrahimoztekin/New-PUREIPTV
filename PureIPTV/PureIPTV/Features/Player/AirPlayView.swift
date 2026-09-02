import AVKit
import SwiftUI

public struct AirPlayView: UIViewRepresentable {
    public init() {}

    public func makeUIView(context _: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.activeTintColor = .systemBlue
        routePickerView.tintColor = .white
        return routePickerView
    }

    public func updateUIView(_: AVRoutePickerView, context _: Context) {
        // No update needed
    }
}
