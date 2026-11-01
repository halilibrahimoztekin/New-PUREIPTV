# tvOS odak ve ekran yaşam döngüsü denetimi

27 Ekim 2026 · Çalışma devam ediyor.

Bu rapor `swift-focusengine-pro` ve `swift-accessibility-skill` ile kaynak kodundan yapılan ilk sistematik taramayı kaydeder. Kullanıcının talimatıyla test, simulator, uygulama akışı veya fiziksel Apple TV kontrolü çalıştırılmadı. Kaynak incelemesi bütün kumanda yollarının cihazda erişilebilir olduğunu kanıtlamaz. ContactCleaner kapsam dışıdır; Localizable.xcstrings incelenmedi.

## Kapsam

| Alan | İnceleme |
|---|---|
| Home, AppCoordinator, LiveTV, EPGGuide, EPGTimeline | Sunum sahipliği, reducer yaşam döngüsü, istek kimlikleri, focus/scroll ve kanal araç çubukları ayrıntılı incelendi. |
| Settings, ProfileSelection, PlaylistManagement, AddPlaylist, CategoryManagement, Onboarding, Paywall, Trakt, Splash | 31 Swift dosyası envanterlendi; focus, loading, modal, disabled ve gesture kalıpları tarandı. İlgili tvOS görünümleri ayrıntılı okundu. |
| VOD, Series, VODDetail, SeriesDetail, Dashboard, Search, Downloads, Shared | İlgili tvOS görünümleri ve reducer’lar; ortak dil filtreleri, sürüm seçici, kartlar ve focus hafızası incelendi. |
| Player, MultiView, Core/UI, TVFocusGuide | 52 Swift dosyası envanterlendi; focus API’si bulunan 14 dosya ayrıca ayrıntılı incelendi. |
| Ortak UI | TVFocusGuide, TVFocusMemory, TVMediaCards, TVParallaxCardContainer, TVButtonStyles, TVAlphabetScrubberOverlay, ResumeWatchingCardView ve filtre çubukları incelendi. Kalan ortak bileşenlerin tek tek ayrıntılı incelemesi sürüyor. |

## Doğrudan davranış hataları

### EPGGuideFeature.swift — kanal yanıtının sahipliği (#211)

`selectChannel` önceki EPG isteğini iptal etmiyor ve yanıt kanal/istek kimliği taşımıyordu. A kanalının geç yanıtı B kanalının başlığında gösterilebiliyordu. Görünümün tekrar `onAppear` alması aynı veriyi silip yükleme durumuna döndürüyordu. Kural: asenkron yanıtı güncel ekran/istek kimliğiyle doğrula; görünümden çıkınca bekleyen işi iptal et.

Önce: `epgResponse(Result<...>)` → Sonra: `epgResponse(channelID:requestID:Result<...>)`, `cancelInFlight`, iki kimlik için guard ve açık görünüm yaşam döngüsü. Aynı kanala ait başarılı veri dönüşte korunuyor. Hata/boş durumlarına kumandayla erişilebilir Retry düğmesi eklendi. Reviewer onayladı; iOS/tvOS Release compile-only build’leri başarılı. Cihaz doğrulaması yapılmadı.

31 Ekim 2026 follow-up: Guide `onAppear` ayrıca EPG source identity çözümlemesi başlatıyordu. Eski UUID yanıtı state’i değiştiremese de görünüm kapandıktan sonra çalışma sürebiliyordu. Bu etki artık ayrı cancellation ID kullanıyor, `Task.isCancelled` kontrol ediyor ve `onDisappear` sırasında iptal ediliyor. Close, normal oynatma ve catch-up başlatma eylemleri görünürlük/istek kimliğini hemen geçersiz kılıp kaynak çözümlemesini iptal ediyor. Preview promotion handoff’u cancellation ID ile izleniyor; delegate gönderilmeden iptal alınırsa henüz Player ekranınca tüketilmemiş promotion aynı VLC player/URL çifti doğrulanarak geri alınıyor. Delegate gönderildikten sonraki Guide kaybolması beklenen route geçişi sayılıyor ve promotion korunuyor. Play delegate’i `presentationID` taşıyor ve coordinator güncel Guide örneğini eşleştiriyor. Handoff sürerken iOS interaktif dismissal ve iki platformda Guide etkileşimleri devre dışı. Bağımsız review `[APPROVED]`; targeted parse/diff kontrolü başarılı. Xcode build bu pre-build SwiftFormat’ın ContactCleaner kaynak grubuna erişme riski nedeniyle çalıştırılmadı.

EPG Timeline performans follow-up: Placeholder shimmer daha önce her görünmede sonsuz animasyona başlıyor, yükleme bitse de ekran açıkken çalışmayı sürdürüyordu. Şimdi yalnız aktif isteği olan, verisi henüz bulunmayan ve başarısız sayılmayan satırlar varken animasyon yapıyor; bu birleşik görünürlük koşulu değiştiğinde duruyor/başlıyor. Reduce Motion açıkken ve görünüm kapanınca sabit faza dönüyor.

### EPGTimelineFeature.swift / EPGTimelineView.swift — görünürlük ve viewport (#211)

