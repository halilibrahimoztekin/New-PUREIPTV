import SwiftUI

public struct FluidScaleButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == FluidScaleButtonStyle {
    static var fluidScale: FluidScaleButtonStyle {
        FluidScaleButtonStyle()
    }
}
