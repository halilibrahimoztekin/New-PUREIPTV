import SwiftUI

/// Empty-state feedback for a failed section request that can be retried in place.
public struct RetryableSectionEmptyState: View {
    private let message: String
    private let retryAction: () -> Void

    #if os(tvOS)
        @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 68
        @ScaledMetric(relativeTo: .title) private var messageSize: CGFloat = 26
        @ScaledMetric(relativeTo: .title) private var buttonSize: CGFloat = 25
    #else
        @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 42
        @ScaledMetric(relativeTo: .body) private var messageSize: CGFloat = 16
        @ScaledMetric(relativeTo: .headline) private var buttonSize: CGFloat = 17
    #endif

    public init(message: String, retryAction: @escaping () -> Void) {
        self.message = message
        self.retryAction = retryAction
    }

    public var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "arrow.clockwise.circle")
                .font(.system(size: iconSize, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.5))
                .accessibilityHidden(true)

            Text(message)
                .font(.system(size: messageSize, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: retryAction) {
                Label(AppStrings.Common.retry, systemImage: "arrow.clockwise")
                    .font(.system(size: buttonSize, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityHint("Yalnızca bu bölüm yeniden yüklenir".localized)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
