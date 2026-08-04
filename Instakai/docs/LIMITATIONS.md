# Kısıtlar ve gerçekler

Bu dosya, projenin neyi yapıp neyi yapamayacağını açıkça yazar. Bir şeyi
denemeden önce buraya bakın.

## 1. Instagram uygulamasını dışarıdan süremeyiz

iOS'ta bir uygulama, başka bir uygulamaya sentetik dokunma olayı gönderemez.
Bunun herkese açık bir API'si yok:

- `UIAccessibility` **okuma** tarafında zengindir; başka uygulamaya olay
  **yazamaz**.
- Switch Control ve AssistiveTouch sistem düzeyinde çalışır, üçüncü taraf
  uygulamalar bunlara giriş kaynağı ekleyemez.
- App Intents / Shortcuts yalnızca uygulamanın kendi açtığı eylemleri sunar;
  Instagram kaydırma eylemi yayımlamaz.
- Ekran Kaydı uzantıları (`ReplayKit`) ekranı **okur**, kontrol etmez.

Bu yüzden Instakai, Instagram web istemcisini (`instagram.com`) kendi içinde bir
`WKWebView` ile barındırır ve komutları oraya uygular. Aynı süreçte hem yüzü
izleyip hem Instagram'a etki edebilmenin tek yolu budur.

**Sonuçları:**

- Yerel uygulamanın bazı özellikleri web istemcisinde yoktur veya farklıdır.
- Instagram, otomasyonu kendi kullanım şartlarında sınırlar. Bu proje
  erişilebilirlik amacıyla, kendi hesabınızda, kendi cihazınızda kullanılmak
  üzere yazıldı. Toplu işlem, sahte etkileşim veya hesap otomasyonu için
  tasarlanmadı ve o amaçla kullanılması hesabınızın kısıtlanmasına yol açabilir.
- Uygulama App Store'a gönderilecekse, başka bir servisin web sitesini
  barındırması nedeniyle inceleme sorunları çıkabilir (Kılavuz 4.2 / 5.2.1).
  Kişisel kullanım için ad-hoc imzalama veya TestFlight uygundur.

### Bu değişirse nereye bakılır

`InstagramSurfaceController` bir soyutlamadır. Aşağıdaki durumlarda yalnızca o
sınıfın yerine yenisi yazılır, motor ve jeneratör aynı kalır:

- **Jailbreak'li cihaz:** `IOHIDEvent` ile sistem geneli dokunma üretilebilir.
- **Mac Catalyst / macOS:** `CGEvent` ile sistem geneli olay gönderilebilir.
- **Instagram resmî API'si:** Kaydırma sunmaz, ancak beğeni/kaydetme gibi
  eylemler için Graph API bir gün yeterli olursa buraya bağlanır.

## 2. Dil yönü tahmini kesin değil

ARKit `tongueOut` için tek bir 0–1 değeri verir. **Yön bilgisi yoktur.**
Yönü Vision + kendi dedektörümüzle çıkarıyoruz (bkz. `docs/GESTURES.md`).

Varsayılan dedektör (`PixelStatisticsTongueTipDetector`) renk istatistiğine
dayanır ve şu durumlarda zayıflar:

- düşük ışık,
- koyu ruj,
- kameraya çok yakın veya çok uzak durma,
- güçlü arkadan ışık.

Bunu telafi eden üç mekanizma var: güven kapısı (`confidenceGate`), dil kapısı
(`tongueGate`) ve kalibrasyon. Yine de üretim kalitesi için `TongueTip.mlmodel`
adında eğitilmiş bir Core ML nesne algılayıcı eklenmesi önerilir; eklendiğinde
otomatik olarak devreye girer.

## 3. Donanım gereksinimi

`ARFaceTrackingConfiguration` TrueDepth kamera veya A12+ yonga ister. iPhone X
ve sonrası çalışır. Desteklenmeyen cihazda uygulama açılır ama takip
başlamaz ve Oturum ekranında bunu söyler.

## 4. Henüz gerçek cihazda doğrulanmadı

Bu depo Linux üzerinde yazıldı; Swift derleyicisi ve Xcode mevcut değildi.
Aşağıdakiler **gerçek iPhone'da doğrulanmalı**:

| Konu | Neden şüpheli | Nerede |
|---|---|---|
| Kamera oryantasyonu | `.leftMirrored` portre için doğru varsayıldı; yanlışsa sol/sağ ekseni ters çalışır | `InstakaiVision.orientation` |
| Baş eğikliği işareti | ARKit'in euler işaret düzeni cihazda doğrulanmalı | `ARSignalMapper.eulerAngles` |
| Instagram DOM seçicileri | Instagram arayüzü sık değişir | `Resources/instakai-bridge.js` |
| Web görünümü kullanıcı arayüzü dizesi | Mobil/masaüstü düzeni hangi düğmeleri gösteriyor | `InstagramSurfaceController.makeWebView` |

Çekirdek (`InstakaiCore`) bu belirsizliklerden bağımsızdır ve birim testleriyle
kapsanmıştır; `make test` ile Xcode olmadan çalıştırılabilir.

## 5. Bilinçli olarak yapılmayanlar

- **Arka planda çalışma:** ARKit oturumu uygulama ön planda değilken çalışmaz.
  Instakai açıkken kullanılır.
- **Birden fazla yüz:** `maximumNumberOfTrackedFaces = 1`.
- **Kamera görüntüsünün kaydı:** hiçbir kare diske yazılmaz veya ağa
  gönderilmez. Hata ayıklama için bile böyle bir yol eklenmedi.
