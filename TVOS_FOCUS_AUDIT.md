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

### ProfileSelectionView+tvOS.swift:203, 231 — iç içe profil düğmeleri (P2, açık)

Kart seçme Button’ı içinde düzenleme modunun Delete Button’ı var; dış eylem bu modda no-op oluyor. Kural: native etkileşimli kontrolleri iç içe yerleştirme.

Önce: `Button { ... Button(delete) ... }` → Öneri: seçim ve silmeyi aynı kart düzeninde kardeş Button’lar yap; edit modunda silme hedefini açıkça odakla.

### PlaylistManagementView.swift:245, 293 — iç içe playlist düğmeleri (P2, açık)

Playlist seçen tüm satır Button’ının içinde tvOS ayar ve silme Button’ları var. Kural: her eylemin bağımsız focus geometrisi olmalı.

Önce: seçim Button’ı içinde ayar/silme → Öneri: HStack içinde ayrı seçim alanı, Settings ve Delete düğmeleri.

### VODView+tvOS.swift:319 / SeriesView+tvOS.swift:316 — filtre sonrası görünmeyen focus kimliği (P2, açık)

Kategori dönüşünde hafızadan gelen kimlik, güncel filtrelenmiş listede doğrulanmadan focus ve `scrollTo` hedefi oluyor. Kural: veri değişince odak kimliğinin hâlâ görünür olduğunu doğrula.

Önce: doğrudan `lastItem(...)` ataması → Öneri: `visibleIDs.contains(savedID)` kontrolü; geçersizse ilk görünür öğe; asenkron kategori sonucu geldikten sonra aynı kontrol.

### CategoryManagementView.swift:351, 359 — tvOS kategori sırası (P2, açık)

`moveCategory` yalnız `.onMove` yolunda; edit modu iOS koşulu altında. tvOS’ta bu eylemin ayrı kumanda yolu bulunmadı. Kural: gesture/edit-mode işlemlerinin alternatif düğmesi olmalı.

Önce: yalnız `.onMove` → Öneri: satır context menu’sünde uygun olduğunda Yukarı/Aşağı Taşı eylemleri.

### SearchView+tvOS.swift — kapsam odağı ve yinelenen scroll (#200)

Yerel focus değişimi reducer’a aktarılıyor; hem yerel focus hem reducer’daki kimlik aynı hedefe `scrollTo` çağırıyordu. Kapsam değişimi odağı siliyordu; gecikmiş restoration kullanıcının yeni seçimini ezebiliyordu. Kural: görünür kimlikleri kapsamına göre hatırla; doğal gezinmede focus/scroll feedback döngüsü oluşturma.

#200’de aynı sorgu boyunca filtre/playlist başına 64 kayıtla sınırlı geçerli odak hafızası; ortak görünür ID/fallback kaynak kimliği; yalnız açık restoration isteğinden ScrollPosition kaydırması eklendi. Sonuçlara girişte bir kez hatırlanan karta dönüş, LazyVGrid hücresi çizildikten sonra ve görünürlük/istek/origin guard’larıyla yapılacak. Kullanıcının input/odak değişimi eski isteği etkisiz kılıyor. EPG yanıtında eksik UUID ve playlist kimliği karşılaştırma hatası da aynı incelemede ele alınıyor. Katalog değişiminde tam pipeline yenileme, kaynak/type/item kimlik ayrımı ve dedupe düzeltmeleri de eklendi. Bağımsız reviewer onayladı; iOS/tvOS Release compile-only build’leri başarılı ve görev çıktıları temizlendi. Cihaz akışı çalıştırılmadı.

### VODDetailView.swift:1604 — gecikmiş başlangıç odağı (P2, açık)

Açılıştan 500 ms sonra koşulsuz Play odağı atanıyor. Kullanıcı o sürede başka kontrole gitse bile geri çekiliyor. Kural: asenkron başlangıç odağı kullanıcı hareketini ezmemeli.

Önce: koşulsuz `asyncAfter { isPlayButtonFocused = true }` → Öneri: iptal edilebilir başlangıç task’ı ve kullanıcının henüz gezinmediği guard’ı veya uygun default-focus.

### EPGGuideFeature.swift / EPGGuideView+iOS.swift — görünmeyen otomatik preview (P2, açık)