Görünüm kapanırken yalnızca sync grubundaki kanal istekleri iptal ediliyordu; bağımsız kanal yüklemeleri devam edebiliyordu. Program odağında `totalTimelineWidth - 800` kullanılıyordu; gerçek viewport daha genişken son saatlerde içerik sınırının ötesine kayılabiliyordu. Kural: focus ve scroll aynı gerçek geometriyi kullanmalı; gizlenen ekranın işleri sona ermeli.

Önce: yalnız `syncPendingEPGChannels` iptali ve sabit `800` clamp → Sonra: bütün `epgRequestIDs` iptali, loading/status temizliği ve gerçek `viewportWidth` sınırı. Zaten görünür program için gereksiz kaydırma yapılmıyor; yeni focus animasyonu Reduce Motion’a uyuyor. Geniş programın yalnız bir kenarı görünüyorsa o kenar viewport’a alınıyor. Reviewer onayladı; iOS/tvOS Release compile-only build’leri başarılı. Cihaz doğrulaması yapılmadı.

### DownloadsView+tvOS.swift — geri yüklenmiş aktif indirmelerin yönetimi (#198)

Aktif indirme var ve tamamlanmış indirme yoksa boş ekran koşulu atlanıyor, fakat içerik yalnız tamamlanmış dosyaları çiziyor. Sonuç boş bir içerik alanı; `DownloadsFeature` içindeki pause/resume/cancel eylemlerinin tvOS düğmesi yok. Kural: kullanıcıya sunulan her işlem kumanda ile erişilebilir olmalı.

Önce: yalnız `completedDownloads` kartları → #198’de aktif işler için progress/durum ve kardeş pause/resume/cancel düğmeleri; başarısız ve tamamlanmış işler için ayrı bölümler eklendi. Büyük native kontrol hedefleri, focus bölümleri ve busy durumunda odağı koruyan action guard’ları var. Eksik dosya oynatması kapalı; tekli silme onaylı. İlk yükleme hatası gerçek boş listeyle karıştırılmıyor. Reviewer onaylı; iOS/tvOS Release compile-only build’leri başarılı ve görev çıktıları temizlendi. Cihaz doğrulaması yapılmadı.

#198’in ek analizinde yeni indirme düğmelerinin iOS/iPadOS’a ait olduğu ve OfflineMedia’nın CloudKit dışında tutulduğu doğrulandı. tvOS’ta bu dal eski bir sürümden kalan URLSession görevinin geri yüklenmesiyle oluşabilir; yeni tvOS indirme başlatma özelliği bu düzeltmenin parçası değil.

### PlayerView+tvOS.swift:1415 — scrubber dikey komutları (P1, düzeltildi)

Önce: up/down hareketi `isScrubbing` durumunu başlatıyor, thumbnail isteği ve debounce sonrası seek üretiyordu. `handleMove` artık yalnız left/right için konum değiştiriyor; up/down hiçbir scrub durumu oluşturmadan dönüyor. `onMoveCommand` focus hedeflerini yeniden atamıyor. Bağımsız reviewer `[APPROVED]`; tvOS hedefli Swift parse ve `git diff --check` başarılı. Build ve Apple TV cihaz focus doğrulaması yapılmadı.

### PlayerView+tvOS.swift:565 / UpNextCountdownOverlayView.swift — Up Next Geri işlemi (P1, düzeltildi)

Önce: kök exit zinciri `isUpNextVisible` durumunu ele almıyor, kartta yerel Geri handler’ı yoktu. Overlay artık kendi `onExitCommand` yoluyla kapatılıyor; Cancel ve kök exit de aynı dismiss/focus-restore yolunu kullanıyor. Odağın görünür player kontrollerine (`controller` veya `play`) dönmesi sağlandı. Bağımsız reviewer `[APPROVED]`; tvOS/iOS Swift parse ve `git diff --check` başarılı. Build ve Apple TV cihaz focus doğrulaması yapılmadı.

### ProfileSelectionView+tvOS.swift — edit modunda seçim/silme focus yolu (P2, düzeltildi)

İlk taramada silme Button’ının seçim Button’ı içinde olduğu sanılmıştı. Güncel yapı seçim Button’ını yalnız normal modda gösteriyor; edit modunda artwork ve 44 pt kardeş silme Button’ı kullanılıyor. Silme eylemi profil adıyla etiketli ve `.focusSection()` içindeki yatay raf ile aşağıdaki Done kontrolü arasında gezinilebiliyor. Statik kaynak incelemesi cihazdaki gerçek focus sırasını kanıtlamaz.

### PlaylistManagementView.swift — satır kontrolleri ve yoğun güncelleme (P2, düzeltildi)

İlk iç içe Button bulgusu güncel kaynakta geçerli değildi: seçim, ayar ve silme kontrolleri HStack kardeşleri. Asıl sorun tüm satıra uygulanan `.disabled(isUpdatingSources)` idi. Satır artık focus zincirinde kalıyor; seçim, ayar, kilit ve silme action’ları update sürerken reducer’da durduruluyor, kontroller loading değerini VoiceOver’a bildiriyor. Silme reducer guard’ı ve güncelleme sırasında context-menu kilit eylemi devre dışı kalıyor. Apple TV cihazında doğrulanmadı.

### VODView+tvOS.swift / SeriesView+tvOS.swift — filtre sonrası görünmeyen focus kimliği (P2, düzeltildi)

Hatırlanan veya seçili öğe focus/scroll uygulanmadan önce güncel `currentVODs` / `currentSeries` kimlikleriyle doğrulanıyor. Gecikmeli scroll category ve focus kimliği hâlâ aynıysa çalışıyor; stale focus günlüğe kaydedilmiyor.

