import Foundation

/// Uygulama genelinde kullanılan tüm metinlerin (strings) merkezi yönetimi.
/// String extension'ı `.localized` kullanılarak yerelleştirilmiş metinler (String) döner.
public enum AppStrings {
    // MARK: - Common

    public enum Common {
        public static let cancel = "İptal".localized
        public static let save = "Kaydet".localized
        public static let delete = "Sil".localized
        public static let ok = "Tamam".localized
        public static let back = "Geri".localized
        public static let loading = "Yükleniyor...".localized
        public static let loadingAlt = "Yükleniyor…".localized
        public static let done = "Bitti".localized
        public static let edit = "Düzenle".localized
        public static let close = "Kapat".localized
        public static let more = "Daha Fazla".localized
        public static let add = "Ekle".localized
        public static let create = "Oluştur".localized
        public static let watchNow = "Hemen İzle".localized
        public static let comingSoon = "Yakında geliyor…".localized
        public static let settingsComingSoon = "Ayarlar yakında geliyor…".localized
        public static let appName = "PureIPTV".localized
        public static let error = "Hata: %@".localized
        public static let addToFavorites = "Favorilere Ekle".localized
        public static let removeFromFavorites = "Favorilerden Çıkar".localized
        public static let hideMediaItem = "İçeriği Gizle".localized
        public static let restoreMediaItem = "Geri Yükle".localized
        public static let favorites = "Favoriler".localized
        public static let favorite = "Favori".localized
        public static let favorited = "Favorilerde".localized
        public static let download = "İndir".localized
        public static let downloaded = "İndirildi".localized
        public static let categoryNotFound = "Kategori bulunamadı".localized
        public static let results = "sonuç".localized
        public static let hour = "saat".localized
        public static let minute = "dakika".localized
        public static let minAbbr = "dk".localized
        public static let watched = "izlendi".localized
        public static let season = "Sezon".localized
        public static let restart = "Baştan Başlat".localized
        public static let liveTV = "Canlı TV".localized
        public static let retry = "Tekrar Dene".localized
        public static let continueWithoutPlaylist = "Playlist olmadan devam et".localized
        public static let play = "Oynat".localized
        public static let search = "Ara".localized
        public static let channels = "Kanallar".localized
        public static let handoffPlaybackUnavailableTitle = "Oynatmaya Devam Edilemiyor".localized
        public static let handoffPlaybackUnavailableMessage = "Bu içerik bu Apple TV'de kullanılamıyor.".localized
    }

    public enum M3UCategoryMapping {
        public static let title = "M3U Etiketlerini Eşle".localized
        public static let destinationCategory = "Hedef Kategori".localized
        public static let instructions = "Bir M3U etiketine kategori adı yazın. Aynı kategoriye eşlenen etiketler Live TV'de birleştirilir. Boş bırakılan etiketler kaynak kategorisini kullanır.".localized
        public static let savedPlaylistRequired = "Kaydedilmiş playlist gerekir".localized
        public static let savedPlaylistRequiredHint = "Etiket eşlemeleri yalnız playlist kimliği olan kaydedilmiş M3U kaynaklarında saklanır.".localized
        public static let noTags = Common.categoryNotFound
        public static let noTagsHint = LiveTV.emptyCategoryLive
    }

    public enum Startup {
        public static let playlistUnavailableTitle = "Kayıtlı playlist’ler okunamadı".localized
        public static let playlistUnavailableMessage = "Playlist bilgilerine şu anda erişilemiyor. Kayıtlı playlist’lerinizi silmeden yeniden deneyin.".localized
        public static let profilesUnavailableTitle = "Profiller yüklenemedi".localized
        public static let profilesUnavailableMessage = "Kayıtlı profillerinize erişilemiyor. Yeniden deneyin.".localized
        public static let openingData = "Kaydedilmiş veriler açılıyor…".localized
        public static let unavailableTitle = "Kaydedilmiş veriler açılamadı".localized
        public static let unavailableMessage = "PureIPTV başlatılamadı. Verilerinizi silmeden yeniden deneyebilirsiniz. Sorun sürerse uygulamayı güncelledikten sonra tekrar açın.".localized
        public static func supportCode(_ code: String) -> String {
            "Destek kodu: %@".localized(code)
        }
    }

    // MARK: - VOD (Movies)

    public enum VOD {
        public static let title = "Filmler".localized
        public static let loadingMovies = "Filmler yükleniyor…".localized
        public static let emptyCategoryMovies = "Bu kategoride film bulunamadı".localized
        public static let noMovies = "Film bulunamadı".localized
    }

    // MARK: - Series

    public enum Series {
        public static let title = "Diziler".localized
        public static let loadingSeries = "Diziler yükleniyor…".localized
        public static let emptyCategorySeries = "Bu kategoride dizi bulunamadı".localized
        public static let noSeries = "Dizi bulunamadı".localized
    }

    // MARK: - Live TV

    public enum LiveTV {
        public static let title = "Canlı TV".localized
        public static let channelsTitle = "Kanallar".localized
        public static let categories = "Kategoriler".localized
        public static let categoryQuickJump = "Kategoriye Hızlı Git".localized
        public static let categoryLockedStatus = "Kilitli".localized
        public static let categoryOrderTitle = "Kategori Sırası".localized
        public static let categoryOrderProvider = "Sağlayıcı Sırası".localized
        public static let categoryOrderCustom = "Elle Sıralama".localized
        public static let categoryOrderAlphabetical = "Alfabetik (A–Z)".localized
        public static let emptyCategoryLive = "Bu kategoride kanal bulunamadı".localized
        public static let loadingChannels = "Kanallar yükleniyor…".localized
        public static let noChannels = "Kanal bulunamadı.".localized
        public static let hideChannel = "Kanalı Gizle".localized
        public static let sendToMultiView = "Çoklu Ekran'a Gönder".localized
        public static let channelGuide = "Yayın Akışı (EPG)".localized
        public static let compactEPGView = "Kompakt EPG görünümü".localized
        public static let standardEPGView = "Standart EPG görünümü".localized
        public static let recentChannels = "Son İzlenen Kanallar".localized
        public static let excludeFromRecentChannels = "Son İzlenenlerden Hariç Tut".localized
        public static let showInRecentChannels = "Son İzlenenlerde Göster".localized
        public static let recentChannelsScopeHint = "Bu ayar yalnızca bu profil ve playlist için geçerlidir.".localized
        public static let quickZapHint = "Siri Remote ile gezin ve kanala anında geçiş yapın".localized
        public static let noRecentChannels = "Henüz izlenmiş kanal bulunmuyor".localized
        public static let pinRecentChannel = "Geçmişin başına sabitle".localized
        public static let unpinRecentChannel = "Sabitlemeyi kaldır".localized
        public static let editChannelLogo = "Kanal logosunu düzenle".localized
        public static let channelLogoURL = "Logo URL’si".localized
        public static let channelLogoURLHint = "HTTP veya HTTPS adresi girin.".localized
        public static let invalidChannelLogoURL = "Geçerli bir HTTP veya HTTPS logo adresi girin.".localized
        public static let smartGroups = "Akıllı Gruplar".localized
        public static let favoriteLists = "Favori Listeleri".localized
        public static let selectChannels = "Kanalları Seç".localized
        public static let cancelChannelSelection = "Seçimi İptal Et".localized
        public static let selectAllChannels = "Tümünü Seç".localized
        public static let clearChannelSelection = "Seçimi Temizle".localized
        public static let hideSelectedChannels = "Seçilenleri Gizle".localized
        public static let selectedChannelCountFormat = "Seçilen kanal sayısı: %d".localized
        public static func selectedChannelCount(_ count: Int) -> String {
            String(format: selectedChannelCountFormat, locale: Locale.current, arguments: [count])
        }

        public static let addSelectedToFavorites = "Seçilenleri Favorilere Ekle".localized
        public static let removeSelectedFromFavorites = "Favorilerden Kaldır".localized
        public static let addSelectedToList = "Listeye Ekle".localized
        public static let removeSelectedFromList = "Listeden Kaldır".localized
        public static let favoriteListCapacityReached = "Bir listede en fazla 2.000 kanal olabilir.".localized
        public static let favoriteListChannelIDTooLong = "Bu kanal kimliği favori listesine kaydedilemeyecek kadar uzun.".localized
        public static let bulkFavoritesAdded = "Kanallar favorilere eklendi.".localized
        public static let bulkFavoritesRemoved = "Kanallar favorilerden kaldırıldı.".localized
        public static let bulkFavoritesFailed = "Favoriler güncellenemedi.".localized
        public static let selectChannelAccessibilityHint = "Bu kanalı seçmek için etkinleştirin.".localized
        public static let deselectChannelAccessibilityHint = "Bu kanalın seçimini kaldırmak için etkinleştirin.".localized
        public static let manageFavoriteLists = "Listeleri Yönet".localized
        public static let addToFavoriteList = "Listeye Ekle/Kaldır".localized
        public static let createFavoriteList = "Liste Oluştur".localized
        public static let newFavoriteList = "Yeni Liste".localized
        public static let favoriteListName = "Liste Adı".localized
        public static let favoriteListsSection = "Listeler".localized
        public static let editFavoriteList = "Listeyi Düzenle".localized
        public static let deleteFavoriteList = "Listeyi Sil".localized
        public static let saveFavoriteListName = "Adı Kaydet".localized
        public static let manageFavoriteListsHint = "Favori kanal listeleri oluşturun ve düzenleyin.".localized
        public static let favoriteListExport = "M3U8 Olarak Dışa Aktar".localized
        public static let favoriteListExportWarningTitle = "Kanal Bağlantılarını Dışa Aktar".localized
        public static let favoriteListExportWarningMessage = "M3U8 dosyası kanal bağlantılarını içerebilir. Bazı bağlantılarda sağlayıcı kullanıcı adı veya parolası bulunabilir. Yalnızca güvendiğiniz kişilerle paylaşın.".localized
        public static let favoriteListExportContinue = "Dışa Aktar".localized
        public static let favoriteListExportNoChannels = "Bu favori listesinde dışa aktarılabilecek kanal yok.".localized
        public static let favoriteListExportFailed = "Favori listesi dışa aktarılamadı.".localized
        public static let favoriteListExportSkippedFormat = "Dosyaya %lld kanal eklendi; kullanılamayan %lld kanal atlandı.".localized
        public static func favoriteListExportSkipped(_ exported: Int, _ skipped: Int) -> String {
            favoriteListExportSkippedFormat.localized(Int64(exported), Int64(skipped))
        }

        public static let newSmartGroup = "Yeni Akıllı Grup".localized
        public static let editSmartGroup = "Akıllı Grubu Düzenle".localized
        public static let smartGroupName = "Grup Adı".localized
        public static let smartGroupPrivacyHint = "Gruplar yalnızca seçili profil ve playlist için kaydedilir. Kanallar seçilen playlist kategorilerinden oluşturulur.".localized
        public static let unavailableSmartGroupCategory = "Artık kullanılmayan kategori".localized
        public static let unavailableFavoriteChannel = "Playlistte kanal eşleşmesi yok".localized
        public static let unavailableFavoriteChannelHint = "Kanal kaldırılmış veya yenileme sonrası kimliği değişmiş olabilir. Güncel kanalı arayıp yeniden favoriye ekleyin.".localized
        public static func reattachFavorite(to channelTitle: String) -> String {
            "Bu favoriyi %@ kanalıyla yeniden eşleştir".localized(channelTitle)
        }

