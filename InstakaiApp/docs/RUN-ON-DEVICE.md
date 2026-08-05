# Uygulamayı kendi iPhone'unda çalıştırmak

**Ücretli Apple Developer hesabı gerekmiyor.** Ücretsiz bir Apple ID yeterli.
Gereken tek şey bir Mac.

---

## Ne gerekiyor

| | |
|---|---|
| Mac | macOS Sonoma (14) veya üstü |
| Xcode | 15 veya üstü — App Store'dan ücretsiz |
| Apple ID | Sahip olduğunuz herhangi bir Apple ID; ücretli üyelik gerekmez |
| iPhone | iOS 17+. Dynamic Island için iPhone 14 Pro ve üzeri |
| Kablo | İlk kurulum için USB. Sonrasında kablosuz da olur |

---

## Adımlar

### 1. Depoyu al ve projeyi üret

```bash
brew install xcodegen
cd InstakaiApp
make project
open Instakai.xcodeproj
```

### 2. Apple ID'ni Xcode'a ekle

**Xcode → Settings → Accounts → +** → Apple ID → giriş yap.

Ücretli üyelik istemiyor. Giriş yapınca hesabın altında **Personal Team** diye
bir takım belirir; imzalama bununla yapılacak.

### 3. Paket kimliğini değiştir

Bu adım atlanabilir gibi durur ama **atlanamaz.** Ücretsiz imzalama, başkasının
kaydettiği bir paket kimliğini reddeder ve `com.instakai.app` yeterince genel
bir isim — büyük ihtimalle alınmış.

`project.yml` içinde iki satırı kendi adınıza çevirin:

```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.<kullaniciadin>.instakai         # Instakai hedefi
PRODUCT_BUNDLE_IDENTIFIER: com.<kullaniciadin>.instakai.widget  # InstakaiWidget hedefi
```

Widget kimliği **uygulamanınkinin altında** kalmalı, yani `.widget` ekiyle aynı
önekten türemeli. Sonra projeyi yeniden üretin:

```bash
make project
```

### 4. Takımı seç

Xcode'da her iki hedef için ayrı ayrı:

**Instakai** hedefi → **Signing & Capabilities** → **Team** → Personal Team
**InstakaiWidget** hedefi → aynı şey

"Automatically manage signing" işaretli olmalı (proje bunu zaten açık üretiyor).

### 5. iPhone'u bağla ve çalıştır

1. iPhone'u USB ile bağla, telefonda **Bu bilgisayara güven** de.
2. Xcode'un üst çubuğundaki cihaz seçicisinden iPhone'unu seç.
3. **⌘R**.

### 6. Geliştiriciye güven

İlk çalıştırmada iPhone "Güvenilmeyen Geliştirici" diyecek. Telefonda:

**Ayarlar → Genel → VPN ve Cihaz Yönetimi → (Apple ID'niz) → Güven**

Sonra uygulamayı tekrar açın.

---

## Ücretsiz hesabın sınırları

Bunlar Apple'ın koyduğu sınırlar, projeyle ilgisi yok:

- **7 gün.** Uygulama bir hafta sonra açılmaz olur. Xcode'dan **⌘R** ile tekrar
  kurmanız yeter — verileriniz kalır.
- **Aynı anda 3 uygulama.** Instakai + widget uzantısı bu kotadan yer kaplar.
- **10 cihaz / 7 gün.** Pratikte takılacağınız bir sınır değil.
- **Push bildirimi yok.** Uygulama şu an kullanmıyor, sorun değil.

Dynamic Island ve Live Activity ücretsiz hesapta çalışır — ücretli üyelik
gerektiren bir yetkilendirme kullanmıyoruz.

---

## Mac'im yok

O zaman native iOS uygulamasını çalıştırmanın pratik bir yolu yok. Seçenekler,
dürüst değerlendirmeleriyle:

| Yol | Gerçekçi mi |
|---|---|
| Bulut Mac kiralama (MacinCloud, Scaleway Mac mini) | Çalışır. Saatlik/aylık ücretli. Cihaza kurulum için iPhone'u fiziksel olarak bağlayamazsınız — yalnızca simülatörde test edersiniz. |
| Ödünç Mac | En hızlısı. Bir öğleden sonra yeter, kurulum 20 dakika. |
| CI'daki simülatör derlemesi | İndirilebilir ama açmak yine Mac ister. |
| Web prototipi | Telefonda hemen açılır, ama gerçek uygulama değil — kamera, Dynamic Island ve haptik yok. |

CI'nin ürettiği `.app` **fiziksel iPhone'a kurulmaz**; o dosya simülatör için
derlenir. Cihaza kurulum yalnızca yukarıdaki Xcode akışıyla olur.

---

## CI neden ücretli hesap istiyor?

Workflow'un sonundaki not ücretli hesaptan bahsediyor, bu adımdaki ücretsiz
akışla çelişmiyor:

- **Xcode'dan kendi cihazınıza kurmak** — ücretsiz Apple ID yeter. Xcode
  arka planda 7 günlük geçici bir profil üretir.
- **CI'nin `.ipa` üretmesi** — ücretli hesap gerekir. Ücretsiz profiller
  Xcode'un arayüz akışına bağlıdır, sunucuda başsız üretilemez ve zaten
  haftada bir yenilenmeleri gerekir.

Yani: test için ücretsiz yeterli, dağıtım için ücretli lazım.

---

## Sorun giderme

| Hata | Sebep |
|---|---|
| "Failed to register bundle identifier" | Paket kimliği alınmış — 3. adımı yapın |
| "No profiles for '...' were found" | Takım seçilmemiş — 4. adım, her iki hedef için |
| "Untrusted Developer" | 6. adım yapılmamış |
| Uygulama açılıp hemen kapanıyor | 7 gün dolmuş — Xcode'dan tekrar ⌘R |
| `xcodegen: command not found` | `brew install xcodegen` |
| Widget hedefi imzalanmıyor | Widget kimliği uygulamanınkinin alt kimliği değil |
