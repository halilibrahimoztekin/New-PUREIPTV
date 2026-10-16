import Foundation

#if os(tvOS)
    import SwiftUI

    // MARK: - Akıllı Focus Hafızası (Smart Focus Memory) - Madde #1

    /// tvOS 10-foot UI için kategori ve medya bazlı akıllı odak hafızası.
    /// Kullanıcı kategoriler arasında geçiş yaptığında, tam ekran oynatıcıdan veya detay
    /// ekranlarından geri döndüğünde kaldığı son öğeye (kanal, film, dizi) milisaniyeler içinde
    /// otomatik odaklanmasını ve görünür alana kaydırılmasını (auto-scroll) garanti eder.
    @MainActor
    public final class TVFocusMemory {
        public static let shared = TVFocusMemory()

        // Bellek sözlükleri: CategoryID -> ItemID
        private var channelMemory: [String: String] = [:]
        private var vodMemory: [String: String] = [:]
        private var seriesMemory: [String: String] = [:]

        public var lastSelectedLiveCategoryID: String?
        public var lastSelectedVODCategoryID: String?
        public var lastSelectedSeriesCategoryID: String?

        private init() {}

        // MARK: - Canlı TV Focus Memory

        public func recordChannel(_ channelID: String, in categoryID: String?) {
            let cat = categoryID ?? "all"
            channelMemory[cat] = channelID
        }

        public func lastChannel(in categoryID: String?, fallback: String? = nil) -> String? {
            let cat = categoryID ?? "all"
            return channelMemory[cat] ?? fallback
        }

        // MARK: - VOD (Filmler) Focus Memory

        public func recordVOD(_ vodID: String, in categoryID: String?) {
            let cat = categoryID ?? "all"
            vodMemory[cat] = vodID
        }

        public func lastVOD(in categoryID: String?, fallback: String? = nil) -> String? {
            let cat = categoryID ?? "all"
            return vodMemory[cat] ?? fallback
        }

        // MARK: - Diziler Focus Memory

        public func recordSeries(_ seriesID: String, in categoryID: String?) {
            let cat = categoryID ?? "all"
            seriesMemory[cat] = seriesID
        }

        public func lastSeries(in categoryID: String?, fallback: String? = nil) -> String? {
            let cat = categoryID ?? "all"
            return seriesMemory[cat] ?? fallback
        }

        // MARK: - Sıfırlama

        public func clear() {
            channelMemory.removeAll()
            vodMemory.removeAll()
            seriesMemory.removeAll()
            lastSelectedLiveCategoryID = nil
            lastSelectedVODCategoryID = nil
            lastSelectedSeriesCategoryID = nil
        }
    }
#endif
