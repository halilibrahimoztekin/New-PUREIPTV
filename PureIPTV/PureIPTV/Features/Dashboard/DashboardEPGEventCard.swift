import SwiftUI

struct DashboardEPGEventCard: View {
    @Environment(\.locale) private var locale
    let event: DashboardFeature.EPGEvent
    let onSelectChannel: (MediaModels.Item) -> Void
    let onChooseChannel: () -> Void

    private var isSportsFixture: Bool {
        let lowered = event.program.title.lowercased()
        return lowered.contains(" vs ") || lowered.contains(" v ") || event.program.title.contains(" - ")
    }

    var body: some View {
        Button { onSelectChannel(event.channel) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(event.program.isPlayingNow ? Color.red : Color(hex: "#0A84FF"))
                        .frame(width: 8, height: 8)
                    Text(event.program.isPlayingNow ? AppStrings.Dashboard.nowAiring : event.program.formattedStartTime(locale: locale))
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

                Text(event.program.formattedTimeRange(locale: locale))
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
        .accessibilityLabel("\(event.program.title), \(event.channel.title), \(event.program.formattedTimeRange(locale: locale))")
        .accessibilityHint(AppStrings.Common.watchNow)
        .contextMenu {
            if isSportsFixture {
                Button("Kanala elle eşle", systemImage: "magnifyingglass", action: onChooseChannel)
            }
            if !event.alternateChannels.isEmpty {
                ForEach(event.alternateChannels) { channel in
                    Button {
                        onSelectChannel(channel)
                    } label: {
                        Label(channel.title, systemImage: "play.tv")
                    }
                }
            }
        }
    }
}

struct DashboardEPGChannelPicker: View {
    @State private var searchText = ""
    let channels: [MediaModels.Item]
    let onSelect: (MediaModels.Item) -> Void
    let onCancel: () -> Void

    private var filteredChannels: [MediaModels.Item] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return channels }
        return channels.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(filteredChannels) { channel in
                Button {
                    onSelect(channel)
                } label: {
                    Label(channel.title, systemImage: "play.tv")
                }
            }
            .searchable(text: $searchText, prompt: "Kanal ara")
            .navigationTitle("Spor yayını için kanal seç")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.Common.cancel, action: onCancel)
                }
            }
        }
    }
}
