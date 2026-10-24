# 🚀 PureIPTV Autonomous R&D Engineering Backlog

Bu dosya, tam otonom iOS & tvOS IPTV mühendislik ekibinin (Analyst, Principal Dev, PR Reviewer) canlı hafızasıdır.

---

## 📊 Backlog Durumu (Active Pipeline)

### 26. [DONE] İçerik Türüne Göre Otomatik Kare Hızı Eşleme (AFR)
- **Bulgu:** AFR tek bir `com.pureiptv.afrEnabled` tercihiyle yönetiliyor; kullanıcı canlı yayın için kapatıp film/dizilerde açık tutamıyor. Bu, r/appletv kullanıcısının canlı TV için AFR’yi kapatıp film/dizilerde açık bırakma isteğine doğrudan karşılık geliyor.
- **Kapsam:** iOS ve tvOS ayarlarında ayrı Live TV ve VOD/Dizi anahtarları; oynatıcıda içerik sınıfına göre eşleme; eski genel tercihi iki sınıfa da geriye dönük varsayılan olarak kullanma.
- **Uygulama:** Ayarlara Live TV ve Film/Dizi için ayrı AFR anahtarları eklendi. Yeni tercihler mevcut genel AFR tercihini her iki içerik türü için geriye dönük varsayılan olarak kullanıyor. Oynatıcı mevcut içeriğin türüne göre doğru anahtarı uyguluyor. tvOS derlemesi, iOS-only `UIPasteboard` erişiminin platform koşuluyla korunmasıyla düzeltildi.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iOS 26.5 / iPhone 17 simulator için Xcode compile-only build başarılı, tvOS Simulator compile-only build ürün üretti. Uygulama akışı veya test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Reviewer onayladı; yalnızca Xcode derlemeleri alındı.
- **Kaynak:** https://www.reddit.com/r/appletv/comments/1pauyyl/iptv_on_appletv/

### 27. [DONE] İzlenen İçeriği Manuel Olarak İzlenmedi İşaretleme
- **Bulgu:** Kullanıcılar dizi/bölüm/film izleme durumunu sıfırlamak istiyor; ortak aile profilleri aynı watch history’yi etkileyebiliyor.
- **Kaynak:** https://www.reddit.com/r/TiviMate/comments/1w6hkes/remove_watched_history/
- **Uygulama:** İzlenmiş film ve bölümlere “İzlenmedi Olarak İşaretle” eylemi eklendi; tamamlanan içerik geçmişte korunurken Devam Et rafından filtreleniyor. Silmeler iCloud’a tombstone olarak gidiyor. KVS depolaması cihaz başına ve toplam kota için sınırlandırıldı; kapasite baskısında eski uzak kayıtlar senkron dışına alınır, cihazdaki yerel geçmiş korunur.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iOS Simulator ve tvOS Simulator Release compile-only Xcode build’leri exit code 0 ile tamamlandı. Akış ve test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Reviewer onayladı; yalnızca Xcode derlemeleri alındı.

### 28. [DONE] Canlı Yayını Kesmeden EPG’de Gezinme
- **Bulgu:** Kullanıcı mevcut kanalı izlemeye devam ederken rehberde dolaşmak, yalnızca vurgulanan kanalın sessiz önizlemesine geçmemek istiyor.
- **Canlı keşif:** 23 Ekim 2026 araştırmasında, Apple TV kullanıcıları mevcut kanal sürerken rehberde gezinme ve kanal seçilmeden stream’in değişmemesini talep ediyor; bazı mevcut EPG preview davranışlarında gecikme, ses düzeyi ve görüntü kararması bildiriliyor. Rakip dokümanları TV rehberinde odak/preview tetikleyicisini ve gecikmesini ayarlanabilir gösteriyor.
- **Kaynaklar:** https://www.reddit.com/r/IPTV_Help_Desk/comments/1uzehpu/apple_tv_iptv_app_with_persistent_live_preview/ · https://www.reddit.com/r/dionapp/comments/1uq27s2/mini_preview_in_epg/ · https://iptvx.app/features/feature.html?feature=app-personalization
- **Analiz:** Oynatıcı EPG timeline’ı yalnızca o anki kanalın programlarını gösteriyordu; geniş EPG rehberi ise LiveTV ekranından açılıp odaklanan kanala ayrı preview akışı başlatıyordu. Player modal/full-screen iken LiveTV rehberine erişilemiyordu.
- **Uygulama:** Oynatıcıdaki EPG paneline kanal seçici eklendi. Kanalda gezinme yalnızca o kanalın EPG listesini yükler; VLC’de çalan mevcut kanal değiştirilmez. “Bu Kanalı İzle” eylemiyle yayın açıkça değişir. iOS ve tvOS aynı TCA durumunu kullanır.
- **Kalite düzeltmeleri:** Canlı kanallar playlist yüklendiğinde cache’lenir; tvOS picker lazy render edilir ve EPG focus section’ı açılış odağını belirleyip kapanışta önceki odağa döner. EPG yükleme efektleri kanal değişimi, kapanış ve yayına geçişte iptal edilir; stale yanıtlar UI’yı güncellemez.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iOS Simulator ve tvOS Simulator Release compile-only Xcode build’leri exit code 0 ile tamamlandı. Xcode mevcut Swift 6 concurrency uyarıları ve bir script-phase notu yazdı; derleme hatası yok. Akış ve test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Reviewer onayladı; yalnızca Xcode derlemeleri alındı.

### 29. [DONE] Kanal Bazlı Catch-up Zaman Ofseti
- **Bulgu:** Farklı sağlayıcıların arşiv zaman farklarını kanal başına düzeltme ihtiyacı; UHF bunu kanal bilgi düzenleme ekranına ekledi.
- **Canlı keşif (23 Ekim 2026):** UHF App Store sürüm notları desteklenen kanala uzun basıp Edit Information içinden kanal bazlı catch-up offset ayarını doğruluyor. Reddit kullanıcısı archive stream’in EPG’ye göre saatler kaydığını, kanal veya playlist seviyesinde time shift gerektiğini bildiriyor.
- **Kaynaklar:** https://apps.apple.com/pl/app/uhf-love-your-iptv/id6443751726?platform=ipad · https://www.reddit.com/r/IPTVGroupBuy/comments/1indo6l/
- **Analiz:** Catch-up URL’leri Player, EPG Guide ve LiveTV EPG timeline’da ayrı ayrı oluşturuluyor. Per-channel EPG shift alanı arşiv URL’sinde kullanılmıyor ve arşiv saat düzeltmesi olarak tekrar kullanılması EPG ile catch-up ayarlarını birbirine bağlardı; M3U catch-up template playback yolu mevcut akışta kapsam dışı.
- **Uygulama:** `CustomEPGMappingClient` içinde kanal ID’sine göre kalıcı, ±12 saat sınırlandırılmış ayrı catch-up ofseti eklendi. Oynatıcıdaki Arşiv Zaman Çizelgesi paneline kanal başına saat düzeltme kontrolleri kondu. Üç Xtream catch-up URL üreticisi arşiv başlangıcına bu ofseti uyguluyor; EPG görüntüleme saatleri ve program süresi değişmiyor.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iOS Simulator ve tvOS Simulator Release compile-only Xcode build’leri exit code 0 ile tamamlandı. Xcode mevcut Swift 6 concurrency uyarıları ve SwiftFormat script-phase notu yazdı; derleme hatası yok. Akış ve test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Reviewer onayladı; yalnızca Xcode derlemeleri alındı.

### 30. [DONE] Canlı Eşleşen Alternatif Kaynağa Kesintisiz Geçiş
- **Bulgu:** Aynı kanalın alternatif canlı kaynaklarını oynatıcıdan, yayın akışını kapatmadan seçme; IPTVX’in son sürüm notlarında yer alıyor.
- **Canlı keşif (23 Ekim 2026):** IPTVX 23.3 sürüm notları oynatıcı içinden eşleşen Live TV kanallarına geçişi doğruluyor. Kullanıcı örneği aynı maçın farklı sağlayıcılarda farklı yayınlara yönlenebildiğini gösteriyor.
- **Kaynaklar:** https://apps.apple.com/rs/app/iptvx/id1451470024?platform=tv · https://www.reddit.com/r/IPTVGroupBuy/comments/1ihdujj/
- **Analiz:** Mevcut player sidebar’ı tüm yüklü kanal satırlarını gösteriyor; aynı başlıklı varyantı bulmak için özel filtre veya kaynak grubu yok. Sağlıklı akışta da seçilebilen kaynak grupları ekleniyor. Stream değişimi oynatıcı ekranını kapatmadan yapılacak ancak player yeniden başlatıldığı için kısa tamponlama aralığı olabilir.
- **Uygulama:** Player kanal çekmecesine yalnızca mevcut kaynakla tam eşleşen, canlı ve farklı ID’li varyantlar varsa görünen “Alternatif Kaynaklar” filtresi eklendi. Eşleştirme kalite/codec token’larını temizleyip kalan başlıkların tamamını karşılaştırıyor; kanal adındaki tekil H/264/265 gibi token’lar korunuyor. Bir kaynak seçilince mevcut Player route içinde kanal değişiyor; gerçek stream restart’ı nedeniyle kısa buffering olabilir.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iOS Simulator ve tvOS Simulator Release compile-only Xcode build’leri exit code 0 ile tamamlandı. Xcode mevcut Swift 6 concurrency uyarıları ve SwiftFormat script-phase notu yazdı; derleme hatası yok. Akış ve test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Reviewer onayladı; yalnızca Xcode derlemeleri alındı.

### 31. [DONE] Dashboard Raflarını Hızlı Açılış için Önbellekleme
- **Bulgu:** Son aktif playlist zaten `PlaylistRepository` ile kalıcı tutuluyor ve açılışta otomatik seçiliyor; bu nedenle yeni playlist açılış tercihi eklemek mevcut davranışı yineleyecekti. Profil seçimi ebeveyn/çocuk profili güvenliği için korunmalı. Gerçek gecikme kaynağı Dashboard’ın her uygulama açılışında üç tam kataloğu tekrar istemesi.
- **Canlı keşif (23 Ekim 2026):** IPTVX 23.2 sürüm notları başlangıçta son playlist’i otomatik açma tercihini doğruluyor. Büyük playlist’lerin açılışta gereksiz yenilenmesiyle ilgili Apple TV kullanıcı şikayeti de hızlı açılış / manuel kontrol ihtiyacını destekliyor.
- **Kaynaklar:** https://apps.apple.com/ly/app/iptvx/id1451470024?platform=tv · https://www.reddit.com/r/IPTV_Help_Desk/comments/1ufhnhh/
- **Analiz:** `DashboardFeature.onAppear` boş durumla oluşturulduğunda tüm canlı yayın, VOD ve dizi kataloglarını paralel indiriyor. Kalıcı catalog cache yok. Önceki öneri, mevcut playlist auto-seçimi nedeniyle tekrar olurdu; profil atlama da ebeveyn denetimi katmanını bozardı.
- **Kapsam:** Playlist ve yetişkin içeriği filtre tercihine göre anahtarlandırılan küçük Dashboard raf snapshot’ını kalıcı tut; sonraki açılışta rafları hemen gösterip güncel içerikleri arka planda yenile. Tam kataloğu kalıcı saklama bu madde kapsamında değil.
- **Uygulama:** Dashboard’ın ilk çiziminde seçili playlist ve yetişkin filtresine ait en son raf snapshot’ı yükleniyor; tam katalog arka planda yenileniyor. Snapshot playlist UUID’si ve filtre durumu ile ayrılıyor, iOS dosya koruması uygulanan Caches dosyasında saklanıyor. Her raf yalnızca kendi endpoint’i başarılıysa güncelleniyor; başarısız endpoint eski rafı/cache’i boşaltmıyor. Yanıtlar playlist, filtre ve istek UUID’si ile doğrulanıp eski istekler eleniyor. Dashboard tekrar açıldığında 15 dakikayı geçen raflar yenileniyor. Cache görüntülenmeden önce güncel yetişkin sınıflandırması tekrar uygulanıyor.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iOS Simulator ve tvOS Simulator Release compile-only Xcode build’leri exit code 0 ile tamamlandı. Xcode projede mevcut Swift 6 concurrency uyarıları ve SwiftFormat script phase notu yazdı; derleme hatası yok. Akış/test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Reviewer onayladı; yalnızca Xcode derlemeleri alındı.

### 32. [DONE] Profil Avatarı Seçimi ve Görünüm Kişiselleştirme
- **Bulgu:** Tema rengi ve uygulama simgesi ayarları zaten var; yeni profil yaratırken avatar seçilemiyordu. Yeni profil formuna mevcut `UserProfile.avatarIcon` alanına kaydeden yerel SF Symbols avatar kataloğu eklendi.
- **Canlı keşif (23 Ekim 2026):** IPTVX 24.1.1 sürüm notları tema görselleri/animasyonları ve add-on görsellerini, 24.1.3 ise playlist avatarı ve tema yüzeylerini iyileştirdi. IPTVX’in resmi add-on sayfası temaların skin, ikon, avatar ve arka planı paket olarak uyumlu hale getirdiğini doğruluyor. Mevcut PureIPTV app icon/accent-color seçimini ve UserProfile.avatarIcon alanını da taradım.
- **Uygulama:** `ProfileAvatarCatalog` whitelist’i ve çocuk/yetişkin varsayılan avatarları eklendi; TCA aksiyonu seçimi doğrulayıp saklıyor. iOS’ta erişilebilir etiket ve seçili durumlu avatar ızgarası, tvOS’ta odak gezintili yatay seçici eklendi. Profil modu değişince yalnızca varsayılan avatar otomatik değişiyor; özel seçim korunuyor.
- **Kaynaklar:** https://apps.apple.com/us/app/iptvx/id1451470024 · https://iptvx.app/addons/index.html · https://iptvx.app/features/index.html
- **Doğrulama:** PR Reviewer `[APPROVED]`; iOS Simulator ve tvOS Simulator Release compile-only Xcode build’leri exit code 0 ile tamamlandı. Projedeki mevcut Swift 6 concurrency uyarıları ve SwiftFormat script-phase notu vardı; derleme hatası yok. Akış/test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Reviewer onayladı; yalnızca Xcode derlemeleri alındı.

### 33. [DONE] Xtream İçe Aktarma ve Kategori Tutarlılık Tanılaması
- **Bulgu:** Kullanıcı değerlendirmeleri bazı dizi ve filmlerin diğer oynatıcılarda görünmesine rağmen uygulamada eksik olduğunu bildiriyor. Kod taramasında canlı/VOD/dizi Xtream DTO’larının `category_id` değerini zorunlu String çözmesi, sağlayıcı sayı/null/eksik değer gönderdiğinde bütün yanıt dizisinin decode edilmesini engelliyor.
- **Canlı keşif (23 Ekim 2026):** Xtream Player API endpoint referansı tüm katalog uçlarının `category_id` filtresini isteğe bağlı desteklediğini gösteriyor; kategori alanının eksik olması filtresiz listede öğeyi kaybetmek için neden olmamalı. UHF App Store değerlendirmesi yaklaşık 12 film/dizinin bir başka ücretsiz oynatıcıda görünürken UHF’te çıkmadığını bildiriyor.
- **Kaynaklar:** https://github.com/worldofiptvcom/xtream-codes-api/blob/master/docs/player-api/overview.md · https://github.com/worldofiptvcom/xtream-codes-api/blob/master/docs/player-api/endpoint-reference.md · https://apps.apple.com/us/app/uhf-love-your-iptv/id6443751726?platform=ipad&see-all=reviews
- **Uygulama:** `XtreamDTOValueDecoder` üç katalog DTO’sunda `category_id` alanını string veya integer olarak okur; eksik/null/başka tür değerlerde boş kimliğe düşürüp canlı, VOD ve dizi öğelerinin tüm yanıt decode’unu korur.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iOS Simulator ve tvOS Simulator Release compile-only Xcode build’leri exit code 0 ile tamamlandı. Projedeki mevcut Swift 6 concurrency uyarıları ve SwiftFormat script-phase notu vardı; derleme hatası yok. Akış/test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Reviewer onayladı; yalnızca Xcode derlemeleri alındı.

