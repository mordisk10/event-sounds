# Instakai

iPhone'da eller serbest Instagram: ön kamera yüzünüzü izler, **dilinizin yönünü**
algılar ve bu hareketleri tamamen sizin ayarladığınız makrolara bağlar.

Dilinizi aşağı uzattığınızda içerik kayar. Neyin ne yapacağına siz karar
verirsiniz — hareket, koşul ve eylemleri bir arayüzden kurarsınız, kod
yazmadan.

> **Önce şunu bilin:** iOS, bir uygulamanın başka bir uygulamaya dokunma olayı
> göndermesine izin vermez. Instakai, Instagram uygulamasını **dışarıdan
> süremez**. Bunun yerine Instagram web istemcisini kendi içinde barındırır ve
> komutları oraya uygular. Ayrıntı ve alternatifler:
> [`docs/LIMITATIONS.md`](docs/LIMITATIONS.md).

---

## Nasıl çalışıyor

```
Ön kamera (TrueDepth)
      │
      ▼
ARKit yüz takibi ──► 52 blend shape (tongueOut, jawOpen, blink, …)
      │
      ▼
Vision + dil ucu dedektörü ──► dil yönü (yukarı / aşağı / sol / sağ)
      │
      ▼
SignalProcessor ──► kalibrasyon, yumuşatma, kapılama
      │
      ▼
RuleEngine ──► "eğer bu hareket VE şu koşul → o zaman şu makro"
      │
      ▼
MacroDispatcher ──► JS köprüsü ──► barındırılan Instagram
```

ARKit `tongueOut` değerini verir ama **yön** vermez. Bu projenin dayandığı
"dil aşağı" hareketi için yönü kendimiz çıkarıyoruz: Vision yüz işaretlerinden
ağız bölgesini buluyor, bir dedektör dil ucunu o bölgede konumlandırıyor, ağız
merkezine göre sapma (baş eğikliğine göre döndürülmüş) yön vektörünü veriyor.
Ayrıntı: [`docs/GESTURES.md`](docs/GESTURES.md).

## Jeneratör

Kurallar elle yazılmaz, **üretilir**. Arayüzde bir *taslak* (`RuleBlueprint`)
doldurursunuz:

| Alan | Örnek |
|---|---|
| Hareket | Dili aşağı uzat |
| Hassasiyet | Orta |
| Ekran | Reels |
| Eğer | `bayrak gezinme = kapalı` |
| O zaman | `scroll-next` makrosu |

`RuleGenerator` bunu eşik, histerezis, basılı tutma süresi, tekrar penceresi ve
bekleme süresi olan çalıştırılabilir bir `Rule`'a çevirir. Eşikleri siz
ayarlamazsınız — hareket ve hassasiyet seçersiniz, sayıları jeneratör bilir.

Faydası: ayarlar tek bir tabloda (`RuleGenerator.tuning`) toplanır. Gerçek
cihazda bir hareket kötü hissettiriyorsa orayı düzeltirsiniz; kullanıcıların
kayıtlı kurallarının hiçbiri değişmek zorunda kalmaz.

Tam şema ve JSON biçimi: [`docs/RULES.md`](docs/RULES.md).

## Koşullar ("eğer")

Koşullar tetikleyiciden ayrıdır. Tetikleyici "hareket oldu mu?" sorusunu,
koşul "şu an sayılmalı mı?" sorusunu yanıtlar. Bu ayrım sayesinde aynı
"dil aşağı" hareketi:

- Reels'te bir sonraki klibe geçer,
- akışta kısmi kaydırır,
- mesajlarda hiçbir şey yapmaz,
- `gezinme` bayrağı açıkken tamamen başka bir iş yapar.

Koşullar iç içe geçebilir: `TÜMÜ`, `HERHANGİ BİRİ`, `DEĞİL`, sinyal
karşılaştırması, ekran, bayrak, saat aralığı, mod.

## Kurulum

Gereken: TrueDepth kameralı bir iPhone (iPhone X ve üstü), iOS 16+, Xcode 15+.

```bash
brew install xcodegen
make project        # Instakai.xcodeproj üretir
open Instakai.xcodeproj
```

Çekirdek mantık Xcode olmadan da test edilir:

```bash
make test           # swift test — Foundation dışında bağımlılığı yok
```

Ayrıntılı adımlar: [`docs/SETUP.md`](docs/SETUP.md).

## Proje yapısı

```
Sources/InstakaiCore/     Platformdan bağımsız çekirdek (test edilebilir)
  Signals/                Sinyal tanımları, kalibrasyon, yumuşatma
  Gestures/               Tetikleyici ve durum makinesi
  Rules/                  Koşullar, kural, motor
  Macros/                 Eylemler, makrolar, genişletici
  Generator/              Taslak → kural derleyicisi
  Profile/                Profil, hazır setler, JSON deposu
App/Instakai/             iOS uygulaması
  Tracking/               ARKit + Vision boru hattı
  Surface/                Instagram web köprüsü
  Runtime/                Dağıtıcı, oturum denetleyicisi
  UI/                     SwiftUI ekranları
Tests/InstakaiCoreTests/  Birim testleri
docs/                     Mimari, hareketler, kurallar, kısıtlar
```

## Gizlilik

Kamera görüntüsü cihazdan çıkmaz, hiçbir yere kaydedilmez ve ağ üzerinden
gönderilmez. İşlenen tek şey ARKit'in ürettiği yüz ölçümleri ve ağız
bölgesinden hesaplanan dil konumudur. Profiller cihazda JSON olarak durur.

## Durum

Çekirdek (`InstakaiCore`) birim testleriyle birlikte tamamlandı. iOS katmanı
yazıldı ancak **henüz gerçek cihazda derlenmedi ve çalıştırılmadı** — özellikle
kamera oryantasyonu ve Instagram DOM seçicileri gerçek donanımda doğrulama
gerektirir. [`docs/LIMITATIONS.md`](docs/LIMITATIONS.md) neyin kesin, neyin
doğrulanmayı beklediğini listeler.

## Lisans

MIT — [`LICENSE`](LICENSE).