        public static let favoriteRecoverySucceeded = "Favori güncel kanalla eşleştirildi".localized
        public static let favoriteRecoveryFailed = "Favori eşleşmesi kaydedilemedi. Tekrar deneyin.".localized
        public static let selected = "Seçili".localized
        public static let notSelected = "Seçili değil".localized
        public static func smartGroupCategoryCount(_ count: Int) -> String {
            String(format: "%d kategori".localized, count)
        }

        public static let resetChannelLogo = "Kaynak logosuna dön".localized
        public static let nowPlayingBadge = "OYNATILIYOR".localized
        public static let allChannels = "Tümü".localized
        public static let categorySports = "Spor".localized
        public static let categoryNews = "Haber".localized
        public static let categoryCinema = "Sinema".localized
        public static let categoryDocs = "Belgesel".localized
        public static let categoryKids = "Çocuk".localized
        public static let category4K = "4K / UHD".localized
        public static let categoryMusic = "Müzik".localized
        public static let clearFilter = "Filtreyi Temizle".localized
        public static let noChannelsMatchingFilter = "Seçili filtre veya arama kriterine uygun kanal bulunamadı.".localized
        public static let channelDialerTitle = "Kanal Numarası".localized
        public static let channelDialerHint = "Kanal numarası tuşlayarak anında geçiş yapın".localized
        public static let editChannelPresentation = "Kanal Görünümünü Düzenle".localized
        public static let channelName = "Kanal Adı".localized
        public static let channelNumber = "Kanal Numarası".localized
        public static let resetChannelPresentation = "Kaynak Bilgilerine Dön".localized
        public static let jumpToChannel = "Kanala Git".localized
        public static let sortTitle = "Sıralama".localized
        public static let sortDefault = "Varsayılan Sıra".localized
        public static let sortProgramStartTime = "Şu Anki Program Başlangıç Saati".localized
        public static let sortPreparingEPG = "EPG sıralaması hazırlanıyor…".localized
        public static let sortNameAZ = "İsim (A-Z)".localized
        public static let sortNameZA = "İsim (Z-A)".localized
        public static let sortMostWatched = "En Çok İzlenenler".localized
        public static let sortRecentlyWatched = "Son İzlenenler".localized
    }

    public enum Favorites {
        public static let sortDefault = "Kanal Sırası".localized
        public static let sortNameAscending = "İsim (A-Z)".localized
        public static let sortNameDescending = "İsim (Z-A)".localized
        public static let sortManual = "Elle Sıralama".localized
        public static let moveUp = "Favoriyi Yukarı Taşı".localized
        public static let moveDown = "Favoriyi Aşağı Taşı".localized
        public static let orderingDescription = "Bu playlist ve profilin favori kanallarının sırasını belirler.".localized
        public static let directionalReorderHint = "Elle sıralamada kanalı taşımak için yukarı/aşağı yön düğmesini basılı tutun. VoiceOver için kanal menüsündeki taşıma eylemlerini kullanın.".localized
    }

    // MARK: - Player & EPG

    public enum Player {
        public static let playbackEngine = "Oynatma Motoru".localized
        public static let itemPlaybackEnginePreference = "Bu İçerik İçin".localized
        public static let saveCurrentPlaybackEngineForItem = "Geçerli Oynatıcıyı Bu İçeriğe Kaydet".localized
        public static let useGeneralPlaybackEnginePreference = "Genel Oynatıcı Tercihini Kullan".localized
        public static func itemPlaybackEnginePreferenceValue(_ engine: String) -> String {
            "Bu içerik için tercih: %@".localized(engine)
        }

        public static let pausePlayback = "Duraklat".localized
        public static let pictureInPicture = "Resim İçinde Resim".localized
        public static let rememberedPlaybackChoiceTitle = "Önceki Oynatıcı Seçimin".localized
        public static let forgetRememberedPlaybackChoice = "Bu Seçimi Unut".localized
        public static func rememberedPlaybackChoiceMessage(_ choice: String) -> String {
            "Bu kaynak ve yayın biçimi için son seçimin %@. Oynatıcı kendiliğinden değiştirilmez.".localized(choice)
        }

        public static func useRememberedPlaybackChoice(_ choice: String) -> String {
            "%@ ile Aç".localized(choice)
        }

        public static let deinterlace = "Deinterlace".localized
        public static let deinterlaceFallback = "Bu akışta Deinterlace uygulanamadı; Otomatik kullanılıyor.".localized
        public static let deinterlaceMemoryPressureFallback = "Bellek uyarısı nedeniyle Deinterlace kapatıldı. Tercihin sonraki oynatımda geri yüklenir.".localized
        public static let deinterlaceMemoryPressureFallbackFailed = "Bellek uyarısı nedeniyle Deinterlace kapatılamadı.".localized
        public static let deinterlaceUnknown = "Deinterlace durumu doğrulanamadı.".localized
        public static let deinterlaceUnknownShort = "Bilinmiyor".localized
        public static let playbackEngineSwitchFailed = "Oynatma motoru değiştirilemedi.".localized
        public static let displayMatchRequested = "tvOS'e ekran eşleme isteği gönderildi. Gerçek geçişi tvOS ve TV belirler.".localized
        public static let displayMatchSystemDisabled = "tvOS İçeriği Eşleştir kapalı; sistem tercihiniz değiştirilmedi.".localized
        public static let displayMatchCriteriaUnavailable = "AVPlayer bu yayın için ekran ölçütü vermedi; sistem tercihiniz değiştirilmedi.".localized
        public static let displayMatchDisplayUnavailable = "tvOS ekran yöneticisine ulaşılamadı; sistem tercihiniz değiştirilmedi.".localized
        public static let displayMatchEngineUnsupported = "VLC ekran ölçütü sağlayamıyor. Uygun VOD için Oynatıcı menüsünden AVPlayer'ı seçin.".localized
        public static let displayMatchPartialUnsupported = "tvOS kare hızı ve dinamik aralığı birlikte eşler. Her iki uygulama seçeneğini de açın.".localized
        public static let displayMatchUnsupportedPlatform = "Bu platformda ekran modu eşleme desteklenmiyor.".localized
        public static let retrySameStream = "Aynı Yayını Yeniden Dene".localized
        public static let retrySameStreamHint = "Aynı yayın bağlantısı yeniden denenir.".localized
        public static let tryOtherPlaybackEngineHint = "Yayını diğer yerleşik oynatıcıda açmayı dener.".localized
        public static let backupLiveSourceHint = "Aynı kanalın kullanılabilir alternatif canlı yayını açılır.".localized
        public static let serverSpeedTestHint = "Sunucu bağlantı hızını ölçer.".localized
        public static let closePlayerHint = "Oynatıcıyı kapatır.".localized
        public static let playbackPositionMayBeRestored = "Mümkünse mevcut oynatma konumundan devam eder.".localized
        public static let playbackPositionRestored = "Oynatma konumu korundu.".localized
        public static let playbackPositionRestoredApproximately = "Yakın bir konumdan devam ediliyor.".localized
        public static let playbackPositionNotRestored = "Oynatma konumu doğrulanamadı.".localized
        public static func tryPlaybackEngine(_ engine: String) -> String {
            "%@ ile Dene".localized(engine)
        }

        public static let originalLanguageFilter = "Orijinal Dil".localized
        public static let originalLanguageUnknownHint = "Dili bilinmeyen içerikler gösterilmeye devam eder.".localized
        public static let startRecording = "Kaydı Başlat".localized
        public static let stopRecording = "Kaydı Durdur".localized
        public static let recordingSaved = "Kayıt kaydedildi".localized
        public static let recordingCouldNotStart = "Kayıt başlatılamadı".localized
        public static let recordingInProgress = "Kayıt yapılıyor".localized
        public static let recordingStopping = "Kayıt durduruluyor".localized
        public static let recordingCouldNotStop = "Kayıt bitişi doğrulanamadı".localized
        public static let skipMarkers = "Atlama İşaretleri".localized
        public static func skipBackwardBy(_ interval: String) -> String {
            "Geri sar: %@".localized(interval)
        }

        public static func skipForwardBy(_ interval: String) -> String {
            "İleri sar: %@".localized(interval)
        }

        public static let replayWithSubtitles = "Altyazıyla tekrar oynat".localized
        public static let replayWithSubtitlesHint = "Önceki 10 saniyeyi altyazıyla tekrar oynatır.".localized
        public static let skipIntro = "Açılışı Atla".localized
        public static let skipCredits = "Jeneriği Atla".localized
        public static let introMarkerTitle = "Açılış".localized
        public static let creditsMarkerTitle = "Jenerik".localized
        public static let markStartHere = "Başlangıcı Burada İşaretle".localized
        public static let markEndHere = "Bitişi Burada İşaretle".localized
        public static let clearMarker = "İşareti Temizle".localized
        public static let removeRecentChannel = "Son İzlenenlerden Kaldır".localized
        public static let liveLabel = "CANLI".localized
        public static let liveLabelNormal = "Canlı".localized
        public static let liveBroadcast = "Canlı Yayın".localized
        public static let playbackSpeed = "Oynatma Hızı".localized
        public static let normalSpeed = "Normal (1.0x)".localized
        public static let off = "Kapalı".localized
        public static let scrubInstruction = "Seçmek için Tıklayın veya Bırakın".localized
        public static let scrubSwipe = "Kaydırarak Akıcı İleri / Geri Sarma".localized
        public static let epg = "Yayın Akışı".localized
        public static let timeline = "Zaman Çizelgesi".localized
        public static let epgNotFound = "EPG bilgisi bulunamadı.".localized
        public static let nowPlaying = "Şu an".localized
        public static let returnToPlayingChannel = "İzlenen Kanala Dön".localized
        public static let epgProgramSelectionUnavailable = "Programı seçmek için önce bu kanalı izlemeye başlayın.".localized
        public static let epgPreviewCorner = "Küçük Video Konumu".localized
        public static let showControls = "Oynatıcı Kontrollerini Göster".localized
        public static let channelInfo = "Kanal Bilgisi".localized
        public static let expandEPGPreviewToFullscreen = "Önizlemeyi Tam Ekranda Aç".localized
        public static let nextUp = "Sıradaki:".localized
        public static let upcoming = "Yaklaşan".localized
        public static let nextLabel = "SONRAKİ".localized
        public static func minutesRemaining(_ minutes: Int) -> String {
            "%lld dk kaldı".localized(Int64(minutes))
        }

        public static func elapsedPercent(_ percent: Int) -> String {
            "%%%lld".localized(Int64(percent))
        }

