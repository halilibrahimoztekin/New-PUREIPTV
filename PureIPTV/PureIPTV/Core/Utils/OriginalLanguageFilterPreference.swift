import Foundation

enum OriginalLanguageFilterLibrary: String {
    case movies
    case series
}

@MainActor
enum OriginalLanguageFilterPreference {
    static func load(profileID: UUID?, library: OriginalLanguageFilterLibrary) -> String? {
        guard let profileID else { return nil }
        let key = key(profileID: profileID, library: library)
        guard let value = UserDefaults.standard.string(forKey: key) else { return nil }
        return ISO639LanguageCode.normalize(value)
    }

    static func save(_ languageCode: String?, profileID: UUID?, library: OriginalLanguageFilterLibrary) {
        guard let profileID else { return }
        let key = key(profileID: profileID, library: library)
        guard let languageCode, let normalized = ISO639LanguageCode.normalize(languageCode) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(normalized, forKey: key)
    }

    private static func key(profileID: UUID, library: OriginalLanguageFilterLibrary) -> String {
        "com.pureiptv.originalLanguageFilter.\(profileID.uuidString).\(library.rawValue)"
    }
}
