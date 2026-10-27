#if os(tvOS)
    import Foundation
    import TVServices

    /// Apple TV Ana Ekranı Top Shelf dinamik içerik sağlayıcısı.
    /// Uygulama üst sırada yer aldığında kullanıcının Kaldığı Yerden Devam Et,
    /// Favori Kanallar ve Yeni Filmler listelerini derin bağlantılarla (Deep Link) sunar.
    /// Hem TVTopShelfCarouselContent (Sinematik Vitrin) hem de TVTopShelfSectionedContent (Bölümlü Liste) destekler.
    public final class PureIPTVTopShelfContentProvider: TVTopShelfContentProvider, @unchecked Sendable {
        override public init() {
            super.init()
        }

        override public func loadTopShelfContent(completionHandler: @escaping ((any TVTopShelfContent)?) -> Void) {
            guard let data = TopShelfService.shared.loadTopShelfData() else {
                completionHandler(nil)
                return
            }

            // 1. Carousel Stili (Sinematik Vitrin Carousel)
            if data.preferredStyle == .carousel {
                let carouselContent = makeCarouselContent(from: data)
                if let carouselContent {
                    completionHandler(carouselContent)
                    return
                }
            }

            // 2. Sectioned Stili (Bölümlü Liste)
            let sectionedContent = makeSectionedContent(from: data)
            if let sectionedContent {
                completionHandler(sectionedContent)
                return
            }

            // Fallback: If sectioned style was requested but empty, or carousel was requested but empty
            completionHandler(nil)
        }

        // MARK: - Carousel Content Builder

        private func makeCarouselContent(from data: TopShelfDataDTO) -> TVTopShelfCarouselContent? {
            var items: [TVTopShelfCarouselItem] = []

            // 1. Devam Eden İçerikler
            for dto in data.continueWatching.prefix(4) {
                guard let deepLink = URL(string: dto.deepLinkURL) else { continue }
                let item = TVTopShelfCarouselItem(identifier: itemIdentifier(section: "continue", id: dto.id))
                item.contextTitle = "KALDIĞIN YERDEN İZLE"
                item.title = dto.title
                item.summary = dto.summary ?? dto.subtitle ?? "Kaldığınız yerden izlemeye devam edin."
                applyMetadata(from: dto, to: item)
                setImageURLs(on: item, dto: dto, prefersLandscape: true)
                item.displayAction = TVTopShelfAction(url: deepLink)
                item.playAction = TVTopShelfAction(url: deepLink)
                items.append(item)
            }

            // 2. Yeni Eklenen / Öne Çıkan Filmler
            for dto in data.recentMovies.prefix(4) {
                guard let deepLink = URL(string: dto.deepLinkURL) else { continue }
                let item = TVTopShelfCarouselItem(identifier: itemIdentifier(section: "recent", id: dto.id))
                item.contextTitle = "ÖNE ÇIKAN FİLM"
                item.title = dto.title
                item.summary = dto.summary ?? dto.subtitle ?? "PureIPTV Sinema Kütüphanesi"
                applyMetadata(from: dto, to: item)
                setImageURLs(on: item, dto: dto, prefersLandscape: true)
                item.displayAction = TVTopShelfAction(url: deepLink)
                item.playAction = TVTopShelfAction(url: deepLink)
                items.append(item)
            }

            // 3. Favori Canlı Kanallar
            for dto in data.favoriteChannels.prefix(4) {
                guard let deepLink = URL(string: dto.deepLinkURL) else { continue }
                let item = TVTopShelfCarouselItem(identifier: itemIdentifier(section: "favorite", id: dto.id))
                item.contextTitle = "CANLI YAYIN"
                item.title = dto.title
                item.summary = dto.summary ?? "Favori TV Kanalı"
                applyMetadata(from: dto, to: item)
                setImageURLs(on: item, dto: dto, prefersLandscape: true)
                item.displayAction = TVTopShelfAction(url: deepLink)
                item.playAction = TVTopShelfAction(url: deepLink)
                items.append(item)
            }

            guard !items.isEmpty else { return nil }
            return TVTopShelfCarouselContent(style: .details, items: items)
        }

        // MARK: - Sectioned Content Builder

        private func makeSectionedContent(from data: TopShelfDataDTO) -> TVTopShelfSectionedContent? {
            var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []

            // 1. Kaldığın Yerden İzle (Continue Watching)
            if !data.continueWatching.isEmpty {
                let items: [TVTopShelfSectionedItem] = data.continueWatching.compactMap { (dto: TopShelfItemDTO) -> TVTopShelfSectionedItem? in
                    guard let deepLink = URL(string: dto.deepLinkURL) else { return nil }
                    let item = TVTopShelfSectionedItem(identifier: itemIdentifier(section: "continue", id: dto.id))
                    if let subtitle = dto.subtitle, !subtitle.isEmpty {
                        item.title = "\(dto.title) - \(subtitle)"
                    } else {
                        item.title = dto.title
                    }
                    setImageURLs(on: item, dto: dto, prefersLandscape: false)
                    if let progress = dto.progress {
                        item.playbackProgress = min(1, max(0, progress.isFinite ? progress : 0))
                    }
                    item.imageShape = .poster
                    item.displayAction = TVTopShelfAction(url: deepLink)
                    item.playAction = TVTopShelfAction(url: deepLink)
                    return item
                }
                if !items.isEmpty {
                    let section = TVTopShelfItemCollection(items: items)
                    section.title = "Kaldığın Yerden İzle"
                    sections.append(section)
                }
            }

            // 2. Favori Kanallar (Favorite Channels)
            if !data.favoriteChannels.isEmpty {
                let items: [TVTopShelfSectionedItem] = data.favoriteChannels.compactMap { (dto: TopShelfItemDTO) -> TVTopShelfSectionedItem? in
                    guard let deepLink = URL(string: dto.deepLinkURL) else { return nil }
                    let item = TVTopShelfSectionedItem(identifier: itemIdentifier(section: "favorite", id: dto.id))
                    item.title = dto.title
                    setImageURLs(on: item, dto: dto, prefersLandscape: false)
                    item.imageShape = .hdtv
                    item.displayAction = TVTopShelfAction(url: deepLink)
                    item.playAction = TVTopShelfAction(url: deepLink)
                    return item
                }
                if !items.isEmpty {
                    let section = TVTopShelfItemCollection(items: items)
                    section.title = "Favori Kanallar"
                    sections.append(section)
                }
            }

            // 3. Yeni Eklenen Filmler (Recent Movies)
            if !data.recentMovies.isEmpty {
                let items: [TVTopShelfSectionedItem] = data.recentMovies.compactMap { (dto: TopShelfItemDTO) -> TVTopShelfSectionedItem? in
                    guard let deepLink = URL(string: dto.deepLinkURL) else { return nil }
                    let item = TVTopShelfSectionedItem(identifier: itemIdentifier(section: "recent", id: dto.id))
                    item.title = dto.title
                    setImageURLs(on: item, dto: dto, prefersLandscape: false)
                    item.imageShape = .poster
                    item.displayAction = TVTopShelfAction(url: deepLink)
                    item.playAction = TVTopShelfAction(url: deepLink)
                    return item
                }
                if !items.isEmpty {
                    let section = TVTopShelfItemCollection(items: items)
                    section.title = "Yeni Filmler"
                    sections.append(section)
                }
            }

            guard !sections.isEmpty else { return nil }
            return TVTopShelfSectionedContent(sections: sections)
        }

        private func itemIdentifier(section: String, id: String) -> String {
            "\(section):\(id)"
        }

        private func setImageURLs(on item: TVTopShelfItem, dto: TopShelfItemDTO, prefersLandscape: Bool) {
            let primaryImageURL = validImageURL(dto.imageURL)
            let landscapeImageURL = validImageURL(dto.landscapeImageURL)
            let imageURL = prefersLandscape
                ? landscapeImageURL ?? primaryImageURL
                : primaryImageURL ?? landscapeImageURL
            guard let imageURL else { return }
            item.setImageURL(imageURL, for: .screenScale1x)
            item.setImageURL(imageURL, for: .screenScale2x)
        }

        private func validImageURL(_ value: String?) -> URL? {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
            return URL(string: value)
        }

        private func applyMetadata(from dto: TopShelfItemDTO, to item: TVTopShelfCarouselItem) {
            if let duration = dto.duration, duration.isFinite, duration > 0 {
                item.duration = duration
            }
            item.creationDate = dto.creationDate
            item.genre = dto.genre

            var attributes: [TVTopShelfNamedAttribute] = []
            if let creationDate = dto.creationDate {
                let year = Calendar(identifier: .gregorian).component(.year, from: creationDate)
                if year > 0 {
                    attributes.append(TVTopShelfNamedAttribute(name: "Yıl", values: [String(year)]))
                }
            }
            if let rating = dto.rating, rating.isFinite, rating > 0 {
                attributes.append(TVTopShelfNamedAttribute(name: "Puan", values: [rating.formatted(.number.precision(.fractionLength(1)))]))
            }
            if let progress = dto.progress, progress.isFinite, progress > 0, progress < 1 {
                attributes.append(TVTopShelfNamedAttribute(
                    name: "İzleme",
                    values: ["%\(Int((progress * 100).rounded())) tamamlandı"]
                ))
            }
            item.namedAttributes = Array(attributes.prefix(4))
        }
    }
#endif
