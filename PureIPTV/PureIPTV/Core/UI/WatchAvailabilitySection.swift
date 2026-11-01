import SwiftUI

struct WatchAvailabilitySection: View {
    let countryCode: String?
    let availability: TMDBWatchProviderRegionDTO?
    let updatedAt: Date?
    let isLoading: Bool
    let failed: Bool
    let onSelectCountry: (String?) -> Void
    let onRetry: () -> Void

    @Environment(\.locale) private var locale

    private struct CountryOption: Identifiable {
        let code: String
        let name: String

        var id: String {
            code
        }
    }

    private struct ProviderGroup: Identifiable {
        let title: String
        let providers: [TMDBWatchProviderDTO]

        var id: String {
            title
        }
    }

    private var countries: [CountryOption] {
        Locale.Region.isoRegions.compactMap { region in
            let code = region.identifier.uppercased()
            guard code.count == 2,
                  let name = locale.localizedString(forRegionCode: code) else { return nil }
            return CountryOption(code: code, name: name)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var selectedCountryName: String? {
        guard let countryCode else { return nil }
        return locale.localizedString(forRegionCode: countryCode)
    }

    private var providerGroups: [ProviderGroup] {
        guard let availability else { return [] }
        return [
            ProviderGroup(title: AppStrings.WatchAvailability.subscription, providers: availability.flatrate ?? []),
            ProviderGroup(title: AppStrings.WatchAvailability.free, providers: availability.free ?? []),
            ProviderGroup(title: AppStrings.WatchAvailability.adSupported, providers: availability.ads ?? []),
            ProviderGroup(title: AppStrings.WatchAvailability.rent, providers: availability.rent ?? []),
            ProviderGroup(title: AppStrings.WatchAvailability.buy, providers: availability.buy ?? []),
        ].filter { !$0.providers.isEmpty }
    }

    private var tmdbURL: URL? {
        guard let link = availability?.link,
              let url = URL(string: link),
              url.scheme?.lowercased() == "https",
              ["www.themoviedb.org", "themoviedb.org"].contains(url.host?.lowercased() ?? ""),
              url.user == nil,
              url.password == nil else { return nil }
        return url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                Text(AppStrings.WatchAvailability.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Menu {
                    if countryCode != nil {
                        Button(AppStrings.WatchAvailability.clearCountry, role: .destructive) {
                            onSelectCountry(nil)
                        }
                        Divider()
                    }

                    ForEach(countries) { country in
                        Button {
                            onSelectCountry(country.code)
                        } label: {
                            if country.code == countryCode {
                                Label(country.name, systemImage: "checkmark")
                            } else {
                                Text(country.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                        Text(selectedCountryName ?? AppStrings.WatchAvailability.chooseCountry)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                    .contentShape(Capsule())
                }
                .accessibilityLabel(selectedCountryName ?? AppStrings.WatchAvailability.chooseCountry)
            }

            if countryCode != nil {
                if isLoading {
                    ProgressView {
                        Text(AppStrings.Common.loading)
                    }
                    .frame(minHeight: 44, alignment: .leading)
                } else if failed {
                    HStack(spacing: 12) {
                        Text(AppStrings.WatchAvailability.fetchFailed)
                            .foregroundStyle(.secondary)
                        Button(AppStrings.Common.retry, action: onRetry)
                            .frame(minHeight: 44)
                    }
                } else {
                    if providerGroups.isEmpty {
                        Text(AppStrings.WatchAvailability.noAvailability)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(providerGroups) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)],
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(group.providers) { provider in
                                        Text(provider.providerName)
                                            .font(.subheadline)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .frame(minHeight: 40, alignment: .leading)
                                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Text(AppStrings.WatchAvailability.source)
                        if let updatedAt {
                            Text(AppStrings.WatchAvailability.updatedAt(updatedAt, locale: locale))
                        }
                        if let tmdbURL {
                            Link(destination: tmdbURL) {
                                Label(AppStrings.WatchAvailability.openOnTMDB, systemImage: "arrow.up.right")
                                    .labelStyle(.titleAndIcon)
                            }
                            .frame(minHeight: 44)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #if os(tvOS)
            .focusSection()
        #endif
    }
}