        public static let mediaInfo = "Media Info".localized
        public static let nerdStats = "Yayın İstatistikleri (Nerd Stats)".localized
        public static let nerdStatsShort = "Teknik Bilgi".localized
        public static let serverPlaybackMode = "Medya Sunucusu Oynatma Modu".localized
        public static let serverPlaybackModeUnavailable = "Sunucu modu bildirilmedi".localized
        public static let serverModeEvidenceSession = "Oturum".localized
        public static let serverModeEvidenceResponse = "Sunucu yanıtı".localized
        public static let serverModeDirectPlay = "Direct Play".localized
        public static let serverModeDirectStream = "Direct Stream".localized
        public static let serverModeTranscoding = "Sunucu dönüştürmesi".localized
        public static let directStreamUnavailable = "Sunucu Direct Stream sağlayamadı; otomatik oynatma seçeneğini deneyin.".localized
        public static let videoCodec = "Video Kod Çözücü".localized
        public static let audioCodec = "Ses Kod Çözücü".localized
        public static let resolution = "Çözünürlük".localized
        public static let bitrate = "Bit Hızı (Bitrate)".localized
        public static let networkThroughput = "Ölçülen Ağ Veri Hızı".localized
        public static let streamBitrate = "Kaynağın Bildirdiği Bit Hızı".localized
        public static let mediaInfoUnavailable = "Teknik bilgi alınamadı".localized
        public static let renderedFPS = "Ölçülen Gösterilen Kare Hızı".localized
        public static let sampleUnavailable = "Örnek bekleniyor".localized
        public static let liveVideoStallTitle = "Görüntü Akışı Duraklamış Olabilir".localized
        public static let liveVideoStallMessage = "Oynatma saati ilerliyor, ancak oynatıcı yeni görüntü kareleri bildirmiyor. Ses çıkışı doğrulanamıyor.".localized
        public static let bufferHealth = "Tampon Durumu".localized
        public static let streamHealthTitle = "Yayın Sağlığı & Tampon".localized
        public static let networkLatency = "Ağ Gecikmesi (Ping)".localized
        public static let networkJitter = "Ağ Dalgalanması (Jitter)".localized
        public static let droppedFramesTitle = "Kayıp Kareler (Drop)".localized
        public static let connectionStabilityTitle = "Bağlantı Kararlılığı".localized
        public static let bufferDuration = "Tampon Süresi".localized
        public static let streamProtocol = "Protokol / Format".localized
        public static let audioTracks = "Ses İzleri".localized
        public static let subtitles = "Altyazılar".localized
        public static let subtitleOnlineSearch = "Çevrimiçi Altyazı Ara".localized
        public static let openSubtitlesAPIKey = "OpenSubtitles API anahtarı".localized
        public static let openSubtitlesAPIKeyHint = "Kendi API anahtarınız güvenli olarak Keychain’de saklanır.".localized
        public static let openSubtitlesAPIKeyRequired = "OpenSubtitles API anahtarı gerekiyor.".localized
        public static let openSubtitlesInvalidResponse = "OpenSubtitles geçersiz bir yanıt döndürdü.".localized
        public static let openSubtitlesRequestFailed = "OpenSubtitles isteği başarısız oldu (HTTP %d).".localized
        public static let openSubtitlesInvalidDownloadURL = "OpenSubtitles güvenli olmayan bir altyazı bağlantısı döndürdü.".localized
        public static let getOpenSubtitlesAPIKey = "API anahtarı alın".localized
        public static let subtitleSearchQuery = "Film veya dizi adı".localized
        public static let subtitleSearchLanguage = "Altyazı dili".localized
        public static let subtitleSearchAllLanguages = "Tüm diller".localized
        public static let subtitleSearchTitleOnlyWarning = "Yalnızca film veya dizi adı girin; URL ve oynatma listesi bilgileri gönderilmez.".localized
        public static let searchSubtitles = "Altyazı ara".localized
        public static let subtitleSearchResults = "Altyazı sonuçları".localized
        public static let subtitleSearchEmpty = "Sonuçları görmek için altyazı arayın.".localized
        public static let subtitleSearchFormat = "Biçim".localized
        public static let subtitleSearchUnknownFormat = "Bilinmeyen biçim".localized
        public static let subtitleTrackSourceLabel = "Kaynak".localized
        public static let subtitleTrackExternalFile = "Harici altyazı dosyası".localized
        public static let subtitleTrackMediaStream = "Medya akışı".localized
        public static let subtitleSearchEpisodeMatch = "Bölüm eşleşmesi".localized
        public static let subtitleSearchDifferentEpisode = "Farklı bölüm".localized
        public static let subtitleSearchEpisodeUnverified = "Bölüm doğrulanamadı".localized
        public static let subtitleSearchTitleMatch = "Başlık eşleşmesi".localized
        public static let subtitleSearchTitleUnverified = "Başlık doğrulanamadı".localized
        public static let subtitleTextEncoding = "Harici Altyazı Metin Kodlaması".localized
        public static let subtitleTextEncodingDescription = "Yalnız indirilen harici metin altyazılarını dönüştürür; gömülü altyazılar etkilenmez. Otomatik, VLC’nin mevcut davranışını korur.".localized
        public static let subtitleEncodingAutomatic = "Otomatik (VLC varsayılanı)".localized
        public static let subtitleEncodingFailed = "Altyazı seçilen kodlamayla okunamadı.".localized
        public static let subtitleFileTooLarge = "Altyazı dosyası 8 MB sınırını aşıyor.".localized
        public static let externalSubtitleAddFailed = "Harici altyazı oynatıcıya eklenemedi.".localized
        public static let tracks = "Ses ve Altyazı".localized
        public static let noOptions = "Seçenek bulunmuyor.".localized
        public static let noRecord = "Kayıt yok".localized
        public static let restart = "Baştan Başlat".localized
        public static let previousChannel = "Önceki Kanal".localized
        public static let nextChannel = "Sonraki Kanal".localized
        public static let recallLastChannel = "Son İzlenen Kanal".localized
        public static let recalledTitle = "Önceki Kanala Dönüldü".localized
        public static let quickRecallBadge = "HIZLI GEÇİŞ".localized
        public static let noPreviousChannel = "Geçmiş Kanal Yok".localized
        public static func recalledChannel(_ name: String) -> String {
            "Geri Dönüldü: %@".localized(name)
        }

        public static func switchingToBackup(_ channel: String) -> String {
            "Yedek Akışa Geçiliyor: %@".localized(channel)
        }

        public static let switchToBackup = "Yedek Yayını Başlat".localized
        public static let backupStreamAvailable = "Alternatif Yedek Yayın Mevcut".localized

        public static func sleepTimerMinutes(_ minutes: Int) -> String {
            "Uyku Zamanlayıcısı: %lld dk".localized(Int64(minutes))
        }

        public static let sleepTimer = "Uyku Zamanlayıcısı".localized
        public static let sleepTimerDisabled = "Uyku Zamanlayıcısı Kapatıldı".localized
        public static let sleepTimerFading = "Uyku Modu: Ses Kısılıyor...".localized
        public static let technicalDetails = "Teknik Bilgi".localized
        public static let hideTechnicalDetails = "Teknik Bilgiyi Gizle".localized
        public static let oledDarkRoomMode = "Karanlık Oda Koruması".localized
        public static let minimize = "Küçült".localized
        public static let miniPlayer = "Mini Oynatıcı".localized
        public static let screenLocked = "Ekran Kilitlendi".localized
        public static let screenUnlocked = "Ekran Kilidi Açıldı".localized
        public static let tapToUnlock = "Kilidi Açmak için Dokunun".localized
        public static let lockScreen = "Ekranı Kilitle".localized
        public static let unlock = "Kilidi Aç".localized
        public static let audioRoute = "Ses Çıkışı".localized
        public static let audioConnected = "Bağlandı".localized
        public static let airplay = "AirPlay".localized
        public static let bluetooth = "Bluetooth".localized
        public static let speaker = "Hoparlör".localized
        public static let jumpToNow = "Şu Ana Git".localized
        public static let returnToLive = "Canlı Yayına Dön".localized
        public static let catchUp = "Geriye Dönük".localized
        public static func catchUpArchiveDays(_ days: Int) -> String {
            "%lld gün arşiv".localized(Int64(days))
        }

        public static func catchUpDescription(archiveDays: Int?) -> String {
            guard let archiveDays, archiveDays > 0 else { return catchUp }
            return "%@ · %@".localized(catchUp, catchUpArchiveDays(archiveDays))
        }

        public static let watchCatchUp = "Tekrarı İzle".localized
        public static let catchupTimelineTitle = "Arşiv Zaman Çizelgesi (Timeshift)".localized
        public static let timelineBookmarks = "Program İmleri".localized
        public static let twoDaysAgo = "2 Gün Önce".localized
        public static let playingArchiveBanner = "Arşiv / Tekrar Yayını Oynatılıyor".localized
        public static let programDetails = "Program Detayı".localized
        public static let setReminder = "Hatırlatıcı Ekle".localized
        public static let reminderSet = "Hatırlatıcı Eklendi".localized
        public static let reminderScheduling = "Hatırlatıcı Ayarlanıyor…".localized
        public static let removeReminder = "Hatırlatıcıyı Kaldır".localized
        public static let reminderRemoved = "Hatırlatıcı Kaldırıldı".localized
        public static let reminderNotificationTitle = "Program Başlıyor".localized
        public static func reminderStartsSoonBody(_ program: String, _ channel: String) -> String {
            "\"%@\", %@ kanalında kısa süre içinde başlayacak!".localized(program, channel)
        }

        public static let autoSwitchReminder = "Program Başlangıcında Kanala Geç".localized
        public static let autoSwitchReminderDescription = "Yalnızca uygulama açıkken ve oynatıcı boşta olduğunda, aynı playlist’teki hatırlatılan programa geçer.".localized
        public static let reminderSchedulingFailed = "Hatırlatıcı ayarlanamadı. Bildirim iznini ve program saatini kontrol edin.".localized
        public static func reminderNotificationBody(_ program: String, _ channel: String, _ mins: Int) -> String {
            "\"%@\", %@ kanalında %lld dakika sonra başlayacak!".localized(program, channel, Int64(mins))
        }

        public static let allCategories = "Tümü".localized
        public static let searchChannelOrProgram = "Kanal veya program ara...".localized
        public static let matchingProgram = "Eşleşen Program".localized
        public static let openChannel = "Kanalı Aç".localized
        public static let share = "Paylaş".localized
        public static let completed = "tamamlandı".localized
        public static let today = "Bugün".localized
        public static let yesterday = "Dün".localized
        public static let returnToToday = "Bugüne Dön".localized
        public static let catchUpArchive = "Geriye Dönük Arşiv".localized
        public static let refreshEPG = "Yayın Akışını Yenile".localized
        public static let syncing = "Senkronize ediliyor...".localized
        public static let epgUpdated = "Yayın akışı güncellendi".localized
        public static func epgPartiallyUpdated(failedChannels: Int) -> String {
            "Yayın akışının bazı kanalları güncellenemedi (%lld)".localized(Int64(failedChannels))
        }

        public static let epgRefreshFailed = "Yayın akışı güncellenemedi".localized
        public static let epgNoChannelsToRefresh = "Güncellenecek kanal bulunamadı".localized
        public static func lastSynced(_ timeString: String) -> String {
            "Son güncelleme: %@".localized(timeString)
        }

        public static func epgDataAge(_ interval: TimeInterval) -> String {
            let formatter = DateComponentsFormatter()
            if interval < 3600 {
                formatter.allowedUnits = [.minute]
            } else if interval < 86400 {
                formatter.allowedUnits = [.hour]
            } else {
                formatter.allowedUnits = [.day]
            }
            formatter.unitsStyle = .abbreviated
            formatter.maximumUnitCount = 1
            let value = formatter.string(from: max(60, interval)) ?? ""
            return "EPG verisi %@ önce güncellendi".localized(value)
        }

        public static let epgDataStale = "EPG verisi eski".localized
        public static let epgLastRefreshIssue = "Son EPG yenilemesinde hata oluştu".localized
        public static let epgFreshnessUnknown = "EPG güncelleme durumu bilinmiyor".localized
        public static let epgThisDevice = "Bu cihazda".localized
        public static let epgDiagnosticsTitle = "EPG Tanılaması".localized
        public static func epgDiagnosticsMessage(
            playlistID: String,
            source: String,
            lastSuccess: String,
            lastFailure: String
        ) -> String {
            "Playlist kimliği: %@\nEPG kaynağı: %@\nBu cihazdaki son başarılı yenileme: %@\nBu cihazdaki son yenileme hatası: %@\nEPG önbelleği ve yenileme zamanı cihazlar arasında eşitlenmez. Diğer cihazlarda playlist kimliğini ve kaynak kodunu karşılaştırın."
                .localized(playlistID, source, lastSuccess, lastFailure)
        }

