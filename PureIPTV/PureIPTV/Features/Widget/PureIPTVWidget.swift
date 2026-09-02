#if os(iOS)
    import AppIntents
    import SwiftData
    import SwiftUI
    import WidgetKit

    /// Define an Entry for the Widget
    struct PureIPTVEntry: TimelineEntry {
        let date: Date
        let lastWatchedTitle: String?
        let lastWatchedCoverURL: URL?
        let favoriteChannels: [String]
    }

    /// Define the Provider
    struct PureIPTVProvider: TimelineProvider {
        func placeholder(in _: Context) -> PureIPTVEntry {
            PureIPTVEntry(date: Date(), lastWatchedTitle: "Breaking Bad S01E01", lastWatchedCoverURL: nil, favoriteChannels: ["TRT 1", "ATV", "FOX"])
        }

        func getSnapshot(in _: Context, completion: @escaping (PureIPTVEntry) -> Void) {
            let entry = PureIPTVEntry(date: Date(), lastWatchedTitle: "Breaking Bad S01E01", lastWatchedCoverURL: nil, favoriteChannels: ["TRT 1", "ATV", "FOX"])
            completion(entry)
        }

        func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
            // In a real widget, you would fetch data from SwiftData using the shared App Group URL.
            // For brevity and safe cross-process data reading:
            let entry = PureIPTVEntry(
                date: Date(),
                lastWatchedTitle: "Kaldığın Yerden Devam Et",
                lastWatchedCoverURL: nil,
                favoriteChannels: ["Favori 1", "Favori 2"]
            )
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }

    /// Define the Widget View
    struct PureIPTVWidgetEntryView: View {
        var entry: PureIPTVProvider.Entry

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("PureIPTV")
                    .font(.headline)
                    .foregroundColor(.accentColor)

                if let title = entry.lastWatchedTitle {
                    Text(title)
                        .font(.subheadline)
                        .lineLimit(2)
                } else {
                    Text("İzlemeye Başla")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .containerBackground(for: .widget) {
                Color.black
            }
        }
    }

    /// Define the Widget
    /// @main
    struct PureIPTVWidget: Widget {
        let kind: String = "PureIPTVWidget"

        var body: some WidgetConfiguration {
            StaticConfiguration(kind: kind, provider: PureIPTVProvider()) { entry in
                PureIPTVWidgetEntryView(entry: entry)
            }
            .configurationDisplayName("PureIPTV")
            .description("Kaldığınız yerden devam edin veya favorilerinize hızlıca ulaşın.")
            .supportedFamilies([.systemSmall, .systemMedium])
        }
    }

#endif