### CategoryManagementView.swift — tvOS kategori sırası ve focus stili (P2, düzeltildi)

`moveCategory` daha önce yalnız iOS edit-mode `.onMove` yolundaydı. tvOS satır context menu’süne, yalnız arama ve filtre kapalıyken kullanılabilen Yukarı/Aşağı Taşı eylemleri eklendi; mevcut reducer sıralama ve preference indekslerini güncelliyor. Düzenle/kilitle düğmeleri daire focus stilini, görünürlük düğmesi kapsül focus stilini kullanıyor. Remote long-press ve focus sırası cihazda doğrulanmadı.

### SearchView+tvOS.swift — kapsam odağı ve yinelenen scroll (#200)

Yerel focus değişimi reducer’a aktarılıyor; hem yerel focus hem reducer’daki kimlik aynı hedefe `scrollTo` çağırıyordu. Kapsam değişimi odağı siliyordu; gecikmiş restoration kullanıcının yeni seçimini ezebiliyordu. Kural: görünür kimlikleri kapsamına göre hatırla; doğal gezinmede focus/scroll feedback döngüsü oluşturma.

#200’de aynı sorgu boyunca filtre/playlist başına 64 kayıtla sınırlı geçerli odak hafızası; ortak görünür ID/fallback kaynak kimliği; yalnız açık restoration isteğinden ScrollPosition kaydırması eklendi. Sonuçlara girişte bir kez hatırlanan karta dönüş, LazyVGrid hücresi çizildikten sonra ve görünürlük/istek/origin guard’larıyla yapılacak. Kullanıcının input/odak değişimi eski isteği etkisiz kılıyor. EPG yanıtında eksik UUID ve playlist kimliği karşılaştırma hatası da aynı incelemede ele alınıyor. Katalog değişiminde tam pipeline yenileme, kaynak/type/item kimlik ayrımı ve dedupe düzeltmeleri de eklendi. Bağımsız reviewer onayladı; iOS/tvOS Release compile-only build’leri başarılı ve görev çıktıları temizlendi. Cihaz akışı çalıştırılmadı.

### VODDetailView.swift — gecikmiş başlangıç odağı (bulgu güncel kaynakta yok)

Önceki satır notundaki koşulsuz 500 ms `asyncAfter` güncel tvOS görünümünde bulunmuyor. Play kontrolleri `.defaultFocus(..., priority: .userInitiated)` kullanıyor; VODDetail görünümünde gecikmeli focus ataması yok. Eski bulgu kaynak snapshot’ı eskidiği için kapatıldı.

### EPGGuideFeature.swift / EPGGuideView+iOS.swift — görünmeyen otomatik preview (P2, düzeltildi)

iOS Guide preview alanı çizmediği halde kanal seçimi gizli preview başlatabiliyordu. State artık tvOS’ta otomatik preview’ı açık, iOS’ta kapalı başlatıyor. Guide seçimi, odak, preview başlangıcı ve yanıtlar görünürlükle korunuyor; geç gelen action gizli ekranda video veya EPG isteği başlatmıyor. tvOS preview akışı ve cihaz odağı ayrıca doğrulanmadı.

### EPGTimelineFeature.swift — başarısız kanalın yeniden açılışta boş kalması (P2, düzeltildi)

Önce `.fetchEPG`, başarısız isteklerin `[]` sentinel’ini cache sanıp tekrar istemiyordu. Şimdi ekran yeniden göründüğünde ilk 15 filtrelenmiş kanal içindeki başarısızlar deneniyor; sonraki LazyVStack satırları ekrana girdiğinde de `.fetchEPG` backoff süresi geçince yeniden deneyebilir. Program kategorisi filtresi başarısız kanalları gizlemiyor. 15/30/300 saniye ve sonrasında 300 saniyede kalan kanal başı bekleme istek fırtınasını önlüyor; provider-wide cooldown tüm row fetch’lerini durduruyor. Retry zamanlayıcı değildir: aynı satır ekranda kalırsa süre geçtikten sonra yeniden görünmesi veya ekranın açılması gerekir.

EPG sync’te ilk 20 kanalın request UUID’si cache yenilenirken reducer’da rezerve ediliyor; mevcut bağımsız fetch iptal ediliyor ve sequential worker aynı UUID’lerle yanıt sahipliğini koruyor. Cache aşaması, sonuç ve gecikmeli status temizliği sync UUID’siyle doğrulandığından eski iptal edilmiş sync daha yenisini değiştiremiyor. Cache hatasında eski EPG korunup rezervasyon temizleniyor; provider-wide 429 başladığında sync dışındaki aktif satır fetch’leri de geçersiz kılınıp iptal ediliyor. Tarihsiz 429 için 60 saniyelik cooldown gösterilip kaydediliyor. Ekran kapanınca fetch, sync, PiP ve preview başlangıçları görünürlük/cancellation ile durduruluyor. Bağımsız sync lifecycle review’u `[APPROVED]`; cihaz davranışı ve Xcode derlemesi yapılmadı.

### DesignSystem/TVFocusGuide.swift:21–34 — hedefsiz UIKit köprüsü (P2, düzeltildi)

