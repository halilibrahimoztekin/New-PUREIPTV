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
        public static let close = "Kapat".localized
        public static let add = "Ekle".localized
        public static let create = "Oluştur".localized
        public static let watchNow = "Hemen İzle".localized
        public static let comingSoon = "Yakında geliyor…".localized
        public static let settingsComingSoon = "Ayarlar yakında geliyor…".localized
        public static let appName = "PureIPTV".localized
        public static let error = "Hata: %@".localized
        public static let addToFavorites = "Favorilere Ekle".localized
        public static let removeFromFavorites = "Favorilerden Çıkar".localized
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
        public static let play = "Oynat".localized
        public static let search = "Ara".localized
        public static let channels = "Kanallar".localized
        public static let handoffPlaybackUnavailableTitle = "Oynatmaya Devam Edilemiyor".localized
        public static let handoffPlaybackUnavailableMessage = "Bu içerik bu Apple TV'de kullanılamıyor.".localized
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
        public static let emptyCategoryLive = "Bu kategoride kanal bulunamadı".localized
        public static let loadingChannels = "Kanallar yükleniyor…".localized
        public static let noChannels = "Kanal bulunamadı.".localized
        public static let hideChannel = "Kanalı Gizle".localized
        public static let sendToMultiView = "Çoklu Ekran'a Gönder".localized
        public static let channelGuide = "Yayın Akışı (EPG)".localized
        public static let recentChannels = "Son İzlenen Kanallar".localized
        public static let quickZapHint = "Siri Remote ile gezin ve kanala anında geçiş yapın".localized
        public static let noRecentChannels = "Henüz izlenmiş kanal bulunmuyor".localized
        public static let pinRecentChannel = "Geçmişin başına sabitle".localized
        public static let unpinRecentChannel = "Sabitlemeyi kaldır".localized
        public static let editChannelLogo = "Kanal logosunu düzenle".localized
        public static let channelLogoURL = "Logo URL’si".localized
        public static let channelLogoURLHint = "HTTP veya HTTPS adresi girin.".localized
        public static let invalidChannelLogoURL = "Geçerli bir HTTP veya HTTPS logo adresi girin.".localized
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
        public static let jumpToChannel = "Kanala Git".localized
        public static let sortTitle = "Sıralama".localized
        public static let sortDefault = "Varsayılan Sıra".localized
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
    }

    // MARK: - Player & EPG

    public enum Player {
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
        public static let videoCodec = "Video Kod Çözücü".localized
        public static let audioCodec = "Ses Kod Çözücü".localized
        public static let resolution = "Çözünürlük".localized
        public static let bitrate = "Bit Hızı (Bitrate)".localized
        public static let networkThroughput = "Ölçülen Ağ Veri Hızı".localized
        public static let streamBitrate = "Yayın Bit Hızı".localized
        public static let renderedFPS = "Ölçülen Gösterilen Kare Hızı".localized
        public static let sampleUnavailable = "Örnek bekleniyor".localized
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
        public static let openInExternalPlayer = "Harici Oynatıcı".localized
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
        public static let unauthorized = "Kullanıcı adı veya şifre hatalı.".localized
        public static let pinMismatch = "PIN kodları eşleşmiyor. Tekrar deneyin.".localized
        public static let incorrectPIN = "Hatalı PIN".localized
        public static let cannotPlayStream = "Yayın oynatılamıyor.".localized

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
        public static let appearance = "GÖRÜNÜM".localized
        public static let visualThemePreset = "Görsel Tema".localized
        public static let visualThemePresetDescription = "Vurgu rengini tvOS atmosferik arka plan tonuyla eşleştirir.".localized
        public static let themePresetClassic = "Klasik".localized
        public static let themePresetOcean = "Okyanus".localized
        public static let themePresetAurora = "Aurora".localized
        public static let themePresetForest = "Orman".localized
        public static let themePresetEmber = "Kor".localized
        public static let themeColor = "Ana Renk".localized
        public static let twoLineTVChannelTitles = "Kanal Adlarını İki Satırda Göster".localized
        public static let appIcon = "Uygulama İkonu".localized
        public static let about = "HAKKINDA".localized
        public static let appVersion = "PureIPTV v1.0.0".localized
        public static let createDiagnosticReport = "Gizlilik Korumalı Tanılama Raporu Oluştur".localized
        public static let diagnosticReportGenerating = "Tanılama raporu hazırlanıyor...".localized
        public static let diagnosticReportTitle = "Tanılama Raporu".localized
        public static let diagnosticReportHint = "Yalnızca sürüm ve işletim sistemi bilgileri gösterilir; hiçbir yere otomatik gönderilmez.".localized
        public static let diagnosticReportUnavailable = "Rapor önizlemesi açılamadı.".localized
        public static let shareDiagnosticReport = "Raporu Dışa Aktar veya Paylaş".localized
        public static let version = "Sürüm".localized
        public static let versionNumber = "1.0.0".localized
        public static let setNewPIN = "Yeni PIN Belirleyin".localized
        public static let verifyPIN = "PIN'i Doğrulayın".localized
        public static let switchProfile = "Profil Değiştir".localized
        public static let hideAdultContent = "Yetişkin İçerikleri Tamamen Gizle".localized
        public static let startupScreen = "Başlangıç Ekranı".localized
        public static let discover = "Keşfet".localized
        public static let contentSorting = "İçerik Sıralaması".localized
        public static let vodSorting = "Filmler (VOD)".localized
        public static let playerSettings = "Oynatıcı (Player) Ayarları".localized
        public static let autoPlayNextEpisode = "Sonraki Bölüme Otomatik Geç".localized
        public static let autoSelectFirstAlternativeSource = "İlk Alternatif Kaynağı Otomatik Oynat".localized
        public static let autoSelectFirstAlternativeSourceDescription = "Alternatif kaynaklar seçildiğinde listeyi açmadan playlist sırasındaki ilk eşleşmeyi oynatır.".localized
        public static let startMuted = "Kanalları Sessiz Başlat".localized
        public static let hardwareAcceleration = "Donanım Hızlandırma".localized
        public static let downloadConcurrencyLimit = "Eşzamanlı İndirme Sayısı".localized
        public static let downloadConcurrencyLimitDesc = "Aynı anda indirilecek içerik sayısını sınırlar.".localized
        public static let oledDimming = "OLED Ekran Koruma / Karartma".localized
        public static let oledDimmingDesc = "Ekran yanmasını önlemek için kontroller açıkken veya duraklatıldığında ekranı kademeli olarak karartır.".localized
        public static let cleanChannelNames = "Kanal İsimlerini Sadeleştir".localized
        public static let cleanChannelNamesDesc = "Kanal adlarındaki gereksiz [TR], FHD, 1080p, 4K, |HEVC| ve VIP etiketlerini temizler.".localized
        public static let epgSettings = "Yayın Akışı (EPG) Ayarları".localized
        public static let timeShift = "Zaman Kaydırma (Time Shift)".localized
        public static func timeShiftHours(_ hours: Int) -> String {
            hours > 0 ? "+%lld Saat".localized(Int64(hours)) : "%lld Saat".localized(Int64(hours))
        }

        public static let autoUpdateEPG = "Akışı Otomatik Güncelle".localized
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
        public static let alphabeticalSort = "A-Z (Alfabetik)".localized
        public static let ratingSort = "IMDb Puanı".localized
        public static let dateAddedSort = "Eklenme Tarihi".localized
        public static let audioAndSubtitleSettings = "Ses ve Altyazı Ayarları".localized
        public static let defaultAudioLanguage = "Varsayılan Ses Dili".localized
        public static let defaultSubtitleLanguage = "Varsayılan Altyazı Dili".localized
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
        public static let searchPlaceholder = "Kanal, film veya dizi ara...".localized
        public static let channelSearchPlaceholder = "Kanal ara...".localized
        public static let liveTV = "Canlı TV".localized
        public static let movies = "Filmler".localized
        public static let series = "Diziler".localized
        public static let recentSearches = "Son Aramalar".localized
        public static let quickTags = "Popüler Kategoriler & Etiketler".localized
        public static let discoverSuggestions = "Öne Çıkan Aramalar".localized
        public static let clear = "Temizle".localized
        public static let loadingMessage = "Arama altyapısı hazırlanıyor...\n(Bu işlem ilk girişte birkaç saniye sürebilir)".localized
        public static let all = "Tümü".localized
        public static let filter4K = "4K / UHD 🌟".localized
        public static let filterEPG = "EPG Programları 🕒".localized
        public static let people = "Kişiler".localized
        public static let programs = "Programlar".localized
        public static let allPlaylists = "Tüm Çalma Listeleri (Global 🌐)".localized
        public static let allPlaylistsShort = "Tümü (Global)".localized
        public static let liveProgramMatch = "Canlı Program:".localized
        public static let playlistSource = "Liste:".localized
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
    }

    // MARK: - Parental Lock

    public enum ParentalLock {
        public static let title = "Ebeveyn Kontrolü".localized
        public static let description = "Bu içeriğe erişmek için PIN girin veya FaceID/TouchID kullanın.".localized
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
        public static let featuredLiveTV = "Canlı TV (Önerilen)".localized
        public static let epgPrograms = "Rehberdeki Programlar".localized
        public static let nowAiring = "ŞU AN".localized
        public static let newMovies = "Yeni Eklenen Filmler".localized
        public static let newSeries = "Yeni Eklenen Diziler".localized
        public static let recommendedForYou = "Sana Özel Öneriler".localized
        public static let actorRecommendationTitle = "Ortak oyuncu: %@ • İzlediğin: %@ • %@".localized
        public static let mostWatchedActors = "En Çok İzlediğin Oyuncular".localized
        public static let popularActors = "Popüler Oyuncular".localized
        public static let actorFilmographyUnavailable = "Bu oyuncunun kataloğunda eşleşen içerik bulunamadı.".localized
        public static let newEpisodesForYou = "Yeni Bölümler".localized
        public static let newEpisodeCardSummary = "S%1$02dE%2$02d · %3$d yeni bölüm".localized
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

    // MARK: - Downloads

    public enum Downloads {
        public static let title = "İndirilenler".localized
        public static let empty = "Henüz indirilmiş içerik yok".localized
        public static let emptyDescription = "Filmleri veya dizileri indirerek internet bağlantınız olmadan da izleyebilirsiniz.".localized
        public static let activeDownloads = "Aktif İndirmeler".localized
        public static let queued = "Kuyrukta".localized
        public static let completedDownloads = "İndirilen İçerikler".localized
        public static let totalStorage = "Kullanılan Alan".localized
        public static let clearCompleted = "Tamamlananları Sil".localized
        public static let clearCompletedTitle = "Tamamlanan İndirmeleri Sil".localized
        public static let clearCompletedMessage = "Tamamlanmış tüm indirmeler bu cihazdan silinir. Devam eden ve sıradaki indirmeler korunur.".localized
        public static let clearCompletedFailure = "Bazı tamamlanmış indirmeler silinemedi. Depolama alanını kontrol edip yeniden deneyin.".localized
        public static let downloadSpeed = "Hız".localized
        public static let tvOSNotice = "Çevrimdışı indirme özelliği Apple TV kısıtlamaları nedeniyle yalnızca iOS ve iPadOS cihazlarında desteklenmektedir.".localized
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
        public static let startMovieNow = "Filmi Şimdi Başlat".localized
        public static let trailerNotAvailable = "Bu film için fragman bulunamadı.".localized
        public static let inLibrary = "Kütüphanenizde".localized
        public static let notInLibrary = "Listenizde Bulunamadı".localized
        public static let notInLibraryDesc = "Bu içerik mevcut IPTV çalma listenizde bulunamadı. TMDB özet bilgisi aşağıdadır.".localized
        public static let unmuteTrailer = "Sesi Aç".localized
        public static let muteTrailer = "Sesi Kapat".localized
        public static let expandTrailer = "Tam Ekran Fragman".localized
        public static let autoPlayTrailer = "Fragmanı Otomatik Oynat".localized
        public static let versionsAndQuality = "Sürüm & Kalite Seçenekleri".localized
        public static let currentVersion = "Mevcut Sürüm".localized
    }

    // MARK: - Series Detail

    public enum SeriesDetail {
        public static let watch = "İzle".localized
        public static let continueWatching = "Devam Et".localized
        public static let currentEpisode = "Mevcut Bölüm".localized
        public static let restart = "Baştan Başlat".localized
        public static let seasons = "Sezonlar".localized
        public static let episodes = "Bölümler".localized
        public static let loading = "Dizi bilgileri yükleniyor…".localized
        public static let episodeCount = "bölüm".localized
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
        public static let playbackSettings = "Oynatma Ayarları".localized
        public static let channelZappingDelay = "Kanal Geçiş Gecikmesi".localized
        public static let channelZappingDelayDescription = "Önceki yayın kapandıktan sonra sonraki kanal açılmadan önce beklenecek süre. 0 ms anında geçiş yapar.".localized
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
