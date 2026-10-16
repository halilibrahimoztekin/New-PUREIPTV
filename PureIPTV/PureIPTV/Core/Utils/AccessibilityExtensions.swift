import SwiftUI

public extension View {
    /// Applies standardized VoiceOver hints and labels (Madde #87)
    func playerAccessibility(label: String, hint: String? = nil) -> some View {
        accessibilityLabel(Text(label))
            .accessibilityHint(hint.map { Text($0) } ?? Text(""))
            .accessibilityAddTraits(.isButton)
    }

    /// Dynamic Type friendly padding and minimum tap area (44x44 pt Apple HIG standard)
    func standardTouchTarget() -> some View {
        frame(minWidth: 44, minHeight: 44)
    }
}