### 34. [DONE] İndirme Kuyruğu için Canlı Aktivite ve Sıralı Devam
- **Bulgu:** IPTVX’in 25 sürüm duyurusu ve FAQ’sı arka plan indirme kuyruğu, otomatik devam/yeniden deneme ve Live Activity ilerleme görünümünü anlatıyor. Kod taramasında PureIPTV’nin background URLSession görev açıklamalarına indirme metadata’sı yazdığı, ancak uygulama yeniden açılınca `DownloadManager` içindeki boş sözlükleri URLSession’ın devam eden görevlerinden geri kurmadığı görüldü. Bu nedenle devam eden indirmeler ekran açılana dek görünmüyor; sonrasında da yönetici ilerleme yayınlamıyor.
- **Canlı keşif (23 Ekim 2026):** IPTVX’in 25 sürüm yazısı iOS Downloads ekranında transfer kontrolü ve tamamlanan içerikleri ayırıyor. Resmi FAQ otomatik kuyruk devamını ve Live Activities durumunu belirtiyor.
- **Kaynaklar:** https://iptvx.app/newsroom/iptvx-25-for-you-redesign/ · https://iptvx.app/faq/index.html
- **Uygulama:** `DownloadManager.getActiveDownloads()` background URLSession görevlerini ilk çağrıda geri yükleyip `taskDescription` metadata’sı ve byte sayaçlarıyla aktif durum yayınlıyor. Eşzamanlı restore/cancel/complete yarışları geçici invalidation kümesi ve mevcut ID önceliğiyle uzlaştırılıyor.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iOS Simulator ve tvOS Simulator Release compile-only Xcode build’leri exit code 0 ile tamamlandı. Projedeki mevcut Swift 6 concurrency uyarıları ve SwiftFormat script-phase notu vardı; derleme hatası yok. Akış/test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Reviewer onayladı; yalnızca Xcode derlemeleri alındı.

### 35. [DONE] Kullanıcının Sağladığı Catch-up Süresini Keşfetme
- **Bulgu:** Xtream `tv_archive_duration` ve M3U `catchup-days` sağlayıcının gün cinsinden arşiv derinliğini taşıyor. `MediaModels.Item.tvArchiveDuration` alanı akıştan geçiriliyor ancak EPG ve kanal kartları sadece genel catch-up rozeti göstererek mevcut bilgiyi kullanıcıdan saklıyor.
- **Canlı keşif (24 Ekim 2026):** Xtream/M3U catch-up açıklamaları kanal arşiv derinliğinin sağlayıcıdan geldiğini ve oynatıcının bunu gösterge olarak kullanabileceğini teyit ediyor. Neverlag’in ürün belgesi kanal başına “Archive · N days” görünümünü sunuyor; kullanıcılar da EPG’nin sağlayıcıdaki geçmiş günleri göstermediğini bildiriyor.
- **Kaynaklar:** https://uniplayer.net/docs/specs/catchup/ · https://neverlag.app/archive-catch-up/ · https://www.reddit.com/r/appletv/comments/1hlb7nk/just_tried_swiptv_app_and_its_my_new_favorite_app/
- **Uygulama:** Paylaşılan `CatchUpBadge` isteğe bağlı arşiv gününü kompakt olarak gösteriyor ve VoiceOver için tam yerelleştirilmiş arşiv ifadesi sağlıyor. Kanal kartları ve EPG satırı sağlayıcı değerini kullanıyor; EPG satırı tek erişilebilir öğe ve okunaklı 10pt metin olarak sunuluyor. Bilinmeyen/boş sürelerde mevcut genel catch-up göstergesi kalıyor.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iOS Simulator ve tvOS Simulator Release compile-only Xcode build’leri exit code 0 ile tamamlandı. Projedeki mevcut Swift 6 concurrency uyarıları ve SwiftFormat script-phase notu vardı; derleme hatası yok. Akış/test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Reviewer onayladı; yalnızca Xcode derlemeleri alındı.

### 36. [DONE] Canlı Yayın Duraklatma ve Yerel Geri Sarma Tamponu — uygulanabilirlik kararı
- **Bulgu:** Apple TV’de kullanıcılar canlı yayın duraklatıldığında konum göstergesi/geri sarma olmamasını, başka platformlarda pause/rewind çalışmasını bildiriyor. PureIPTV’de VLC’nin canlı yayın state/position API’si var, fakat normal network buffer gerçek DVR zaman çizgisi değil; anlamlı geri sarma için dosya/segment yakalama, süre ve depolama sınırı, seek destekleme ve canlı noktaya dönüş yönetimi gerekiyor.
- **Canlı keşif (24 Ekim 2026):** UHF Apple TV kullanıcısı pause çalışırken timeline/geri sarma olmadığını bildiriyor. Ayrı bir Apple TV tartışması pause’un platform/uygulama desteğini soruyor; hizmet değiştirme iddiası kaynakla doğrulanmadığı için çıkarıldı. OrbitAI sayfası yerel HLS/MPEG-TS tamponu için rakip tasarım örneğidir, SwiftVLC uyumluluğunun kanıtı değildir.
- **Kaynaklar:** https://www.reddit.com/r/uhf_app/comments/1o4d2da/appletv_os_skip_forward_backforward_not_possible/ · https://www.reddit.com/r/localtvplus/comments/1u5jgbv/pause_rewind_on_apple_tv/ · https://orbitai.tv/en/docs/timeshift-catch-up
- **Kod taraması:** Player VLC için pause, relative seek ve buffer-health metriklerini sunuyor; `totalTime == 0` canlı durumda scrubber’ı gizliyor. Entegrasyondaki mevcut network buffer göstergesi local DVR kapasitesi sağlamıyor. Güvenli kapsam için önce SwiftVLC/libVLC’nin iOS/tvOS’ta erişilebilir kayıt/caching kabiliyetini ve depolama politikasını araştırmak gerekiyor.
- **Paket incelemesi:** SwiftVLC `Player.startRecording(to:)` kaydı dosyaya başlatıp durduruyor; oynatılan canlı stream için döngüsel seek tamponu veya canlı noktaya dönme API’si sunmuyor. Uygulamanın `LocalDVRManager` da URLSession’dan ayrı `.ts` dosyası yazıyor ve VLC playback’ine bağlanmıyor. Bu iki yol kayıt işlevi, canlı time-shift değildir.
- **Sonuç:** Mevcut SwiftVLC entegrasyonunda bounded segment-ring buffer, VLC’ye seek edilebilir kaynak, dosya yaş/kapasite eviction’ı ve live-edge geçişi bulunmuyor. UI-only scrubber yanlış seek vaadi olur. Bu nedenle bu altyapıyla özellik için **NO-GO**; ayrı playback/DVR mimarisi gerekir. Kullanıcı akışları çalıştırılmadı. **Canlı pause/rewind özelliği gönderilmedi.**
- **Durum:** `[DONE]` — yalnızca uygulanabilirlik kararı kapatıldı; DVR özelliği tamamlanmadı.

### 37. [IN_PROGRESS] Hatalı Xtream Bölümü İçin Tekrar Dene
- **Bulgu:** IPTVX 24.3.1/24.3.2 sürüm notları, yüklenemeyen Xtream bölümüne playlist’in tamamını yeniden yüklemeden bölüm bazlı Retry eylemi eklediğini belirtiyor. Bu, büyük kataloglarda hata kurtarmayı daha hızlı ve düşük maliyetli yapıyor.
- **Kaynak:** https://apps.apple.com/de/app/iptvx/id1451470024?platform=tv
- **Kod incelemesi:** Live TV, VOD ve Series kategori istekleri hataları boş listeye çeviriyordu; bu yüzden ağ/API hatası “kategori yok” gibi görünüyordu. Mevcut reducer’lar kategori yükleme hatasını `errorMessage` durumuna iletiyor ve `reloadCategories(config:)` ile yalnız o içerik türünün kategori endpoint’ini tekrar çağırıyor.
- **Uygulama:** iOS ve tvOS kategori boş durumlarına bölüm bazlı Retry eylemi eklendi. Başarısız ilk yükleme artık kategorileri sessizce boş göstermiyor; hata ve retry butonu gösteriliyor. Retry sırasında mevcut kategoriler korunuyor ve yükleme göstergesi yalnız ilk boş yüklemede çıkıyor. Ortak empty-state metni, ikon ve buton ölçüleri Dynamic Type ile ölçekleniyor.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iOS 26.5 iPhone 17 Release ve tvOS 26.5 Simulator Release Xcode build’leri exit code 0 ile tamamlandı. Mevcut Swift 6 concurrency uyarıları derleme çıktısında yer aldı. Akış veya test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Live TV, VOD ve Series kategori hataları için yerel retry eklendi; reviewer onayladı.

### 38. [IN_PROGRESS] Playlist Başına Özel User-Agent
- **Bulgu:** IPTVX 24.3.1/24.3.2 sürüm notları hazır User-Agent seçeneklerine ek olarak özel değer girişi sunduğunu bildiriyor. Sağlayıcı uyumluluğunda istemci başlığını değiştirmek kullanıcıya pratik bir çözüm veriyor.
- **Kaynak:** https://apps.apple.com/de/app/iptvx/id1451470024?platform=tv
- **İnceleme odağı:** `UserAgentManager` mevcut ortak başlık kaynağı; tercih playlist bazında saklanıp Xtream, M3U, catch-up ve artwork isteklerinde tutarlı kullanılabilir.
- **Uygulama:** Playlist başına özel User-Agent saklama/düzenleme ve doğrulama eklendi; Xtream/M3U istekleri, player/VLC, preview, prebuffer, downloads ve Kingfisher artwork istekleri bu değeri kullanıyor. Aktif playlist değiştirilince Home, mini-player ve açık player route’ları yeni başlıkla güncelleniyor. Artwork cache anahtarları URL ve UA’yı kapsıyor.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iPhone 17 / iOS 26.5 Release ve tvOS Simulator Release Xcode derlemeleri başarılı (`BUILD SUCCEEDED`). `git diff --check` başarılı. Yalnızca derleme yapıldı; uygulama akışı ve test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Reviewer onayladı; yalnızca Xcode derlemeleri alındı.

### 39. [DONE] VOD için Daha Büyük Ağ Tamponu Seçeneği
- **Bulgu:** IPTVX 24.3.1/24.3.2 sürüm notları Metal oynatıcıya daha akıcı oynatma için isteğe bağlı büyük tampon modu eklediğini bildiriyor.
- **Kaynak:** https://apps.apple.com/de/app/iptvx/id1451470024?platform=tv
- **Kod taraması:** `BufferProfile` için 1/3/8 saniyelik model ve UserDefaults kaydı vardı; ayar satırı ve VLC medya seçeneğine bağlantısı yoktu. SwiftVLC `Media.addOption(_:)` ile `:network-caching=<ms>` seçeneğini destekliyor.
- **Uygulama:** Ayarlara film/dizi için 1/3/8 saniyelik arabellek seçimi ve gecikme açıklaması eklendi; seçili değer geri yükleniyor, bozuk/eksik kayıt 3 saniyeye düşüyor. Normal VOD oynatımı ve yeniden bağlanma VLC medya nesnesine seçilen değeri iletiyor. Canlı, catch-up ve MultiView çağrıları varsayılan VLC tamponunda kalıyor.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iPhone 17 / iOS 26.5 Release ve tvOS Simulator Release Xcode build’leri başarılı (`BUILD SUCCEEDED`). `git diff --check` başarılı. Yalnızca derleme yapıldı; uygulama akışı ve test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Reviewer onayladı; yalnızca Xcode derlemeleri alındı.

### 40. [DONE] Oyuncu İçinden Playback Engine Seçimi — uygulanabilirlik kararı
- **Bulgu:** IPTVX 22.0.1 sürüm notları oynatıcı içinde yalnız mevcut oturuma uygulanan motor değiştirme seçeneğini tanıtıyor; resmi App Store açıklaması da çoklu oynatıcı uyumluluğunu vurguluyor.
- **Kaynaklar:** https://apps.apple.com/us/app/iptvx/id1451470024?platform=tv · https://apps.apple.com/de/app/iptvx/id1451470024?platform=tv
- **İnceleme odağı:** PureIPTV’nin VLC sarmalayıcısı içerik/codec uyumsuzluğunda alternatif playback backend açabiliyor mu; sağlayıcı parolası ve playback konumu dışarı sızmadan oturuma özel seçim tasarla.
- **Kod incelemesi:** `PlayerClient`, `PlayerFactoryClient`, Player view’ları, PiP render yüzeyi ve `PlayerFeature` doğrudan SwiftVLC `Player`, `VideoView`, olay, track, EQ ve stats API’lerine bağlı. `ExternalPlayerManager` ayrı uygulama açıyor ve credential içeren stream URL’sini panoya kopyalıyor; bu, oturum içi backend seçimi değil.
- **Uygulanabilirlik kararı:** Küçük bir ayar/eylem bu gereksinimi güvenli biçimde karşılayamaz. Gelecekteki ayrı mimari işi backend-neutral playback protokolü, engine-specific render/PiP/audio lifecycle, normalize event/capability modeli ve credential-safe harici handoff gerektirir. Mevcut harici URL şemaları alternatif motor gibi sunulmamalı.
- **Doğrulama:** PR Reviewer `[APPROVED — NO-GO]`; kaynak incelemesi. Kullanıcı akışı veya test çalıştırılmadı; kod değişmedi.
- **Durum:** `[DONE]` — Mevcut mimaride bu kapsamla uygulanmaması reviewer tarafından onaylandı; backend soyutlaması ayrı iş olarak gerekli.

### 41. [DONE] Arama Sonuçlarında EPG Programı ve Kayıt Eylemi — uygulanabilirlik kararı
- **Bulgu:** IPTVX 22.3 sürüm notları arama sonuçlarındaki EPG programları için doğrudan kayıt seçeneklerini eklediğini belirtiyor. Program araması ile eylem arasındaki gezinmeyi azaltıyor.
- **Kaynak:** https://apps.apple.com/us/app/iptvx/id1451470024?platform=tv
- **İnceleme odağı:** Global arama EPG programlarını içeriyor mu; program satırından mevcut catch-up oynatma veya kayıt altyapısı kullanılabiliyor mu? Kayıt varsa UHF Server ve yerel DVR kapsamlarını ayır.
- **Kod incelemesi:** Global Search yalnız kanal/VOD/dizi kataloglarını indeksliyor; “EPG Programları” filtresi eşleşen programları değil EPG ID’si olan kanalları sayıyor. Kısa EPG/catch-up yalnız oynatıcıdaki seçili kanal için çalışıyor. UHF recording client yok. `LocalDVRManager` çağrı yeri olmayan, gözlemlenmeyen ve yalnız iptal/ağ bitimine kadar ham URLSession yanıtı yazan bir sınıf; planlı bitiş, TCA lifecycle ve playlist UA taşıması yok.
- **Uygulanabilirlik kararı:** Güvenilir tam özellik küçük bir search UI işi değil; playlist/kanal/tarih aralığı EPG index/cache/cancellation ve planlı kayıt için kalıcı, gözlemlenebilir, iptal edilebilir bir kayıt motoru gerektiriyor. Mevcut ham stream writer’ı arama eylemine bağlamak yanıltıcı ve güvenilmez olur.
- **Doğrulama:** PR Reviewer `[APPROVED — NO-GO]`; analist ve reviewer kaynak incelemesi. Kod değişmedi; yalnız akış/test/derleme çalıştırılmadı.
- **Durum:** `[DONE]` — Tam program arama/kayıt mimarisi ayrı iş olarak gerektiğinden bu kapsam reviewer tarafından NO-GO onaylandı.