Guide state’inde `isAutoPreviewEnabled` varsayılanı true; kanal seçimi preview oynatmayı başlatıyor. iOS Guide görünümünde preview’ı çizen bir alan yok. Kural: ekranda kullanılmayan video işini başlatma; görünümün sunduğu yetenekle reducer davranışı eşleşmeli.

Önce: bütün platformlarda otomatik preview → Öneri: preview gösteren sunumdan açık capability/config geçir veya iOS’ta görünür, kullanıcı tarafından kontrol edilen preview sun. Mevcut preview engine test sözleşmesi ve promotion akışı birlikte incelenmeli.

### DesignSystem/TVFocusGuide.swift:21–34 — hedefsiz UIKit köprüsü (P2, açık)

UIFocusGuide oluşturulup boyutlandırılıyor, fakat hiçbir `preferredFocusEnvironments` hedefi atanmıyor. `focusGuideBoundary` ve sütun arasındaki bridge bu nedenle bir yönlendirme tanımlamıyor. Kural: UIKit guide’ın görünür, focus alabilen bir hedefi olmalı; boş yardımcıya güvenerek erişim kanıtlanamaz.

Önce: hedefsiz UIFocusGuide → Öneri: SwiftUI sütunlarında gerçek `.focusSection()`/açık focus hedefleriyle geometriyi doğrula; UIKit yönlendirme gerekmiyorsa no-op köprüyü kaldır, gerekiyorsa hedefleri açıkça bağla.

## Statik riskler: uygulama düzeltmesi ve cihaz kontrolü gerekli

| Dosya / satır | Kural ve risk | Önce → önerilen değişiklik |
|---|---|---|
| PlayerView+tvOS.swift:680, 702 | Görünmez etkileşimli katmanlar focus hedefi bırakmamalı. Kontrol ağacı sürekli kurulup yalnız `opacity(0)` ile gizleniyor. | Opacity ile gizleme → fade sonrası alt ağacı kaldırma ve yüzeye focus dönüşü. |
| MultiView.swift:383–489 | Tam slot `.focusable()` hedefi, aynı ZStack’teki Button/Menu’larla geometrik olarak örtüşüyor. | Tüm slot hedefi → kontrollerle örtüşmeyen ayrı seçim alanı. |
| PlayerView+tvOS.swift:324, 601 | Koşullu özel HUD kapanışında kaynak kontrole dönüş tanımlı olmalı. Yalnız EPG bunu açıkça yapıyor. | Sadece EPG restore → her HUD için kararlı kaynak kimliği ve kapanış sonrası restore. |
| PlayerSidebarDrawer.swift:504 | Lazy satırlar tekrar girişte focus hafızasıyla eşleşmeli. | Yalnız LazyVStack → kaydedilmiş satır kimliği + koordineli scroll/focus; büyük listeyi sırf bunun için eager VStack’e çevirme. |
| DashboardView+tvOS.swift:62, 118, 435 | Busy durumunda `.disabled` focus’taki düğmeyi zincirden çıkarabiliyor. | `.disabled(busy)` → action guard + görünür busy durumu; reducer guard’ını koru. |
| CategoryManagementView.swift:180–258 | Plain düğmenin odaklandığı görünür olmalı. | Stilsiz `.plain` → ortak focus stilini kullan. |
| ChannelSelectionToolbar.swift:37–68 | Toplu işlem başlayınca birden çok düğme focus zincirinden çıkarılıyor. | `.disabled(isBusy)` → tvOS action guard, busy açıklaması; iOS doğrulamasını koru. |
| MediaLanguageFilterBar.swift:24 / OriginalLanguageFilterBar.swift:23 | Dikey içerikteki yatay filtre satırları focus bölümü oluşturmalı. | Yatay ScrollView → tvOS `.focusSection()`. |
| MovieVersionPickerView.swift:43 / VODDetailView.swift:1457, 1525 / SportsHubView.swift:43 | Yatay sürüm/oyuncu/benzer/maç satırlarının focus geometrisi ayrılmalı. | Yatay ScrollView → tvOS `.focusSection()`. |
| VODDetailView.swift:1276 / SeriesDetailView+tvOS.swift:21 | Dikey katalog alanlarının sınırı tanımlanmalı. | Katalog ScrollView → uygun `.focusSection()`, yukarı sekme barına çıkış korunarak cihaz kontrolü. Downloads kapsamındaki focus bölümleri #198’de eklendi. |
| EPGTimelineView.swift | tvOS program başlıkları 10–14 pt, bazı badge’ler 7–9 pt; kanepeden okunabilirlik zayıf. Alt sağ floating navigasyon grid hücreleriyle örtüşüyor. | Küçük metin/floating controls → tvOS tipografi ve row ölçüleri; navigasyonu ayrı inset/bölüme al. |

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

