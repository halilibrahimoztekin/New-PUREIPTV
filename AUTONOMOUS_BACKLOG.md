# 🚀 PureIPTV Autonomous R&D Engineering Backlog

Bu dosya, tam otonom iOS & tvOS IPTV mühendislik ekibinin (Analyst, Principal Dev, PR Reviewer) canlı hafızasıdır.

---

## 📊 Backlog Durumu (Active Pipeline)

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

### 15. [IN_PROGRESS] Multi-Playlist Global Smart Search with Instant Filter Badges
- **Açıklama:** Tüm M3U ve Xtream çalma listeleri arasında anında canlı arama yapan; Canlı TV, VOD Film, Dizi, 4K ve EPG mevcut program adına göre renk kodlu rozetlerle sonuçları ayıran ultra-hızlı global arama motoru.
- **Platformlar:** iOS, tvOS (10-foot UI, Siri Remote Focus Engine).
- **TCA & Mimari:** `GlobalSearchFeature`, debounce search query, playlist cross-indexing.
- **Durum:** `[IN_PROGRESS]`

### 16. [PENDING] Smart Channel Name Cleaner & Clutter Stripper Regex Engine
- **Açıklama:** IPTV listelerinde kanal isimlerindeki gereksiz "[TR]", "FHD", "1080p", "4K-UHD", "|HEVC|", "VIP" gibi gürültülü ekleri otomatik temizleyen, temiz başlık sunan ve istendiğinde tek tıkla orijinal başlığa dönülebilen akıllı normalizer motoru.
- **Platformlar:** iOS, tvOS (Siri Remote uyumlu ayarlar ve OSD gösterimi).
- **TCA & Mimari:** `ChannelNameCleaner`, `SettingsClient` regex clutter toggles, `PlayableItem` presentation extension.
- **Durum:** `[PENDING]`

### 17. [PENDING] Trakt.tv Watchlist & Scrobble Sync Engine
- **Açıklama:** VOD film ve diziler izlenirken ilerleme durumunu gerçek zamanlı Trakt.tv hesabıyla senkronize eden, "İzlendi" olarak işaretleyen ve kullanıcıların yarım bıraktıkları içerikleri diğer tüm cihazlarından devam ettirmesini sağlayan modern scrobbler.
- **Platformlar:** iOS, tvOS.
- **TCA & Mimari:** `TraktClient`, `TraktFeature`, `PlayerFeature` playback progress scrobble effect.
- **Durum:** `[PENDING]`

### 18. [PENDING] Native Picture-in-Picture (PiP) Background Audio & Auto-PiP on Exit
- **Açıklama:** Oynatıcıdan ana menüye veya diğer uygulamalara geçildiğinde yayını kesintiye uğratmadan iOS ve tvOS sistem PiP penceresine aktaran veya arka planda sadece ses dinleme (background audio playback) modunu akıllıca yöneten motor.
- **Platformlar:** iOS, tvOS (AVPictureInPictureController, AudioSession background modes).
- **TCA & Mimari:** `PiPClient`, `PlayerFeature` PiP state actions (`togglePiP`, `onPiPStatusChanged`).
- **Durum:** `[PENDING]`

### 19. [PENDING] Channel Hide & Category Blacklist PIN Protection System
- **Açıklama:** İstenmeyen kategorileri veya yetişkin kanallarını çalma listelerinden tamamen gizleyen, ebeveyn denetimi (Parental Control PIN) ile korunan ve liste gezintisini tertemiz tutan gizleme/kilit motoru.
- **Platformlar:** iOS, tvOS.
- **TCA & Mimari:** `ParentalControlClient`, `HiddenChannelsDatabase`, `SettingsFeature`.
- **Durum:** `[PENDING]`

### 20. [PENDING] HDR, Dolby Vision & SDR Dynamic Range Indicator HUD
- **Açıklama:** Yayının video akışında HDR10, HLG, Dolby Vision veya SDR renk uzayı ve pik parlaklık bilgisini algılayıp oynatıcı açılışında ve OSD bilgi kartında sinematik altın/mor rozetle gösteren renk uzayı algılayıcı HUD'ı.
- **Platformlar:** tvOS, iOS (Display Gamut & Dynamic Range detection).
- **TCA & Mimari:** `ColorSpaceDetector`, `PlayerFeature.State.videoDynamicRange`, `ChannelInfoOSDView`.
- **Durum:** `[PENDING]`

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