UIFocusGuide oluşturulup boyutlandırılıyor, fakat hiçbir `preferredFocusEnvironments` hedefi atanmıyor. `focusGuideBoundary` ve sütun arasındaki bridge bu nedenle bir yönlendirme tanımlamıyor. Kural: UIKit guide’ın görünür, focus alabilen bir hedefi olmalı; boş yardımcıya güvenerek erişim kanıtlanamaz.

Önce: hedefsiz UIFocusGuide → Düzeltme: kullanılmayan köprü ve modifier kaldırıldı; var olan SwiftUI `.focusSection()` sınırları bırakıldı. Cihazda focus geometrisi ayrıca doğrulanmalı.

## Statik riskler: uygulama düzeltmesi ve cihaz kontrolü gerekli

| Dosya / satır | Kural ve risk | Önce → önerilen değişiklik |
|---|---|---|
| PlayerView+tvOS.swift:680, 702 | Görünmez etkileşimli katmanlar focus hedefi bırakmamalı. | Düzeltildi: controller yalnız görünürken ekleniyor, opacity transition ile kapanıyor ve `.play` focus hedefi tekrar etkinleşiyor. Focus review `[APPROVED]`; gerçek cihazda yön hareketi ayrıca doğrulanmalı. |
| MultiView.swift:383–489 | Tam slot `.focusable()` hedefi, aynı ZStack’teki Button/Menu’larla geometrik olarak örtüşüyordu. | Düzeltildi: tvOS kanal adı 44 pt minimum yüksekliğe sahip ayrı slot-focus düğmesi; audio/aspect/remove/swap kontrolleri bağımsız focus alıyor. Play/Pause handler focus almayan ortak slot üst görünümünde. Review `[APPROVED]`; cihaz kontrolü açık. |
| PlayerView+tvOS.swift | Etkileşimli HUD açıkken idle timer controller’ı kaldırıp kapanışta kaynak focus’u kaybettirebilirdi. | Düzeltildi: etkileşimli HUD’lar açıkken controller mounted kalıyor; HUD kapanışı yeni idle timer başlatıyor. Up Next Play Now yolu da timer’ı yeniliyor. Hedefli review `[APPROVED]`; cihaz kontrolü açık. |
| PlayerSidebarDrawer.swift:504 | Lazy satırlar tekrar girişte focus hafızasıyla eşleşmeli. | Düzeltildi: açılışta görünür listedeki oynatılan kanal, yoksa ilk görünür kanal seçiliyor; gecikmeli ScrollViewReader kaydırması yalnız aynı satır hâlâ odaktayken çalışıyor. Review `[APPROVED]`; cihaz kontrolü açık. |
| DashboardView+tvOS.swift:62, 118, 435 | Busy durumunda `.disabled` focus’taki düğmeyi zincirden çıkarabiliyordu. | Düzeltildi: retry kontrolleri focus’ta kalıyor, spinner/loading değeri gösteriyor; reducer yinelenen isteği reddediyor. |
| CategoryManagementView.swift:180–258 | Plain düğmelerde focus farkı görünmüyordu. | Düzeltildi: tvOS edit/kilit kontrolleri TVCircle, görünürlük eylemi TVCapsule focus stilini kullanıyor. |
| ChannelSelectionToolbar.swift | Toplu işlem başlayınca düğmeler focus zincirinden çıkıyordu; iOS eylemleri dar ekranda yatay kaydırma arkasında kalıyordu. | Düzeltildi: iOS’ta ana eylemler 44 pt araç çubuğunda, ikinciller More menüsünde; tvOS’ta göstergeli yatay raf ve action guard/busy geri bildirimi var. Hide etiketi 22 locale çevrildi. |
| LiveTVView+iOS.swift / LiveTVView+tvOS.swift | Dar iPhone başlığında beş küçük hedef; tvOS kategori sütunu başlığında aksiyon sıkışması ve eager satırlar. | Düzeltildi: iOS ikincil eylemleri More menüsünde, kalan hedefler 44 pt; tvOS eylemleri ayrı satırda ve kategori satırları lazy focus section içinde. |
| UpNextCountdownOverlayView.swift | Thumbnail, uzun metin ve yan yana iki aksiyon iPhone portrede yatay taşma riski taşıyordu. | Düzeltildi: ViewThatFits dar yatay alanda kompakt dikey yerleşimi seçiyor; iki eylem 44 pt minimum yüksekliğe sahip. |
| MediaLanguageFilterBar.swift / OriginalLanguageFilterBar.swift | Dikey içerikteki yatay filtre satırları focus bölümü oluşturmalı. | Düzeltildi: her yatay HStack tvOS’ta `.focusSection()` sınırı taşıyor. |
| MovieVersionPickerView.swift / VODDetailView.swift / SportsHubView.swift | Yatay sürüm/oyuncu/benzer/maç satırlarının focus geometrisi ayrılmalı. | Düzeltildi: sürüm seçici, tvOS oyuncu/benzer rafları ve maç rafı focus bölümlerine ayrıldı. Focus review `[APPROVED]`; cihaz kontrolü açık. |
| VODDetailView.swift / SeriesDetailView+tvOS.swift | Dikey katalog alanlarının sınırı tanımlanmalı. | Düzeltildi: tvOS VOD ve Series ScrollView’larına `.focusSection()` eklendi. Yukarı sekme barına çıkış cihazda doğrulanmalı. Downloads kapsamındaki focus bölümleri #198’de eklendi. |
| EPGTimelineView.swift | tvOS program metinleri küçük, alt sağ floating navigasyon grid hücrelerini kapatıyordu. | Düzeltildi: tvOS program başlıkları kullanılabilir karta göre 12–18 pt, badge’ler 11–12 pt, kanal başlıkları 13–15 pt; zaman kontrolleri kaydırılabilir grid’in altında ayrı focus section’da. Reviewer `[APPROVED]`; dar kartlar başlığı kısaltabilir, cihaz okunabilirlik kontrolü açık. |

