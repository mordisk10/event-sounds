# Açık sorular / Open questions

Arayüzü kurarken karar vermem gereken ama sizin belirtmediğiniz noktalar.
Hepsine bir varsayımla devam ettim — hangisini değiştirmek isterseniz söyleyin,
tek tek düzeltirim.

Kolay yanıtlamak için numaralı; "3 → şu olsun" demeniz yeterli.

---

## Ürün kararları

**1. Plan kademeleri ve fiyatlar**
Varsayım: 3 kademe — Başlangıç (ücretsiz), Pro ($4.99/ay), Studio ($9.99/ay);
yıllık = 10 aylık ücret ("2 ay bedava"). Pro "en çok seçilen" olarak işaretli.
→ Kaç kademe, hangi isimler, hangi fiyatlar? Para birimi TL mi USD mi?

**2. Hangi özellik hangi planda**
Varsayım: yapay zekâ ile otomasyon kurma, Dynamic Island geri bildirimi ve
"sabit" mikrofon modu Pro'da; ücretsiz planda 3 otomasyon sınırı.
→ Doğru mu? Özellikle Dynamic Island'ı ücretli yapmak istiyor musunuz?

**3. Giriş yöntemleri**
Varsayım: e-posta + parola, ayrıca "Apple ile devam et". Google/Facebook yok.
→ Başka sağlayıcı ister misiniz? (Not: başka sosyal giriş eklerseniz App Store
Apple ile Giriş'i zorunlu kılar.)

**4. Kayıt sonrası onboarding**
Varsayım: yok — kayıt olur olmaz ana sayfa açılıyor.
→ Kamera izni, ilk otomasyon kurulumu ve kalibrasyon için 3-4 ekranlık bir
karşılama akışı ister misiniz?

**5. Sohbetin işlevi**
Varsayım: sohbet, otomasyon kurmaya yarayan bir asistan (yazdığınız cümleyi
otomasyona çeviriyor). Genel amaçlı bir sohbet değil.
→ Yoksa serbest sohbet mi olmalı?

---

## Tasarım kararları

**6. Koyu mod**
Varsayım: yok. "Beyaz iPhone için" dediğiniz için uygulama `.light` moda
sabitlendi.
→ Koyu mod ister misiniz? (Sonradan eklemek, şimdi eklemekten pahalı.)

**7. Logo ve uygulama simgesi**
Varsayım: yok. Şu an turuncu daire içinde bir SF Symbol yüz simgesi kullanılıyor.
→ Logonuz var mı? Yoksa tasarlamamı ister misiniz?

**8. Ana sayfadaki widget'lar**
Varsayım: 4 kart — kaydırma sayısı, beğeni, ses komutu, seri. Veriler şu an
sahte.
→ Hangi metrikleri görmek istersiniz? Kart sayısı 4'te kalsın mı?

**9. Kutlama eşiği**
Varsayım: her 5. tanınan harekette konfeti/parçacık patlaması.
→ Ne sıklıkta olmalı? Sadece günlük seri kırıldığında mı?

**10. Boş durumlar ve hata ekranları**
Varsayım: her liste için tek satırlık boş durum var; ağ hatası ekranı yok
(çünkü henüz ağ yok).
→ Sunucu bağlanınca hata/çevrimdışı ekranları da tasarlayayım mı?

---

## Teknik kararlar

**11. Yapay zekâ sağlayıcısı**
Varsayım: yok. `AutomationStore.generate` şu an anahtar kelime eşleştirmesi
yapıyor; arayüz akışı (öner → kabul/değiştir/vazgeç) gerçek.
→ Hangi modeli kullanacağız? Cihaz üstü mü, sunucu mu?

**12. Ödeme altyapısı**
Varsayım: StoreKit 2, uygulama içi satın alma. Fiyatlar şu an sabit yazılı.
→ Onaylıyor musunuz? RevenueCat gibi bir aracı ister misiniz?

**13. Yasal metinler**
Varsayım: yer tutucu. Ekranlarda "bu metin yalnızca yerleşim içindir, yayına
çıkmadan önce hukukçu yazmalı" uyarısı var.
→ Metinleri siz mi sağlayacaksınız?

**14. Destek kanalı**
Varsayım: uygulama içi form, "hafta içi 09:00–18:00". Canlı sohbet yok.
→ Gerçek bir canlı destek (Intercom, Zendesk vb.) bağlayacak mıyız?

**15. Analitik**
Varsayım: yok, hiçbir izleme kodu eklenmedi.
→ Eklenecek mi? Eklenecekse gizlilik metnini de güncellemek gerekir.