### 42. [DONE] EPG Yüklenirken Boşlukları Azalt ve Kısmi Sonuç Göster
- **Bulgu:** IPTVX 22.2 sürüm notları büyük EPG yüklemesinde placeholder boşluklarını azaltıp rehber güvenilirliğini iyileştirdiğini; UHF kullanıcıları ise Apple TV’de EPG’nin çok uzun sürmesi ve cihazlar arasında eski/farklı bilgi göstermesi sorununu paylaşıyor.
- **Kaynaklar:** https://apps.apple.com/us/app/iptvx/id1451470024?platform=tv · https://www.reddit.com/r/uhf_app/comments/1q1edqo/ · https://www.reddit.com/r/uhfapp/comments/1x5esu8/epg_not_fully_loading_on_apple_tv/
- **Uygulama:** EPG yenilemesi başarılı kanal verisini ekranda tutup her kanal sonucunu geldikçe işler. Yenileme aynı kanaldaki önceki isteği iptal edip yeni istek nesliyle değiştirir; eski yanıtlar atlanır. Senkronizasyon yalnızca kendi bekleyen kanal yanıtları bitince tamamlanır; eski durum mesajı zamanlayıcısı yeni yenilemeyi temizleyemez.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iPhone 17 / iOS 26.5 ve tvOS Release Xcode build; `git diff --check`. Kullanıcı isteği gereği test ve uygulama akışı çalıştırılmadı.
- **Durum:** `[DONE]` — Kısmi EPG yenileme ve istek nesli koruması tamamlandı.

### 43. [DONE] Canlı Önizlemeyi Tam Ekrana Yeniden Bağlanmadan Terfi Ettir
- **Bulgu:** IPTVX 22.3 App Store notları önizlenen kanalı tam ekrana geçirirken mümkün olduğunda yeniden bağlantıyı önlediğini ve kategori değişiminde eski preview akışını kapattığını bildiriyor.
- **Kaynak:** https://apps.apple.com/us/app/iptvx/id1451470024?platform=tv
- **Uygulama:** EPG preview aynı SwiftVLC `Player` örneğini `PlayerClient`’a devrediyor; tam ekran açılışında eş URL için yeni `play` çağrısı atlanıp mevcut playback state reconcile ediliyor. Devredilen kanal Start Muted tercihini koruyor. Önizleme aynı kanal/URL değilse normal stop-then-play fallback’i uygulanıyor; catch-up dönüşü playlist User-Agent değerini koruyor.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iPhone 17 / iOS 26.5 ve tvOS Release Xcode build; `git diff --check`. Kullanıcı isteği gereği test ve uygulama akışı çalıştırılmadı.
- **Durum:** `[DONE]` — EPG mini-preview’den aynı oynatıcıyla tam ekrana geçiş tamamlandı.

### 44. [DONE] TV Rehberinde EPG Yenileme ve Yaş Damgası
- **Bulgu:** Kullanıcılar Apple TV rehberinin hiç yüklenmemesi veya iOS cihazdaki rehberden farklı/eski içerik göstermesi sorununu bildiriyor; sağlayıcıyı silip tekrar eklemenin geçici çözüm olduğuna dair rapor da var.
- **Kaynaklar:** https://www.reddit.com/r/uhfapp/comments/1x5esu8/epg_not_fully_loading_on_apple_tv/ · https://www.reddit.com/r/uhf_app/comments/1q1edqo/epg_on_apple_tv/
- **İnceleme odağı:** Kullanıcıya playlist/EPG kaynağı başına son başarılı güncelleme zamanı, kısmi hata ve yalnız EPG’yi yenile eylemi sun; tam playlist silme/yeniden ekleme gerektirmesin.
- **Uygulama:** Son başarılı yenileme zamanı playlist ID’sine göre kalıcı saklanıyor ve TV rehberinde geri yükleniyor. Yenileme yalnız aktif playlist’in XMLTV cache’ini temizliyor; başarılı/başarısız kanal sayılarıyla kısmi ve tam hata durumu gösteriliyor. Xtream’ın iki EPG endpoint’i de başarısız veya çözümlenemeyen yanıt verirse, M3U’da kaynak yoksa ya da XMLTV parse edilemezse hata artık boş program listesi gibi raporlanmıyor; geçerli boş program yanıtı başarı olarak kalıyor.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iPhone 17 / iOS 26.5 Release ve tvOS Release Xcode build’leri `BUILD SUCCEEDED` ile tamamlandı; ilk tvOS denemesi geçici DerivedData alanı yetersizliğinde durdu, geçici build çıktıları temizlendikten sonra mevcut DerivedData ile başarılı oldu. `git diff --check` başarılı. Yalnızca Xcode derlemeleri alındı; uygulama akışı/test çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — Reviewer onayladı.

### 45. [DONE — NO-GO] EPG Programında Kayıt Süresini Serbest Belirleme
- **Bulgu:** UHF 1.95 sürüm notları kayıt süresini 15 dakikalık aralıklara bağlı olmadan seçme ve 24 saate kadar kayıt başlatma özelliğini duyuruyor.
- **Kaynak:** https://apps.apple.com/us/app/uhf-love-your-iptv/id6443751726?platform=mac
- **İnceleme odağı:** Uygulamadaki `LocalDVRManager` yalnızca ham URL dosyasını kaydediyor; EPG program zamanlaması, uçta pay bırakma ve kayıt çakışması çözümleme ayrı TCA akışı gerektirir.
- **Kod incelemesi:** EPG satırlarında kayıt eylemi yok; `ReminderClient` yalnızca bildirim planlıyor. `LocalDVRManager` çağrı yeri olmayan, tek bir manuel stream’i ikinci bir URLSession ile kopyalayan yardımcı sınıf; EPG program zamanı, süre, zamanlanmış iş, arka plan kaydı, kota/eviction veya playlist User-Agent desteği yok. Catch-up yalnızca hemen oynatma yapıyor ve provider/server DVR istemcisi bulunmuyor.
- **Karar:** Reviewer `[NO-GO]` bulgusunu onayladı. Mevcut altyapı zamanlanmış EPG kaydını güvenli biçimde karşılayamaz; bunun için ayrı provider/server DVR entegrasyonu veya kapsamı açıkça “aktif kanalı belirli süre yerel kaydet” ile sınırlı arka plan/recording mimarisi gerekir. Kod değişmedi; uygulama akışı/test/build çalıştırılmadı.
- **Durum:** `[DONE — NO-GO]` — Reviewer onayladı; kapsam mevcut kodla uygulanabilir değil.

### 46. [DONE] Kanal Geçişi Gecikmesini Sağlayıcıya Göre Ayarlama
- **Bulgu:** UHF 1.101.2 sürüm notları, kanal değişiminde aktif bağlantı sorunları yaşayan kullanıcıların kapatılan ve açılan stream arasındaki gecikmeyi artırabilmesi için “Channel zapping delay” ayarı eklediğini bildiriyor.
- **Kaynak:** https://apps.apple.com/us/app/uhf-love-your-iptv/id6443751726?platform=mac
- **İnceleme odağı:** Hızlı geçiş isteyenleri yavaşlatmadan, bağlantı çakışan sağlayıcılar için playlist/sağlayıcı bazında geçiş gecikmesi sun; AFR tercihi ve alternatif-source değişimiyle etkileşimini kontrol et.
- **Uygulama:** Playlist bazında kapalı varsayılan 0–3000 ms gecikme; iOS’ta 250 ms adımlı Stepper, tvOS’ta aynı aralığı seçen Picker. Geçişte önceki stream durdurulur, iptal edilebilir gecikme beklenir ve seçili kanal kimliği tekrar doğrulanmadan yeni stream başlamaz. Yalnız aynı playlist içindeki manuel canlı kanal değişimine uygulanır.
- **Doğrulama:** PR Reviewer `[APPROVED]`; tvOS Release ve bağlı iOS 26.5 iPhone 17 Release build’leri başarılı. `git diff --check` temiz. Test ve uygulama akışı çalıştırılmadı.
- **Durum:** `[DONE]` — playlist’e özel geçiş ayarı, iptal güvenliği ve platform kontrolleri tamamlandı.

### 47. [DONE] Aktif Audio Session’da Gereksiz Kategori Değişimini Önle
- **Bulgu:** Kullanıcı iOS 26.5 iPhone 17 loglarında `setCategory` sırasında aktif AVAudioSession’ın main-thread hang uyarısını ve SwiftVLC kaynaklı `defaultToSpeaker`/`playAndRecord` kategori uyumsuzluğu hatasını paylaştı.
- **Kod incelemesi:** App `PlaybackAudioSession` mutasyonları seri arka plan kuyruğuna gönderiyor; kategori/mode/policy’yi her `setActive(true)` çağrısında tekrar kuruyordu. App target’ındaki Swift kaynaklarda `defaultToSpeaker` kullanılmıyor; PiP player’ları `.applicationManaged` SwiftVLC instance’ını kullanıyor. Kaynakta görünür kategori tekrarını azaltmak güvenli, repo dışı kategori hatasının kaynağını bu kodla belirlemek mümkün değil.
- **Uygulama:** Kategori, mode veya route-sharing policy istenen değerlerden farklıysa değiştirilecek; aynı ayar aktif oturuma tekrar uygulanmayacak.
- **Doğrulama:** PR Reviewer `[APPROVED]`; bağlı iOS 26.5 iPhone 17 için Release compile-only build exit code 0. Debug build, `TCACoordinators 0.16.0` bağımlılığında XCTest sembolleri çözülmediği için başarısız oldu. App akışı/test edilmedi.
- **Durum:** `[DONE]` — audio-session kategori ayarı idempotent hale getirildi; reviewer onayladı.

### 48. [DONE] Aktif Playlist EPG Program Rafı (Daraltılmış Kapsam)
- **Bulgu:** UHF 2.3.0, playlist’ler arasında etkinlik araması ve takip edilen takım/turnuvalar için Home etkinlik rafı ekledi.
- **Kaynak:** https://apps.apple.com/al/app/uhf-love-your-iptv/id6443751726?platform=tv
- **Canlı keşif:** App Store sürüm metni, etkinliğin playlist’ler arası canlı kanal bulduğunu söylüyor. Bir TiviMate kullanıcısı spor rehber verisinin bir uygulamada eksik, diğerinde bulunduğunu bildirmiş; bu, sağlayıcı EPG kapsamı değişkenliğinin sonucu etkileyebileceğini gösteriyor: https://www.reddit.com/r/TiviMate/comments/1sktke4/i_have_an_epg_question/
- **Kapsam kararı:** Kaynak kodunda bağlı etkinlik API’si veya kalıcı takım takip modeli yok; `SportsHubManager` EPG adlarından güvenilmez biçimde takım/lig çıkarıyor. Reviewer’ın önerisiyle yalnız aktif playlist’ten sınırlı EPG isteği yapıp sağlayıcının ham program başlıklarını kanal ve saatle göstereceğiz; takım takibi ve playlist’ler arası etkinlik araması yapılmayacak.
- **Güvenlik/perf sınırları:** Programlar doğrulanmış maç gibi etiketlenmeyecek; küçük kanal kümesi, sınırlı eşzamanlılık ve yenilemede iptal uygulanacak.
- **Uygulama:** Dashboard’a aktif playlist’in EPG verisinden kanal adı, ham program başlığı ve saat gösteren bir raf eklendi. En fazla 8 kanal sorgulanıyor; Xtream istekleri 2, M3U/XMLTV istekleri 1 eşzamanlı görevle sınırlandı. Raf Home bölüm tercihiyle gizlenebiliyor; oynatıcı olmayan hedefler ve sağlayıcının boş rehberi güvenli biçimde ele alınıyor. Yetişkin içerik tercihi veya playlist değişince EPG adayları ve eski sonuçlar geçersiz kılınıyor; iptal/stale-request kontrolleri eklendi.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iPhone 17 / iOS 26.5 Release ve tvOS Release Xcode build’leri `BUILD SUCCEEDED`; `git diff --check` temiz. Yalnız Xcode build alındı; test ve uygulama akışı çalıştırılmadı (kullanıcı talimatı).
- **Durum:** `[DONE]` — sınırlandırılmış aktif-playlist EPG rafı tamamlandı ve reviewer onayladı.

### 49. [DONE] VOD Zaman Çizelgesinde Önizleme Küçük Resimleri
- **Bulgu:** UHF’in App Store sürüm geçmişi, VOD scrub sırasında thumbnail önizlemesi sunduğunu belirtiyor; bu, kullanıcının hedef sahneye daha hızlı ulaşmasını sağlar.
- **Kaynak:** https://apps.apple.com/al/app/uhf-love-your-iptv/id6443751726?platform=tv
- **Canlı keşif (24 Ekim 2026):** UHF’in güncel App Store sürüm notları VOD scrub thumbnail’larını listeliyor; tvOS kullanıcıları başka bir oynatıcıda scrub önizlemesinin geri gelmesini talep etmiş, Swiptv 3.7.0 da Apple TV scrub preview’ını yeni özellik olarak duyurmuş. Kaynaklar: https://apps.apple.com/mm/app/uhf-love-your-iptv/id6443751726?platform=ipad · https://www.reddit.com/r/MovieBoxPro/comments/1ubx8wn/apple_tv_users_no_thumbnail_previews_while/ · https://www.reddit.com/r/Swiptv_Official/comments/1wcctt5/swiptv_v370_redesigned_apple_tv_player_scrubbing/
- **Kod incelemesi:** Uygulamanın scrub arayüzleri yalnız hedef zaman ve progress gösteriyordu. Reviewer, paketin `Media.thumbnail(at:width:height:crop:seekMode:timeout:instance:)` API’sini doğruladı; ayrı `Player` veya ana oynatıcı seek’i olmadan hedef kare üretebiliyor ve görev iptalini destekliyor.
- **Kapsam:** Ana player’a dokunmadan aynı VLC instance’ında istek başına 360×203 PNG üret; 300 ms debounce, cancellable latest-request-wins, global single-flight gate, 3 sn timeout ve tek görsellik bellek sınırı kullan. iOS sürükleme HUD’ı ve tvOS scrubber’ı thumbnail göstermeli; başarısız/seek edilemeyen provider’da zaman/progress scrubber’ı çalışmayı sürdürmeli. Herhangi bir seek veya item/screen değişimi eski isteği iptal etmeli.
- **Uygulama:** SwiftVLC `Media.thumbnail` aynı player instance’ında hedef kareyi alıyor; PlayerClient URL ve playlist User-Agent’ı ile çağırıyor. TCA 300 ms debounce, latest-request-wins, stale response ID, global cancellation-aware FIFO single-flight gate, 360×203 çıktı ve 3 sn timeout sağlıyor. iOS gesture scrub HUD’ı ve tvOS remote scrubber’ı kareyi göstermeye çalışıyor; hatada zaman göstergesi korunuyor. Seek, item değişimi ve ekran ayrılışı isteği iptal ediyor.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iPhone 17 / iOS 26.5 Release ve tvOS Release Xcode build’leri `BUILD SUCCEEDED`; `git diff --check` temiz. Yalnız build alındı; test ve uygulama akışı çalıştırılmadı.
- **Durum:** `[DONE]` — VOD scrub thumbnail desteği tamamlandı ve reviewer onayladı.