## EPG sunum mimarisi araştırması

Önce LiveTV tvOS EPG’yi yerel `fullScreenCover` ile sunuyor, iOS ise yerel `sheet` kullanıyordu; oynatıcı üst AppCoordinator’ın TCARouter cover’ıydı. Timeline’dan oynatmaya geçerken EPG state’i korunuyor; Guide ise nil yapılıyordu. Kaynak bu farklı sözleşmeleri doğruluyor, ancak kullanıcının bildirdiği kapanıp yeniden açılmanın tek nedeninin bu olduğunu kanıtlamıyor.

Backlog #201’in ilk diliminde EPG Guide `AppScreen` ve AppCoordinator route’una taşındı. LiveTV/Home yalnızca immutable Guide state snapshot’ını Coordinator’a iletiyor; iOS route sheet, tvOS route cover olarak açılıyor. Guide→Player geçişi aktif playlist’i yeniden çözmek yerine aynı snapshot’ın config ve kanal listesini kullanıyor. Her Guide sunumunun UUID preview sahibi var; `onDisappear` cleanup root Coordinator’dan gönderildiği için interaktif route dismissal’ında Guide reducer effect’lerinin iptal edilmesi preview temizliğini yutmuyor. Sahiplik kontrolü eski Guide kapanışının daha yeni preview’ı durdurmasını engelliyor.

Bu slice iOS ve tvOS Release compile-only derlemelerinde başarılı oldu. Test, simülatör veya cihaz akışı çalıştırılmadı; focus erişimi ve sheet/cover geçiş hissi cihazda doğrulanmadı. EPGTimeline ve diğer yerel ekran sunumları hâlâ #201 kapsamındadır; genel merkezi navigasyon tamamlandı denemez.

- **Independent review:** İlk review playback başlangıç hatasında sahiplik/cleanup boşluğu buldu. Preview owner ilk throwing `await` öncesine alındı; audio-session açılışı, cancellation kontrolü ve stream başlangıcı aynı owner-scoped `do/catch` içinde temizleniyor. Son reviewer kararı `[APPROVED]`; ek bulgu yok.
- **Final build:** Son kaynak revizyonuyla iOS Release ve tvOS Release compile-only Xcode build’leri exit 0 / `BUILD SUCCEEDED`. Projedeki mevcut Swift 6 concurrency ve deprecation uyarıları sürüyor. Test, simülatör veya uygulama akışı çalıştırılmadı.
- **Task cleanup:** İlk compile/review döngüsünde `/private/tmp/PureIPTV201-20261028` **4,143,144 KiB**, tools wrapper **4 KiB**, iOS logu **4,100 KiB**, tvOS logu **3,124 KiB** kaldırıldı; **4,150,372 KiB**. İlk review düzeltmesinden sonraki `/private/tmp/PureIPTV201-fix-20261028` **4,175,544 KiB**, wrapper **4 KiB**, kesilen ilk iOS logu **3,076 KiB**, son iOS logu **2,052 KiB**, tvOS logu **3,100 KiB** kaldırıldı; **4,183,776 KiB**. Son per-attempt owner build’inden sonra normal DerivedData’da yalnız bu görevde oluşan `Build` **3,258,916 KiB**, `ModuleCache.noindex` **370,004 KiB**, `CompilationCache.noindex` **28 KiB** ve `Logs/Build` **1,340 KiB** kaldırıldı; temp wrapper **4 KiB**, iOS logu **5,176 KiB**, tvOS logu **3,096 KiB** ile bu son tur **3,638,564 KiB** oldu. Üç turda toplam **11,972,712 KiB** silindi; tüm 16 kesin yolun yokluğu doğrulandı. Normal DerivedData’da Build/Index/ModuleCache/CompilationCache/Logs/Build yok; ortak SourcePackages **1,873,636 KiB**, SDKExplicitPrecompiledModules **525,764 KiB** ve Logs **12 KiB** korundu. ContactCleaner’a dokunulmadı.

### EPGTimeline tvOS route (#201 ikinci dilim)

tvOS’taki yerel `fullScreenCover` AppCoordinator `AppScreen.epgTimeline` cover route’una taşındı. LiveTV, timeline için immutable config/channel snapshot’ı üretip Home üzerinden Coordinator’a iletiyor; iOS’ta inline EPGTimeline ve child state aynen yerinde kaldı. Route UUID ile eşitleniyor; close/play Coordinator’da yönetiliyor, logo override sonucu arka plandaki LiveTV state’ine taşınıyor. Background olayında aktif route’a `cancelEPGSync` gönderiliyor.

