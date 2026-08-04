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
brew install xcodegen
make project
open Instakai.xcodeproj
```

Gereken: Xcode 15+, iOS 17+ hedef cihaz. Dynamic Island için iPhone 14 Pro ve
üzeri; diğer cihazlarda Live Activity kilit ekranında görünür.

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
Widget/           Dynamic Island ve kilit ekranı sunumu
docs/             Açık sorular
```

## Durum

Bu ortamda Swift derleyicisi yoktu — **kod derlenmedi**. Xcode'da ilk açılışta
küçük düzeltmeler gerekebilir.

Ayrıca **veriler sahte**: otomasyon istatistikleri, ana sayfa widget'ları ve
"yapay zekâ" üretimi (şu an anahtar kelime eşleştirmesi) yer tutucu. Arayüz
akışları gerçek, arkalarındaki servisler değil.

Karar bekleyen 15 nokta: [`docs/OPEN-QUESTIONS.md`](docs/OPEN-QUESTIONS.md).
