import SwiftUI

/// Uygulama genelinde kullanılan tüm metinlerin (strings) merkezi yönetimi.
/// LocalizedStringKey kullanılarak SwiftUI'ın native dil desteğiyle uyumlu çalışması sağlanır.
public enum AppStrings {
    // MARK: - Common

    public enum Common {
        public static let cancel = LocalizedStringKey("İptal")
        public static let save = LocalizedStringKey("Kaydet")
        public static let delete = LocalizedStringKey("Sil")
        public static let ok = LocalizedStringKey("Tamam")
        public static let back = LocalizedStringKey("Geri")
        public static let loading = LocalizedStringKey("Yükleniyor...")
        public static let loadingAlt = LocalizedStringKey("Yükleniyor…")
        public static let done = LocalizedStringKey("Bitti")
        public static let close = LocalizedStringKey("Kapat")
        public static let add = LocalizedStringKey("Ekle")
        public static let create = LocalizedStringKey("Oluştur")
        public static let watchNow = LocalizedStringKey("Hemen İzle")
        public static let comingSoon = LocalizedStringKey("Yakında geliyor…")
        public static let settingsComingSoon = LocalizedStringKey("Ayarlar yakında geliyor…")
        public static let appName = LocalizedStringKey("PureIPTV")
        public static let error = LocalizedStringKey("Hata: %@")
        public static let addToFavorites = LocalizedStringKey("Favorilere Ekle")
        public static let removeFromFavorites = LocalizedStringKey("Favorilerden Çıkar")
        public static let categoryNotFound = LocalizedStringKey("Kategori bulunamadı")
    }

    // MARK: - VOD (Movies)

    public enum VOD {
        public static let title = LocalizedStringKey("Filmler")
        public static let loadingMovies = LocalizedStringKey("Filmler yükleniyor…")
        public static let emptyCategoryMovies = LocalizedStringKey("Bu kategoride film bulunamadı")
        public static let noMovies = LocalizedStringKey("Film bulunamadı")
    }

    // MARK: - Series

    public enum Series {
        public static let title = LocalizedStringKey("Diziler")
        public static let loadingSeries = LocalizedStringKey("Diziler yükleniyor…")
        public static let emptyCategorySeries = LocalizedStringKey("Bu kategoride dizi bulunamadı")
        public static let noSeries = LocalizedStringKey("Dizi bulunamadı")
    }

    // MARK: - Live TV

    public enum LiveTV {
        public static let title = LocalizedStringKey("Canlı TV")
        public static let channelsTitle = LocalizedStringKey("Kanallar")
        public static let categories = LocalizedStringKey("Kategoriler")
        public static let emptyCategoryLive = LocalizedStringKey("Bu kategoride kanal bulunamadı")
        public static let loadingChannels = LocalizedStringKey("Kanallar yükleniyor…")
        public static let noChannels = LocalizedStringKey("Kanal bulunamadı.")
    }

    // MARK: - Player & EPG

    public enum Player {
        public static let liveLabel = LocalizedStringKey("CANLI")
        public static let liveLabelNormal = LocalizedStringKey("Canlı")
        public static let liveBroadcast = LocalizedStringKey("Canlı Yayın")
        public static let off = LocalizedStringKey("Kapalı")
        public static let scrubInstruction = LocalizedStringKey("Seçmek için Tıklayın veya Bırakın")
        public static let scrubSwipe = LocalizedStringKey("Kaydırarak Akıcı İleri / Geri Sarma")
        public static let epg = LocalizedStringKey("Yayın Akışı")
        public static let timeline = LocalizedStringKey("Zaman Çizelgesi")
        public static let epgNotFound = LocalizedStringKey("EPG bilgisi bulunamadı.")
        public static let nowPlaying = LocalizedStringKey("Şu an")
        public static let mediaInfo = LocalizedStringKey("Media Info")
        public static let audioTracks = LocalizedStringKey("Ses İzleri")
        public static let subtitles = LocalizedStringKey("Altyazılar")
        public static let noOptions = LocalizedStringKey("Seçenek bulunmuyor.")
        public static let noRecord = LocalizedStringKey("Kayıt yok")
    }

    // MARK: - Errors

    public enum Errors {
        public static let invalidURL = String(localized: "Geçersiz URL adresi.")
        public static let invalidResponse = String(localized: "Sunucudan geçersiz yanıt alındı.")
        public static let unauthorized = String(localized: "Kullanıcı adı veya şifre hatalı.")
        public static let pinMismatch = String(localized: "PIN kodları eşleşmiyor. Tekrar deneyin.")
        public static let incorrectPIN = String(localized: "Hatalı PIN")
        public static let cannotPlayStream = String(localized: "Yayın oynatılamıyor.")

        public static func serverError(code: Int) -> String {
            String(localized: "Sunucu hatası (Kod: \(code)).")
        }

        public static func decodingFailed(desc: String) -> String {
            String(localized: "Veri işlenemedi: \(desc)")
        }

        public static func underlying(desc: String) -> String {
            String(localized: "Bir hata oluştu: \(desc)")
        }

        public static func searchFailed(desc: String) -> String {
            String(localized: "Arama verileri yüklenemedi: \(desc)")
        }
    }

    // MARK: - Onboarding

