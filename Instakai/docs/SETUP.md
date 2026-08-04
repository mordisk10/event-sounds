# Kurulum

## Gereksinimler

- TrueDepth kameralı iPhone (iPhone X ve sonrası) — Simülatör yüz takibi
  sağlamaz, gerçek cihaz şart.
- iOS 16 veya üstü
- Xcode 15 veya üstü
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Adımlar

```bash
git clone <repo>
cd Instakai

make project           # project.yml'den Instakai.xcodeproj üretir
open Instakai.xcodeproj
```

Xcode'da:

1. **Signing & Capabilities** → kendi Apple kimliğinizi Team olarak seçin.
2. `PRODUCT_BUNDLE_IDENTIFIER`'ı benzersiz bir değere çevirin
   (örn. `com.<kullanıcıadınız>.instakai`).
3. Hedef cihaz olarak iPhone'unuzu seçip çalıştırın.
4. İlk açılışta kamera izni istenir; reddederseniz Oturum ekranı bunu söyler.

Ücretsiz geliştirici hesabıyla imzalanan uygulamalar 7 günde bir yeniden
yüklenmelidir.

## Testler

Çekirdek yalnızca Foundation'a bağlıdır; Xcode veya simülatör gerekmez:

```bash
make test     # veya: swift test
```

Kapsananlar: tetikleyici durum makinesi (histerezis, basılı tutma, tekrar,
tekrar penceresinin dolması), kural motoru (koşullar, bekleme süreleri,
öncelik, "yalnızca bu", bayrak görünürlüğü), makro genişletme (yuvalama,
döngü tespiti), jeneratör (hassasiyet ölçekleme, doğrulama) ve profil JSON
tur testleri.

## İlk kullanım

1. **Oturum** sekmesi → **Başlat**. Kamera açılır, üstte "Yüz izleniyor"
   rozeti belirir.
2. Sağ üstteki dalga simgesiyle sinyal göstergesini açın. Dilinizi aşağı
   uzatın — `tongueDown` çubuğunun eşik çizgisini geçip geçmediğine bakın.
3. Geçmiyorsa: **Ayarlar → Kalibrasyon sihirbazı**. Nötr ve en yüksek
   değerlerinizi kaydedin.
4. **Kurallar** sekmesinden hazır set seçin ya da kendi kuralınızı kurun.

## İlk kural nasıl kurulur

**Kurallar → +**

| Alan | Değer |
|---|---|
| Ad | Dil aşağı → kaydır |
| Hareket | Dili aşağı uzat |
| Hassasiyet | Orta |
| Ekran | Reels |
| O zaman | Makro çalıştır → `scroll-next` |

Kaydetmeden önce **Canlı önizleme** bölümünde hareketi deneyin: çubuk eşiği
geçiyorsa kural gerçek kullanımda da tetiklenir.

## Core ML dil modeli (isteğe bağlı ama önerilir)

Varsayılan renk sezgiseli yerine eğitilmiş bir dedektör kullanmak için
`docs/GESTURES.md` içindeki "Kendi modelinizi eğitmek" bölümünü izleyin.
`TongueTip.mlmodel` dosyasını `App/Instakai/Resources/` altına ekleyip
`make project` komutunu tekrar çalıştırmanız yeterli.

`.gitignore` model dosyalarını dışarıda tutar; büyük ikili dosyaları depoya
değil, sürüm eklerine koyun.

## Sorun giderme

| Sorun | Çözüm |
|---|---|
| "Bu cihaz yüz takibini desteklemiyor" | Simülatörde veya TrueDepth'siz cihazdasınız |
| Instagram sayfası açılmıyor | Ağ bağlantısı; Ayarlar → Durum bölümündeki hata |
| "Köprü bekliyor" kalıyor | `instakai-bridge.js` uygulama paketine eklenmemiş — `make project` tekrar |
| Hareket tanınıyor ama hiçbir şey olmuyor | Ekran koşulu tutmuyor olabilir; Oturum üstündeki ekran etiketine bakın |
| Kaydırma çok az/çok fazla | Eylem → kaydırma miktarı; Reels için `1.0 ekran` |