        public static func epgProviderCooldownUntil(_ date: String) -> String {
            "Sağlayıcının bildirdiği EPG bekleme süresi %@ tarihinde doluyor".localized(date)
        }

        public static let epgProviderRateLimitedWithoutDate = "Sağlayıcı EPG isteklerini sınırladı ancak yeniden deneme zamanı bildirmedi.".localized

        public static let automaticBroadcast = "Canlı Yayın".localized
        public static let broadcastIntermission = "Yayın Arası".localized
        public static let epgFallbackDescription = "Yayın akışı sağlayıcı tarafından iletilmediğinde otomatik olarak oluşturulan yayın kuşağı.".localized
        public static let morningBroadcast = "Sabah Yayını Kuşağı".localized
        public static let dayBroadcast = "Gündüz Yayını Kuşağı".localized
        public static let primeBroadcast = "Akşam Yayını Kuşağı".localized
        public static let nightBroadcast = "Gece Kuşağı Yayını".localized
        public static let preparingGuide = "Yayın Akışı Hazırlanıyor".localized
        public static func reconnecting(_ retryCount: Int, max: Int = 5) -> String {
            "Bağlantı koptu, yeniden bağlanılıyor... (%lld/%lld)".localized(Int64(retryCount), Int64(max))
        }

        public static let audioSync = "Ses Senkronizasyonu".localized
        public static let audioSettings = "Ses Ayarları".localized
        public static let resetAudioDelay = "Sesi Sıfırla".localized
        public static let lipSyncAdjustment = "Hassas Lip-Sync Ayarı".localized
        public static let audioSyncSubtitle = "Ses ve görüntü kaymasını 50ms adımlarla düzeltin".localized
        public static let rememberForChannel = "Bu kanal için ayarı hatırla".localized
        public static let synchronizedBadge = "SENKRONİZE".localized
        public static let adjustedBadge = "DÜZELTME AKTİF".localized
        public static func audioDelayMs(_ ms: Int) -> String {
            ms > 0 ? "+%lld ms".localized(Int64(ms)) : "%lld ms".localized(Int64(ms))
        }

        public static let subtitleSync = "Altyazı Senkronizasyonu".localized
        public static let resetSubtitleDelay = "Sıfırla".localized
        public static func subtitleDelayMs(_ ms: Int) -> String {
            ms > 0 ? "+%lld ms".localized(Int64(ms)) : "%lld ms".localized(Int64(ms))
        }

        public static func audioTrackChanged(_ name: String) -> String {
            "Ses: %@".localized(name)
        }

        public static func subtitleTrackChanged(_ name: String) -> String {
            "Altyazı: %@".localized(name)
        }

        public static let upNext = "Sonraki Bölüm".localized
        public static let playNow = "Hemen Oynat".localized
        public static let cancel = "İptal".localized
        public static func upNextPlayingInSeconds(_ seconds: Int) -> String {
            "%lld saniye içinde oynatılacak".localized(Int64(seconds))
        }
    }

    // MARK: - Errors

    public enum Errors {
        public static let invalidURL = "Geçersiz URL adresi.".localized
        public static let invalidResponse = "Sunucudan geçersiz yanıt alındı.".localized
        public static let rateLimited = "Sunucu istekleri geçici olarak sınırladı.".localized
        public static let unauthorized = "Kullanıcı adı veya şifre hatalı.".localized
        public static let pinMismatch = "PIN kodları eşleşmiyor. Tekrar deneyin.".localized
        public static let incorrectPIN = "Hatalı PIN".localized
        public static let cannotPlayStream = "Yayın oynatılamıyor.".localized
        public static let invalidXMLTVSource = "XMLTV kaynağı bozuk, izin verilen boyutu aşıyor veya desteklenmeyen bir arşiv biçiminde.".localized
        public static let hiddenMediaSaveFailed = "İçerik gizlenemedi. Lütfen tekrar deneyin.".localized

        public static func serverError(code: Int) -> String {
            "Sunucu hatası (Kod: %lld).".localized(Int64(code))
        }

        public static func decodingFailed(desc: String) -> String {
            "Veri işlenemedi: %@".localized(desc)
        }

        public static func underlying(desc: String) -> String {
            "Bir hata oluştu: %@".localized(desc)
        }

        public static func searchFailed(desc: String) -> String {
            "Arama verileri yüklenemedi: %@".localized(desc)
        }
    }

    // MARK: - Onboarding

    public enum Onboarding {
        public static let skip = "Atla".localized
        public static let howToUse = "Nasıl Kullanılır?".localized
        public static let description = "Ana ekrandan '+' butonuna basarak Xtream Codes veya M3U bağlantılarınızı kolayca ekleyebilir ve izlemeye başlayabilirsiniz.".localized
        public static let startNow = "Hemen Başla".localized
        public static let next = "İleri".localized
        public static let page1Title = "PureIPTV'ye Hoşgeldiniz".localized
        public static let page1Desc = "Apple ekosistemi için özenle tasarlanmış, akıcı ve reklamsız premium IPTV deneyimi.".localized
        public static let page2Title = "Hızlı Arama & Geçmiş".localized
        public static let page2Desc = "Gelişmiş arama altyapısı sayesinde binlerce kanal ve film arasında saniyeler içinde geçiş yapın.".localized
        public static let page3Title = "Zengin Oynatıcı & PiP".localized
        public static let page3Desc = "Picture in Picture desteği ve ses/altyazı kontrolüyle seyir zevkinizi üst seviyeye taşıyın.".localized
    }

    // MARK: - Profile Selection

    public enum Profile {
        public static let whoIsWatching = "Kim İzliyor?".localized
        public static let addProfile = "Profil Ekle".localized
        public static let editProfiles = "Profilleri Düzenle".localized
        public static let manageProfiles = "Profilleri Yönet".localized
        public static let deleteInstruction = "Silmek istediğiniz profilin üzerindeki çöp kutusunu seçin.".localized
        public static let personalizeDesc = "İçeriklerinizi ve izleme geçmişinizi kişiselleştirin.".localized
        public static let newProfile = "Yeni Profil".localized
        public static let createProfile = "Yeni Profil Oluştur".localized
        public static let profileName = "Profil Adı".localized
        public static let enterProfileName = "Profil Adı Girin".localized
        public static let profileInfo = "Profil Bilgileri".localized
        public static let profileAvatar = "Profil Avatarı".localized
        public static let kidsBadge = "ÇOCUK".localized
        public static let kidsProfileInfo = "Çocuk Profili (Sadece Çocuk İçerikleri)".localized
        public static let kidsProfileDesc = "Çocuk Profili (Sadece çocuk içerikleri)".localized
        public static let defaultAdultProfile = "Yetişkin".localized
        public static let defaultKidsProfile = "Çocuk".localized
    }

    // MARK: - Add Playlist

    public enum AddPlaylist {
        public static let title = "Playlist Ekle".localized
        public static let connectWith = "Xtream Codes veya\nM3U URL ile bağlanın.".localized
        public static let connectWithIOS = "Xtream Codes bilgilerinizi veya M3U adresinizi girin".localized
        public static let connect = "Bağlan".localized
        public static let m3uComingSoon = "M3U desteği çok yakında geliyor! Şimdilik Xtream Codes kullanın.".localized
        public static let serverPlaceholder = "Sunucu URL (https://provider.net:8080)".localized
        public static let usernamePlaceholder = "Kullanıcı Adı".localized
        public static let passwordPlaceholder = "Şifre".localized
        public static let m3uPlaceholder = "M3U URL (http://...)".localized
    }

    // MARK: - Settings

    public enum Settings {
        public static let title = "Ayarlar".localized
        public static let accounts = "HESAPLAR".localized
        public static let manageAccounts = "Hesap Yönetimi (Playlists)".localized
        public static let security = "GÜVENLİK".localized
        public static let searchHistory = "Arama Geçmişi".localized
        public static let saveRecentSearches = "Son Aramaları Kaydet".localized
        public static let searchHistoryDescription = "Arama geçmişi en fazla 20 aramayı seçilen süre boyunca saklar. Bu tercih bu cihazda tutulur. Geçmiş, CloudKit etkinse cihazlar arasında eşitlenebilen mevcut ortak veri deposunu kullanır. Kapatmak mevcut kayıtları siler.".localized
        public static let searchHistoryRetention = "Saklama Süresi".localized
        public static let searchHistorySevenDays = "7 gün".localized
        public static let searchHistoryThirtyDays = "30 gün".localized
        public static let searchHistoryNinetyDays = "90 gün".localized
        public static let appearance = "GÖRÜNÜM".localized
        public static let visualThemePreset = "Görsel Tema".localized
        public static let visualThemePresetDescription = "Vurgu rengini tvOS atmosferik arka plan tonuyla eşleştirir.".localized
        public static let visualThemePackageImport = "Görünüm Paketi İçe Aktar (.json)".localized
        public static let visualThemePackageDescription = "Paketler bu profilde saklanır. JSON yalnızca ad, kimlik, vurgu rengi ve arka plan rengini belirleyebilir; görsel, kod ve playlist kabul edilmez.".localized
        public static let visualThemePackageInvalid = "Tema paketi geçersiz. JSON yalnızca ad, kimlik, vurgu rengi ve arka plan rengi içerebilir.".localized
        public static let visualThemePackageTooLarge = "Tema paketi 16 KB sınırını aşıyor.".localized
        public static let visualThemePackageLimit = "Bir profilde en fazla 20 tema paketi saklanabilir.".localized
        public static func visualThemePackageAdded(_ name: String) -> String {
            "%@ paketi bu profile eklendi.".localized(name)
        }

        public static func visualThemePackageRemove(_ name: String) -> String {
            "%@ paketini kaldır".localized(name)
        }

