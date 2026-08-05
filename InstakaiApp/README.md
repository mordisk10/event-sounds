# Instakai — UI

iPhone için SwiftUI arayüzü. Açık/beyaz zemin, turuncu vurgu, 4 sekmeli
navigasyon, iki dilli (TR/EN, uygulama içinden değiştirilebilir).

> **Kapsam:** Bu tur yalnızca **arayüz**. Instagram'ı sürme yöntemi (taşıma
> katmanı) bilinçli olarak seçilmedi — o karar sonraya bırakıldı. Arayüzün
> hiçbir yerinde WebView yok ve arayüz seçilecek yöntemden bağımsız çalışacak
> şekilde kuruldu.

---

## Ekranlar

| Sekme | İçerik |
|---|---|
| **Ana** | Oturum durumu, mikrofon (bas-konuş / sabit), gizli sohbet girişi, panoramik widget kaydırıcısı |
| **Otomasyon** | Yapay zekâ ile kurulum, otomasyon listesi, düzenleyici (basit + teknik) |
| **Planlar** | Aylık/yıllık, panoramik plan kartları, karşılaştırma |
| **Profil** | Hesap, ayarlar, yardım ve destek, yasal, çıkış, hesap silme |

Sekme dışı: giriş/kayıt/parola sıfırlama, sohbet, iletişim formu, 4 yasal
doküman.

## Ana tasarım kararları

**Mikrofon iki farklı jest istiyor.** `Button` kullanılamaz: bas-konuş için
basma ve bırakma ayrı olaylar olarak gerekir, `onLongPressGesture` ise minimum
süre dolmadan bırakmayı bildiremez. Bu yüzden sıfır mesafeli bir `DragGesture`
kullanılıyor. Mod seçici butonun **sağında**, iki seçenek ve altında o modun
tek cümlelik açıklaması ile duruyor.

**Panoramik kaydırıcı** dört dönüşümü tek bir değerden türetiyor: kartın
görüntü alanı merkezine olan uzaklığı (`-1…1`). Y ekseni etrafında perspektifli
döndürme, ölçek, saydamlık ve hafif bulanıklık. `scrollTransition` ile
yapılıyor; iOS'ta Z ötelemesi olmadığı için derinliği ölçek + bulanıklık
taşıyor. Hem ana sayfadaki widget'lar hem de plan kartları aynı bileşeni
kullanıyor, böylece ödeme ekranı ayrı bir "paywall" gibi durmuyor.

**Push efekti tek yerden geliyor.** `PushButtonStyle` üç yoğunlukta (subtle /
standard / pronounced) ölçek + parlaklık düşüşü ve dokunma anında haptik
uygular. Uygulamadaki her dokunulabilir şey bunu kullanır — tek kişilikli bir
his bunu gerektiriyor.

**Dynamic Island iki katmanlı.** Uygulama açıkken ekranın üstündeki siyah kapsül
(`IslandFeedbackOverlay`) adadan büyüyerek çıkıyor; uygulama arka plandayken
aynı olaylar `Widget/` içindeki Live Activity'ye gidiyor ve gerçek adada
görünüyor. Kutlama, klasik çok renkli konfeti değil — turuncu ailede kalan
parçacıklar, çünkü bir kilometre taşı hâlâ Instakai gibi görünmeli. Rutin geri
bildirimde kutlama yok; olsaydı anlamını yitirirdi.

**Teknik sayfa boğmuyor.** Otomasyonlar sekmesinde en üstte yapay zekâ kutusu
var (en kolay yol ilk yol). Satırlar cümle gibi okunuyor: tetikleyici → eylem.
Öncelik, bekleme ve "yalnızca bu" gibi kafa karıştıran üç ayar bir açılır
bölümün arkasında ve her birinin yanında ⓘ butonu var — paragraf yerine tek
cümle, bir dokunuş uzakta.

**Dil sistemden değil, kullanıcıdan.** `NSLocalizedString` sistem diline bakar
ve uygulama içi seçiciyle çakışırdı. Bunun yerine `S` enum'u + arama tablosu
kullanılıyor; Ayarlar'daki seçici belirleyici. İlk açılışta cihaz dilinden
tahmin ediliyor.

## Kurulum

```bash
cd InstakaiApp
./Tools/bootstrap.sh com.<kullaniciadin>
```