EPGTimeline preview’ı route `presentationID` ve playback-attempt UUID’siyle sahipleniliyor; route kapanışında root Coordinator owner-scoped cleanup gönderiyor. Böylece eski iptal/hata cevabı yeni kanal preview’ını durdurmuyor. Reducer/view focus ve scroll snapshot’larını mevcut EPGTimeline state’inde kaydedip görünmede geri yüklüyor; `.focusSection()` düzeni değişmedi. Sunum taşımasının cihazdaki focus dönüşüne etkisi runtime test edilmedi; kullanıcı talimatıyla yalnız Xcode compile-only build yapıldı. EPGTimeline’daki küçük tvOS metinler ve sağ alt timeline navigasyonunun hücrelerle örtüşmesi ayrı audit bulguları olarak açık kaldı.

- **Independent review:** İlk review background sırasında route’a bağlı EPG sync’in iptal edilmediğini buldu; AppCoordinator düzeltmesi ve route-action imza düzeltmeleri sonrası `[APPROVED]`.
- **Build:** iOS Release ve tvOS Release compile-only build’leri exit 0 / `BUILD SUCCEEDED`; mevcut Swift 6 concurrency uyarıları sürüyor. Test, simülatör veya uygulama akışı çalıştırılmadı.
- **Cleanup:** İki başarısız ilk denemenin kesin temp wrapper/logları **32 KiB** ve **24 KiB** ölçülüp handle yokluğu doğrulandıktan sonra silindi. Son ortak temp DerivedData wrapper’ı **4,119,760 KiB**, iOS logu **424 KiB**, tvOS logu **3,092 KiB**; toplam **4,123,276 KiB** silindi ve yokluğu doğrulandı. Bu görevde normal DerivedData Build/Index/ModuleCache/CompilationCache/Logs/Build oluşmadı. SourcePackages **1,873,636 KiB** ve SDKExplicitPrecompiledModules **525,764 KiB** korundu. `/private/tmp` içinde bilinen Git index snapshot’ları ve patch’ler korundu; ContactCleaner alanı envanter dışında bırakıldı.

## İndirme incelemesinden kalan çapraz ekran işleri

