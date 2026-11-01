import ComposableArchitecture
import SwiftUI

private struct ViewingStatisticsRankedMedia: Identifiable {
    let id: String
    let title: String
    let kind: ViewingStatisticsContentKind
    let seconds: Double
}

struct ViewingStatisticsView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @State private var periodDays = 7
    @State private var isConfirmingClear = false

    private var currentStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -(periodDays - 1), to: today) ?? today
    }

    private var previousStart: Date {
        Calendar.current.date(byAdding: .day, value: -periodDays, to: currentStart) ?? currentStart
    }

    private var currentEntries: [ViewingStatisticsEntry] {
        store.viewingStatisticsEntries.filter { $0.day >= currentStart }
    }

    private var previousEntries: [ViewingStatisticsEntry] {
        store.viewingStatisticsEntries.filter { $0.day >= previousStart && $0.day < currentStart }
    }

    private var currentSeconds: Double {
        currentEntries.reduce(0) { $0 + $1.seconds }
    }

    private var previousSeconds: Double {
        previousEntries.reduce(0) { $0 + $1.seconds }
    }

    private var rankedMedia: [ViewingStatisticsRankedMedia] {
        let grouped = Dictionary(grouping: currentEntries, by: \.identity)
        return grouped.compactMap { identity, entries in
            guard let first = entries.first else { return nil }
            return ViewingStatisticsRankedMedia(
                id: identity,
                title: first.title,
                kind: first.kind,
                seconds: entries.reduce(0) { $0 + $1.seconds }
            )
        }
        .sorted { $0.seconds > $1.seconds }
    }

    var body: some View {
        List {
            Section {
                Picker(AppStrings.ViewingStatistics.period, selection: $periodDays) {
                    Text(AppStrings.ViewingStatistics.last7Days).tag(7)
                    Text(AppStrings.ViewingStatistics.last30Days).tag(30)
                    Text(AppStrings.ViewingStatistics.last90Days).tag(90)
                }
                #if !os(tvOS)
                .pickerStyle(.segmented)
                #endif
            }

            if currentEntries.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(AppStrings.ViewingStatistics.noData)
                            .font(.headline)
                        Text(AppStrings.ViewingStatistics.trackingNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            } else {
                Section(AppStrings.ViewingStatistics.totalTime) {
                    LabeledContent(AppStrings.ViewingStatistics.currentPeriod, value: formattedDuration(currentSeconds))
                    if previousSeconds > 0 {
                        LabeledContent(AppStrings.ViewingStatistics.previousPeriod, value: formattedDuration(previousSeconds))
                        LabeledContent(
                            AppStrings.ViewingStatistics.periodChangeLabel,
                            value: formattedChange
                        )
                    } else {
                        Text(AppStrings.ViewingStatistics.noPreviousPeriod)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(AppStrings.ViewingStatistics.contentTypes) {
                    ForEach(ViewingStatisticsContentKind.allCases, id: \.self) { kind in
                        let seconds = currentEntries
                            .filter { $0.kind == kind }
                            .reduce(0) { $0 + $1.seconds }
                        LabeledContent(title(for: kind), value: formattedDuration(seconds))
                    }
                }

                if !rankedMedia.isEmpty {
                    Section(AppStrings.ViewingStatistics.mostWatched) {
                        ForEach(rankedMedia.prefix(10)) { media in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(media.title)
                                    .lineLimit(2)
                                HStack {
                                    Text(title(for: media.kind))
                                    Spacer()
                                    Text(formattedDuration(media.seconds))
                                        .monospacedDigit()
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }

            Section(AppStrings.ViewingStatistics.privacyTitle) {
                Text(AppStrings.ViewingStatistics.privacyDetails)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(AppStrings.ViewingStatistics.trackingNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !store.viewingStatisticsEntries.isEmpty {
                Section {
                    Button(AppStrings.ViewingStatistics.clear, role: .destructive) {
                        isConfirmingClear = true
                    }
                }
            }
        }
        .navigationTitle(AppStrings.ViewingStatistics.title)
        .task(id: store.personalizationProfileID) {
            store.send(.loadViewingStatistics)
        }
        .confirmationDialog(
            AppStrings.ViewingStatistics.clearTitle,
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button(AppStrings.ViewingStatistics.clear, role: .destructive) {
                store.send(.clearViewingStatisticsTapped)
            }
            Button(AppStrings.Common.cancel, role: .cancel) {}
        } message: {
            Text(AppStrings.ViewingStatistics.clearMessage)
        }
    }

    private var formattedChange: String {
        guard previousSeconds > 0 else { return "—" }
        let percentage = ((currentSeconds - previousSeconds) / previousSeconds) * 100
        let sign = percentage > 0 ? "+" : ""
        return AppStrings.ViewingStatistics.periodChange("\(sign)\(percentage.formatted(.number.precision(.fractionLength(0))))%")
    }

    private func title(for kind: ViewingStatisticsContentKind) -> String {
        switch kind {
        case .live: AppStrings.Common.liveTV
        case .movie: AppStrings.VOD.title
        case .series: AppStrings.Series.title
        }
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .pad
        formatter.calendar = Calendar.current
        formatter.calendar?.locale = Locale.current
        return formatter.string(from: max(0, seconds)) ?? "0"
    }
}
