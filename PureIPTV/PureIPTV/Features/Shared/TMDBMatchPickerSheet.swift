import SwiftUI

/// A reusable sheet for searching and selecting a TMDB movie or series match.
public struct TMDBMatchPickerSheet: View {
    private let results: [TMDBMovieSearchResultDTO]
    private let selectedTMDBID: Int?
    private let isLoading: Bool
    private let onSearch: (String) -> Void
    private let onSelect: (Int) -> Void
    private let onClear: () -> Void
    private let onDismiss: () -> Void

    @State private var query = ""

    public init(
        results: [TMDBMovieSearchResultDTO],
        selectedTMDBID: Int?,
        isLoading: Bool,
        search: @escaping (String) -> Void,
        select: @escaping (Int) -> Void,
        clear: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.results = results
        self.selectedTMDBID = selectedTMDBID
        self.isLoading = isLoading
        onSearch = search
        onSelect = select
        onClear = clear
        onDismiss = dismiss
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                searchBar

                if selectedTMDBID != nil {
                    Button(role: .destructive, action: onClear) {
                        Label(AppStrings.TMDBMatchPicker.clearMatch, systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityHint(AppStrings.TMDBMatchPicker.clearMatchHint)
                }

                if isLoading {
                    ProgressView(AppStrings.Common.loading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    ContentUnavailableView(
                        AppStrings.TMDBMatchPicker.noResults,
                        systemImage: "film",
                        description: Text(AppStrings.TMDBMatchPicker.noResultsHint)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(results, id: \.id) { result in
                        resultRow(result)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.horizontal)
            .navigationTitle(AppStrings.TMDBMatchPicker.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.Common.close, action: onDismiss)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            TextField(AppStrings.TMDBMatchPicker.searchPlaceholder, text: $query)
                .submitLabel(.search)
                .onSubmit(performSearch)
                .accessibilityLabel(AppStrings.TMDBMatchPicker.searchAccessibilityLabel)

            Button(action: performSearch) {
                Image(systemName: "magnifyingglass")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(AppStrings.Common.search)
        }
    }

    private func resultRow(_ result: TMDBMovieSearchResultDTO) -> some View {
        let title = result.title ?? result.name ?? result.originalTitle ?? result.originalName ?? "—"
        let date = result.releaseDate ?? result.firstAirDate
        let isSelected = result.id == selectedTMDBID

        return Button {
            onSelect(result.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let date, !date.isEmpty {
                        Text(String(date.prefix(4)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let overview = result.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if isSelected {
                    Label(AppStrings.TMDBMatchPicker.selected, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? AppStrings.TMDBMatchPicker.selected : "")
        .accessibilityHint(AppStrings.TMDBMatchPicker.selectResultHint)
    }

    private func performSearch() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        onSearch(trimmedQuery)
    }
}
