# Hareketler ve dil yönü

## Sinyaller

Motorun gördüğü her şey `Signal` enum'unda tanımlıdır ve **0–1 aralığına**
normalize edilir. İşaretli eksenler yoktur: `headYaw` yerine `headYawLeft` ve
`headYawRight` vardır. Böylece bir kural `"headYawLeft > 0.5"` gibi doğrudan
okunur.

| Grup | Sinyaller | Kaynak |
|---|---|---|
| Dil | `tongueOut`, `tongueUp/Down/Left/Right`, `tongueConfidence` | ARKit + Vision |
| Ağız | `jawOpen`, `mouthPucker`, `mouthFunnel`, `mouthSmileLeft/Right`, `cheekPuff` | ARKit |
| Göz & kaş | `eyeBlinkLeft/Right`, `eyeSquintLeft/Right`, `browInnerUp`, `browDownLeft/Right` | ARKit |
| Baş | `headYawLeft/Right`, `headPitchUp/Down`, `headRollLeft/Right` | ARKit dönüşüm matrisi |
| Bakış | `gazeLeft/Right/Up/Down` | ARKit `eyeLook*` |
| Durum | `faceVisible` | ARKit |

## Dil yönü nasıl çıkarılıyor

ARKit yalnızca `tongueOut` verir — dilin **ne kadar** çıktığını söyler, **nereye
baktığını** söylemez. Projenin çekirdek hareketi ("dil aşağı → kaydır") yön
istediği için bunu kendimiz hesaplıyoruz:

1. **Ağız bölgesi.** `VNDetectFaceLandmarksRequest` iç dudak poligonunu verir.
   Dil ağızdan *dışarı* çıktığı için arama bölgesi dudakların altına doğru
   genişletilir (`docs` yerine koda bakın: `TongueDirectionEstimator.analyse`).

2. **Dil ucu.** İki dedektörden biri çalışır:
   - `CoreMLTongueTipDetector` — pakette `TongueTip.mlmodelc` varsa.
   - `PixelStatisticsTongueTipDetector` — model yoksa; kırmızılık ağırlıklı
     ağırlık merkezi.

3. **Yön vektörü.** Uç konumunun ağız merkezine göre sapması, ağız boyutuna
   bölünür ve **baş eğikliği kadar ters döndürülür**. Böylece başınız yana
   yatıkken de "aşağı" çeneye doğru olan yön kalır.

4. **Ölçekleme.** Yön bileşenleri `tongueOut` ile çarpılır: zar zor görünen bir
   dil, ne kadar güvenli konumlandırılırsa konumlandırılsın güçlü sinyal
   üretemez.

5. **Kapılama.** `SignalProcessor`, `tongueOut < tongueGate` veya
   `tongueConfidence < confidenceGate` ise tüm yön sinyallerini sıfırlar.
   Kapalı ağızda gürültünün kaydırma tetiklemesini bu engeller.

### Kendi modelinizi eğitmek

Varsayılan renk sezgiseli çalışır ama zayıf noktadır. Daha iyisi için:

1. Create ML → **Object Detection** projesi açın.
2. Kendi yüzünüzden ~300 kare toplayın: dil dışarı, dört yöne ve arada.
   Farklı ışık, mesafe ve açı ekleyin.
3. Tek sınıf kullanın: `tongue`. Kutuyu **yalnızca dilin görünen kısmına**
   çizin, dudakları dahil etmeyin.
4. Modeli `TongueTip.mlmodel` adıyla dışa aktarıp `App/Instakai/Resources/`
   altına ekleyin ve Xcode hedefine dahil edin.

Kod değişikliği gerekmez — `CoreMLTongueTipDetector.makeIfAvailable()` modeli
bulur ve otomatik devreye girer.

## Hazır hareketler ve ayarları

`RuleGenerator.tuning(for:)` her hareket için temel değerleri tutar.
Hassasiyet bunları ölçekler (`düşük` 1.25×, `orta` 1.0×, `yüksek` 0.78× eşik).

| Hareket | Eşik | Basılı tutma | Mod | Bekleme |
|---|---|---|---|---|
| Dil aşağı/yukarı/sol/sağ | 0.45 | 0.16 sn | 0.55 sn'de bir tekrar | 0.25 sn |
| Dili kısa çıkar | 0.50 | 0.10–0.55 sn | bırakınca | 0.40 sn |
| Dili uzun çıkar | 0.50 | 0.90 sn | kenar | 1.00 sn |
| Dili iki kez çıkar | 0.50 | 2× / 1.0 sn | bırakınca | 0.70 sn |
| Ağzı aç | 0.55 | 0.25 sn | kenar | 0.60 sn |
| Çift göz kırpma | 0.62 | 2× / 0.85 sn | bırakınca | 0.80 sn |
| Kaş kaldır | 0.50 | 0.22 sn | kenar | 0.70 sn |
| Gülümse | 0.55 | 0.30 sn | kenar | 1.20 sn |
| Yanak şişir | 0.50 | 0.25 sn | kenar | 0.80 sn |
| Baş hareketleri | 0.42 | 0.30 sn | kenar | 0.80 sn |

Neden yön hareketleri **tekrarlı**: dili aşağı tutup bırakmadan kaydırmaya devam
etmek, her kaydırma için ayrı bir hareket yapmaktan çok daha az yorucudur.

Neden göz kırpma **çift**: doğal göz kırpması tek eşiği kolayca geçer.

## Yanlış tetikleme giderme

| Belirti | Bakılacak yer |
|---|---|
| Hiç tetiklenmiyor | Oturum → sinyal göstergesi; çubuk eşik çizgisini geçiyor mu? |
| Çubuk eşiği geçmiyor | Ayarlar → Kalibrasyon sihirbazı |
| Kapalı ağızda tetikleniyor | Ayarlar → dil kapısı ve güven kapısını yükseltin |
| Titriyor / çift tetikliyor | Ayarlar → yumuşatmayı düşürün, kural beklemesini artırın |
| Yanlış kural kazanıyor | Kural → Gelişmiş → öncelik ve "yalnızca bu" |
| Sol/sağ ters | `InstakaiVision.orientation` (bkz. `docs/LIMITATIONS.md` §4) |