### 50. [DONE] İndirme Kuyruğunda Eşzamanlı İndirme Sınırı
- **Bulgu:** IPTVX 22.10.2, otomatik resume/retry ve Live Activity yanında isteğe bağlı eşzamanlı indirme sayısı ekledi.
- **Kaynak:** https://apps.apple.com/us/app/iptvx/id1451470024?platform=appleTV
- **Canlı keşif (24 Ekim 2026):** IPTVX’in güncel App Store notları isteğe bağlı eşzamanlı indirmeleri duyuruyor; resmi FAQ bunun iPhone/iPad’e özel olduğunu ve sağlayıcıların bağlantı sınırlarına dikkat edilmesi gerektiğini açıklıyor: https://apps.apple.com/us/app/iptvx/id1451470024?platform=mac · https://iptvx.app/faq/
- **Kod incelemesi:** `DownloadManager.startDownload` her background `URLSessionDownloadTask`’ını hemen `resume()` ediyor; başlatılmış işler için global admission cap yok. `taskDescription` zaten yeniden açılışta kullanılan metadata taşıyor ve `getAllTasks` arka plan görevlerini geri yüklüyor. Ayar yalnız iOS/iPadOS görünmeli; mevcut işler duraklatılmadan yalnızca yeni slot kabulünü sınırlamalı. Kuyruk suspended background task’lar olarak temsil edilip process relaunch sonrasında URLSession’dan restore edilmeli.
- **Kapsam:** iOS/iPadOS için varsayılan 1 ve kullanıcı seçeneği 1–4 eşzamanlı indirme; yeni/restore edilen suspended task’ları FIFO ile yalnız boş slota resume et. Limit düşürülürse fazla çalışan işler kesilmeden URLSession üzerinden askıya alınır ve yeniden kuyruğa alınır; arıza/iptal slotu bırakmalı. Aynı içerik yeniden başlatıldığında eski task callback’leri yeni işi, dosyayı veya SwiftData kaydını değiştirememeli. Mevcut URLSession identifier ve User-Agent metadata’sı korunmalı.
- **Uygulama:** Settings’te iOS/iPadOS için 1–4 seçimi ve UserDefaults kalıcılığı eklendi. DownloadManager yeni ve restore edilen task’ları suspended URLSession görevleriyle FIFO kuyruğunda tutuyor; limit değişiminde fazla çalışan task’ları askıya alıyor. Kuyruk satırında durum gösteriliyor; iptal/hata slotu serbest bırakıp sıradaki indirmeyi başlatıyor. Progress ve dosya tamamlama işlemleri taskIdentifier ile eşleştiriliyor; geçici dosya manager actor içinde kimlik doğrulamasından sonra kalıcı dosya ve SwiftData kaydına çevriliyor.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iPhone 17 / iOS 26.5 Release ve tvOS Release Xcode build’leri `BUILD SUCCEEDED`; `git diff --check` temiz. Yalnız build alındı; test ve uygulama akışı çalıştırılmadı.
- **Durum:** `[DONE]` — eşzamanlı indirme sınırı tamamlandı ve reviewer onayladı.

### 51. [DONE] Canlı Arama Sonuçlarında Hatırlatıcı Durumu
- **Bulgu:** IPTVX 22.10.2, Live TV arama kartlarında daha zengin program bilgisiyle birlikte hatırlatma eylemi ve planlandı durumunu sundu.
- **Kaynak:** https://apps.apple.com/us/app/iptvx/id1451470024?platform=appleTV
- **Canlı keşif (24 Ekim 2026):** IPTVX 22.10.3 duyurusu arama sonuçlarında hatırlatıcı action ve durumunu, resmi FAQ da EPG programına hatırlatıcı ekleme ve cihaz iznini doğruluyor: https://apps.apple.com/us/app/iptvx/id1451470024?platform=tv · https://iptvx.app/faq/
- **Kod taraması:** `EPGTimelineFeature` program hatırlatıcısını destekliyor; global `SearchFeature` canlı kartlarında ise EPG program nesnesi, scheduled ID state’i veya reminder action yoktu. Karttaki `matchedEPGTitle` alanı da arama indeksinde doldurulmuyordu. Timeline’daki optimistic state, izin reddedilince yanlış bell durumunda kalabiliyordu.
- **Kapsam:** iOS/tvOS canlı arama kartlarının küçük bir üst kümesine iptal edilebilir EPG zenginleştirmesi bağla; yaklaşan program varsa schedule/remove context action’ı ve scheduled bell göster. İzin reddi, başarısız zamanlama, hızlı tekrar dokunuş ve eski reminder-load cevabı UI durumunu bozmamalı. M3U EPG program ID’leri playlist+zaman üzerinden kararlı olmalı ki yeniden aramada durum korunabilsin.
- **Uygulama:** iOS/tvOS global canlı arama sonuçları ilk 6 kanal için EPG ile zenginleşiyor; arama değişince iptal ediliyor ve M3U XMLTV yükünün çoğalmaması için seri çalışıyor. Yaklaşan programlara hatırlatıcı ekle/kaldır menüsü ve kartta program/bell durumu eklendi. Arama ve TV rehberi ortak, uzunluk önekli playlist+kanal+program kimliği kullanıyor; yeni bildirim/cache kayıtları çakışmıyor. Bekleyen eylem ayrı gösteriliyor ve başarı yanıtı gelmeden scheduled bell görünmüyor. Eski sürümlerin playlist kapsamı içermeyen ham program kimlikleri görünür ve kaldırılabilir tutuluyor; eski kayıt için playlist eşleşmesi saklanmadığından bu fallback yalnız program ID’sine dayanıyor.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iPhone 17 / iOS 26.5 Release ve tvOS Release Xcode build’leri `BUILD SUCCEEDED`. İlk sandbox build’i GitHub DNS erişimi olmadığı için paketleri çözümleyemedi; mevcut Xcode Swift Package önbelleği kullanılarak iki build de başarıyla tamamlandı. `git diff --check` başarılı. Kullanıcı isteği gereği test ve uygulama akışı çalıştırılmadı.
- **Durum:** `[DONE]` — Canlı arama hatırlatıcıları tamamlandı ve reviewer onayladı.

### 52. [DONE] Kişiye Göre Ayarlanabilir Keşif Vitrini
- **Bulgu:** IPTVX 25 farklı izleme davranışından beslenen For You rafları sunuyor; UHF 2.0 hero vitrinin kişiselleştirilmesine ve kaldırılmasına izin veriyor.
- **Canlı keşif (24 Ekim 2026):** IPTVX For You açıklaması öneri satırlarının kütüphane geçmişi ve mevcut metadata’ya göre değiştiğini; UHF 2.0 kullanıcı duyurusu hero’nun Home customization’dan ayarlanabildiğini doğruluyor: https://iptvx.app/newsroom/iptvx-25-for-you-redesign/ · https://www.reddit.com/r/uhfapp/comments/1ww274e/new_uhf_update_200/
- **Kod taraması:** `SmartRecommendationEngine` ve “Sana Özel Öneriler” rafı mevcut; `HomeSectionManager` görünürlük/sıralama saklıyor ve `ModularHomeSettingsView` var. Ancak ayar ekranına hiçbir navigation/sheet bağlantısı yok, model yalnız 5 satır tanımlıyor; dashboard hero, öneri, canlı, devam etme, favoriler ve katalog raflarını sabit sırada çiziyor. `DashboardFeature` yalnız sports hub görünürlüğünü ayardan okuyor.
- **Kapsam:** Mevcut davranış tabanlı öneri algoritmasını koru; ana ekranda hero ve mevcut rafların gizlenip yeniden sıralanmasını iOS/tvOS’ta erişilebilir bir “Ana Ekranı Düzenle” ekranına bağla. Tercihler kalıcı kalsın; önceden kaydedilmiş beşli ayar dizileri yeni raflara güvenli varsayılan eklesin.
- **Uygulama:** iOS ve tvOS ana ekranlarına erişilebilir ayar girişi eklendi. Hero, devam etme, favoriler, canlı TV, spor, kişisel öneriler, yeni filmler ve diziler rafları kalıcı tercihe göre gizlenip sıralanabiliyor. Eski beşli tercih kayıtları yinelenen türleri temizleyip eksik rafları varsayılan sıralarına ekleyerek taşınıyor. tvOS’ta Siri Remote context menu ile bölüm sıralama, iOS’ta düzenleme modu bulunuyor. Hero gizlenince öne çıkan film yeni filmler rafında kaybolmuyor.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iPhone 17 / iOS 26.5 Release ve tvOS Release Xcode build’leri `BUILD SUCCEEDED`; `git diff --check` başarılı. Kullanıcı talimatı gereği test, kurulu uygulama akışı veya login akışı çalıştırılmadı.
- **Durum:** `[DONE]` — Reviewer onayladı; yalnızca Xcode derlemeleri alındı.

### 53. [DEFERRED] Web Konsolundan Playlist ve Yedek Yönetimi
- **Bulgu:** UHF’in App Store sürüm geçmişi, PRO kullanıcıları için playlist ve yedeklerin tarayıcıdan yönetildiği web konsolunu listeliyor.
- **Kaynak:** https://apps.apple.com/al/app/uhf-love-your-iptv/id6443751726?platform=tv
- **Mimari kararı:** Mevcut uygulamada playlist sırları iCloud Keychain’de; web oturumu, kimlik doğrulamalı backend veya güvenli browser-to-device eşleştirmesi yok. QR deep link’i yalnız kod üretiyor ve `setup` handler’ı bulunmuyor; `CloudKitBackupManager` çağrılmıyor, mevcut `.iptvbackup` yalnız tercihleri içeriyor. Reviewer `[NO-GO]`: bu altyapı olmadan sırları yeni web servisine açmak güvenli değil. Web konsolu, hesap/authorization ve credential-transfer tasarımı sağlanana kadar ertelendi. Yakın vadeli uygulanabilir alternatif, credential kapsamını açıkça belirleyen uygulama içi dışa/içe aktarma akışı.

### 54. [DONE] Film Ayrıntısında Sinematik Hero ve Hızlı Oynatım
- **Bulgu:** IPTVX 25, film ayrıntı sayfasını sinematik hero ile yeniden tasarlıyor; içerik bilgisinden oynatmaya geçişi kısaltıyor.
- **Kaynak:** https://iptvx.app/
- **Kod incelemesi:** iOS ve tvOS ayrıntı ekranlarında sinematik backdrop ve doğrudan Play/Resume eylemleri zaten var. iOS backdrop’un statik provider resmi `AsyncImage` ile yüklendiğinden, User-Agent isteyen playlist sunucularında poster yüklenemiyordu.
- **Kapsam:** Var olan hero ve hızlı oynatma hiyerarşisini koru; iOS statik backdrop isteğine playlist User-Agent’ını geçir ve başarısız provider fallback’ını diğer playlist görselleriyle tutarlı hale getir.
- **Uygulama:** `InlineTrailerHeroView` playlist User-Agent’ını alıp statik backdrop’u `PlaylistAsyncImage` ile yüklüyor; fragman oynatımı değişmedi.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iPhone 17 / iOS 26.5 Release ve tvOS Release Xcode build’leri `BUILD SUCCEEDED`. Projedeki mevcut Swift concurrency uyarıları dışında derleme hatası yok. Kullanıcı talimatı gereği test veya uygulama akışı çalıştırılmadı.
- **Durum:** `[DONE]` — Sinematik hero’daki provider görsel isteği düzeltildi, reviewer onayladı ve yalnızca Xcode derlemeleri alındı.

### 55. [IN_PROGRESS] Alternatif Dosya/Sürüm Seçimi Oynatmadan Önce
- **Bulgu:** UHF, Jellyfin/Emby/Plex öğesinde birden çok medya dosyası olduğunda oynatma öncesi seçim gösteriyor; farklı kalite sürümleri için benzer ihtiyaç ayrıca incelenebilir.
- **Kaynak:** https://apps.apple.com/al/app/uhf-love-your-iptv/id6443751726?platform=tv
- **Kod taraması:** VOD ayrıntısında sürüm/kalite seçici zaten mevcut ve varyantları katalog başlıklarından buluyor. İç içe substring eşleşmesi devam filmi/benzer başlıkları yanlış sürüm sayabiliyor; eşit kalite sıralaması deterministik değil; asenkron geçmiş yanıtı seçilmiş varyant kimliğini taşımadığından hızlı seçimde eski izleme konumunu gösterebiliyor.
- **Kapsam:** Yalnız normalize edilmiş tam başlık eşleşmelerini sürüm olarak grupla; kalite eşitliğinde tutarlı başlık/ID sırası uygula; izleme geçmişi yanıtını varyant kimliğiyle doğrula ve varyant değişimi/ekran kapanışında isteği iptal et.
- **Uygulama:** Sürüm listesi yalnız normalize edilmiş tam başlık eşleşmeleriyle oluşturuluyor; kalite, normalize başlık ve item ID üzerinden deterministik sıralanıyor. Seçilen sürüm geçmişi temizlenip ilgili ID ile yeniden yükleniyor; gecikmiş yanıtlar seçili VOD kimliğiyle doğrulanıyor ve ekran kapanırken/variant değişirken önceki istek iptal ediliyor. Saf sürüm model başlatıcısı ve parser’lar `nonisolated` yapılarak Swift 6 isolation uyarısı giderildi.
- **Doğrulama:** PR Reviewer `[APPROVED]`; iPhone 17 / iOS 26.5 Release ve tvOS Release Xcode build’leri `BUILD SUCCEEDED`. Kullanıcı talimatı gereği test veya uygulama akışı çalıştırılmadı.
- **Durum:** `[DONE]` — sürüm eşleşmesi, kararlı sıralama ve varyant geçmişi yarışları düzeltildi; reviewer onayladı.

### 56. [DONE] Fuzzy Search Alaka Düzeyi ve Sonuç Sıralama İyileştirmesi
- **Bulgu:** UHF’in App Store sürüm geçmişi, arama algoritmasının doğruluk ve alaka düzeyini geliştirdiğini belirtiyor; büyük playlist’lerde başlık/kanal/metadata ağırlıkları ölçülebilir.
- **Kaynak:** https://apps.apple.com/al/app/uhf-love-your-iptv/id6443751726?platform=tv
- **Kod taraması:** `FuzzySearchEngine` kanal drawer/MultiView için; `GlobalSearchEngine` iOS/tvOS ortak araması için kullanılıyor. Tek bir target kelimesi tekrar eden query token’larını birden fazla kez karşılayabiliyor; kısa 1–2 harfli arama kelime içi her alt parçayı bulabiliyor; typo fallback her adayda tam başlık Levenshtein’i hesaplıyor. Global aramada kategori eşleşmeleri başlıkla aynı 200 puanı alıyor, EPG başlığı skora katılmıyor, eşit puan sıraları kararsız ve büyük tarama yalnız başta/sonda iptal kontrolü yapıyor.
- **Uygulama:** Query token’ları ayrı target kelimelerini tüketiyor; kısa tek kelime araması yalnız kelime başlangıcında eşleşiyor. Typo toleransı en fazla 32 karakterlik sorguda, benzer uzunluktaki token’lara banded edit distance ile uygulanıyor. Global arama EPG başlığına sınırlı ikincil puan, kategoriye düşük puan veriyor; sonuçlar başlık/playlist/item kimliğiyle kararlı sıralanıyor. Katalog taraması 64 öğede bir iptal durumunu denetliyor.
- **Reviewer:** `[APPROVED]` — edit-distance bandı, kısa query sınırı, düşük kategori puanı, deterministik tie-break ve tarama iptali statik incelemeden geçti.
- **Doğrulama:** iPhone 17 / iOS 26.5 Release ve tvOS Release Xcode build’leri `BUILD SUCCEEDED`; `git diff --check` başarılı. Kullanıcı isteği gereği test veya uygulama akışı çalıştırılmadı.
- **Durum:** `[DONE]` — ortak arama alaka puanları ve büyük katalog sıralaması iyileştirildi; reviewer onayladı.

### 57. [PENDING] tvOS EPG Kartında Erişilebilir Program Özeti
- **Bulgu:** IPTVX’in TV Guide, Live Search ve Apple TV sürüm notları daha zengin program bilgisi, okunabilir satırlar ve focus sorunlarının giderilmesini öne çıkarıyor; odak kartı program/kanal/saat bilgisini erişilebilir tek özet olarak sunabilir.
- **Kaynak:** https://apps.apple.com/us/app/iptvx/id1451470024?platform=appleTV

### 58. [PENDING] Tür ve Yıla Göre Görsel Keşif Koleksiyonları
- **Bulgu:** IPTVX 25 Explore koleksiyonlarını sağlayıcı kataloglarından türetilen tür ve yıl/onyıl girişlerine bölüyor; aday içerik yalnızca kütüphanede mevcutsa açılıyor.
- **Kaynak:** https://iptvx.app/newsroom/iptvx-25-for-you-redesign/