- `VODDetailFeature.downloadTapped` ve `SeriesDetailFeature.downloadEpisode` mevcut dosya indirildi olarak işaretliyken doğrudan silme API’sine gidiyor; queue ekranına eklenen onay bu iki ayrıntı akışında henüz yok. Aynı onay ve görünür hata sözleşmesi bu çağrı noktalarına da taşınmalı. Manager’ın canonical/aktif görev/düzenli dosya koruması bu çağrılar için de uygulanıyor.
- DownloadManager’ın custom context’leri aynı actor içinde tutulup UI’ye Sendable snapshot dönüyor. `SharedDatabaseConfig.shared` erişimi ise projedeki mevcut MainActor varsayımı nedeniyle iOS derlemesinde Swift 6 uyarısı üretiyor. Container’ın açık actor/isolation enjeksiyonu ayrı bir concurrency incelemesi gerektiriyor; uyarının giderildiği veya uygulamanın Swift 6 modunda temiz olduğu iddia edilmiyor.

## Başlangıç ve veri koruma incelemesi (#199)

- SwiftData container açılamazsa uygulama `fatalError` ile kapanıyordu. Başarılı açılış cache’i, throwing provider ve Store/sync’ten önce çalışan başlangıç gate’i eklendi; native Retry ve sınırlı domain/kod tanısı sunuluyor. Genişletilmiş profil/Keychain akışı ve iki profil yarışı da bağımsız reviewer’dan onay aldı; iOS/tvOS Release compile-only build başarılı ve görev çıktıları temizlendi. Cihaz akışı çalıştırılmadı.
- Keychain okunamadığında playlist’lerin gerçekten boş olduğu varsayılıyordu; başlangıçta typed okuma hatası ve Retry ayrı ele alınıyor. Profil fetch hataları için de görünür recovery yolu eklendi; başarılı boş sonuç varsayılanları tek MainActor işlemiyle oluşturuyor. Save sonrası committed action, sonraki okuma hata verse de listeyi uzlaştırıyor.
- **Açık veri konumu riski:** İstenen App Group `group.com.pureiptv.shared`, entitlements içindeki değer `group.com.pureiptv.app`. Mevcut fallback/default store konumları bu görevde değiştirilmedi. Üretimdeki eski store URL’leri doğrulanmadan entitlement/URL değiştirmek önceki veriyi görünmez yapabilir; ayrı migration tasarımı gerekiyor. Gerçek uyumsuz şema onarımı bu gate’in çözdüğü iddia edilmiyor.

## Devam sırası

1. #211 EPG yanıt/yaşam döngüsü ve viewport düzeltmeleri reviewer + iOS/tvOS compile-only build ile tamamlandı; görev çıktıları temizlendi.
2. #198 indirme UI/veri değişiklikleri reviewer + iOS/tvOS compile-only build ile tamamlandı; görev çıktıları temizlendi.
3. Player scrubber / Up Next / görünmez kontroller ve HUD focus dönüşlerini düzelt.
4. İç içe profil/playlist kontrollerini ayır; kategori sıralamasına remote yolu ekle.
5. Filtre/row focus geometrisi, scroll döngüleri, tvOS tipografi ve örtüşen kontrol alanlarını düzelt.
6. Merkezi ekran sunumu ve EPG dönüş yolunu tutarlı hale getir. Kalan ortak UI ve iOS ekranlarının ayrıntılı taramasını sürdür.

Tüm açık maddeler kapanmadan ve gerçek cihaz erişim yolları kullanıcı tarafından doğrulanmadan genel hedef tamamlanmış sayılmaz.