Betik Xcode sürümünü doğrular, XcodeGen'i kurar, paket kimliğini sizinkiyle
değiştirir, projeyi üretir ve açar. Elle yapmak isterseniz `make project`.

Gereken: **Xcode 16+** (XcodeGen'in ürettiği proje formatını Xcode 15 açamıyor),
iOS 17+ hedef cihaz. Dynamic Island için iPhone 14 Pro ve üzeri; diğer
cihazlarda Live Activity kilit ekranında görünür.

Kendi iPhone'unuza kurmak için ücretli Apple Developer hesabı **gerekmiyor** —
ücretsiz bir Apple ID yeterli. Adım adım:
[`docs/RUN-ON-DEVICE.md`](docs/RUN-ON-DEVICE.md).

## Sürekli entegrasyon

`.github/workflows/instakai.yml` her push'ta macOS runner üzerinde çalışır:

| İş | Yaptığı |
|---|---|
| `core` | `InstakaiCore` birim testleri (`swift test`) — simülatör gerekmez |
| `app` | XcodeGen ile projeyi üretip uygulamayı ve widget uzantısını derler |

`app` işi simülatör hedefine, imzalama kapalı olarak derler; sertifika
gerekmez. Derlenen `.app` artifact olarak yüklenir ve simülatöre kurulabilir:

```bash
xcrun simctl install booted Instakai.app
```

**Bu dosya fiziksel iPhone'a kurulmaz.** Cihaza kurulabilir bir `.ipa` için
Apple Developer hesabınızdan üç secret gerekir — ayrıntısı workflow dosyasının
sonunda yazılı.

## Uygulama ikonu

`Tools/make_appicon.py` ikonu signed distance field'lardan üretir; yalnızca
standart kütüphane kullanır, Pillow gerekmez.

```bash
python3 Tools/make_appicon.py
```

İşaret ürüne özel: bir Dynamic Island kapsülü ve altından düşen chevron —
uygulamanın iki tanımlayıcı fikri tek şekilde. Üretici depoda tutuluyor, yani
ikon açıklanamaz bir ikili dosya değil, yeniden üretilebilir bir çıktı.

## Yapı

```
Instakai/
  App/            Giriş noktası, kök görünüm, 4 sekmeli navbar
  DesignSystem/   Renk/tipografi/aralık, push efekti, ortak bileşenler
  Localization/   İki dilli metin tablosu ve dil yöneticisi
  Auth/           Oturum durumu, giriş/kayıt/parola sıfırlama
  Home/           Mikrofon, sohbet, ana ekran
  Panorama/       3D panoramik kaydırıcı ve kartları
  Automations/    Model, liste, düzenleyici
  Pricing/        Plan kademeleri ve planlar ekranı
  Profile/        Profil, ayarlar, yardım, iletişim, yasal
  Island/         Ekran üstü geri bildirim, kutlama, Live Activity modeli
  Assets.xcassets Vurgu rengi ve uygulama ikonu
Widget/           Dynamic Island ve kilit ekranı sunumu
Tools/            İkon üreteci
docs/             Açık sorular
```

## Durum

**Derleniyor.** Uygulama ve widget uzantısı CI'da Xcode 16 ile hatasız ve
uyarısız derleniyor (`** BUILD SUCCEEDED **`). Kod bu depoda Swift derleyicisi
olmadan yazıldı, o yüzden bunu doğrulayan tek şey CI — yeşil kalmasına dikkat
edin.

**Cihazda çalıştırılmadı.** Derlenmek çalışmak değil. Kamera izni akışı, gerçek
Dynamic Island davranışı, haptikler ve panoramik kaydırıcının dokunmatik hissi
yalnızca fiziksel bir iPhone'da doğrulanabilir.

**Veriler sahte.** Otomasyon istatistikleri, ana sayfa widget'ları ve "yapay
zekâ" üretimi (şu an anahtar kelime eşleştirmesi) yer tutucu. Arayüz akışları
gerçek, arkalarındaki servisler değil.

**Taşıma katmanı seçilmedi.** Instagram'ın gerçekte nasıl sürüleceği (XCUITest /
harici BLE donanımı / jailbreak) açık bir karar. Arayüz bilinçli olarak bu
karardan bağımsız kuruldu.

Karar bekleyen 15 nokta: [`docs/OPEN-QUESTIONS.md`](docs/OPEN-QUESTIONS.md).