    public enum Onboarding {
        public static let skip = LocalizedStringKey("Atla")
        public static let howToUse = LocalizedStringKey("Nasıl Kullanılır?")
        public static let description = LocalizedStringKey("Ana ekrandan '+' butonuna basarak Xtream Codes veya M3U bağlantılarınızı kolayca ekleyebilir ve izlemeye başlayabilirsiniz.")
        public static let startNow = LocalizedStringKey("Hemen Başla")
        public static let next = LocalizedStringKey("İleri")
        public static let page1Title = LocalizedStringKey("PureIPTV'ye Hoşgeldiniz")
        public static let page1Desc = LocalizedStringKey("Apple ekosistemi için özenle tasarlanmış, akıcı ve reklamsız premium IPTV deneyimi.")
        public static let page2Title = LocalizedStringKey("Hızlı Arama & Geçmiş")
        public static let page2Desc = LocalizedStringKey("Gelişmiş arama altyapısı sayesinde binlerce kanal ve film arasında saniyeler içinde geçiş yapın.")
        public static let page3Title = LocalizedStringKey("Zengin Oynatıcı & PiP")
        public static let page3Desc = LocalizedStringKey("Picture in Picture desteği ve ses/altyazı kontrolüyle seyir zevkinizi üst seviyeye taşıyın.")
    }

    // MARK: - Profile Selection

    public enum Profile {
        public static let whoIsWatching = LocalizedStringKey("Kim İzliyor?")
        public static let addProfile = LocalizedStringKey("Profil Ekle")
        public static let editProfiles = LocalizedStringKey("Profilleri Düzenle")
        public static let manageProfiles = LocalizedStringKey("Profilleri Yönet")
        public static let deleteInstruction = LocalizedStringKey("Silmek istediğiniz profilin üzerindeki çöp kutusunu seçin.")
        public static let personalizeDesc = LocalizedStringKey("İçeriklerinizi ve izleme geçmişinizi kişiselleştirin.")
        public static let newProfile = LocalizedStringKey("Yeni Profil")
        public static let createProfile = LocalizedStringKey("Yeni Profil Oluştur")
        public static let profileName = LocalizedStringKey("Profil Adı")
        public static let enterProfileName = LocalizedStringKey("Profil Adı Girin")
        public static let profileInfo = LocalizedStringKey("Profil Bilgileri")
        public static let kidsBadge = LocalizedStringKey("ÇOCUK")
        public static let kidsProfileInfo = LocalizedStringKey("Çocuk Profili (Sadece Çocuk İçerikleri)")
        public static let kidsProfileDesc = LocalizedStringKey("Çocuk Profili (Sadece çocuk içerikleri)")
    }

    // MARK: - Add Playlist

    public enum AddPlaylist {
        public static let title = LocalizedStringKey("Playlist Ekle")
        public static let connectWith = LocalizedStringKey("Xtream Codes veya\nM3U URL ile bağlanın.")
        public static let connectWithIOS = LocalizedStringKey("Xtream Codes bilgilerinizi veya M3U adresinizi girin")
        public static let connect = LocalizedStringKey("Bağlan")
        public static let m3uComingSoon = LocalizedStringKey("M3U desteği çok yakında geliyor! Şimdilik Xtream Codes kullanın.")
        public static let serverPlaceholder = LocalizedStringKey("Sunucu URL (https://provider.net:8080)")
        public static let usernamePlaceholder = LocalizedStringKey("Kullanıcı Adı")
        public static let passwordPlaceholder = LocalizedStringKey("Şifre")
        public static let m3uPlaceholder = LocalizedStringKey("M3U URL (http://...)")
    }

    // MARK: - Settings

    public enum Settings {
        public static let title = LocalizedStringKey("Ayarlar")
        public static let accounts = LocalizedStringKey("HESAPLAR")
        public static let manageAccounts = LocalizedStringKey("Hesap Yönetimi (Playlists)")
        public static let security = LocalizedStringKey("GÜVENLİK")
        public static let appearance = LocalizedStringKey("GÖRÜNÜM")
        public static let themeColor = LocalizedStringKey("Ana Renk")
        public static let appIcon = LocalizedStringKey("Uygulama İkonu")
        public static let about = LocalizedStringKey("HAKKINDA")
        public static let appVersion = LocalizedStringKey("PureIPTV v1.0.0")
        public static let version = LocalizedStringKey("Sürüm")
        public static let versionNumber = LocalizedStringKey("1.0.0")
        public static let setNewPIN = LocalizedStringKey("Yeni PIN Belirleyin")
        public static let verifyPIN = LocalizedStringKey("PIN'i Doğrulayın")
    }

    // MARK: - Search

    public enum Search {
        public static let startSearch = LocalizedStringKey("Aramaya Başlayın")
        public static let noResults = LocalizedStringKey("Sonuç Bulunamadı")
        public static let searchPlaceholder = LocalizedStringKey("Kanal, film veya dizi ara...")
        public static let channelSearchPlaceholder = LocalizedStringKey("Kanal ara...")
        public static let liveTV = LocalizedStringKey("Canlı TV")
        public static let movies = LocalizedStringKey("Filmler")
        public static let series = LocalizedStringKey("Diziler")
        public static let recentSearches = LocalizedStringKey("Son Aramalar")
        public static let clear = LocalizedStringKey("Temizle")
        public static let loadingMessage = LocalizedStringKey("Arama altyapısı hazırlanıyor...\n(Bu işlem ilk girişte birkaç saniye sürebilir)")
    }

    // MARK: - MultiView

    public enum MultiView {
        public static let title = LocalizedStringKey("Multi-view")
        public static let addChannel = LocalizedStringKey("Kanal Ekle")
        public static let selectChannel = LocalizedStringKey("Kanal Seç")
    }

    // MARK: - Parental Lock

    public enum ParentalLock {
        public static let title = LocalizedStringKey("Ebeveyn Kontrolü")
        public static let description = LocalizedStringKey("Bu içeriğe erişmek için PIN girin veya FaceID/TouchID kullanın.")
        public static let pin = LocalizedStringKey("PIN")
    }
}
