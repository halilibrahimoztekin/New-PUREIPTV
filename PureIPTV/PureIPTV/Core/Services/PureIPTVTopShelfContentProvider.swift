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
                let item = TVTopShelfCarouselItem(identifier: dto.id)
                item.contextTitle = "KALDIĞIN YERDEN İZLE"
                item.title = dto.title
                item.summary = dto.subtitle ?? "Kaldığınız yerden izlemeye devam edin."
                if let imageURLStr = dto.imageURL, let imageURL = URL(string: imageURLStr) {
                    item.setImageURL(imageURL, for: .screenScale1x)
                    item.setImageURL(imageURL, for: .screenScale2x)
                }
                item.displayAction = TVTopShelfAction(url: deepLink)
                item.playAction = TVTopShelfAction(url: deepLink)
                items.append(item)
            }

            // 2. Yeni Eklenen / Öne Çıkan Filmler
            for dto in data.recentMovies.prefix(4) {
                guard let deepLink = URL(string: dto.deepLinkURL) else { continue }
                let item = TVTopShelfCarouselItem(identifier: dto.id)
                item.contextTitle = "ÖNE ÇIKAN FİLM"
                item.title = dto.title
                item.summary = dto.subtitle ?? "PureIPTV Sinema Kütüphanesi"
                if let imageURLStr = dto.imageURL, let imageURL = URL(string: imageURLStr) {
                    item.setImageURL(imageURL, for: .screenScale1x)
                    item.setImageURL(imageURL, for: .screenScale2x)
                }
                item.displayAction = TVTopShelfAction(url: deepLink)
                item.playAction = TVTopShelfAction(url: deepLink)
                items.append(item)
            }

            // 3. Favori Canlı Kanallar
            for dto in data.favoriteChannels.prefix(4) {
                guard let deepLink = URL(string: dto.deepLinkURL) else { continue }
                let item = TVTopShelfCarouselItem(identifier: dto.id)
                item.contextTitle = "CANLI YAYIN"
                item.title = dto.title
                item.summary = "Favori TV Kanalı"
                if let imageURLStr = dto.imageURL, let imageURL = URL(string: imageURLStr) {
                    item.setImageURL(imageURL, for: .screenScale1x)
                    item.setImageURL(imageURL, for: .screenScale2x)
                }
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
                    let item = TVTopShelfSectionedItem(identifier: dto.id)
                    if let subtitle = dto.subtitle, !subtitle.isEmpty {
                        item.title = "\(dto.title) - \(subtitle)"
                    } else {
                        item.title = dto.title
                    }
                    if let imageURLStr = dto.imageURL, let imageURL = URL(string: imageURLStr) {
                        item.setImageURL(imageURL, for: .screenScale1x)
                        item.setImageURL(imageURL, for: .screenScale2x)
                    }
                    if let progress = dto.progress {
                        item.playbackProgress = progress
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
                    let item = TVTopShelfSectionedItem(identifier: dto.id)
                    item.title = dto.title
                    if let imageURLStr = dto.imageURL, let imageURL = URL(string: imageURLStr) {
                        item.setImageURL(imageURL, for: .screenScale1x)
                        item.setImageURL(imageURL, for: .screenScale2x)
                    }
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
                    let item = TVTopShelfSectionedItem(identifier: dto.id)
                    item.title = dto.title
                    if let imageURLStr = dto.imageURL, let imageURL = URL(string: imageURLStr) {
                        item.setImageURL(imageURL, for: .screenScale1x)
                        item.setImageURL(imageURL, for: .screenScale2x)
                    }
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
    }
#endif