        public static let themePresetClassic = "Klasik".localized
        public static let themePresetOcean = "Okyanus".localized
        public static let themePresetAurora = "Aurora".localized
        public static let themePresetForest = "Orman".localized
        public static let themePresetEmber = "Kor".localized
        public static let themeColor = "Ana Renk".localized
        public static let twoLineTVChannelTitles = "Kanal Adlarını İki Satırda Göster".localized
        public static let highContrastFocusFrame = "Yüksek Kontrast Odak Çerçevesi".localized
        public static let highContrastFocusFrameDescription = "Odaktaki kart ve düğmelerin çevresinde belirgin beyaz ve koyu bir çerçeve gösterir.".localized
        public static let favoriteChannelWrapAroundFocus = "Favori Listede Sınırda Çevrimsel Odak".localized
        public static let favoriteChannelWrapAroundFocusDescription = "Açıkken ilk favori kanalda yukarı, son kanalda aşağı yön listenin diğer ucuna geçer. Yalnızca favori kanal listelerinde çalışır.".localized
        public static let appIcon = "Uygulama İkonu".localized
        public static let about = "HAKKINDA".localized
        public static let appVersion = "PureIPTV v1.0.0".localized
        public static let tmdbAttribution = "Bu ürün TMDB API’sini kullanır ancak TMDB tarafından desteklenmez veya onaylanmaz.".localized
        public static let tmdbAPIKeyTitle = "Kişisel TMDB API Anahtarı".localized
        public static let tmdbAPIKeyDescription = "Anahtar cihazın Keychain’inde tutulur ve iCloud eşitlemesine eklenmez. Doğrulama yalnızca düğmeye dokunduğunuzda yapılır.".localized
        public static let tmdbAPIKeyPlaceholder = "TMDB v3 API anahtarı".localized
        public static let tmdbAPIKeyValidateAndSave = "Doğrula ve Kaydet".localized
        public static let tmdbAPIKeyValidating = "TMDB anahtarı doğrulanıyor…".localized
        public static let tmdbAPIKeySaved = "Kişisel TMDB anahtarı etkin. Değer gizli tutuluyor.".localized
        public static let tmdbAPIKeyDefaultActive = "Uygulamanın varsayılan TMDB anahtarı kullanılıyor.".localized
        public static let tmdbAPIKeyDelete = "Kişisel Anahtarı Sil".localized
        public static let tmdbAPIKeyValidationFailed = "Anahtar doğrulanamadı. Anahtarı veya bağlantıyı kontrol edin.".localized
        public static let tmdbAPIKeyLoadFailed = "TMDB anahtarı için güvenli depolamaya erişilemedi.".localized
        public static let tmdbAPIKeyDeleteFailed = "Kişisel TMDB anahtarı güvenli biçimde silinemedi.".localized
        public static let createDiagnosticReport = "Gizlilik Korumalı Tanılama Raporu Oluştur".localized
        public static let diagnosticReportGenerating = "Tanılama raporu hazırlanıyor...".localized
        public static let diagnosticReportTitle = "Tanılama Raporu".localized
        public static let diagnosticReportHint = "Sürüm, cihaz türü ve varsa son bağlantı/playlist denetiminin sabit durum kodlarını içerir. URL, hesap bilgisi, günlük ve ham hata metni eklenmez; hiçbir yere otomatik gönderilmez.".localized
        public static let diagnosticReportUnavailable = "Rapor önizlemesi açılamadı.".localized
        public static let shareDiagnosticReport = "Raporu Dışa Aktar veya Paylaş".localized
        public static let version = "Sürüm".localized
        public static let versionNumber = "1.0.0".localized
        public static let setNewPIN = "Yeni PIN Belirleyin".localized
        public static let verifyPIN = "PIN'i Doğrulayın".localized
        public static let switchProfile = "Profil Değiştir".localized
        public static let hideAdultContent = "Yetişkin İçerikleri Tamamen Gizle".localized
        public static let startupScreen = "Başlangıç Ekranı".localized
        public static let hideEmptyContentTabs = "Boş içerik sekmelerini gizle".localized
        public static let hideEmptyContentTabsDescription = "Playlist'te içerik olmayan canlı TV, film ve dizi sekmelerini gizler.".localized
        public static let hideChannelsWithoutPrograms = "EPG programı olmayan kanalları gizle".localized
        public static let hideChannelsWithoutProgramsDescription = "Yalnızca başarılı EPG yanıtı boş dönen satırları gizler. Yüklenmemiş, yenilenmekte veya hata almış kanallar görünür kalır.".localized
        public static let epgMappingSuggestionsTitle = "EPG Eşleme Önerileri".localized
        public static let epgMappingSuggestionsDescription = "Kanal adlarına göre güven skorlu XMLTV eşleşmeleri önerir; siz onaylamadan hiçbir eşleme kaydedilmez.".localized
        public static let secondaryEPGSourcePriorityDescription = "Eşleştirmeler aktif playlist'e özeldir. Playlist sağlayıcısının EPG'si önceliklidir; eşleştirdiğiniz harici XMLTV kaynağı yalnız boş zaman aralıklarını tamamlar.".localized
        public static let findEPGMappingSuggestions = "Önerileri Bul veya Yenile".localized
        public static let noEPGMappingSuggestions = "Güvenilir bir EPG eşleşmesi önerisi bulunamadı.".localized
        public static let confirmEPGMapping = "Eşlemeyi Onayla".localized
        public static func retryFailedCustomEPGSources(_ count: Int) -> String {
            "Başarısız EPG Kaynaklarını Yeniden Dene (%lld)".localized(Int64(count))
        }

        public static func epgMappingConfidence(_ confidence: Int) -> String {
            "Güven: %lld%%".localized(Int64(confidence))
        }

        public static let discover = "Keşfet".localized
        public static let contentSorting = "İçerik Sıralaması".localized
        public static let categorySortFallbackDescription = "Kategori için özel sıralama seçilmediyse bu varsayılan kullanılır.".localized
        public static let contentManagement = "İçerik Yönetimi".localized
        public static let hiddenMediaManagement = "Gizlenen Film ve Diziler".localized
        public static let hiddenMediaManagementDescription = "Gizlediğiniz film ve dizileri görüntüleyip geri yükleyin.".localized
        public static let noHiddenMedia = "Henüz gizlenmiş film veya dizi yok.".localized
        public static let defaultMediaSource = "Varsayılan kaynak".localized
        public static let vodSorting = "Filmler (VOD)".localized
        public static let playerSettings = "Oynatıcı (Player) Ayarları".localized
        public static let remoteControls = "Oynatıcı Kumanda Yönleri".localized
        public static let remoteControlsDescription = "Yalnızca oynatıcı kontrolleri gizliyken yön hareketlerine atanır. Aynı eylemi birden fazla yöne atayabilirsiniz.".localized
        public static let restoreRemoteControlDirections = "Varsayılan Kumanda Yönlerini Geri Yükle".localized
        public static let remoteDirectionUp = "Yukarı".localized
        public static let remoteDirectionDown = "Aşağı".localized
        public static let remoteDirectionLeft = "Sol".localized
        public static let remoteDirectionRight = "Sağ".localized
        public static let autoPlayNextEpisode = "Sonraki Bölüme Otomatik Geç".localized
        public static let autoSelectFirstAlternativeSource = "İlk Alternatif Kaynağı Otomatik Oynat".localized
        public static let autoSelectFirstAlternativeSourceDescription = "Alternatif kaynaklar seçildiğinde listeyi açmadan playlist sırasındaki ilk eşleşmeyi oynatır.".localized
        public static let reverseChannelZappingDirection = "Kanal Gezinme Yönünü Ters Çevir".localized
        public static let reverseChannelZappingDirectionDescription = "Canlı oynatıcıda yukarı ve aşağı yönleriyle önceki veya sonraki kanala geçişi tersine çevirir.".localized
        public static let startMuted = "Kanalları Sessiz Başlat".localized
        public static let downloadConcurrencyLimit = "Eşzamanlı İndirme Sayısı".localized
        public static let downloadConcurrencyLimitDesc = "Aynı anda indirilecek içerik sayısını sınırlar.".localized
        public static let oledDimming = "OLED Ekran Koruma / Karartma".localized
        public static let oledDimmingDesc = "Ekran yanmasını önlemek için kontroller açıkken veya duraklatıldığında ekranı kademeli olarak karartır.".localized
        public static let cleanChannelNames = "Kanal İsimlerini Sadeleştir".localized
        public static let cleanChannelNamesDesc = "Kanal adlarındaki gereksiz [TR], FHD, 1080p, 4K, |HEVC| ve VIP etiketlerini temizler.".localized
        public static let epgSettings = "Yayın Akışı (EPG) Ayarları".localized
        public static let liveTVArtworkSource = "Canlı TV Görsel Kaynağı".localized
        public static let liveTVArtworkEPG = "EPG Program Görseli".localized
        public static let liveTVArtworkChannel = "Kanal Logosu".localized
        public static let liveTVArtworkSourceDescription = "EPG görseli bulunmadığında kanal logosu kullanılır. Playlist’e özel logo her zaman önceliklidir.".localized
        public static let timeShift = "Zaman Kaydırma (Time Shift)".localized
        public static func timeShiftHours(_ hours: Int) -> String {
            hours > 0 ? "+%lld Saat".localized(Int64(hours)) : "%lld Saat".localized(Int64(hours))
        }

        public static let autoUpdateEPG = "Akışı Otomatik Güncelle".localized
        public static let epgAutoRefreshInterval = "EPG Otomatik Yenileme Aralığı".localized
        public static let epgAutoRefreshDescription = "Guide refresh checks this interval when the guide opens; background updates are not guaranteed.".localized
        public static let deferAutoEPGRefreshOnConstrainedNetwork = "Kısıtlı Ağda Tam EPG Yenilemesini Ertele".localized
        public static let deferAutoEPGRefreshOnConstrainedNetworkDescription = "Tam rehber yenilemesi yalnızca sistem bağlantıyı pahalı veya Düşük Veri olarak işaretlediğinde bekletilir. Rehberdeki Yenile düğmesiyle istediğiniz zaman elle başlatabilirsiniz.".localized
        public static let epgAutoRefreshDeferredMessage = deferAutoEPGRefreshOnConstrainedNetworkDescription
        public static let subscriptionAndStorage = "Abonelik & Depolama".localized
        public static let subscriptionStatus = "Abonelik Durumu".localized
        public static let premiumStatus = "Premium 👑".localized
        public static let freeStatus = "Ücretsiz / Süresi Dolmuş".localized
        public static let clearCache = "Önbelleği Temizle".localized
        public static let clearCacheTitle = "Önbelleği Temizle".localized
        public static let clearCacheMessage = "Önbelleğe alınan posterler, kapak resimleri ve ağ verileri silinecektir. İndirilen içerikleriniz ve ayarlarınız korunur.".localized
        public static let clearCacheConfirm = "Önbelleği Boşalt".localized
        public static let clearCacheSuccess = "Önbellek başarıyla temizlendi.".localized
        public static let clearing = "Temizleniyor...".localized
        public static let calculating = "Hesaplanıyor...".localized
        public static let defaultSort = "Varsayılan".localized
        public static let useLibrarySortDefault = "Kütüphane varsayılanını kullan".localized
        public static let alphabeticalSort = "A-Z (Alfabetik)".localized
        public static let ratingSort = "IMDb Puanı".localized
        public static let dateAddedSort = "Eklenme Tarihi".localized
        public static let audioAndSubtitleSettings = "Ses ve Altyazı Ayarları".localized
        public static let defaultAudioLanguage = "Varsayılan Ses Dili".localized
        public static let defaultSubtitleLanguage = "Varsayılan Altyazı Dili".localized
        public static let subtitleTextSize = "Altyazı Boyutu (VLC)".localized
        public static let subtitleTextSizeDescription = "Boyut VLC’de uygulanır. AVPlayer, WebVTT dışındaki altyazılarda sistem görünümünü kullanır.".localized
        public static let subtitleAppearanceProfile = "VLC Altyazı Görünümü".localized
        public static let subtitleAppearanceGlobalScope = "Profil, tüm VLC oynatımları için uygulama genelinde geçerlidir.".localized
        public static let subtitleAppearanceDescription = "VLC metin altyazıları için geçerlidir. AVPlayer sistem altyazıları, görüntü tabanlı altyazılar ve ASS/SSA’nın kendi stilleri etkilenmez. HDR otomatik algılanmaz. Değişiklik için uygulamayı tamamen kapatıp yeniden açın.".localized
        public static let subtitleAppearanceStandard = "Varsayılan (Beyaz)".localized
        public static let subtitleAppearanceSoftGray = "Yumuşak Gri".localized
        public static let subtitleAppearanceDimGray = "Daha Sönük Gri".localized
        public static let forceSDROutput = "HDR İçeriği SDR Olarak Görüntüle".localized
        public static let forceSDROutputDescription = "Seçili motor AVPlayer olmalı. iOS/tvOS 26 ve üzerindeki yerel görüntü HDR içeriği SDR ton aralığına eşler. TV/HDMI görüntü modu değiştirilmez; VLC ve AirPlay etkilenmez.".localized
        public static let catchupSkipInterval = "Catch-up Atlama Adımı".localized
        public static let catchupSkipIntervalDescription = "Catch-up sırasında geri ve ileri düğmeleri seçilen aralık kadar atlar. Canlı TV ve VOD atlamaları değişmez.".localized
        public static let vodSkipInterval = "VOD Atlama Adımı".localized
        public static let vodSkipIntervalDescription = "Film ve dizi oynatımında geri ve ileri düğmeleri seçilen aralık kadar atlar. Catch-up kendi ayarını kullanır; canlı yayında atlama kullanılamaz.".localized
        public static let rememberTrackPreferences = "Akıllı Tercih Belleği".localized
        public static let rememberTrackPreferencesDesc = "İzlenen her içerik için son seçilen ses ve altyazı otomatik hatırlanır.".localized
        public static let cloudSyncSection = "BULUT & EŞZAMANLAMA".localized
        public static let iCloudSync = "iCloud Eşzamanlama".localized
        public static let iCloudSyncDesc = "Kaldığınız yer ve izleme geçmişi Apple TV, iPhone ve iPad arasında otomatik eşitlenir.".localized
    }

