import SwiftUI

struct DashboardCatalogCountSummaryView: View {
    let changes: [DashboardCatalogCountChange]
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                Text(AppStrings.Dashboard.catalogCountSummaryTitle)
                #if os(tvOS)
                    .font(.system(size: 22, weight: .semibold))
                #else
                    .font(.headline)
                #endif
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Button(AppStrings.Common.done, action: onDismiss)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .frame(minHeight: 44)
            }

            Text(AppStrings.Dashboard.catalogCountSummaryDescription)
            #if os(tvOS)
                .font(.system(size: 17))
            #else
                .font(.caption)
            #endif
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(changes) { change in
                HStack(spacing: 12) {
                    Text(catalogTitle(change.catalog))
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    Text(countDescription(change))
                    #if os(tvOS)
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                    #else
                        .font(.body)
                        .monospacedDigit()
                    #endif
                        .foregroundStyle(change.netChange < 0 ? Color.orange : Color.green)
                        .accessibilityLabel(countAccessibilityDescription(change))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func catalogTitle(_ catalog: DashboardFeature.PrimaryCatalog) -> String {
        switch catalog {
        case .live: AppStrings.Search.liveTV
        case .movies: AppStrings.Search.movies
        case .series: AppStrings.Search.series
        }
    }

    private func countDescription(_ change: DashboardCatalogCountChange) -> String {
        let sign = change.netChange > 0 ? "+" : ""
        return "\(change.previousCount) → \(change.currentCount) (\(sign)\(change.netChange))"
    }

    private func countAccessibilityDescription(_ change: DashboardCatalogCountChange) -> String {
        "\(catalogTitle(change.catalog)): \(countDescription(change))"
    }
}