### 59. [PENDING] Öneri Bağlantısının Nedenini Açıklama
- **Bulgu:** IPTVX öneri rafı, “çünkü izledin” başlığında çıkış filmini/dizisini gösteriyor; genel bir öneri listesi yerine ilişkiyi kullanıcıya açıklıyor.
- **Kaynak:** https://iptvx.app/newsroom/iptvx-25-for-you-redesign/

### 60. [PENDING] İzleme Geçmişinden Oyuncu Tabanlı Öneriler
- **Bulgu:** IPTVX, izlenen filmlerin oyuncularından kitaplıktaki başka film ve dizilere ayrı keşif yolları oluşturuyor.
- **Kaynak:** https://iptvx.app/newsroom/iptvx-25-for-you-redesign/

### 61. [PENDING] En Çok İzlenen Oyuncular Koleksiyonu
- **Bulgu:** IPTVX For You, oyuncu portrelerini izleme davranışına göre sıralı bir giriş noktası olarak kullanıyor; geçmiş yoksa popüler aktörlerle başlıyor.
- **Kaynak:** https://iptvx.app/newsroom/iptvx-25-for-you-redesign/

### 62. [PENDING] İzlenen Diziler İçin Yeni Bölüm Rafı
- **Bulgu:** IPTVX, sağlayıcıda yeni bölüm bildirilen ve kullanıcı tarafından daha önce izlenmiş dizileri genel katalog güncellemesinden ayrı gösteriyor.
- **Kaynak:** https://iptvx.app/newsroom/iptvx-25-for-you-redesign/

### 63. [PENDING] Puan ve Oy Sayısından Ayrı Film Keşfi
- **Bulgu:** IPTVX “Most Rated” ve “Highest Rated” koleksiyonlarını ayrı sinyaller olarak sunuyor; oy hacmiyle puan ortalamasını karıştırmıyor.
- **Kaynak:** https://iptvx.app/newsroom/iptvx-25-for-you-redesign/

### 64. [PENDING] Ödüllü İçerik Koleksiyonları
- **Bulgu:** IPTVX kullanılabilir ödül metadata’sını kazanan eserler ve daha geniş ödül tanınırlığı olarak ayırıyor; veri yoksa boş raf göstermiyor.
- **Kaynak:** https://iptvx.app/newsroom/iptvx-25-for-you-redesign/

### 65. [PENDING] Aramada Alan Filtreleri ve Sonuç Sayıları
- **Bulgu:** IPTVX 25 aramayı All, Movies, Shows, People, Live ve Programs olarak altı alana ayırıyor; sayılar kullanıcının eşleşme alanını görmesini sağlıyor.
- **Kaynak:** https://iptvx.app/newsroom/iptvx-25-for-you-redesign/

### 66. [PENDING] Kişi Aramasında Portreli Sonuç Sunumu
- **Bulgu:** IPTVX arama sonuçlarında oyuncuları poster kartı gibi göstermeyip portreleriyle ayırıyor; filtre seçimi ilgili alanın tam sonuç ızgarasına gidiyor.
- **Kaynak:** https://iptvx.app/newsroom/iptvx-25-for-you-redesign/

### 67. [PENDING] Dizi Sayfasında Sezon Seçimini ve Güncel Bölümü Koruma
- **Bulgu:** IPTVX’in yenilenmiş dizi sayfası, yükleme sırasında seçilen sezonu koruyor ve “Current Episode” kısayoluyla devam bölümünü açmadan gösteriyor.
- **Kaynak:** https://iptvx.app/newsroom/iptvx-25-for-you-redesign/

### 1. [DONE] Quick Recent Channels Carousel HUD (Quick-Zap Dock for tvOS & iOS)
- **Açıklama:** Canlı yayın izlerken Siri Remote aşağı basıldığında veya iOS'ta buton/menü ile ekranın altında beliren, son izlenen 10 kanalı logo, canlı badge, aktif oynatma halkası ve odaklanabilir kartlarla gösteren hızlı zapping rulosu.
- **Platformlar:** tvOS (Siri Remote Focus Engine uyumlu, .onExitCommand, focusSection), iOS (Haptic feedback, bottom glass dock).
- **TCA & Mimari:** `RecentChannelDTO`, `RecentChannelsClient` (UserDefaults persistent), `PlayerFeature` state/actions (`toggleRecentChannelsHUD`, `selectRecentChannel`, `loadRecentChannels`), `RecentChannelsHUDView.swift`.
- **Durum:** `[DONE]` (PR Onaylandı, derleme başarılı).

### 2. [DONE] Audio Delay & Lip-Sync Micro-Adjustment Engine (-2000ms .. +2000ms)
- **Açıklama:** IPTV akışlarında sıkça yaşanan ses/görüntü senkron kaymasını anında düzeltmek için canlı oynatıcı HUD'ında 50ms hassasiyetle ayarlanabilir ses ve altyazı gecikme düzelticisi (+/- 2000ms), kalıcı kanal hafızası ve anlık OSD görsel geri bildirimi.
- **Platformlar:** iOS, tvOS (Siri Remote Focus Engine, D-pad steppers, iOS Slider & Haptics).
- **TCA & Mimari:** `SettingsClient` (per-channel audio & subtitle delay persistence), `PlayerFeature` (`isAudioSyncHUDVisible`, `rememberDelayForChannel`, automated save/restore on channel change), `AudioSyncHUDView.swift`.
- **Durum:** `[DONE]` (PR Onaylandı, iOS & tvOS derlemeleri sıfır hata ile tamamlandı).

### 3. [DONE] Stream Health, Buffer Gauge & Real-time Network Jitter HUD
- **Açıklama:** Canlı akışta anlık tampon doluluk süresi (buffer seconds), dinamik bitrate, frame drop ve ağ gecikmesi / jitter'ı gösteren ultra-thin glassmorphic HUD ve Nerd Stats entegrasyonu.
- **Platformlar:** tvOS (Siri Remote Focus Engine, .onExitCommand, 10-foot UI), iOS (Haptic Feedback, top glass card).
- **TCA & Mimari:** `StreamHealthMetrics`, `StreamHealthClient` (actor-isolated latency & jitter probe), `PlayerClient.getPlaybackCounters` (SwiftVLC native counters), `PlayerFeature` state/actions (`streamHealthMetrics`, `isStreamHealthHUDVisible`, `toggleStreamHealthHUD`), `StreamHealthHUDView.swift` & yükseltilmiş `NerdStatsHUDView.swift`.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS & iOS derlemeleri sıfır hata ile tamamlandı).

### 4. [DONE] Catchup / Timeshift TV Archive Visual Scrubber & Timeline Bookmarks
- **Açıklama:** `tvArchive == 1` olan kanallarda geçmiş 3 günlük EPG programlarını zaman çizelgesi üzerinde interaktif imler (bookmarks/ticks) ile gösteren, anlık program önizlemeli scrubber, gün filtreleme (Bugün/Dün/Önceki Gün) ve tek tuşla "Canlıya Dön" (Return to Live) motoru.
- **Platformlar:** tvOS (Siri Remote D-pad bookmark zapping, 10-foot UI, focus highlight), iOS (Haptic scrubber, day tabs, floating live button).
- **TCA & Mimari:** `PlayerFeature` state/actions (`activeCatchupProgram`, `isPlayingCatchup`, `isCatchupTimelineVisible`, `returnToLiveStream`), `CatchupTimelineScrubberView.swift`, `PlayerView+tvOS.swift`, `PlayerView+iOS.swift`.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 5. [DONE] MultiView 1+3 Layout & Siri Remote One-Tap Audio Focus Swapping
- **Açıklama:** MultiView ekranında 1 ana odak ekranı (%73) ve yanında 3 dikey alt ekran (%27) düzeni sunma; üst barda 1+3 Vitrin, 2x2 Izgara ve 1+1 İkili mod değiştirici haplar; Siri Remote veya dokunma ile anında ana ses kanalını değiştirme (`setAudioActive`) ve tek tuşla ana ekrana terfi (`swapToPrimary`).
- **Platformlar:** tvOS (Siri Remote Focus Engine, D-pad gezinme ile anlık ses odağı, Play/Pause ile ana ekrana taşıma), iPadOS & iOS (Dokunmatik ses odağı, haptik geri bildirim, 1+3 vitrin kartları).
- **TCA & Mimari:** `MultiViewLayoutMode`, `MultiViewFeature` (`layoutMode`, `primarySlotID`, `activeAudioSlotID`, `swapToPrimary`, `setAudioActive`), `MultiView.swift`.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 6. [DONE] Sleep Timer Smooth Audio Fade-Out Engine & Visual Dimmer
- **Açıklama:** Uyku zamanlayıcısının son 60 saniyesinde sesi kademeli olarak sıfıra indiren ve ekran parlaklığını (`oledDimLevel`) yumuşakça kısarak oynatmayı sonlandıran sinematik deneyim. tvOS ve iOS oynatıcı kontrol barlarında özel Siri Remote menüsü ve üst yüzen uyarı hapı.
- **Platformlar:** iOS, tvOS (Siri Remote Focus uyumlu menü, dynamic countdown göstergesi, Obsidian/Purple yüzen cam bildirim hapı).
- **TCA & Mimari:** `PlayerFeature` (`sleepTimerInitialVolume: Int32`, `isSleepFadingActive`, `.sleepTimerTick` kademeli ses ve parlaklık eğrisi, `userInteracted` anında kurtarma), `PlayerView+tvOS.swift`, `PlayerView+iOS.swift`.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 7. [DONE] EPG 'Now & Next' Channel Peek with Live Elapsed Progress Ring
- **Açıklama:** Kanal zapping HUD'ında (`ChannelZappingHUDView`), OSD bilgi kartında (`ChannelInfoOSDView`) ve son izlenenler çekmecesinde (`RecentChannelsHUDView`) o anki programın ne kadarının geçtiğini gösteren şık dairesel progress ring, canlı yüzde (`48%`), çift renk geçişli degrade bar, kalan dakika rozeti (`22 dk kaldı`) ve hemen sonrasındaki programın ("SONRAKİ") başlama saati ve adı.
- **Platformlar:** iOS, tvOS (Siri Remote Focus Engine, 10-foot UI, D-pad gezinme, Obsidian & Cyan/Purple sinematik cam estetiği).
- **TCA & Mimari:** `NowNextEPGPeekView.swift`, `EPGProgram` uzantıları (`progress`, `remainingMinutes`, `elapsedMinutes`, formatlayıcılar), `ChannelInfoOSDView.swift`, `ChannelZappingHUDView.swift`, `RecentChannelsHUDView.swift`, `AppStrings.Player`.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 8. [DONE] Smart Stream Reconnect with Exponential Backoff & Backup Stream Fallback
- **Açıklama:** Yayın koptuğunda veya sunucu 403/timeout/buffer underrun verdiğinde donmayı engelleyen akıllı üstel geri çekilmeli (exponential backoff: 1s, 2s, 4s, 8s, 16s) otomatik yeniden bağlanma motoru ve aynı kanala ait yedek yayın akışı (backup stream) bulunduğunda anında/otomatik yedek kanala aktarma (Fallback Switch) sistemi.
- **Platformlar:** iOS, tvOS (Siri Remote Focus Engine uyumlu hata ekranı & butonları, Obsidian/Amber yeniden bağlanma HUD'ı, tek tuşla yedek akışa geçiş).
- **TCA & Mimari:** `PlayerFeature` (`reconnectAttempts`, `isFallbackSwitching`, `fallbackStreamName`, `backupStreamItem`, `failedStreamIDs`, `.switchToBackupStream`, `exponential backoff retryEffect`), `PlayerFriendlyErrorView.swift` (yedek akış butonu, FocusState), `PlayerView+tvOS.swift`, `PlayerView+iOS.swift`.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 9. [DONE] Instant Channel Category Filter Chips in Channel Drawer (Sports, News, Cinema, 4K/UHD)
- **Açıklama:** Kanal yan çekmecesinde binlerce kanal arasında anında "Tümü", "Spor ⚽️", "Haber 📰", "Sinema 🍿", "Belgesel 🌍", "Çocuk 🧸", "4K / UHD 🌟", "Müzik 🎵" ve çalma listesi kategorilerini listeleyen, anlık sayaç rozetleri (`(48)`), boş durum kurtarma butonu ve Siri Remote odak efektleriyle donatılmış dinamik cam buton barı.
- **Platformlar:** tvOS (Siri Remote Focus Engine, yatay çip odak gezintisi, renkli parıltı gölgesi), iOS (Haptic touch, horizontal scrollable glass chips).
- **TCA & Mimari:** `ChannelCategoryFilter.swift` (akıllı anahtar kelime eşleştirme, çok dilli destek, aksan renkleri), `PlayerSidebarDrawer.swift` (akıllı kategori ve arama filtreleme motoru, 4K ve arşiv rozetleri, empty state), `AppStrings.LiveTV`.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 10. [DONE] Instant Previous Channel Quick-Recall Gesture & Mini-Preview HUD (Double-Tap Return)
- **Açıklama:** Canlı maç izlerken veya reklam aralarında iki kanal arasında anında mekik dokumayı sağlayan hızlı geri çağırma ("Quick Recall / Swap Channel"). tvOS'ta Siri Remote D-pad SAĞ tuşu veya iOS'ta ekrana çift dokunuş jesti ile son izlenen önceki kanala anında zapping ve ekranda 2.5 saniyelik sinematik "Önceki Kanala Dönüldü ↩️" amber cam HUD bildirimi.
- **Platformlar:** tvOS (Siri Remote D-pad Sağ tuşu, 10-foot UI Obsidian cam HUD, kontrol barı geri butonu), iOS (Ekrana çift dokunuş jesti, dokunsal haptik, Dynamic Island / Toast cam HUD).
- **TCA & Mimari:** `PlayerFeature` (`previousChannel`, `recalledChannelItem`, `isRecallHUDVisible`, `.recallLastChannel`, `.setRecallHUDVisible`, `.hideRecallHUD`, `CancelID.recallHUD`), `PreviousChannelRecallHUDView.swift`, `PlayerView+tvOS.swift`, `PlayerView+iOS.swift`.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 11. [DONE] Direct Channel Number Dialing HUD (Quick-Jump Number Pad for tvOS & iOS)
- **Açıklama:** Geleneksel televizyon kumandası hissiyatı sunan hızlı kanal numarası tuşlama motoru. Siri Remote üzerinde sayı tuşlayarak veya ekrandaki sinematik cam numaratör ile "1-0-4" tuşlandığında 1.8 saniye içinde doğrudan 104. kanala zapping yapan, eşleşen kanalların anlık önizleme kartlarını veren akıllı tuşlama HUD'ı.
- **Platformlar:** tvOS (Siri Remote Focusable cam 3x4 tuş takımı, D-pad sayı seçici, yeşil/mavi odak ışığı, `.onExitCommand`), iOS (Floating 10-key glass keypad modal, dokunsal haptik geri bildirim, iPad Magic Keyboard 'd' kısayolu).
- **TCA & Mimari:** `PlayerFeature` (`dialedChannelNumber: String`, `isChannelDialerVisible: Bool`, `matchedDialedChannels: [(index: Int, item: PlayableItem)]`, `.appendDialedDigit`, `.deleteDialedDigit`, `.clearDialedDigits`, `.submitDialedChannel`, `CancelID.dialerAutoSubmit`), `DirectChannelDialHUDView.swift`, `PlayerView+tvOS.swift`, `PlayerView+iOS.swift`.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 12. [DONE] Smart Channel Sorting & Grouping Rules Engine (Most Watched, Watch Frequency, A-Z)
- **Açıklama:** TiviMate ve UHF kullanıcılarının en çok övdüğü akıllı kanal sıralama motoru. Kanalları orijinal liste sırası, en çok izlenenler (top watch frequency), son izlenenler veya alfabetik (A-Z / Z-A) olarak anında yeniden sıralayan; izlenme sıklığı rozeti (`🔥 12x`) ekleyen ve sıralama tercihini kalıcı saklayan akıllı motor.
- **Platformlar:** tvOS (Siri Remote Focusable Segmented Sort Menu, `TVSortOptionButtonStyle`), iOS (Haptic feedback, quick sort pill menu).
- **TCA & Mimari:** `ChannelSortOption.swift` (genel sıralama algoritması, aksan renkleri, başlıklar), `RecentChannelsClient` (izlenme sıklığı `watchCountsKey` sayacı), `SettingsClient` (kalıcı canlı TV sıralama tercihi), `PlayerFeature` state/actions (`channelSortOption`, `channelWatchCounts`, `setChannelSortOption`, `loadChannelSortPreferences`), `PlayerSidebarDrawer.swift` entegrasyonu.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 13. [DONE] Custom Channel Audio & Subtitle Language Auto-Selector (Preferred Audio Stream Engine)
- **Açıklama:** Çok dilli yayınlarda (İngilizce, Türkçe, Almanca) kullanıcının kanal bazlı tercihini ve genel birincil/ikincil dil tercihlerini kademeli olarak (Kanal Bazlı -> Birincil Dil -> İkincil Yedek Dil -> Akış Varsayılanı) otomatik seçen, kanal değişimlerinde parça listelerini sıfırlayıp akış demuxing sonrasında akıllıca kilitleyen ve ses/altyazı HUD'ı ile görsel geri bildirim sunan akıllı ses motoru.
- **Platformlar:** iOS, tvOS.
- **TCA & Mimari:** `AudioTrackSelector.swift` (kademeli parça seçimi, dil kodları ve takma ad normalizasyonu), `SettingsClient` (`secondaryAudioLanguage`, kanal bazlı tercih saklama), `PlayerFeature` (`selectChannel` parça sıfırlama, progressive polling ile gecikmeli parça algılama, parça seçiminde otomatik kanal tercihi kaydı).
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 14. [DONE] Live Stream Audio Equalizer Presets & Dialogue Enhancer HUD
- **Açıklama:** IPTV yayınlarında boğuk veya gürültülü spor/film seslerini iyileştirmek için "Diyalog Netleştirici (Vocal Boost)", "Stadyum / Spor Atmosferi (Stadium Surround)", "Gece Modu (Night Compression)", "Bas Güçlendirici (Bass Boost)", "Akustik / Netlik (Acoustic)" ve "Düz (Flat)" sinematik ses EQ profilleri. SwiftVLC yerel 10-bant EQ motoru, interaktif frekans eğrisi görselleştirici, Siri Remote Focus Engine odak desteği ve kanal hafızası.
- **Platformlar:** iOS, tvOS (Siri Remote Focus Engine ses menüsü & dock butonu, iOS modal cam HUD & klavye 'e' kısayolu).
- **TCA & Mimari:** `AudioEQPreset`, `PlayerClient.setEqualizerPreset`, `PlayerFactoryClient`, `SettingsClient` (kanal bazlı kalıcı EQ hafızası), `PlayerFeature` state/actions (`audioEQPreset`, `isAudioEQHUDVisible`, `selectAudioEQPreset`), `AudioEQHUDView.swift`.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 15. [DONE] Multi-Playlist Global Smart Search with Instant Filter Badges
- **Açıklama:** Tüm M3U ve Xtream çalma listeleri arasında anında canlı arama yapan; Canlı TV, VOD Film, Dizi, 4K ve EPG mevcut program adına göre renk kodlu rozetlerle sonuçları ayıran ultra-hızlı global arama motoru.
- **Platformlar:** iOS, tvOS (10-foot UI, Siri Remote Focus Engine).
- **TCA & Mimari:** `GlobalSearchFeature`, debounce search query, playlist cross-indexing.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri ile testleri sıfır hata ile tamamlandı).