    // MARK: - Search

    public enum Search {
        public static let startSearch = "Aramaya Başlayın".localized
        public static let noResults = "Sonuç Bulunamadı".localized
        public static let searchAllTypes = "Tüm İçerik Türlerini Ara".localized
        public static let searchAllPlaylists = "Tüm Çalma Listelerinde Ara".localized
        public static let searchPlaceholder = "Kanal, film, dizi veya kategori ara...".localized
        public static let channelSearchPlaceholder = "Kanal ara...".localized
        public static let categories = "Kategoriler".localized
        public static let allCategories = "Tüm Kategoriler".localized
        public static let channelCountFormat = "%d Kanal".localized
        public static let movieCountFormat = "%d Film".localized
        public static let seriesCountFormat = "%d Dizi".localized
        public static let liveTV = "Canlı TV".localized
        public static let movies = "Filmler".localized
        public static let series = "Diziler".localized
        public static let recentSearches = "Son Aramalar".localized
        public static let pinnedSearches = "Sabitlediğim Aramalar".localized
        public static let pinnedSearchesDescription = "Bu liste bu cihazda saklanır ve son arama geçmişinden bağımsızdır.".localized
        public static let pinSearch = "Aramayı Sabitle".localized
        public static let unpinSearch = "Sabitlemeyi Kaldır".localized
        public static let togglePinnedSearchHint = "Aramayı sabit listenize ekler veya listeden çıkarır.".localized
        public static let runPinnedSearchHint = "Bu sabit aramayı yeniden çalıştırır.".localized
        public static let pinnedSearchLimitTitle = "Sabitleme Sınırı".localized
        public static let pinnedSearchLimitMessage = "En fazla 10 arama sabitlenebilir. Yeni bir arama eklemek için önce birini kaldırın.".localized
        public static let quickTags = "Popüler Kategoriler & Etiketler".localized
        public static let discoverSuggestions = "Öne Çıkan Aramalar".localized
        public static let clear = "Temizle".localized
        public static let loadingMessage = "Arama altyapısı hazırlanıyor...\n(Bu işlem ilk girişte birkaç saniye sürebilir)".localized
        public static let all = "Tümü".localized
        public static let myCategories = "Kategorilerim".localized
        public static let filter4K = "4K / UHD 🌟".localized
        public static let filterEPG = "EPG Programları 🕒".localized
        public static let people = "Kişiler".localized
        public static let programs = "Programlar".localized
        public static let allPlaylists = "Tüm Çalma Listeleri (Global 🌐)".localized
        public static let allPlaylistsShort = "Tümü (Global)".localized
        public static let liveProgramMatch = "Canlı Program:".localized
        public static let playlistSource = "Liste:".localized
        public static let myCollection = "Koleksiyonum".localized
        public static let openCategory = "Kategoriye Git".localized
    }

    // MARK: - MultiView

    public enum MultiView {
        public static let title = "Multi-view".localized
        public static let addChannel = "Kanal Ekle".localized
        public static let selectChannel = "Kanal Seç".localized
        public static let layoutShowcase = "1+3 Vitrin".localized
        public static let layoutGrid = "2x2 Izgara".localized
        public static let layoutDual = "1+1 İkili".localized
        public static let swapToPrimary = "Ana Ekrana Taşı".localized
        public static let audioActive = "Aktif Ses".localized
        public static let audioMuted = "Sessiz".localized
        public static let primaryScreen = "Ana Ekran".localized
        public static let aspectRatioControl = "Görüntü Oranı".localized
        public static let aspectFit = "Orijinal (Fit)".localized
        public static let aspectFill = "Ekranı Doldur (Fill)".localized
        public static let aspectStretch = "Genişlet (Stretch)".localized
    }

    // MARK: - Parental Lock

    public enum ParentalLock {
        public static let title = "Ebeveyn Kontrolü".localized
        public static let description = "Bu içeriğe erişmek için PIN girin veya FaceID/TouchID kullanın.".localized
        public static let categoryUnlockNotice = "PIN doğrulamasından sonra bu kategori 15 dakika açık kalır.".localized
        public static let pin = "PIN".localized
        public static let biometricReason = "Yetişkin içeriğine erişmek için doğrulama gerekiyor".localized
    }

    // MARK: - Dashboard

    public enum Dashboard {
        public static let title = "Keşfet".localized
        public static let pinHomeCategory = "Kategoriyi Ana Sayfaya Sabitle".localized
        public static let unpinHomeCategory = "Ana Sayfadan Kategoriyi Kaldır".localized
        public static let movePinnedCategoryUp = "Sabit Kategoriyi Yukarı Taşı".localized
        public static let movePinnedCategoryDown = "Sabit Kategoriyi Aşağı Taşı".localized
        public static let pinnedCategoryHint = "Bu kategori yalnızca seçili profil ve playlist için ana sayfada gösterilir.".localized
        public static let manageHomeCategories = "Ana Sayfa Kategorilerini Yönet".localized
        public static let noHomeCategories = "Henüz kategori yok".localized
        public static let homeCategoriesLoadHint = "Kategoriler playlist yüklemesi tamamlandıktan sonra burada görünür.".localized
        public static let continueWatching = "Kaldığın Yerden İzle".localized
        public static let myFavorites = "Favorilerim".localized
        public static let favoriteLiveTV = "Favori Canlı TV".localized
        public static let favoriteMovies = "Favori Filmler".localized
        public static let favoriteSeries = "Favori Diziler".localized
        public static let sortFavoriteSeries = "Dizi sıralaması".localized
        public static let newestEpisodeDate = "En yeni bölüme göre".localized
        public static let existingFavoriteOrder = "Mevcut sıra".localized
        public static let loadingFavoriteSeriesDates = "Bölüm tarihleri alınıyor…".localized
        public static let favoriteSeriesDatesLoadFailed = "Bölüm tarihleri yüklenemedi. Yeniden deneyin.".localized
        public static let featuredLiveTV = "Canlı TV (Önerilen)".localized
        public static let catalogCountSummaryTitle = "Katalog yenileme özeti".localized
        public static let catalogCountSummaryDescription = "Önceki başarılı sayımlara göre net toplam farkı. Tek tek eklenen veya kaldırılan içerikler gösterilmez.".localized
        public static let epgPrograms = "Rehberdeki Programlar".localized
        public static let showFollowedSportsEvents = "Takip Ettiklerim".localized
        public static let showAllSportsEvents = "Tüm Maçlar".localized
        public static let noFollowedSportsEvents = "Takip ettiğiniz takımlarda bu aralıkta maç yok.".localized
        public static let otherSportsMatches = "Diğer Maçlar".localized
        public static let sportsFollowHint = "İzlemek için seçin. Takım veya tanınan turnuva takibi için basılı tutun.".localized
        public static let sportsFollowHintTV = "İzlemek için seçin. Takım veya turnuvayı takip etmek için Siri Remote üzerinde Seç düğmesini basılı tutun.".localized
        public static let sportsFollowSyncLimitExceeded = "iCloud eşitleme alanı sınırına ulaşıldı. Bu takip değişikliği eşitlenmedi.".localized
        public static let sportsFollowSyncUnavailable = "iCloud şu anda kullanılamıyor. Bu takip değişikliği eşitlenmedi.".localized
        public static func followSportsTeam(_ team: String) -> String {
            "Takımı Takip Et: %@".localized(team)
        }

        public static func unfollowSportsTeam(_ team: String) -> String {
            "Takım Takibini Bırak: %@".localized(team)
        }

        public static func followSportsCompetition(_ competition: String) -> String {
            "Turnuvayı Takip Et: %@".localized(competition)
        }

        public static func unfollowSportsCompetition(_ competition: String) -> String {
            "Turnuva Takibini Bırak: %@".localized(competition)
        }

        public static let nowAiring = "ŞU AN".localized
        public static let newMovies = "Yeni Eklenen Filmler".localized
        public static let newSeries = "Yeni Eklenen Diziler".localized
        public static let recommendedForYou = "Sana Özel Öneriler".localized
        public static let noPersonalizedMovies = "Bu profil için şu anda kişisel film önerisi yok.".localized
        public static let actorRecommendationTitle = "Ortak oyuncu: %@ • İzlediğin: %@ • %@".localized
        public static let mostWatchedActors = "En Çok İzlediğin Oyuncular".localized
        public static let popularActors = "Popüler Oyuncular".localized
        public static let actorFilmographyUnavailable = "Bu oyuncunun kataloğunda eşleşen içerik bulunamadı.".localized
        public static let newEpisodesForYou = "Yeni Bölümler".localized
        public static let newEpisodeCardSummary = "S%1$02dE%2$02d · %3$d yeni bölüm".localized
        public static let unwatchedEpisodeCountFormat = "%d izlenmemiş bölüm"
        public static func unwatchedEpisodeCount(_ count: Int) -> String {
            String(format: unwatchedEpisodeCountFormat.localized, locale: Locale.current, arguments: [count])
        }

        public static let mostRatedMovies = "En Çok Oy Alan Filmler".localized
        public static let highestRatedMovies = "En Yüksek Puanlı Filmler".localized
        public static let ratingVotesSummary = "★ %1$.1f · %2$d oy".localized
        public static let mostVotesSummary = "%1$d oy · ★ %2$.1f".localized
        public static let awardWinningMovies = "Ödül Kazanan Filmler".localized
        public static let awardNomineeMovies = "Ödüle Aday Filmler".localized
        public static let awardRecognitionCount = "%d ödül".localized
        public static let awardNominationCount = "%d adaylık".localized
        public static let actorFilmographyTitle = "%@ • Filmografi • %@"
        public static let hdBadge = "HD".localized
        public static let movieBadge = "Film".localized
        public static let details = "Detaylar".localized
    }

