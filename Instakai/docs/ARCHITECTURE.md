# Mimari

## Neden iki katman

`InstakaiCore` yalnızca Foundation'a bağlıdır. ARKit, Vision, WebKit, SwiftUI —
hiçbiri çekirdeğe girmez. Karşılığında:

- Kural motoru, tetikleyici zamanlaması ve makro genişletme **cihazsız test
  edilir**. Kamera karşısında oturup el yordamıyla doğrulanacak mantık kalmaz.
- Aynı çekirdek ileride macOS'ta veya farklı bir barındırma yüzeyinde
  değiştirilmeden kullanılır.

Uygulama katmanı yalnızca "sinyalleri üret" ve "eylemleri gerçekleştir"
işlerinden sorumludur.

## Veri akışı

```
ARSession (60 Hz)
  └─ ARFaceAnchor
       ├─ ARSignalMapper.makeFrame        blend shape'ler + baş pozu → SignalFrame
       └─ TongueDirectionEstimator        Vision, 20 Hz, ayrı kuyruk
            └─ decorate(frame)            yön sinyallerini ekler
                 └─ SignalProcessor       kalibrasyon → yumuşatma → kapılama
                      └─ RuleEngine.update(frame:context:)
                           └─ [RuleFiring]
                                └─ MacroDispatcher.dispatch
                                     └─ SurfaceCommand → JS köprüsü
```

## Eşzamanlılık

| İş | Yer | Neden |
|---|---|---|
| ARKit kare işleme | ARKit delege kuyruğu | Kare hızını bloklamamak |
| Vision yüz işaretleri | özel seri kuyruk | Pahalı; her 3. karede bir |
| Kural değerlendirme | main actor | Bayrak ve bağlam durumu tek yerde |
| Eylem gönderme | main queue, zamanlanmış | WebKit main-thread ister |

`TongueDirectionEstimator` bir kare işlenirken gelen yeni kareleri **düşürür**.
Kuyruk biriktirmek gecikmeyi büyütür; hareket algılamada bayat veri işe
yaramaz.

## Durum nerede tutulur

| Durum | Sahip | Ömrü |
|---|---|---|
| Hareket fazı (idle/arming/active) | `TriggerStateMachine`, kural başına | Oturum |
| Bekleme süreleri | `RuleEngine.lastFired` | Oturum |
| Yumuşatma geçmişi | `SignalProcessor.smoothed` | Yüz kaybolunca sıfırlanır |
| Bayraklar | `FlagRegistry` (referans tipi) | Oturum |
| Profil | `Profile` (değer tipi) + `ProfileStore` | Kalıcı |

`FlagRegistry`'nin referans tipi olması bilinçlidir: aynı karede önce çalışan
bir kuralın yazdığı bayrağı, sonra değerlendirilen bir kural görmelidir.

`RuleEngine.replace(rules:)` hayatta kalan kuralların durum makinelerini
korur. Kullanıcı kamera açıkken kural düzenlerken her tuş vuruşunda hareket
durumunun sıfırlanmaması için gereklidir.

## Sınır: taslak mı, kural mı

- **Kaydedilen, paylaşılan, düzenlenen:** `RuleBlueprint`.
- **Çalıştırılan:** `Rule`, her uygulamada `RuleGenerator` tarafından üretilir.

Eşik sabitleri tek bir tabloda (`RuleGenerator.tuning`) toplanır. Gerçek
cihazda bir hareket kötü hissettiriyorsa oradaki sayı değişir; kimsenin kayıtlı
kuralı bozulmaz.

## Genişletme noktaları

| İhtiyaç | Yapılacak |
|---|---|
| Yeni sinyal | `Signal` + `ARSignalMapper` |
| Yeni hareket ön ayarı | `GesturePreset` + `RuleGenerator.tuning` |
| Yeni eylem | `MacroAction` (+ Codable) + `SurfaceCommand.make` + köprüde komut |
| Yeni koşul türü | `Condition` (+ Codable, `evaluate`) + `ConditionEditorView` |
| Başka barındırma yüzeyi | `InstagramSurfaceController` yerine yeni sınıf |

`MacroAction` ve `Condition` elle yazılmış `Codable` uygulamaları kullanır
(otomatik sentez yerine). Sebep: JSON'da `type` ayırıcısıyla okunabilir, kararlı
ve elle düzenlenebilir bir biçim istiyoruz — profiller paylaşılmak üzere
tasarlandı.