### 16. [DONE] Smart Channel Name Cleaner & Clutter Stripper Regex Engine
- **Açıklama:** IPTV listelerinde kanal isimlerindeki gereksiz "[TR]", "FHD", "1080p", "4K-UHD", "|HEVC|", "VIP" gibi gürültülü ekleri otomatik temizleyen, temiz başlık sunan ve istendiğinde tek tıkla orijinal başlığa dönülebilen akıllı normalizer motoru.
- **Platformlar:** iOS, tvOS (Siri Remote uyumlu ayarlar ve OSD gösterimi).
- **TCA & Mimari:** `ChannelNameCleaner`, `SettingsClient` regex clutter toggles, `PlayableItem` presentation extension.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri ile 6 birim testi sıfır hata ile tamamlandı).

### 17. [DONE] Trakt.tv Watchlist & Scrobble Sync Engine
- **Açıklama:** VOD film ve diziler izlenirken ilerleme durumunu gerçek zamanlı Trakt.tv hesabıyla senkronize eden, "İzlendi" olarak işaretleyen ve kullanıcıların yarım bıraktıkları içerikleri diğer tüm cihazlarından devam ettirmesini sağlayan modern scrobbler.
- **Platformlar:** iOS, tvOS (Siri Remote Focus Engine & QR Code TV Login).
- **TCA & Mimari:** `TraktClient`, `TraktFeature`, `PlayerFeature` playback progress scrobble effect, `KeychainManager`.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri ile 5 birim testi sıfır hata ile tamamlandı).

### 18. [DONE] Native Picture-in-Picture (PiP) Background Audio & Auto-PiP on Exit
- **Açıklama:** Oynatıcıdan ana menüye veya diğer uygulamalara geçildiğinde yayını kesintiye uğratmadan iOS ve tvOS sistem PiP penceresine aktaran veya arka planda sadece ses dinleme (background audio playback) modunu akıllıca yöneten motor.
- **Platformlar:** iOS, tvOS (AVPictureInPictureController, AudioSession background modes).
- **TCA & Mimari:** `PiPClient`, `PlayerFeature` PiP state actions (`togglePiP`, `onPiPStatusChanged`).
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri ile 5 birim testi sıfır hata ile tamamlandı).

### 19. [DONE] Channel Hide & Category Blacklist PIN Protection System
- **Açıklama:** İstenmeyen kategorileri veya yetişkin kanallarını çalma listelerinden tamamen gizleyen, ebeveyn denetimi (Parental Control PIN) ile korunan ve liste gezintisini tertemiz tutan gizleme/kilit motoru.
- **Platformlar:** iOS, tvOS.
- **TCA & Mimari:** `ParentalControlClient`, `HiddenChannelsDatabase`, `SettingsFeature`.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri ile 3 birim testi sıfır hata ile tamamlandı).

### 20. [DONE] HDR, Dolby Vision & SDR Dynamic Range Indicator HUD
- **Açıklama:** Yayının video akışında HDR10, HLG, Dolby Vision veya SDR renk uzayı ve pik parlaklık bilgisini algılayıp oynatıcı açılışında ve OSD bilgi kartında sinematik altın/mor rozetle gösteren renk uzayı algılayıcı HUD'ı.
- **Platformlar:** tvOS, iOS (Display Gamut & Dynamic Range detection).
- **TCA & Mimari:** `ColorSpaceDetector`, `PlayerFeature.State.videoDynamicRange`, `ChannelInfoOSDView`.
- **Durum:** `[DONE]` (PR Onaylandı, tvOS ve iOS derlemeleri ile 7 birim testi sıfır hata ile tamamlandı).