    public enum ViewingStatistics {
        public static let title = "İzleme İstatistikleri".localized
        public static let period = "Dönem".localized
        public static let last7Days = "Son 7 gün".localized
        public static let last30Days = "Son 30 gün".localized
        public static let last90Days = "Son 90 gün".localized
        public static let totalTime = "İzleme Süresi".localized
        public static let currentPeriod = "Bu dönem".localized
        public static let previousPeriod = "Önceki dönem".localized
        public static let periodChangeLabel = "Dönem karşılaştırması".localized
        public static let noPreviousPeriod = "Önceki dönemde kayıtlı izleme süresi yok.".localized
        public static let contentTypes = "İçerik Türleri".localized
        public static let mostWatched = "En Çok İzlenenler".localized
        public static let noData = "Bu dönemde izleme kaydı yok".localized
        public static let trackingNote = "İstatistikler bu sürümden itibaren kaydedilir. Geçmişteki kayıtlı oynatma konumu, izlenen süreyi göstermez ve toplama dahil edilmez.".localized
        public static let privacyTitle = "Gizlilik".localized
        public static let privacyDetails = "İstatistikler yalnızca bu cihazda ve seçili profilde tutulur; en fazla 180 gün saklanır. iCloud ile eşitlenmez, ham izleme geçmişi veya kaynak bağlantıları sunucuya gönderilmez.".localized
        public static let clear = "İstatistikleri Sil".localized
        public static let clearTitle = "İstatistikler silinsin mi?".localized
        public static let clearMessage = "Bu profilin bu cihazda tutulan izleme istatistikleri kalıcı olarak silinir.".localized
        public static func periodChange(_ percent: String) -> String {
            "%@ önceki döneme göre".localized(percent)
        }
    }

    // MARK: - Downloads

    public enum Downloads {
        public static let title = "İndirilenler".localized
        public static let empty = "Henüz indirilmiş içerik yok".localized
        public static let emptyDescription = "Filmleri veya dizileri indirerek internet bağlantınız olmadan da izleyebilirsiniz.".localized
        public static let activeDownloads = "Aktif İndirmeler".localized
        public static let queued = "Kuyrukta".localized
        public static let paused = "Duraklatıldı".localized
        public static let pauseDownload = "İndirmeyi Duraklat".localized
        public static let resumeDownload = "İndirmeye Devam Et".localized
        public static let downloadNext = "İlk Sırada İndir".localized
        public static let completedDownloads = "İndirilen İçerikler".localized
        public static let exportActions = "Dışa Aktarma Seçenekleri".localized
        public static let shareCompletedDownload = "İndirilen Dosyayı Paylaş".localized
        public static let saveCompletedDownloadToFiles = "Dosyalara Kaydet".localized
        public static let exportUnavailableTitle = "İndirme Dosyası Kullanılamıyor".localized
        public static let exportUnavailableMessage = "Bu indirme dosyası artık kullanılamıyor. İndirmeler listesini yenileyip tekrar deneyin.".localized
        public static let totalStorage = "Kullanılan Alan".localized
        public static let availableStorage = "Kullanılabilir Alan".localized
        public static let storageUnavailable = "Alan bilgisi alınamadı".localized
        public static let refreshDownloads = "İndirmeleri Yenile".localized
        public static let failedDownloads = "Başarısız İndirmeler".localized
        public static let failedDownload = "İndirme tamamlanamadı".localized
        public static let failedDownloadHint = "İçerik ekranından indirmeyi yeniden başlatabilirsiniz.".localized
        public static let dismissFailedDownload = "Listeden Kaldır".localized
        public static let cancelDownload = "İndirmeyi İptal Et".localized
        public static let missingDownload = "İndirilen dosya bu cihazda kullanılamıyor.".localized
        public static let deleteDownloadTitle = "İndirilen Dosyayı Sil".localized
        public static func deleteDownloadMessage(_ title: String) -> String {
            "“%@” bu cihazdan silinecek. İzleme geçmişiniz korunacak.".localized(title)
        }

        public static let deleteDownloadFailure = "Dosya silinemedi. Aktif indirmeyi ve depolama alanını kontrol edip yeniden deneyin.".localized
        public static let downloadLoadFailure = "İndirme listesi alınamadı. Yeniden deneyin.".localized
        public static let downloadCommandFailure = "İndirme işlemi tamamlanamadı. Yeniden deneyin.".localized
        public static let clearCompleted = "Tamamlananları Sil".localized
        public static let clearCompletedTitle = "Tamamlanan İndirmeleri Sil".localized
        public static let clearCompletedMessage = "Tamamlanmış tüm indirmeler bu cihazdan silinir. Devam eden ve sıradaki indirmeler korunur.".localized
        public static let clearCompletedFailure = "Bazı tamamlanmış indirmeler silinemedi. Depolama alanını kontrol edip yeniden deneyin.".localized
        public static let downloadSpeed = "Hız".localized
        public static let tvOSNotice = "Çevrimdışı indirme özelliği Apple TV kısıtlamaları nedeniyle yalnızca iOS ve iPadOS cihazlarında desteklenmektedir.".localized
    }

    // MARK: - Local Media Presentation

    public enum MediaPresentation {
        public static let edit = "Yerel Bilgileri Düzenle".localized
        public static let title = "Görünen Başlık".localized
        public static let posterURL = "Poster URL’si".localized
        public static let year = "Yıl".localized
        public static let reset = "Kaynak Bilgilerine Dön".localized
        public static let localOnlyDescription = "Bu değişiklik yalnızca bu profil ve playlist için saklanır. Sağlayıcı kaydınız değişmez.".localized
        public static let posterURLDescription = "Poster bağlantısı HTTPS kullanmalıdır.".localized
        public static let invalidYear = "Yıl 1888 ile 2100 arasında olmalıdır.".localized
    }

    // MARK: - VOD Detail

    public enum VODDetail {
        public static let watch = "İzle".localized
        public static let continueWatching = "Devam Et".localized
        public static let restart = "Baştan Başlat".localized
        public static let download = "İndir".localized
        public static let downloading = "İndiriliyor".localized
        public static let downloaded = "İndirildi".localized
        public static let cast = "Yayınla".localized
        public static let trailer = "Fragman".localized
        public static let similarMovies = "Benzer Filmler".localized
        public static let loading = "Film bilgileri yükleniyor…".localized
        public static let genres = "Türler".localized
        public static let overview = "Konusu".localized
        public static let productionCountries = "Yapım Ülkeleri".localized
        public static let productionCompanies = "Yapım Şirketleri".localized
        public static let viewOnIMDb = "IMDb'de Görüntüle".localized
        public static let castCrew = "Oyuncu Kadrosu".localized
        public static let biography = "Biyografi".localized
        public static let born = "Doğum".localized
        public static let birthplace = "Doğum Yeri".localized
        public static let character = "Karakter".localized
        public static let noBiography = "Bu oyuncu için henüz biyografi bilgisi eklenmemiştir.".localized
        public static let uhdQualityBadge = "4K UHD".localized
        public static let hdrBadge = "HDR10".localized
        public static let audio51Badge = "5.1 Surround".localized
        public static let imdbRating = "IMDb".localized
        public static let watchTrailer = "Fragmanı İzle".localized
        public static let trailerNotAvailable = "Bu film için fragman bulunamadı.".localized

        public static let inLibrary = "Kütüphanenizde".localized
        public static let notInLibrary = "Listenizde Bulunamadı".localized
        public static let notInLibraryDesc = "Bu içerik mevcut IPTV çalma listenizde bulunamadı. TMDB özet bilgisi aşağıdadır.".localized
        public static let versionsAndQuality = "Sürüm & Kalite Seçenekleri".localized
        public static let currentVersion = "Mevcut Sürüm".localized
    }

    public enum WatchAvailability {
        public static let title = "Yayın Platformları".localized
        public static let chooseCountry = "Ülke seç".localized
        public static let clearCountry = "Ülke seçimini kaldır".localized
        public static let subscription = "Abonelik".localized
        public static let free = "Ücretsiz".localized
        public static let adSupported = "Reklam destekli".localized
        public static let rent = "Kirala".localized
        public static let buy = "Satın al".localized
        public static let noAvailability = "Bu ülkede sağlayıcı bilgisi bulunamadı.".localized
        public static let fetchFailed = "Sağlayıcı bilgileri yüklenemedi.".localized
        public static let source = "Veri kaynağı: JustWatch · TMDB".localized
        public static let openOnTMDB = "TMDB’de görüntüle".localized

        public static func updatedAt(_ date: Date, locale: Locale) -> String {
            var format = Date.FormatStyle(date: .abbreviated, time: .shortened)
            format.locale = locale
            return "Son kontrol: %@".localized(date.formatted(format))
        }
    }

    // MARK: - TMDB Match Picker

    public enum TMDBMatchPicker {
        public static let title = "TMDB eşleşmesi".localized
        public static let searchPlaceholder = "Film veya dizi adı".localized
        public static let searchAccessibilityLabel = "TMDB arama metni".localized
        public static let clearMatch = "TMDB eşleşmesini temizle".localized
        public static let clearMatchHint = "İçerik için seçilen TMDB eşleşmesini kaldırır.".localized
        public static let noResults = "TMDB eşleşmesi bulunamadı".localized
        public static let noResultsHint = "Başlık arayarak eşleşme bulabilirsiniz.".localized
        public static let selected = "Seçili".localized
        public static let selectResultHint = "Bu TMDB sonucunu eşleşme olarak seçer.".localized
    }

    // MARK: - Series Detail

    public enum SeriesDetail {
        public static let watch = "İzle".localized
        public static let continueWatching = "Devam Et".localized
        public static let currentEpisode = "Mevcut Bölüm".localized
        public static let restart = "Baştan Başlat".localized
        public static let seasons = "Sezonlar".localized
        public static let episodes = "Bölümler".localized
        public static let oldestEpisodesFirst = "Önce En Eskiler".localized
        public static let newestEpisodesFirst = "Önce En Yeniler".localized
        public static let shuffleEpisodes = "Bölümleri Karıştır".localized
        public static let shuffleSeason = "Sezonu Karıştır".localized
        public static let shuffleSeries = "Diziyi Karıştır".localized
        public static let loading = "Dizi bilgileri yükleniyor…".localized
        public static let episodeCount = "bölüm".localized
        public static let catalogDiagnosticsTitle = "Katalog Tanılaması".localized
        public static let catalogDiagnosticsDescription = "Yalnızca bu cihazdaki katalog numaralandırmasını denetler. Sağlayıcı verisi kesin olmayabilir; cihazları karşılaştırmaz.".localized
        public static let possibleMissingEpisodeNumbers = "Olası eksik bölüm numaraları".localized
        public static let duplicateEpisodePositions = "Aynı bölüm konumunda birden fazla kaynak kaydı".localized
        public static let sourceIDs = "Kaynak kimlikleri".localized
        public static let nextEpisode = "Sıradaki Bölüm".localized
        public static let playNextEpisode = "Sıradaki Bölümü İzle".localized
        public static let watched = "İzlendi".localized
        public static let unwatched = "İzlenmedi".localized
        public static let markAsUnwatched = "İzlenmedi Olarak İşaretle".localized
        public static let listView = "Liste".localized
        public static let gridView = "Izgara".localized
        public static let selectSeason = "Sezon Seç".localized
        public static func seasonFormat(_ num: Int) -> String {
            "%lld. Sezon".localized(Int64(num))
        }

        public static func seasonEpisodeCount(_ num: Int, _ count: Int) -> String {
            "%lld. Sezon (%lld Bölüm)".localized(Int64(num), Int64(count))
        }
    }

    // MARK: - Paywall

    public enum Paywall {
        public static let unlockPremium = "Premium'u Aç".localized
        public static let fullAccessDescription = "Tüm özelliklere, canlı kanallara ve sınırsız filmlere tam erişim sağlayın.".localized
        public static let subscribe = "Abone Ol".localized
        public static let restorePurchases = "Satın Alımları Geri Yükle".localized
        public static let termsOfService = "Kullanım Koşulları".localized
        public static let privacyPolicy = "Gizlilik Politikası".localized
    }

