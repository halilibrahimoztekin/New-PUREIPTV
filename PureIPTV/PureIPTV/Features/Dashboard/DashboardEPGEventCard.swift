import SwiftUI

struct DashboardEPGEventCard: View {
    let event: DashboardFeature.EPGEvent
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(event.program.isPlayingNow ? Color.red : Color(hex: "#0A84FF"))
                        .frame(width: 8, height: 8)
                    Text(event.program.isPlayingNow ? AppStrings.Dashboard.nowAiring : event.program.formattedStartTime)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                    Spacer(minLength: 8)
                    Image(systemName: "play.fill")
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.78))

                Text(event.program.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)

                Text(event.channel.title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                Text(event.program.formattedTimeRange)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 154, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#182438"), Color(hex: "#111116")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    }
            }
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityLabel("\(event.program.title), \(event.channel.title), \(event.program.formattedTimeRange)")
        .accessibilityHint(AppStrings.Common.watchNow)
    }
}
