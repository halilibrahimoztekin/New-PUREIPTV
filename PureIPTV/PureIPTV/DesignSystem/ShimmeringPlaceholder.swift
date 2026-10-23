import Shimmer
import SwiftUI

public extension View {
    /// Masks the view as a redacted placeholder and applies a shimmering effect when `isLoading` is true.
    /// Otherwise, renders the original view normally.
    @ViewBuilder
    func shimmeringPlaceholder(isLoading: Bool) -> some View {
        if isLoading {
            redacted(reason: .placeholder)
                .shimmering()
        } else {
            self
        }
    }
}
