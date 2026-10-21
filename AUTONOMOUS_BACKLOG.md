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

### 4. [PENDING] Catchup / Timeshift TV Archive Visual Scrubber & Timeline Bookmarks
- **Açıklama:** `tvArchive == 1` olan kanallarda geçmiş 3 günlük EPG programlarını zaman çizelgesi üzerinde gösterip tek dokunuşla geriye dönük izleme başlatan interaktif timeline scrubber.
- **Platformlar:** iOS, tvOS.
- **Durum:** `[PENDING]`

### 5. [PENDING] MultiView 1+3 Layout & Siri Remote One-Tap Audio Focus Swapping
- **Açıklama:** MultiView ekranında 1 ana odak ekranı ve yanında 3 dikey alt ekran düzeni sunma; Siri Remote veya dokunma ile anında ana ses kanalını değiştirme.
- **Platformlar:** tvOS, iPadOS, iOS.
- **Durum:** `[PENDING]`

### 6. [PENDING] Sleep Timer Smooth Audio Fade-Out Engine
- **Açıklama:** Uyku zamanlayıcısının son 60 saniyesinde sesi kademeli olarak sıfıra indiren ve ekran parlaklığını yumuşakça kısarak oynatmayı sonlandıran sinematik deneyim.
- **Platformlar:** iOS, tvOS.
- **Durum:** `[PENDING]`

### 7. [PENDING] EPG 'Now & Next' Channel Peek with Live Elapsed Progress Ring
- **Açıklama:** Kanal zapping HUD'ında ve OSD'sinde o anki programın ne kadarının geçtiğini gösteren şık dairesel/çizgisel progress bar ve hemen sonrasındaki programın başlama saati.
- **Platformlar:** iOS, tvOS.
- **Durum:** `[PENDING]`

### 8. [PENDING] Smart Stream Reconnect with Exponential Backoff & Backup Stream Fallback
- **Açıklama:** Yayın koptuğunda veya sunucu 403/timeout döndüğünde donmayı engelleyen akıllı yeniden bağlanma ve alternatif playlist linkine otomatik geçiş mekanizması.
- **Platformlar:** iOS, tvOS.
- **Durum:** `[PENDING]`

### 9. [PENDING] Instant Channel Category Filter Chips in Channel Drawer (Sports, News, 4K)
- **Açıklama:** Kanal yan çekmecesinde binlerce kanal arasında anında Spor, Haber, Sinema veya 4K/FHD kanalları listeleyen akıcı filter chip bileşeni.
- **Platformlar:** iOS, tvOS.
- **Durum:** `[PENDING]`

### 10. [PENDING] Instant Previous Channel Quick-Recall Gesture (Double-Tap Return)
- **Açıklama:** Siri Remote'ta veya iOS ekranda çift dokunuşla son izlenen bir önceki kanala anında geri dönme ("Recall / Previous Channel") özelliği.
- **Platformlar:** tvOS, iOS.
- **Durum:** `[PENDING]`

---

## 🏁 Tamamlanan Özellikler ([DONE])
- **#1 Quick Recent Channels Carousel HUD (Quick-Zap Dock):** 
  - `RecentChannelDTO` modeli oluşturuldu.
  - `RecentChannelsClient` TCA bağımlılık servisi eklendi (UserDefaults kalıcılığı ile son 20 kanalı otomatik saklar).
  - `PlayerFeature` reducer'ına `toggleRecentChannelsHUD`, `selectRecentChannel`, `loadRecentChannels` aksiyonları eklendi.
  - `RecentChannelsHUDView.swift` oluşturuldu: tvOS Focus Engine tam uyumlu, Siri Remote ile gezinilebilir, 1.08x odak büyütmesi, OLED siyahı & Electric Blue vurguları.
  - iOS ve tvOS `PlayerView`'lerine doğrudan entegre edildi: tvOS'ta Siri Remote Aşağı yön tuşu ile, iOS'ta ise kontroller ve hızlı menüden anında açılır.
