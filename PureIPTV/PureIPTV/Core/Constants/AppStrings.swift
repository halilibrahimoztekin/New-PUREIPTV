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
    }

    // MARK: - Player & EPG

    public enum Player {
        public static let liveLabel = "CANLI".localized
        public static let liveLabelNormal = "Canlı".localized
        public static let liveBroadcast = "Canlı Yayın".localized
        public static let off = "Kapalı".localized
        public static let scrubInstruction = "Seçmek için Tıklayın veya Bırakın".localized
        public static let scrubSwipe = "Kaydırarak Akıcı İleri / Geri Sarma".localized
        public static let epg = "Yayın Akışı".localized
        public static let timeline = "Zaman Çizelgesi".localized
        public static let epgNotFound = "EPG bilgisi bulunamadı.".localized
        public static let nowPlaying = "Şu an".localized
        public static let mediaInfo = "Media Info".localized
        public static let audioTracks = "Ses İzleri".localized
        public static let subtitles = "Altyazılar".localized
        public static let noOptions = "Seçenek bulunmuyor.".localized
        public static let noRecord = "Kayıt yok".localized
        public static let restart = "Baştan Başlat".localized
        public static let previousChannel = "Önceki Kanal".localized
        public static let nextChannel = "Sonraki Kanal".localized
        public static func sleepTimerMinutes(_ minutes: Int) -> String {
            "Uyku Zamanlayıcısı: %lld dk".localized(Int64(minutes))
        }

        public static let sleepTimerDisabled = "Uyku Zamanlayıcısı Kapatıldı".localized
        public static func reconnecting(_ retryCount: Int) -> String {
            "Bağlantı koptu, yeniden bağlanılıyor... (%lld/3)".localized(Int64(retryCount))
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
        public static let themeColor = "Ana Renk".localized
        public static let appIcon = "Uygulama İkonu".localized
        public static let about = "HAKKINDA".localized
        public static let appVersion = "PureIPTV v1.0.0".localized
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
        public static let startMuted = "Kanalları Sessiz Başlat".localized
        public static let hardwareAcceleration = "Donanım Hızlandırma".localized
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
        public static let clearing = "Temizleniyor...".localized
        public static let calculating = "Hesaplanıyor...".localized
        public static let defaultSort = "Varsayılan".localized
        public static let alphabeticalSort = "A-Z (Alfabetik)".localized
        public static let ratingSort = "IMDb Puanı".localized
        public static let dateAddedSort = "Eklenme Tarihi".localized
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
        public static let clear = "Temizle".localized
        public static let loadingMessage = "Arama altyapısı hazırlanıyor...\n(Bu işlem ilk girişte birkaç saniye sürebilir)".localized
        public static let all = "Tümü".localized
    }

    // MARK: - MultiView

    public enum MultiView {
        public static let title = "Multi-view".localized
        public static let addChannel = "Kanal Ekle".localized
        public static let selectChannel = "Kanal Seç".localized
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
        public static let continueWatching = "Kaldığın Yerden İzle".localized
        public static let myFavorites = "Favorilerim".localized
        public static let featuredLiveTV = "Canlı TV (Önerilen)".localized
        public static let newMovies = "Yeni Eklenen Filmler".localized
        public static let newSeries = "Yeni Eklenen Diziler".localized
        public static let hdBadge = "HD".localized
        public static let movieBadge = "Film".localized
        public static let details = "Detaylar".localized
    }

    // MARK: - Downloads

    public enum Downloads {
        public static let title = "İndirilenler".localized
        public static let empty = "Henüz indirilmiş içerik yok".localized
        public static let emptyDescription = "Filmleri veya dizileri indirerek internet bağlantınız olmadan da izleyebilirsiniz.".localized
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
    }

    // MARK: - Series Detail

    public enum SeriesDetail {
        public static let watch = "İzle".localized
        public static let continueWatching = "Devam Et".localized
        public static let restart = "Baştan Başlat".localized
        public static let seasons = "Sezonlar".localized
        public static let episodes = "Bölümler".localized
        public static let loading = "Dizi bilgileri yükleniyor…".localized
        public static let episodeCount = "bölüm".localized
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
    }

    // MARK: - Playlist Management

    public enum PlaylistMgmt {
        public static let savedAccounts = "Kayıtlı Hesaplar".localized
        public static let switchNote = "Hesaplar arasında geçiş yaptığınızda uygulama yeni hesaba ait verileri yükleyecektir.".localized
        public static let accountManagement = "Hesap Yönetimi".localized
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
}