- **VOD/Series indirme silme akışı (#234):** İndirildi düğmesi artık dosyayı doğrudan silmiyor; mevcut Downloads onay metniyle destructive confirmation istiyor. Series reducer bekleyen bölüm kimliğini doğruluyor, silme hatasını görünür alert’te gösteriyor ve başarıda yalnız silinen bölümü yerel listeden çıkarıyor. Series liste kartındaki iç içe Button’lar ve grid’de eksik olan indirme eylemi düzeltildi; Play/İndir hedefleri birbirinden bağımsız ve en az 44 pt, silme sürerken spinner/erişilebilir busy değeri gösteriliyor. VOD silmesi de busy feedback alıyor. Dialog kapanış sırası ve view disappearance için pending state temizliği eklendi. Manager’ın canonical/aktif görev/düzenli dosya koruması aynen kullanılıyor. Hedefli kaynak incelemesi ve `git diff --check` dışında doğrulama yok; ContactCleaner sınırı nedeniyle Xcode build çalıştırılmadı.
- DownloadManager’ın custom context’leri aynı actor içinde tutulup UI’ye Sendable snapshot dönüyor. `SharedDatabaseConfig.shared` erişimi ise projedeki mevcut MainActor varsayımı nedeniyle iOS derlemesinde Swift 6 uyarısı üretiyor. Container’ın açık actor/isolation enjeksiyonu ayrı bir concurrency incelemesi gerektiriyor; uyarının giderildiği veya uygulamanın Swift 6 modunda temiz olduğu iddia edilmiyor.

## Başlangıç ve veri koruma incelemesi (#199)

- SwiftData container açılamazsa uygulama `fatalError` ile kapanıyordu. Başarılı açılış cache’i, throwing provider ve Store/sync’ten önce çalışan başlangıç gate’i eklendi; native Retry ve sınırlı domain/kod tanısı sunuluyor. Genişletilmiş profil/Keychain akışı ve iki profil yarışı da bağımsız reviewer’dan onay aldı; iOS/tvOS Release compile-only build başarılı ve görev çıktıları temizlendi. Cihaz akışı çalıştırılmadı.
- Keychain okunamadığında playlist’lerin gerçekten boş olduğu varsayılıyordu; başlangıçta typed okuma hatası ve Retry ayrı ele alınıyor. Profil fetch hataları için de görünür recovery yolu eklendi; başarılı boş sonuç varsayılanları tek MainActor işlemiyle oluşturuyor. Save sonrası committed action, sonraki okuma hata verse de listeyi uzlaştırıyor.
- **Açık veri konumu riski:** İstenen App Group `group.com.pureiptv.shared`, entitlements içindeki değer `group.com.pureiptv.app`. Mevcut fallback/default store konumları bu görevde değiştirilmedi. Üretimdeki eski store URL’leri doğrulanmadan entitlement/URL değiştirmek önceki veriyi görünmez yapabilir; ayrı migration tasarımı gerekiyor. Gerçek uyumsuz şema onarımı bu gate’in çözdüğü iddia edilmiyor.

## Devam sırası

1. #211 EPG yanıt/yaşam döngüsü ve viewport düzeltmeleri reviewer + iOS/tvOS compile-only build ile tamamlandı; görev çıktıları temizlendi.
2. #198 indirme UI/veri değişiklikleri reviewer + iOS/tvOS compile-only build ile tamamlandı; görev çıktıları temizlendi.
3. Player scrubber ve Up Next Geri hataları düzeltildi; görünmez kontroller ve diğer HUD focus dönüşlerini sürdür.
4. İç içe profil/playlist kontrollerini ayır; kategori sıralamasına remote yolu ekle.
5. Filtre/row focus geometrisi, scroll döngüleri, tvOS tipografi ve örtüşen kontrol alanlarını düzelt.
6. Merkezi ekran sunumu ve EPG dönüş yolunu tutarlı hale getir. Kalan ortak UI ve iOS ekranlarının ayrıntılı taramasını sürdür.

Tüm açık maddeler kapanmadan ve gerçek cihaz erişim yolları kullanıcı tarafından doğrulanmadan genel hedef tamamlanmış sayılmaz.

## 29 Ekim 2026 devam denetimi

- EPG sync görünüm kapanırken etkinse otomatik yenileme deneme damgası temizleniyor; böylece yarıda kesilen yenileme tekrar açılışta bekleme aralığına takılmıyor.
- Timeline yeniden açıldığında kaydedilmiş kanal veya program odağı verilmeden önce lazy kanal satırı dikey olarak görünür alana kaydırılıyor; kayıtlı program artık yoksa kanal odağına dönülüyor.
- Player EPG’de başka kanala ait program düğmeleri odak alabilir durumda; seçim action içinde korunuyor ve erişilebilir ipucu veriliyor.
- tvOS oynatıcı controller’ı `isMaskShow` false iken focus ağacından kaldırılıyor; mevcut fade geçişi ve `.play` focus dönüşü korunuyor. Hedefli source review `[APPROVED]`.
- MultiView’de full-slot focus hedefi kaldırıldı. Kanal adı tvOS’ta görünür 44 pt slot seçim düğmesi; alttaki/üstteki sibling kontroller ayrı focus alıyor ve Play/Pause komutu ortak slot üst görünümünden fullscreen/swap davranışını koruyor. Reviewer `[APPROVED]`; cihaz test edilmedi.
- PlayerSidebarDrawer lazy satırları açılışta görünür geçerli kanal ID’sine odaklanıyor; gecikmeli scroll callback odak veya filtre değişince stale kalıyor ve atlanıyor. Hedefli review `[APPROVED]`.
- tvOS yatay dil/versiyon/oyuncu/benzer/maç satırları `.focusSection()` ile ayrıldı; VOD detayının dikey kataloğu da focus section sınırında. Reviewer yatay section’ları ve VOD modifier kapsamını `[APPROVED]` etti; cihaz kontrolü açık.
- Etkileşimli Player HUD açıkken idle timer artık controller’ı kaldırmıyor. HUD kapanışı ve Up Next Play Now timer’ı yeniliyor; focused source view açık kaldığından dismissal focus kaybetmiyor. Reviewer `[APPROVED]`.
- Series detayının dış dikey kataloğuna `.focusSection()` eklendi. Hedefsiz UIFocusGuide helper kaldırıldı.
- Yukarıdaki düzeltilen EPG/focus yollarının hedefli kaynak review’ları onaylandı. Tam iOS/tvOS compile-only build ve fiziksel Apple TV focus doğrulaması tamamlanmadı; uygulama akışları bu hedefte çalıştırılmayacak.

### 29 Ekim 2026 Focus Engine tarama devamı

- **Player EPG:** Program timeline ve kanal picker yatay ScrollView’larına kendi `.focusSection()` sınırları eklendi. Program seçimi mümkün değilken tvOS’ta kartlar odakta kalıp açıklama sunuyor; iOS’ta aynı kartlar hâlâ disabled ve VoiceOver/touch eylemi oluşturmuyor.
- **Player yardımcı şeritleri:** Catch-up program şeridi ve numara tuşlama eşleşme şeridi focus section sınırında; dikey kumanda hareketi bu yatay satırların dışına beklenmedik sıçramamalı.
- **Trakt:** Watchlist ve playback-progress kartları tvOS’ta odak alınabilir, birleşik erişilebilirlik metni ve belirgin çerçeve sunuyor; dikey scroll view section olarak gruplanıyor. Mevcut TraktFeature’da içerik açma/play action’ı bulunmadığından kartlara yeni action uydurulmadı.
- **MultiView:** Audio, aspect ratio, kaldır, kanal başlığı ve companion swap eylemleri ayrı `MultiViewSlotFocusTarget` kimlikleri kullanıyor. Slot vurgusu tüm focused descendants’ı izliyor; aynı slotta tekrar odak event’i audio state’ini yeniden yazmıyor. Bağımsız kaynak reviewer `[APPROVED]`.
- **Ayarlar ve ön kontrol:** CategoryManagement bulk/filter/reset, Paywall kapat, playlist preflight, Cloud Sync, tanılama raporu ve özel EPG yenileme kontrolleri tvOS focus geri bildirimi gösteriyor. Çalışan işlemler sırasında tvOS kontrolleri focus zincirinde kalırken action guard’ları tekrar isteği önlüyor; kullanılabilir olmayan preflight focus dışı kalıyor. iOS disabled davranışı korunuyor. Kaynak review `[APPROVED]`.
- **Kanal isimleri:** EPG Guide aynı tvOS iki-satır tercihini kullanıyor; mevcut setting Live TV/favori kartları ve player drawer’da da tüketiliyor. EPG Timeline kompakt/standart satır seçimini koruyor.
- **Ortak ağ hızı ekranı:** `StreamSpeedTestView`’daki simge-only kapatma düğmesinin erişilebilir etiketi yoktu ve `.plain` stil tvOS focus vurgusunu kaldırıyordu. Yerelleştirilmiş Kapat etiketi ve dairesel `tvFocusEffect` eklendi; ana test/durdur düğmesi de tvOS’ta ortak odak vurgusunu kullanıyor. Bağımsız kaynak review `[APPROVED]`; build veya ekran akışı çalıştırılmadı.
- **SportsHub maç rafı:** Kartın tek kumanda eylemi olan “İzle” düğmesi `.plain` nedeniyle odakta görünmüyordu ve 44 pt’den kısa kalıyordu. tvOS’ta minimum yükseklik 44 pt ve kapsül `tvFocusEffect` eklendi; iOS stili değişmedi. Bağımsız kaynak review `[APPROVED]`.
- **EPG Guide başlangıç odağı:** Seçili kanal ilk LazyVStack ekranının dışındaysa doğrudan `@FocusState` ataması odaklanabilir satır bulamıyordu. Kanal listesi açılışta seçili/geçerli kanal kimliğine kayıyor; view-lifecycle task bir run-loop adımı sonra odak atıyor ve görünüm iptali, güncel seçim ile yeni odak guard’ları eski atamanın geç kalmasını önlüyor. Boş/eski seçime ilk görünür kanal fallback’i var. Preview mute düğmesi 44×44 hedef ve `TVCircleButtonStyle` odak görünümü kullanıyor. Reviewer `[APPROVED]`.
- **LiveTV seçim modu focus dönüşü:** Kaydedilmiş kanal seçim sırasında gizlenirse dönüş odağı artık `displayChannels` içinden görünür fallback seçiyor. Her seçim modu geçişi restore generation token’ını yeniliyor; gecikmiş callback modun hâlâ kapalı olduğunu ve aynı request’in geçerli kaldığını doğruluyor, geçerli yeni kanal/kategori odağını ezmiyor. Reviewer `[APPROVED]`.
- **Settings işlem odağı ve tanılama raporu:** tvOS’ta çalışan Custom EPG, Cloud Sync ve tanılama eylemleri odakta kalıyor; yinelenen işlem action/reducer guard’larıyla reddediliyor, iOS disabled davranışı korunuyor. Eylem adları busy spinner sırasında da sabit ve loading accessibility value’su var. Tanılama raporu üreticisi 2 KiB üst sınırı koyuyor; önizleme dosyayı arka planda cancellation-linked işçiyle okuyup beş satırlık focusable `VStack` bölümleri olarak `.focusSection()` içinde gösteriyor, böylece uzun rapor satırları virtualization yüzünden odağı kaybetmiyor. Custom EPG kaynak yenileme ve Toggle busy sırasında focus zincirinde kalıyor; etiket ve loading value korunuyor. Kaynak reviewer `[APPROVED]`.
- **SportsHub yatay focus sınırı:** `.focusSection()` değişken içerik genişliğindeki HStack’ten tam viewport genişliğini sağlayan horizontal ScrollView’a taşındı. Kaynak reviewer `[APPROVED]`.
- **Kullanılmayan ortak ekran adayları:** `ChannelNumberPadView` ve `ShuffleMoviePickerView` için uygulama içi çağrı yeri kaynak aramasında bulunmadı. Bu nedenle erişilebilirlikleri canlı ekran denetimi sayılmadı; silme kararı ayrı dead-code incelemesine bırakıldı.
- **Açık cihaz riski:** SeriesDetail uzun sezon listesi stable ID, `@FocusState` binding ve `.focusSection()` taşıyor; kaynakta kalıcı bir focus dead-end bulunmadı. Apple TV HD’de LazyVStack virtualization sırasında hızlı dikey gezinme riski yalnız gerçek cihazda doğrulanabilir. Bu hedefte app flow çalıştırılmıyor.
- **Doğrulama:** Hedefli `git diff --check` başarılı. Xcode build, test, simulator veya uygulama akışı çalıştırılmadı; Xcode pre-build SwiftFormat’ın ContactCleaner’a erişmeyeceği garanti edilemiyor.

## 31 Ekim 2026 devam denetimi

- **Recent Live TV rafı:** Pin kaldırma işlemi sürerken Dashboard tüm kartı devre dışı bırakıyordu; bu, ayrı Watch düğmesini de tvOS focus ağacından çıkarıyordu. Kart genelindeki `.disabled` kaldırıldı. Bağımsız reviewer Watch eyleminin odakta kaldığını ve reducer’ın yinelenen pin/remove çağrılarını reddettiğini doğruladı.
- **EPG kanal oynatma:** Timeline ve Guide, `streamURL` boş olsa bile oynatma öncesi görünmez duruma geçebiliyordu. Her iki akışta da URL doğrulaması görünürlük/preview state değişikliklerinden önce yapılıyor; route, geçersiz oynatmada açık ve kapatılabilir kalıyor.
- **Doğrulama:** EPG handoff iptali, sahiplik temizliği ve route sunum kimliği reviewer tarafından `[APPROVED]` edildi. Değişen Swift dosyalarında `swiftc -frontend -parse` ve hedefli `git diff --check` başarılı. Build, simulator, app flow ve cihaz focus kontrolü çalıştırılmadı; EPG metin okunabilirliği ve kumanda ile gerçek cihaz dolaşımı hâlâ cihazda doğrulanmalı.
