# Kural şeması ve jeneratör

## Katmanlar

```
RuleBlueprint   (kullanıcının gördüğü, kaydedilen, paylaşılan biçim)
     │  RuleGenerator.makeRule
     ▼
Rule            (motorun çalıştırdığı biçim: eşikler, süreler, öncelik)
     │  RuleEngine.update
     ▼
RuleFiring      (genişletilmiş, zamanlanmış eylemler)
```

Kaydedilen şey **taslaktır**, derlenmiş kural değil. Bu bilinçli: eşik
sabitlerini gerçek cihaz deneyiminden sonra değiştirdiğinizde, kullanıcıların
kayıtlı kuralları kendiliğinden yeni ayarları alır.

## Taslak alanları

| Alan | Tür | Anlamı |
|---|---|---|
| `name` | metin | Listede görünen ad |
| `gesture` | `GesturePreset` | Hangi hareket |
| `sensitivity` | `low`/`medium`/`high` | Eşik ve süre çarpanı |
| `surface` | `Surface?` | Hangi Instagram ekranı; `null` = hepsi |
| `extraConditions` | `[Condition]` | Ek "eğer" maddeleri (VE ile bağlanır) |
| `actions` | `[MacroAction]` | Sırayla çalışacak eylemler |
| `cooldownScale` | sayı | Üretilen bekleme süresi çarpanı |
| `priority` | tam sayı | Yüksek olan kazanır |
| `isExclusive` | mantıksal | Düşük öncelikli kuralları bastır |

## Koşul ağacı

Koşullar iç içe geçebilir. JSON'da her düğüm bir `type` alanı taşır:

```json
{
  "type": "all",
  "children": [
    { "type": "surface", "surface": "reels" },
    { "type": "not",
      "child": { "type": "flag", "name": "gezinme", "equals": true } },
    { "type": "any", "children": [
        { "type": "signal", "signal": "jawOpen", "op": "gt", "value": 0.4 },
        { "type": "timeOfDay", "startMinute": 1320, "endMinute": 420 }
    ]}
  ]
}
```

Düğüm türleri: `always`, `all`, `any`, `not`, `signal`, `surface`, `flag`,
`timeOfDay`, `mode`.

`timeOfDay` gece yarısını aşabilir: `startMinute > endMinute` ise aralık ertesi
güne sarkar (örnekte 22:00–07:00).

## Eylemler

```json
[
  { "type": "like" },
  { "type": "delay", "seconds": 0.35 },
  { "type": "scroll", "direction": "down", "amount": 1.0,
    "unit": "screens", "animated": true }
]
```

Tam liste: `scroll`, `tap`, `like`, `unlike`, `doubleTapLike`, `savePost`,
`openComments`, `closeOverlay`, `navigate`, `toggleMute`, `playPause`, `delay`,
`haptic`, `speak`, `runMacro`, `setFlag`, `toggleFlag`, `javascript`.

`unit` iki değer alır: `screens` (görüntü alanı yüksekliğinin katı — bir Reels
klibi tam olarak `1.0`) veya `pixels`.

## Makrolar

Bir makro adlandırılmış eylem dizisidir ve başka makro çağırabilir.
`MacroExpander` çağrıları düzleştirir:

- `delay` adımları kaldırılıp **zaman ofsetine** dönüşür, böylece dağıtıcı
  hiçbir zaman bir kuyruğu bekletmez.
- Döngüler ve 8'den derin yuvalamalar kaydederken hata olarak yakalanır.

## Bayraklarla katmanlı kısayollar

Motor, `setFlag`/`toggleFlag` eylemlerini dağıtıcıya vermeden **kendisi**
uygular. Bu sayede aynı karede daha sonra değerlendirilen bir kural yeni değeri
görür ve "mod" mantığı ek bir motor kavramı gerektirmez:

```
Dil sağa            → gezinme bayrağını çevir           (öncelik 30, yalnızca bu)
Dil aşağı  + gezinme kapalı → kaydır                    (öncelik  0)
Dil aşağı  + gezinme açık   → Reels'e git, bayrağı kapat (öncelik 40, yalnızca bu)
```

## Çakışma çözümü

Bir karede birden fazla kural tetiklenirse motor sırayla:

1. koşulu sağlamayanları eler,
2. bekleme süresi dolmayanları eler (kural bazlı ve genel),
3. **önceliğe göre azalan** sıralar,
4. ilk `isExclusive` kuraldan sonrasını atar,
5. `maximumConcurrentFirings` kadarını çalıştırır.

Aynı hareketi aynı ekranda paylaşan, aynı öncelikte ve hiçbiri "yalnızca bu"
olmayan iki kural varsa jeneratör kaydederken uyarır.

## Profil JSON'u

Dışa aktarım tek dosyadır ve şunları taşır: `blueprints`, `macros`, `modes`,
`flags`, `signalTuning`, `engineOptions`, `calibration`. `schemaVersion` alanı
ileri sürümlerde göç için kullanılır (`ProfileStore.migrate`).

İçe aktarılan profile her zaman yeni bir kimlik verilir; kendi dışa aktarımınızı
geri yüklemek aslını sessizce ezmez.