    // MARK: - Category Management

    public enum CategoryMgmt {
        public static let noCategoriesFound = "Kategori bulunamadı.".localized
        public static func manageTitle(for type: String) -> String {
            "%@ Kategorilerini Yönet".localized(type)
        }

        public static let showAll = "Tümünü Göster".localized
        public static let hideAll = "Tümünü Gizle".localized
        public static let invert = "Tersine Çevir".localized
        public static let filterAll = "Tümü".localized
        public static let filterVisible = "Görünenler".localized
        public static let filterHidden = "Gizlenenler".localized
        public static let searchPlaceholder = "Kategori ara...".localized
        public static let resetOrder = "Sıralamayı Sıfırla".localized
        public static let moveCategoryUp = "Yukarı Taşı".localized
        public static let moveCategoryDown = "Aşağı Taşı".localized
        public static let lockCategory = "Kategoriyi PIN ile Kilitle".localized
        public static let unlockCategory = "Kategori Kilidini Kaldır".localized
        public static let editCategoryName = "Kategori Adını Düzenle".localized
        public static let categoryName = "Kategori Adı".localized
        public static let resetCategoryName = "Kaynak Adına Dön".localized
        public static let nameRulesTitle = "Kategori Adı Kuralları".localized
        public static let nameRulesDescription = "Açık kurallar yenilemede eşleşen kategorileri gizler. Eşleşenleri inceleyin; yeniden göstermek için kuralı kapatın. Regex: ., [a-z], \\d, ^/$ ve tek tekrar (*, +, ? veya {n}); grup ve | yok.".localized
        public static let nameRuleMatchType = "Eşleşme Türü".localized
        public static let nameRuleLiteral = "Metin".localized
        public static let nameRuleRegularExpression = "Güvenli Regex".localized
        public static let nameRuleEnabled = "Kuralı Uygula".localized
        public static let nameRuleInvalidPattern = "Geçersiz ya da desteklenmeyen kural deseni.".localized
        public static let nameRuleSaveFailed = "Kategori adı kuralları kaydedilemedi.".localized
        public static let bulkActions = "Toplu İşlemler".localized
        public static func visibleCountInfo(visible: Int, total: Int) -> String {
            "%lld / %lld kategori aktif".localized(Int64(visible), Int64(total))
        }
    }

    // MARK: - Playlist Management

    public enum PlaylistMgmt {
        public static let savedAccounts = "Kayıtlı Hesaplar".localized
        public static let addAccount = "Yeni Hesap Ekle".localized
        public static let switchNote = "Hesaplar arasında geçiş yaptığınızda uygulama yeni hesaba ait verileri yükleyecektir.".localized
        public static let accountManagement = "Hesap Yönetimi".localized
        public static let contentSources = "İçerik Kaynakları".localized
        public static let contentSourcesDescription = "Canlı TV, filmler ve diziler için ayrı playlist seçin. Kaynak kilitliyse veya bulunamıyorsa etkin playlist kullanılır.".localized
        public static let activePlaylistSource = "Etkin Playlist (varsayılan)".localized
        public static let playbackSettings = "Oynatma Ayarları".localized
        public static let updateCenter = "Güncelleme Merkezi".localized
        public static let updateAllSources = "Tüm Kaynakları Güncelle".localized
        public static let updateCatalog = "Playlist Kataloğu".localized
        public static let updateProviderEPG = "Sağlayıcı EPG".localized
        public static let updateCustomEPG = "Özel EPG Kaynağı".localized
        public static let refreshSource = "Kaynağı Yenile".localized
        public static let updateFailed = "Kaynak güncellenemedi; mevcut veriler korundu.".localized
        public static let defaultStartupPlaylist = "Uygulama Açılışında Kullan".localized
        public static let defaultStartupPlaylistDescription = "Uygulama açıldığında bu playlist otomatik seçilir.".localized
        public static let playlistICloudSync = "Bu Playlist için iCloud Eşitlemesi".localized
        public static let playlistICloudSyncDescription = "Kapalıyken bağlantı bilgileri bu cihazın yerel Keychain’inde kalır; ortak iCloud Keychain kopyası ve playlist’in eşitlenmiş favori/izleme kayıtları kaldırılır. Diğer cihazlar da bu playlist’i eşitlemez. Playlist kimliği olmayan eski kayıtlar ile gizli öğeler ve görünüm tercihleri genel ayarı izler.".localized
        public static let automaticCatalogRefresh = "Açılışta Otomatik Katalog Yenileme".localized
        public static let automaticCatalogRefreshDescription = "Kapalıysa Ana Sayfa bu playlist’in kataloglarını ve öne çıkan içeriklerini uygulama açılışında otomatik indirmez. Ana Sayfa’daki Yenile düğmesiyle elle güncelleyebilirsiniz.".localized
        public static let refreshScheduleTitle = "Otomatik Yenileme Sıklığı".localized
        public static let refreshScheduleDescription = "Seçimler etkin profil ve bu playlist için geçerlidir. Kapalı seçeneği yalnız otomatik yenilemeyi durdurur.".localized
        public static let liveTVRefreshFrequency = "Canlı TV".localized
        public static let moviesRefreshFrequency = "Filmler".localized
        public static let seriesRefreshFrequency = "Diziler".localized
        public static let refreshEveryOneHour = "Her saat".localized
        public static let refreshEveryFourHours = "4 saatte bir".localized
        public static let refreshEveryTwelveHours = "12 saatte bir".localized
        public static let refreshEveryDay = "Günde bir".localized
        public static let refreshEveryThreeDays = "3 günde bir".localized
        public static let refreshEveryWeek = "Haftada bir".localized
        public static let channelZappingDelay = "Kanal Geçiş Gecikmesi".localized
        public static let channelZappingDelayDescription = "Önceki yayın kapandıktan sonra sonraki kanal açılmadan önce beklenecek süre. 0 ms anında geçiş yapar.".localized
        public static let embyPlaybackPreference = "Emby Oynatma Tercihi".localized
        public static let embyPlaybackAutomatic = "Otomatik (sunucu seçsin)".localized
        public static let embyPlaybackDirectStreamOnly = "Direct Stream; dönüştürme kapalı".localized
        public static let embyPlaybackDirectStreamOnlyDescription = "Emby sunucusundan encoding/transcoding yapmamasını ister. Sunucu ve oynatıcı uyumlu doğrudan akış bulamazsa içerik oynatılamayabilir.".localized
        public static let healthCheck = "Playlist Sağlığını Denetle".localized
        public static let healthReportTitle = "Playlist sağlık sonuçları".localized
        public static let healthCheckDescription = "Denetim yalnızca sınırlı bir playlist örneği okur. URL, hesap bilgisi ve ham hata metni paylaşım raporuna eklenmez.".localized
        public static let healthCheckProgress = "Playlist denetleniyor…".localized
        public static let healthConnection = "Bağlantı".localized
        public static let healthAuthentication = "Kimlik doğrulama".localized
        public static let healthFormat = "Biçim".localized
        public static let healthParsing = "Ayrıştırma".localized
        public static let healthEPG = "EPG".localized
        public static let healthPassed = "Başarılı".localized
        public static let healthFailed = "Sorun bulundu".localized
        public static let healthNotChecked = "Denetlenmedi".localized
        public static let healthNotConfigured = "Yapılandırılmadı".localized
        public static let healthNotApplicable = "Uygulanamaz".localized
        public static let healthConnectionFailed = "Playlist sunucusuna bağlanılamadı.".localized
        public static let healthEPGConnectionFailed = "EPG kaynağına bağlanılamadı.".localized
        public static let healthServerUnavailable = "Sunucu şu anda kullanılamıyor.".localized
        public static let healthPlaylistFormatMismatch = "Playlist biçimi tanınmadı.".localized
        public static let healthEPGFormatMismatch = "EPG yanıt biçimi tanınmadı.".localized
        public static let healthNoPlayableEntries = "Örnekte oynatılabilir kayıt bulunamadı.".localized
        public static let healthConfiguredFormatUnsupported = "Seçilen akış biçimi sağlayıcı tarafından desteklenmiyor.".localized
        public static let healthSampleIncomplete = "Örnek sınırına ulaşıldığı için sonuç doğrulanamadı.".localized
        public static let healthProviderDidNotReportFormats = "Sağlayıcı desteklenen biçimleri bildirmedi.".localized
        public static let healthRequiresSampleStream = "EPG denetimi için örnek yayın kimliği gerekiyor.".localized

        public static func healthIssueDescription(_ issue: PlaylistHealthIssue) -> String {
            switch issue {
            case .invalidConfiguration:
                AppStrings.Errors.invalidURL
            case .connectionFailed:
                healthConnectionFailed
            case .epgConnectionFailed:
                healthEPGConnectionFailed
            case .credentialsRejected:
                AppStrings.Errors.unauthorized
            case .rateLimited:
                AppStrings.Errors.rateLimited
            case .serverUnavailable:
                healthServerUnavailable
            case .invalidResponse:
                AppStrings.Errors.invalidResponse
            case .formatMismatch:
                healthPlaylistFormatMismatch
            case .epgFormatMismatch:
                healthEPGFormatMismatch
            case .noPlayableEntries:
                healthNoPlayableEntries
            case .configuredFormatUnsupported:
                healthConfiguredFormatUnsupported
            case .sampleIncomplete:
                healthSampleIncomplete
            case .providerDidNotReportFormats:
                healthProviderDidNotReportFormats
            case .requiresSampleStream:
                healthRequiresSampleStream
            case .noEPGSource:
                healthNotConfigured
            }
        }

        public static func channelZappingDelayValue(_ milliseconds: Int) -> String {
            "%lld ms".localized(Int64(milliseconds))
        }
    }

    // MARK: - Player Media Info

    public enum MediaInfo {
        public static let resolution = "Çözünürlük".localized
        public static let videoCodec = "Video Codec".localized
        public static let audioCodec = "Ses Codec".localized
        public static let bitrate = "Bit Hızı".localized
        public static let unknown = "Bilinmiyor".localized
    }

    // MARK: - EPG

    public enum EPG {
        public static let guide = "Yayın Akışı".localized
        public static let watch = "İzle".localized
        public static let error = "Hata: ".localized
        public static let noData = "Bu kanal için EPG verisi bulunamadı.".localized
        public static let loadingEPG = "Yayın akışı yükleniyor...".localized
        public static let mutePreview = "Önizleme sesini kapat".localized
        public static let unmutePreview = "Önizleme sesini aç".localized
    }

    // MARK: - Splash

    public enum Splash {
        public static let appName = "PureIPTV".localized
        public static let tagline = "Pure. Premium. IPTV.".localized
    }

    // MARK: - Widget

    public enum Widget {
        public static let startWatching = "İzlemeye Başla".localized
        public static let description = "Kaldığınız yerden devam edin veya favorilerinize hızlıca ulaşın.".localized
    }

    // MARK: - Media Filter

    public enum MediaFilter {
        public static let all = "Tümü".localized
        public static let turkishDubbed = "Türkçe Dublaj".localized
        public static let turkishSubtitled = "Türkçe Altyazılı".localized
        public static let dualAudio = "Çift Ses (Multi)".localized
        public static let originalAudio = "Orijinal / EN".localized
        public static let filterTitle = "Ses & Dil Filtresi".localized
        public static let noMatchingResults = "Seçilen dil filtresine uygun içerik bulunamadı.".localized
    }
}
