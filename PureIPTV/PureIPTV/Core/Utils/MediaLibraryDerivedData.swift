import Foundation

/// Expensive list and language-filter values shared by the VOD and Series
/// catalogs. Reducers rebuild this snapshot only when its source inputs change.
public struct MediaLibraryDerivedData: Equatable {
    public private(set) var items: [MediaModels.Item] = []
    public private(set) var availableLanguageFilters: [MediaLanguageFilter] = [.all]
    public private(set) var availableOriginalLanguageCodes: [String] = []
    public private(set) var originalLanguageCounts: [String: Int] = [:]
    public private(set) var languageFilterCounts: [MediaLanguageFilter: Int] = [:]
    public private(set) var availableLetters: Set<String> = []

    public init() {}

    public static func alphabetLetter(for title: String) -> String {
        let first = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
        return ("A" ... "Z").contains(first) ? first : "#"
    }

    public mutating func rebuild(
        from sourceItems: [MediaModels.Item],
        languageFilter: MediaLanguageFilter,
        originalLanguageCode: String?,
        sortMethod: SortMethod
    ) {
        var filterCounts: [MediaLanguageFilter: Int] = [.all: sourceItems.count]
        var originalCodes = Set<String>()
        var audioFilteredCounts: [String: Int] = [:]
        var audioFilteredUncodedCount = 0
        var audioFilteredCount = 0
        var filteredItems: [MediaModels.Item] = []
        filteredItems.reserveCapacity(sourceItems.count)

        for item in sourceItems {
            let tags = MediaLanguageDetector.detectTags(from: item.title)
            let normalizedCode = ISO639LanguageCode.normalize(item.originalLanguageCode)
            if let normalizedCode {
                originalCodes.insert(normalizedCode)
            }

            for filter in MediaLanguageFilter.allCases where filter != .all {
                if MediaLanguageDetector.matches(tags: tags, filter: filter) {
                    filterCounts[filter, default: 0] += 1
                }
            }

            let matchesLanguage = MediaLanguageDetector.matches(tags: tags, filter: languageFilter)
            if matchesLanguage {
                audioFilteredCount += 1
                if let normalizedCode {
                    audioFilteredCounts[normalizedCode, default: 0] += 1
                } else {
                    audioFilteredUncodedCount += 1
                }
            }

            let matchesOriginalLanguage = originalLanguageCode == nil
                || normalizedCode == nil
                || normalizedCode == originalLanguageCode
            if matchesLanguage, matchesOriginalLanguage {
                filteredItems.append(item)
            }
        }

        switch sortMethod {
        case .alphabetical:
            filteredItems.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .rating:
            filteredItems.sort { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .dateAdded:
            filteredItems.sort { ($0.addedDate ?? .distantPast) > ($1.addedDate ?? .distantPast) }
        case .defaultOrder:
            break
        }

        let sortedCodes = originalCodes.sorted()
        var originalCounts = ["all": audioFilteredCount]
        for code in sortedCodes {
            originalCounts[code] = audioFilteredCounts[code, default: 0] + audioFilteredUncodedCount
        }

        items = filteredItems
        availableLanguageFilters = [.all] + MediaLanguageFilter.allCases.filter {
            $0 != .all && filterCounts[$0, default: 0] > 0
        }
        availableOriginalLanguageCodes = sortedCodes
        originalLanguageCounts = originalCounts
        languageFilterCounts = filterCounts
        availableLetters = Set(filteredItems.map { Self.alphabetLetter(for: $0.title) })
    }
}