### 21. [DONE] Auto Frame Rate & Match Dynamic Range Engine (AFR 24/50/60fps Judder-Free Display Switching)
- **Açıklama:** Canlı spor (50fps/60fps) veya sinema filmlerinde (24fps) micro-stutter ve judder'ı önlemek için Apple TV ve iOS ProMotion ekran yenileme hızını akışın orijinal kare hızına (FPS) ve dinamik aralığına göre otomatik eşleyen sinematik görüntü motoru.
- **Platformlar:** tvOS (`AVDisplayManager`, mode switching), iOS (`CADisplayLink`, ProMotion 120Hz adaptif kare hızı).
- **TCA & Mimari:** `DisplayModeClient`, `PlayerFeature` FPS detection & auto refresh-rate match effect, `AFRToastView.swift`, `SettingsFeature`.
- **Durum:** `[DONE]` (PR Onaylandı, 8 birim testi geçti, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 22. [DONE] Apple TV Top Shelf Content Provider & Quick-Launch Carousel
- **Açıklama:** Kullanıcı Apple TV ana ekranında PureIPTV ikonunun üzerindeyken açılan üst vitrinde (Top Shelf) en sevilen kanalları, son izlenenleri ve yarım kalan VOD filmleri dinamik afiş ve doğrudan oynatma bağlantısıyla sunan yerel tvOS uzantısı.
- **Platformlar:** tvOS (`TVTopShelfProvider`, `TVTopShelfCarouselContent`, `TVTopShelfSectionedContent`).
- **TCA & Mimari:** `TopShelfService`, `TopShelfClient`, App Group Shared UserDefaults / CoreData paylaşımı, `PureIPTVTopShelfContentProvider`, `SettingsFeature`.
- **Durum:** `[DONE]` (PR Onaylandı, 5 birim testi geçti, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 23. [DONE] Custom EPG XMLTV Source Mapping & Channel Time-Shift Offset Engine
- **Açıklama:** IPTV sağlayıcısının EPG'si eksik veya hatalı saat diliminde olduğunda harici XMLTV/GZ URL ekleme, kanal bazında EPG ID eşleştirme ve +/- 12 saate kadar zaman kaydırma (time-shift offset) imkanı sağlayan gelişmiş EPG motoru.
- **Platformlar:** iOS, tvOS.
- **TCA & Mimari:** `EPGManager`, `CustomEPGMappingClient`, `SettingsFeature`.
- **Durum:** `[DONE]` (PR Onaylandı, 9 birim testi geçti, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 24. [DONE] iCloud Cross-Device Sync Engine for Favorites, Hidden Channels & Watch Progress
- **Açıklama:** Apple TV, iPhone, iPad ve Mac arasında favori kanalları, gizlenen kanalları, VOD izleme kaldığı yeri (resume point) ve kanal sıralama tercihlerini iCloud KVS (NSUbiquitousKeyValueStore) ile kesintisiz ve arka planda senkronize eden çoklu cihaz motoru.
- **Platformlar:** iOS, tvOS, iPadOS, macOS.
- **TCA & Mimari:** `CloudSyncClient`, `NSUbiquitousKeyValueStore` background notification sync.
- **Durum:** `[DONE]` (PR Onaylandı, 8 birim testi geçti, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

### 25. [DONE] Live EPG Focus Mini-Video Preview PIP in Channel Grid
- **Açıklama:** EPG rehberinde veya kanal listesinde gezinirken Siri Remote ile bir kanalın üzerine gelindiğinde (focus), ana yayını kesmeden sağ üst köşede küçük bir canlı önizleme penceresinde kanalın anlık canlı akışını sessizce başlatan UHF/TiviMate tarzı hızlı kanal gözetleme motoru.
- **Platformlar:** tvOS (Siri Remote Focus debounce, secondary mini player layer), iPadOS.
- **TCA & Mimari:** `PreviewPlayerClient`, `EPGFeature` debounce focus preview effect.
- **Durum:** `[DONE]` (PR Onaylandı, 9 birim testi geçti, tvOS ve iOS derlemeleri sıfır hata ile tamamlandı).

---

## 🏁 Tamamlanan Özellikler ([DONE])
- **#1 Quick Recent Channels Carousel HUD (Quick-Zap Dock):** 
  - `RecentChannelDTO` modeli oluşturuldu.
  - `RecentChannelsClient` TCA bağımlılık servisi eklendi (UserDefaults kalıcılığı ile son 20 kanalı otomatik saklar).
  - `PlayerFeature` reducer'ına `toggleRecentChannelsHUD`, `selectRecentChannel`, `loadRecentChannels` aksiyonları eklendi.
  - `RecentChannelsHUDView.swift` oluşturuldu: tvOS Focus Engine tam uyumlu, Siri Remote ile gezinilebilir, 1.08x odak büyütmesi, OLED siyahı & Electric Blue vurguları.
  - iOS ve tvOS `PlayerView`'lerine doğrudan entegre edildi: tvOS'ta Siri Remote Aşağı yön tuşu ile, iOS'ta ise kontroller ve hızlı menüden anında açılır.
- **#2 Audio Delay & Lip-Sync Micro-Adjustment Engine:**
  - `SettingsClient` ses ve altyazı gecikme hafızasıyla güçlendirildi (kanal bazlı kalıcı saklama).
  - `PlayerFeature` reducer'ına `audioDelay`, `subtitleDelay`, `isAudioSyncHUDVisible`, `rememberDelayForChannel` durum ve aksiyonları eklendi.
  - `AudioSyncHUDView.swift` oluşturuldu: tvOS D-pad kademeli adımlayıcılar, iOS slider ve titreşimli geri bildirim desteği.
  - OSD ve ses menülerine kalıcı entegrasyon sağlandı.
- **#3 Stream Health, Buffer Gauge & Real-time Network Jitter HUD:**
  - `StreamHealthMetrics` ve actor-isolated `StreamHealthClient` geliştirildi.
  - `PlayerClient` SwiftVLC donanımsal sayaçlarıyla (`PlayerPlaybackCounters`) genişletildi.
  - `StreamHealthHUDView.swift` oluşturuldu, `NerdStatsHUDView.swift` tampon göstergesi ve ping/jitter grafikleriyle yükseltildi.
  - tvOS ve iOS oynatıcı arayüzlerine tam entegre edildi.
- **#4 Catchup / Timeshift TV Archive Visual Scrubber & Timeline Bookmarks:**
  - `PlayerFeature` durumuna `activeCatchupProgram`, `isPlayingCatchup`, `isCatchupTimelineVisible` ve `returnToLiveStream` mantığı eklendi.
  - `CatchupTimelineScrubberView.swift` geliştirildi: Günlük filtre sekmeleri (Bugün / Dün / 2 Gün Önce), yatay program imleri (bookmarks), Siri Remote Focus Engine odak takibi ve ölçeklendirme animasyonları.
  - tvOS ve iOS için canlıya dönüş rozeti ("Canlı Yayına Dön") ve kontrol barı butonları entegre edildi. tvOS geri tuşu (`onExitCommand`) güvenli kapatma ile donatıldı.
- **#5 MultiView 1+3 Layout & Siri Remote One-Tap Audio Focus Swapping:**
  - `MultiViewLayoutMode` (`showcase1Plus3`, `grid2x2`, `dual1Plus1`) eklendi.
  - `MultiViewFeature` reducer'ına `layoutMode`, `primarySlotID`, `activeAudioSlotID`, `swapToPrimary`, `setAudioActive` eklendi.
  - `MultiView.swift` tamamen modernize edildi: Üst bar mod değiştirici haplar, aktif ses rozeti, 1+3 asimetrik vitrin hesaplamaları (%73 ana vitrin + %27 3 alt slot).
  - Siri Remote ile gezinirken anında ses odağı geçişi (`.onChange(of: tvFocusedSlotID)`), D-pad Play/Pause veya "Ana Ekrana Taşı" butonu ile vitrine terfi mekanizması hayata geçirildi.
- **#6 Sleep Timer Smooth Audio Fade-Out Engine & Visual Dimmer:**
  - `PlayerFeature.State` içine `sleepTimerInitialVolume: Int32` ve `isSleepFadingActive: Bool` entegre edildi.
  - `.setSleepTimer`, `.sleepTimerTick`, `.sleepTimerEnded` ve `.userInteracted` aksiyonları güncellendi: son 60 saniyede ses doğrusal olarak kısılarak 0'a çekilir, ekran `oledDimLevel` ile sinematik olarak kararır. Kullanıcı kumandaya veya ekrana dokunduğu anda orijinal ses seviyesi ve parlaklık anında geri yüklenir.
  - tvOS `VideoControllerView` içine Siri Remote uyumlu Sleep Timer menüsü eklendi (aktifken kalan dakikayı buton üzerinde canlı gösterir).
  - tvOS ve iOS oynatıcı üst katmanlarına Obsidian/Purple cam malzeme ile "Uyku Modu: Ses Kısılıyor..." yüzen bildirim hapı yerleştirildi.
- **#7 EPG 'Now & Next' Channel Peek with Live Elapsed Progress Ring:**
  - `NowNextEPGPeekView.swift` bağımsız ve yüksek performanslı bileşen olarak geliştirildi (dairesel progress ring, yüzde rozeti, degrade ilerleme çubuğu, kalan dakika ve sonraki program kartı).
  - `EPGProgram` modeline `progress(at:)`, `remainingMinutes(at:)`, `elapsedMinutes(at:)` ve dinamik saat formatlayıcıları eklendi.
  - `ChannelInfoOSDView.swift` tamamen `NowNextEPGPeekView` ile modernize edildi.
  - `ChannelZappingHUDView.swift` zapping anında canlı program ve sıradaki program verileriyle donatıldı (tvOS ve iOS `PlayerView`'lerinden beslenir).
  - `RecentChannelsHUDView.swift` son izlenenler çekmecesindeki aktif kanal kartına anlık canlı EPG ilerleme çizgisi ve yüzdesi entegre edildi.
- **#8 Smart Stream Reconnect with Exponential Backoff & Backup Stream Fallback:**
  - `PlayerFeature.State` içine `reconnectAttempts: Int`, `isFallbackSwitching: Bool`, `fallbackStreamName: String?`, `backupStreamItem: PlayableItem?`, `failedStreamIDs: Set<String>` eklendi.
  - Yayın koptuğunda veya buffer underrun oluştuğunda 5 denemeye kadar üstel geri çekilme (`2^(attempts-1)` saniye: 1s, 2s, 4s, 8s, 16s) uygulandı.
  - Eğer aynı kanalın alternatif/yedek akışı varsa (`PlayerFeature.areChannelsRelated`), otomatik olarak veya kullanıcı butonuyla `switchToBackupStream` aksiyonu tetiklenir; akıcı bir şekilde yedek akış başlatılır.
  - `PlayerFriendlyErrorView.swift` Obsidian cam kartı, hata kodu, yeniden deneme butonu ve Siri Remote uyumlu "Yedek Akışa Geç" butonuyla yenilendi.
  - tvOS ve iOS oynatıcı katmanlarına üstel geri çekilme sayacı ve yedek akış bildirim HUD'ı entegre edildi.
- **#9 Instant Channel Category Filter Chips in Channel Drawer (Sports, News, Cinema, 4K/UHD):**
  - `ChannelCategoryFilter.swift` mimarisi kuruldu: Tümü, Spor, Haber, Sinema, Belgesel, Çocuk, 4K/UHD, Müzik, Son İzlenenler ve özel M3U kategorileri için akıllı anahtar kelime eşleştirme motoru.
  - `PlayerSidebarDrawer.swift` baştan sona yeniden tasarlandı:
    - tvOS Siri Remote Focus Engine uyumlu `TVCategoryFilterChipButtonStyle` (odaklanıldığında 1.08x büyüme, parlaklık ve kategoriye özel renkli parıltı efekti).
    - Her kategori çipinde anlık kanal sayısı rozeti (`(count)`), yalnızca kanalı bulunan kategorileri dinamik listeleme.
    - Boş liste durumunda sinematik `emptyStateView` ve tek tuşla "Filtreyi Temizle" kurtarma aksiyonu.
    - Kanal satırlarında 4K ve arşiv (`tvArchive`) rozetleri, aktif oynatılan kanal ve geçmiş kanal göstergeleri.
    - iOS için akıcı yatay kaydırma, cam kapsül tasarımı ve dokunsal haptik geri bildirim entegre edildi.
- **#10 Instant Previous Channel Quick-Recall Gesture & Mini-Preview HUD (Double-Tap Return):**
  - `PlayerFeature.State` içine `isRecallHUDVisible: Bool` ve `recalledChannelItem: PlayableItem?` eklendi.
  - `PlayerFeature.Action` içine `.recallLastChannel`, `.setRecallHUDVisible`, `.hideRecallHUD` eklendi; `CancelID.recallHUD` ile otomatik 2.5s zamanlayıcı yönetildi.
  - `PreviousChannelRecallHUDView.swift` geliştirildi: Kanal logosu, amber renkli "arrow.uturn.backward" rozeti, "Önceki Kanala Dönüldü" başlığı, "HIZLI GEÇİŞ" hapı ve kanal adı.
  - tvOS entegrasyonu: Siri Remote D-pad SAĞ tuşu ile anında önceki kanala geçiş sağlandı (`playView`'de `.onMoveCommand`), kontrol çubuğu "Önceki Kanal" butonuyla tam senkronize edildi.
  - iOS entegrasyonu: Canlı yayında ekrana çift dokunulduğunda (`handleTap` center double-tap) anında önceki kanala dönme jesti ve Dynamic Island tarzı üst bildirim HUD'ı entegre edildi.
- **#11 Direct Channel Number Dialing HUD (Quick-Jump Number Pad for tvOS & iOS):**
  - `DirectChannelDialHUDView.swift` geliştirildi: 3x4 cam tuş takımı, Siri Remote Focus Engine uyumlu `TVDialKeypadButtonStyle` (1.08x odak büyümesi, yeşil parlaklık), eşleşen kanal önizleme şeridi.
  - `PlayerFeature` reducer'ına `appendDialedDigit`, `deleteDialedDigit`, `clearDialedDigits`, `submitDialedChannel` aksiyonları eklendi.
  - tvOS oynatıcı katmanına kumanda butonu, `.onExitCommand` ve otomatik 1.8 saniye submit zamanlayıcısı entegre edildi; iOS oynatıcı katmanına alt dock butonu, üst menü ve klavye 'd' kısayolu eklendi.
- **#12 Smart Channel Sorting & Grouping Rules Engine (Most Watched, Watch Frequency, A-Z):**
  - `ChannelSortOption.swift` geliştirildi: `.defaultOrder`, `.mostWatched`, `.recentlyWatched`, `.nameAscending`, `.nameDescending` algoritmaları ve görsel rozet renkleri.
  - `RecentChannelsClient` izlenme sıklığı (`watchCountsKey`) sayacı ile genişletildi; `SettingsClient` kalıcı sıralama tercihi saklayıcıları eklendi.
  - `PlayerFeature` reducer'ına `channelSortOption`, `channelWatchCounts`, `setChannelSortOption` eklendi.
  - `PlayerSidebarDrawer.swift` içine tvOS `TVSortOptionButtonStyle` ve Siri Remote odaklanabilir sıralama menüsü ile `🔥 12x` izlenme sıklığı rozetleri entegre edildi.
- **#13 Custom Channel Audio & Subtitle Language Auto-Selector (Preferred Audio Stream Engine):**
  - `AudioTrackSelector.swift` motoru geliştirildi: Çok dilli takma ad çözümleyici, kademeli öncelik (Kanal Bazlı -> Birincil Dil -> İkincil Dil -> Varsayılan) ve altyazı motoru.
  - `SettingsClient` ikincil ses dili (`secondaryAudioLanguage`), kanal bazlı ses ve altyazı tercih saklama API'leri ile genişletildi.
  - `PlayerFeature` kanal geçişlerinde eski parça önbelleklerinin sıfırlanması, live IPTV gecikmeli akış demuxing için çok aşamalı progressive polling (500ms, 1200ms) ve HUD bildirimleriyle donatıldı.
- **#14 Live Stream Audio Equalizer Presets & Dialogue Enhancer HUD:**
  - `AudioEQPreset.swift` modeli geliştirildi: 6 sinematik ön ayar (.flat, .dialogueEnhancer, .stadium, .nightMode, .bassBoost, .acoustic) ile 10-bant frekans kazançları (60Hz..16kHz) ve preamp kazancı.
  - `PlayerClient` ve `PlayerFactoryClient` SwiftVLC `Equalizer` API'si (`eq.setBands`, `eq.preampGain`, `player.equalizer = eq`) ile genişletildi; .flat modunda sıfır overhead ile nil bypass uygulandı.
  - `SettingsClient` genel ve kanal bazlı kalıcı ses EQ profili saklama fonksiyonlarıyla güçlendirildi (`audioEQPreset`, `setAudioEQPreset`, `getChannelAudioEQPreset`, `setChannelAudioEQPreset`).
  - `PlayerFeature` reducer'ına `audioEQPreset`, `isAudioEQHUDVisible`, `toggleAudioEQHUD`, `selectAudioEQPreset`, `loadAudioEQPreferences` ve kanal geçişinde hafızadan otomatik yükleme eklendi.
  - `AudioEQHUDView.swift` Obsidian cam estetiği, 10-bant animasyonlu dinamik spektrum eğrisi, Siri Remote Focus Engine uyumlu `TVEQPresetButtonStyle` (1.05x büyüme ve renkli parıltı) ve otomatik gizlenme zamanlayıcısıyla geliştirildi.
  - tvOS (`PlayerView+tvOS.swift` ses menüsü, alt dock butonu, `.onExitCommand` modal yönetimi) ve iOS (`PlayerView+iOS.swift` hızlı menü, parça sayfası, modal cam HUD ve 'e' klavye kısayolu) oynatıcılarına tam entegre edildi.
- **#15 Multi-Playlist Global Smart Search with Instant Filter Badges:**
  - `GlobalSearchResultItem.swift` ve `PlaylistSourceBadge` modelleri oluşturuldu: Her sonuç için kaynak çalma listesi rozeti, 4K UHD tespiti ve EPG canlı program eşleşmesi.
  - `GlobalSearchEngine.swift` thread-safe, yüksek performanslı çapraz arama motoru geliştirildi: Dinamik kategori ve 4K sayaç hesaplaması, token normalizasyonu ve puanlama.
  - `SearchFeature.swift` çoklu çalma listesi indeksleme (`indexedChannels`, `indexedVODs`, `indexedSeries`, `filterCounts`, `selectPlaylistFilter`) ve concurrent yükleme ile zenginleştirildi; geriye dönük uyumluluk korundu.
  - `GlobalSearchResultCard.swift` Obsidian cam estetiğinde 16:9 (Canlı TV) ve 2:3 (VOD) kartları, 4K Altın rozet, çalma listesi kaynağı, Siri Remote Focus Engine (1.06x büyüme & parıltı) ile geliştirildi.
  - `SearchView+iOS.swift` ve `SearchView+tvOS.swift` zenginleştirilmiş filtre hapları (Canlı TV (48), 4K / UHD (12) gibi sayaçlar), çoklu çalma listesi sekme seçicisi ve 10-foot TV UI ile güncellendi.
  - Birim testleri (`SearchFeatureTests.swift`) ve iOS / tvOS derlemeleri sıfır hata ile tamamlandı.
- **#16 Smart Channel Name Cleaner & Clutter Stripper Regex Engine:**
  - `ChannelNameCleaner.swift` geliştirildi: Ülke/dil ön ekleri (`[TR]`, `TR:`, `TR -`, `[DE]`, `[FR]`), çözünürlük (`4K`, `UHD`, `FHD`, `1080p`, `720p`, `HD`, `SD`), codec/gürültü (`HEVC`, `H.265`, `RAW`, `50FPS`, `60FPS`, `MULTI-AUDIO`) ve sunucu etiketlerini (`VIP`, `BACKUP`, `YEDEK`) temizleyen önceden derlenmiş statik regex motoru.
  - Zengin metadata çıkarımı eklendi: `CleanedChannelMetadata` ile `cleanTitle`, `detectedQuality` (`ChannelQualityBadge`: `.uhd4k`, `.fhd1080`, `.hd720`, `.sd`), `detectedCountry`, `isBackup`, `isHEVC`, `hasStrippedClutter` tespiti.
  - `MediaModels.Item` ve `PlayerFeature.PlayableItem` modellerine `.cleanTitle` ve `.cleanedMetadata` presentation extension'ları eklendi.
  - `SettingsClient` ve `SettingsFeature` kalıcı `isChannelNameCleaningEnabled` ayarıyla donatıldı; `SettingsView` oynatıcı ayarları altına toggle eklendi.
  - `PlayerFeature` reducer'ına `isChannelNameCleaningEnabled` durumu, onAppear yüklemesi ve `toggleChannelNameCleaning` aksiyonu entegre edildi.
  - `PlayerSidebarDrawer.swift` içine tek tıkla "Sade / Ham" mod geçiş butonu (`cleanerToggleButton`), tvOS Siri Remote için `TVCleanerButtonStyle` ve `CleanedChannelMetadata` etiketleri eklendi.
  - `ChannelInfoOSDView.swift`, `ChannelZappingHUDView.swift`, `ChannelCardView.swift` ve `RecentChannelsHUDView.swift` temiz başlık ve kalite rozetleri ile güncellendi.
- **#17 Trakt.tv Watchlist & Scrobble Sync Engine:**
  - `TraktModels.swift` oluşturuldu: OAuth2 Device Flow modelleri (`TraktDeviceCode`, `TraktTokenResponse`), `TraktUser`, scrobbler payloadları (`TraktScrobblePayload`, `TraktScrobbleResponse`), `TraktWatchlistItem` ve `TraktPlaybackProgressItem`.
  - `TraktMediaParser.swift` VOD / Dizi akıllı regex ayrıştırıcı motoru yazıldı: Başlıklardaki sezon & bölüm formatlarını (`S01E05`, `1x05`), yapım yılını (`(2014)`), codec ve ses gürültülerini temizleyerek başlığı netleştirir ve Trakt API payloadına dönüştürür.
  - `TraktClient.swift` TCA bağımlılık servisi geliştirildi: Device Code akışı, OAuth2 token yenileme ve polling döngüsü, canlı scrobble başlangıç/duraklatma/tamamlama çağrıları, izleme listesi ve devam etme ilerlemesi getirme; KeychainManager üzerinden iCloud Keychain kalıcılığı sağlandı.
  - `TraktFeature.swift` TCA reducer'ı yazıldı: Cihaz yetkilendirme akışı, otomatik scrobble açma/kapama, izleme listesi senkronizasyonu ve kullanıcı çıkış yönetimi.
  - `TraktAuthView.swift` Obsidian cam estetiğinde tvOS ve iOS için QR kodlu giriş modalı (`CIQRCodeGenerator` ile ekranda dinamik QR kod ve 8 haneli `user_code`) geliştirildi; Siri Remote Focus Engine butonları ile donatıldı.
  - `TraktWatchlistView.swift` ile Trakt İzleme Listesi ve İzlemeye Devam Et arayüzü tasarlandı.
  - `TraktScrobbleHUDView.swift` oynatıcı üzerine scrobble başlangıç ve tamamlanma bildirim tostu eklendi.
  - `PlayerFeature.swift` VOD ve dizi oynatımlarında >=10s izlemede otomatik scrobble başlatma, duraklatmada senkronize etme ve >=%80 izlemede "İzlendi" olarak işaretleme etkileriyle donatıldı; HUD tostu tetikleyicileri eklendi.
  - `SettingsFeature.swift` ve `SettingsView.swift` içine "Trakt.tv Senkronizasyonu" yönetim kartı, bağlı hesap profili, izleme listesi bağlantısı ve giriş/çıkış modalı eklendi.
  - 5 adet birim testi (`TraktSyncEngineTests.swift`) yazıldı; TestClock ve scheduler entegrasyonu sağlandı; iOS ve tvOS derlemeleri ile testleri 0 hata ile tamamlandı.
- **#18 Native Picture-in-Picture (PiP) Background Audio & Auto-PiP on Exit:**
  - `PiPClient.swift` TCA bağımlılık servisi ve `BackgroundPlaybackMode` (`.pip`, `.audioOnly`, `.disabled`) enum modeli oluşturuldu.
  - `AVPictureInPictureController.isPictureInPictureSupported()` entegrasyonu sağlandı; UserDefaults üzerinde `com.pureiptv.autoPiPEnabled` ve `com.pureiptv.backgroundPlaybackMode` kalıcılığı kuruldu.
  - Arka planda kesintisiz ses için `AVAudioSession` category `.playback`, mode `.moviePlayback` ve options `[.allowAirPlay, .defaultToSpeaker]` konfigürasyonu tamamlandı.
  - `PlayerFeature.swift` durum ve aksiyonlarına `isPiPSupported`, `isAutoPiPEnabled`, `backgroundPlaybackMode`, `isBackgroundAudioActive`, `shouldTriggerPiP`, `togglePiP`, `onPiPStatusChanged`, `appMovedToBackground`, `appMovedToForeground` entegre edildi.
  - `PlayerView.swift` SwiftUI scenePhase lifecycle (`.background` / `.active`) dinleyicisi eklendi; arka plana geçildiğinde seçili moda göre PiP tetikleme, ses çalmaya devam etme veya duraklatma akışları bağlandı.
  - tvOS için `PlayerView+tvOS.swift` alt dock çubuğuna Siri Remote Focus Engine uyumlu PiP / MiniPlayer butonu eklendi.
  - `SettingsFeature.swift` ve `SettingsView.swift` içine "Resim İçinde Resim (PiP) & Arka Plan" ayar kartı, otomatik PiP anahtarı ve oynatma modu seçici menüsü eklendi.
  - 5 adet birim testi (`PiPBackgroundEngineTests.swift`) yazılarak test edildi; iOS Simulator ve tvOS Simulator derlemeleri ile birim testleri sıfır hata ile tamamlandı.
- **#19 Channel Hide & Category Blacklist PIN Protection System:**
  - `ParentalControlClient.swift` ve `HiddenItemDTO` (id, title, type: .channel/.category, hiddenAt) modelleri oluşturuldu: Gizli kanal ve kara liste kategori yönetimi, PIN doğrulama/kaydetme, yetişkin anahtar kelime tespiti, Face ID / Touch ID biyometrik doğrulama ve geriye dönük uyumlu UserDefaults/Keychain kalıcılığı sağlandı.
  - `PlayerFeature.swift` durumuna `hiddenChannelIDs` ve `blacklistedCategoryIDs` eklendi; kanal gizleme (`hideChannel`), gizlilik tercihlerini yükleme ve oynatılmakta olan kanal gizlendiğinde listedeki bir sonraki uygun kanala otomatik atlama lojiği kuruldu.
  - `PlayerSidebarDrawer.swift` kanal listesinde gizlenen kanalları ve kilitli kategorileri filtreleyecek şekilde güncellendi; her kanal satırına "Kanalı Gizle" (`eye.slash.fill`) context menu eylemi eklendi.
  - `LiveTVFeature.swift` ve `SearchFeature.swift` arama motoru ve canlı liste görünümleri gizli kanal ve kategorileri tüm sonuçlardan filtreleyecek şekilde `parentalControlClient` ile güçlendirildi.
  - `SettingsFeature.swift` içine gizli içerik yönetimi açma/kapama, biyometrik kilit açma, 4 haneli PIN modalı ve tek tek/toplu görünür yapma aksiyonları entegre edildi.
  - `HiddenContentManagementView.swift` Obsidian cam estetiğinde (`#0C0C10`), sekmeli yapı ("Gizlenen Kanallar" & "Kara Liste Kategoriler"), tvOS Siri Remote Focus Engine uyumlu PIN klavyesi ve iOS SecureField ile tasarlandı.
  - `SettingsView.swift` Güvenlik bölümüne "Gizlenen Kanallar & Kategoriler" yönetim satırı ve dinamik sayaç rozeti eklendi.
  - 3 adet kapsamlı TCA birim testi (`ParentalControlEngineTests.swift`) yazıldı; hem iOS hem tvOS platformlarında sıfır hata ile derlendi ve doğrulandı.
- **#20 HDR, Dolby Vision & SDR Dynamic Range Indicator HUD:**
  - `ColorSpaceDetector.swift` ve `VideoDynamicRange` enum'ı (`.dolbyVision`, `.hdr10Plus`, `.hdr10`, `.hlg`, `.sdr`, `.unknown`) geliştirildi: Akış başlıkları ve URL parametrelerinden regex tabanlı akıllı format tespiti, CoreMedia/CoreVideo `CMFormatDescription` ve AVAssetTrack `containsHDRVideo` karakteristik analizi, renk gamı (BT.2020 / DCI-P3 / BT.709), transfer fonksiyonları (SMPTE ST 2084 PQ, ARIB HLG) ve pik parlaklık seviyeleri sağlandı.
  - `DynamicRangeHUDView.swift` Obsidian cam estetiğinde (`#0C0C10`) sinematik HUD kapsülü tasarlandı: Format rozeti (Dolby Vision için Neon Mor-Altın gradyanı, HDR10/HDR10+ için Altın Sarısı, HLG için Canlı Yeşil), çözünürlük bilgisi (4K UHD / 1080p), bit derinliği (10-Bit / 12-Bit), BT.2020 renk gamı ve pik parlaklık (1000/4000 nits) çipleri, animasyonlu parıldayan neon çerçeve ile donatıldı.
  - `ChannelInfoOSDView.swift` OSD bilgi kartı zenginleştirildi: Çözünürlük ve HEVC rozetlerinin hemen yanına akıllı `dynamicRange` rozeti eklendi; geriye dönük uyumlu `dynamicRange` desteği sağlandı.
  - `PlayerFeature.swift` durumuna `videoDynamicRange`, `dynamicRangeInfo` ve `isDynamicRangeHUDVisible` durumları eklendi; başlatıcıda otomatik tespit, `selectChannel` geçişlerinde yeni kanal için renk uzayı tespiti, HDR yayın açılışlarında 3.5 saniye otomatik gösterim ve zamanlayıcı iptal mekanizması kuruldu.
  - `PlayerView+iOS.swift` ve `PlayerView+tvOS.swift` oynatıcı arayüzlerine dinamik HUD kapsülü ve OSD entegrasyonu sağlandı.
- **#21 Auto Frame Rate & Match Dynamic Range Engine (AFR 24/50/60fps Judder-Free Display Switching):**
  - `DisplayModeClient.swift` TCA servis istemcisi, `FrameRate` enum'ı (`.fps23_976`, `.fps24`, `.fps25`, `.fps29_97`, `.fps30`, `.fps50`, `.fps59_94`, `.fps60`, `.fps120`) ve `DisplayMatchResult` veri modelleri geliştirildi: 24Hz sinematik film, 50Hz Avrupa/TR canlı yayın ve 60/120Hz yüksek akıcılık modları desteklendi.
  - `FrameRateDetector` regex motoru geliştirildi: Yayın başlığı, URL ve içerik türünden (VOD vs Live) 50fps, 60fps, 24fps/24p, 25fps ve 30fps yayınları ultra hızlı ve sıfır gecikmeyle tespit eden akıllı analiz ve judder-free frekans haritalama lojiği kuruldu.
  - `AFRToastView.swift` Obsidian cam estetiğinde (`#0C0C10`, `.ultraThinMaterial`) sinematik toast kapsülü tasarlandı: Eşlenen yenileme frekansı rozeti (24 Hz, 50 Hz, 60 Hz), "Judder-Free • Kare Hızı Eşlendi" bildirim çipi, içerik türüne göre renk gradyanı (Sinematik 24p için Apple Mavisi, Canlı TV için Canlı Yeşil, 60/120Hz için Neon Mor) ve HDR/DV renk uzayı rozeti entegre edildi.
  - `PlayerFeature.swift` durum ve aksiyonlarına `isAFREnabled`, `isMatchDynamicRangeEnabled`, `currentFrameRate`, `afrMatchResult`, `isAFRToastVisible`, `matchDisplayMode`, `displayModeSwitched`, `showAFRToast`, `hideAFRToast` eklendi; başlatıcıda ve kanal değişimlerinde otomatik frekans tespiti ve ekran eşleme tetiklendi; oynatıcıdan çıkışta `resetDisplayMode` ve toast temizliği sağlandı.
  - `PlayerView+iOS.swift` ve `PlayerView+tvOS.swift` oynatıcı arayüzlerine `AFRToastView` animasyonlu üst toast bildirim katmanı eklendi.
  - `SettingsFeature.swift` ve `SettingsView.swift` içine "Ekran & Kare Hızı Eşleme (AFR)" ayar bölümü, otomatik kare hızı anahtarı ve dinamik aralık eşleme anahtarları entegre edildi.
  - 8 adet kapsamlı birim testi (`AutoFrameRateEngineTests.swift`) yazıldı; hem iOS Simulator hem de tvOS Simulator platformlarında testler ve derleme sıfır hata ile başarıyla doğrulandı.
- **#22 Apple TV Top Shelf Content Provider & Quick-Launch Carousel:**
  - `TopShelfStyle` enum modeli (`.sectioned`, `.carousel`) ve `TopShelfDataDTO` genişletildi; App Group `group.com.pureiptv.app` ve shared UserDefaults desteği kuruldu.
  - `PureIPTVTopShelfContentProvider.swift` hem `TVTopShelfCarouselContent` (Sinematik Vitrin Carousel) hem de `TVTopShelfSectionedContent` (Bölümlü Liste: Kaldığın Yerden İzle, Favori Kanallar, Yeni Filmler) üretecek şekilde iki yönlü adaptif motor haline getirildi; deep link (`pureiptv://play?...`) tetikleyicileri ile hızlı başlatma sağlandı.
  - `TopShelfClient` TCA dependency client oluşturuldu (`updateTopShelfData`, `loadTopShelfData`, `getPreferredStyle`, `setPreferredStyle`), liveValue ve testValue tescillendi.
  - `SettingsFeature.swift` ve `SettingsView.swift` tvOS arayüzüne "Apple TV Top Shelf Vitrin Modu" başlığı altında bölüm/carousel düzeni seçici menüsü eklendi; vitrin stili değiştiğinde sistem `.TVTopShelfItemsDidChange` bildirimi tetiklendi.
  - 5 adet kapsamlı birim testi (`TopShelfEngineTests.swift`) yazıldı; serialization, deep link formatı, TCA client ve tvOS provider carousel/sectioned içerikleri test edilerek hem iOS hem tvOS platformlarında sıfır hata ile tamamlandı.
- **#23 Custom EPG XMLTV Source Mapping & Channel Time-Shift Offset Engine:**
  - Darwin `zlib` tabanlı `GzipDecompressor` geliştirildi: `16 + MAX_WBITS` pencere boyutu ile sıkıştırılmış `.xml.gz` akışlarını harici bağımlılık olmadan bellek içinde çözebilen yüksek performanslı açıcı entegre edildi.
  - `CustomEPGSource`, `ChannelEPGMapping`, `CustomEPGStore` actor ve `CustomEPGMappingClient` (@DependencyClient) geliştirildi: Harici XMLTV/GZ kaynaklarını indirme, UserDefaults üzerinde kalıcı saklama, arka planda ayrıştırma, genel veya kanal bazında +/- 12 saat zaman kaydırma ve EPGID haritalama mekanizmaları sağlandı.
  - `CustomEPGSettingsView.swift` Obsidian cam estetiğinde (`#0C0C10`, `.ultraThinMaterial`) tasarlandı: Genel zaman kaydırma kademeli adımlayıcılar, harici kaynak listesi, tek tıkla güncelleme/silme/etkinleştirme ve yeni kaynak ekleme modal formu sunuldu.
  - `PlayerFeature.swift` canlı yayın EPG getirme mantığı yükseltildi: Önce özel harici XMLTV kaynakları arandı, bulunamazsa sağlayıcı kısa EPG'sine dönülerek hem genel hem de kanal bazlı saat dilimi zaman kaydırması (`applyTimeShift`) uygulandı.
  - `SettingsFeature.swift` ve `SettingsView.swift` EPG ayarları menüsüne "Özel XMLTV Kaynakları & Eşleme" gezinti butonu ve modal yönetim sayfası eklendi.
  - 9 adet kapsamlı birim testi (`CustomEPGMappingEngineTests.swift`) yazıldı; gzip algılama, decompressor, veri modelleri, canlı zaman kaydırma hesaplamaları, kanal bazlı override ve TCA Settings akışı test edilerek iOS ve tvOS'ta sıfır hata ile başarıyla doğrulandı.
- **#24 iCloud Cross-Device Sync Engine for Favorites, Hidden Channels & Watch Progress:**
  - `FavoriteSyncDTO`, `CloudSyncSummary`, `CloudSyncStatus` ve `@DependencyClient CloudSyncClient` mimarisi geliştirildi: Apple TV, iPhone, iPad ve Mac arasında favori kanalları, gizlenen kanalları/kategorileri ve VOD izleme kaldığı yeri `NSUbiquitousKeyValueStore` üzerinden arka planda sıfır gecikmeyle eşitler.
  - Akıllı çakışma çözümleme (Conflict Resolution): Zaman damgalı son yazan kazanır (Last-Write-Wins) ve yerel/uzak veri kümesi birleştirme (union merge) algoritmaları ile çift yönlü veri kaybı engellendi; iCloud KVS 1MB kota sınırına göre otomatik budama (pruning) uygulandı.
  - `NotificationCenter` üzerinden `.cloudSyncDidComplete`, `.favoritesDidChange` ve `.hiddenContentDidChange` yayınları kuruldu; `NSUbiquitousKeyValueStore.didChangeExternallyNotification` ile arka planda uzaktan gelen değişiklikler anında yerel SwiftData ve UserDefaults'a entegre edildi.
  - `SettingsFeature.swift` ve `SettingsView.swift` iCloud Senkronizasyon bölümü zenginleştirildi: Son eşitleme zamanı göreceli formatı ("X dakika önce"), gerçek zamanlı durum rozetleri ("X Favori • Y Gizli • Z İlerleme"), animasyonlu "Şimdi Eşitle" butonu ve durum bildirimleri Obsidian Cam estetiğinde eklendi.
  - 8 adet kapsamlı birim testi (`CloudSyncEngineTests.swift`) yazıldı; model serileştirme, SwiftData dönüşümleri, çakışma çözümleme ve TCA Reducer akışı hem iOS Simulator hem de tvOS Simulator platformlarında sıfır hata ile doğrulandı.
- **#25 Live EPG Focus Mini-Video Preview PIP in Channel Grid:**
  - `PreviewPlayerClient` mimarisi kuruldu: Ana oynatıcıyı etkilemeden, izole `SwiftVLC.Player` ile sessizce (`volume = 0`) arka planda anlık canlı video akışı başlatan, oynatma durumu (`PreviewPlaybackStatus`), ses açma/kapama ve tam ekran terfi yeteneklerine sahip TCA bağımlılık istemcisi geliştirildi.
  - `LiveEPGMiniPreviewView.swift` Obsidian cam estetiğinde (`#0C0C10`, `.ultraThinMaterial`) tasarlandı: 16:9 oranında canlı akış penceresi, kırmızı yanıp sönen "CANLI ÖNİZLEME" rozeti, ses açma/kapama butonu, kanal logosu, kalite rozeti ("4K", "FHD", "HD"), anında tam ekrana geçiş ("arrow.up.left.and.arrow.down.right") ve kapatma butonları entegre edildi.
  - `EPGTimelineFeature.swift` reducer'ına 400ms odaklanma gecikmesi (`channelFocused` -> `startPreviewDebounce` effect debounce) eklendi; kullanıcı Siri Remote veya dokunmatik ekranla kanallar arasında hızlıca gezinirken gereksiz ağ trafiği ve sunucu yükü önlendi.
  - `EPGTimelineView.swift` yüzen mini PIP penceresi `LiveEPGMiniPreviewView` ile donatıldı; kanal hücrelerine uzun basıldığında veya context menu açıldığında "Canlı Mini Önizleme" eylemi eklendi.
  - `EPGGuideFeature.swift` ve Apple TV `EPGGuideView_tvOS.swift` Siri Remote Focus Engine ile kanal seçildiğinde üst başlık alanında canlı video önizlemesi ve ses açma/kapama butonu sunacak şekilde modernize edildi.
  - 9 adet kapsamlı birim testi (`LiveEPGPreviewEngineTests.swift`) yazıldı; hem iOS Simulator (9/9 passed) hem de tvOS Simulator platformlarında sıfır hata ile doğrulandı.





