# Bloodwake — devir notu (24 Eylül 2026)

Ana geliştirme artık `godot/` içindeki Godot 4.6.3 standard/GDScript projesinde.
Hedef önce PC, sonra ölçülerek optimize edilecek mobil sürüm. Flutter kaynakları
referans olarak korunuyor. Yeni bilgisayarda `godot/project.godot` dosyasını açıp
ilk import sonrası F5 ile çalıştır; Flutter kurulumu gerekmiyor.

## Çalışan durum

Gerçek 3D arena ve yönüne dönen Bloodbound; kullanıcının GLB dosyasındaki beş
iskelet animasyonu (idle/run/attack/hit/death) bağlı. Dört sınıf, yedi silah,
sınıf yetenekleri, yedi düşman tipi, elitler, üç aşamalı boss, dalgalar, XP,
yükseltmeler, mağaza, kalıcı yetenek ağacı, ekipman ve üç loadout taşındı.
Klavye/fare, gamepad ve dokunmatik kontrol altyapısı; PC/Mobile kalite ayarları var.
Altı test paketinin tamamı yeşil: 170 + 55 + 53 + 1254 kontrol, artı iki asset
paketi ve `--smoke`. Dört yönde hareket ve ana ekranlar görüntüyle
kontrol edildi. Linux ve Windows export presetleri hazır. Linux build çalıştırıldı;
Windows cihaz testi henüz yapılmadı. Bu port oynanabilir bir temel; uzun süreli
oynanış ve denge testi hâlâ gerekli.

## Son yapılan iş

`world.gd` 1215 satırdan 714 satıra indi: geçici savaş efektleri `scripts/fx.gd`
içine, sınıf yetenekleri ve ultiler `scripts/skills.gd` içine taşındı. Davranış
değişmedi.

Testler tuning'in gerisinde kalmıştı; dört kontrol sabitlenmiş tuning sayıları
yüzünden kırmızıydı, niyeti ölçecek şekilde düzeltildi. Sekiz bağlı yetenekten
altısı, bölge turu, dalga kapıları, elit ölçekleme ve burn/bleed/slow sayaçları
hiç test edilmiyordu; `class_kit_test.gd` ve `wave_field_test.gd` eklendi.

Her bölge artık kendi `garrison` tablosunu taşıyor: ossuary gövde yığar, ruins
okçu tutar, grove pusu kurar, altar kültü sahaya sürer, courtyard nötr kalır.
Ağırlık sıfırın üstünde kırpılıyor, yani bir bölge kendi havuzunu boşaltamaz.

## Sonraki işler

1. Kullanıcıyla PC oynanış testi; özellikle silah hissi, kamera, boss dengesi.
2. Brazier mesh'i 2,20 m genişlikte ama çarpışma yarıçapı 0,45 (çap 0,9): oyuncu
   ve düşmanlar demir işçiliğinin görünen kısmından geçiyor. `_model` bunu
   kasıtlı olarak `radius*6`'ya kadar serbest bırakıyor (dallanan ağaç çalıya
   dönmesin diye), ama brazier bu kuralın en uçtaki örneği. Yarıçapı büyütmek mi,
   mesh'i daraltmak mı gerektiği tasarım kararı.
3. Oyuncu Warrior: kullanıcının şövalye ve büyük kılıç modeli, beş Mixamo
   animasyonuyla bağlandı (`warrior_player.glb`). Düşman Warrior hâlâ geçici
   Quaternius modelini kullanıyor. Mage modeli ve altı Mixamo animasyonu bağlandı; elde sürekli büyü VFX’i var.
   Assassin animasyonları bekleniyor.
4. Windows üzerinde build doğrulaması.
5. Mobil export/gerçek cihaz profilleme, LOD/texture bütçesi ve dokunmatik UX.

Orijinal Bloodbound: `art/bloodbound/source/bloodbound_animated.glb`.
İşlenmiş model: `bloodbound_game.glb`; Godot kopyası `godot/assets/models/bloodbound.glb`.
Gunslinger iç kimliği korunur, görünen ad Bloodbound. Eski atlas üretimi Godot için
zorunlu değil. `DEVELOPMENT_PLAN.md` eski Flutter planıdır; güncel durum bu dosyada.

Komutlar, kod haritası, kayıt aktarma ve build adımları `godot/README.md` içinde.
Motor/export templates ve `godot/builds/` Git'te yok; diğer PC'de yeniden kur/üret.
Yerel commit başka PC'ye otomatik ulaşmaz; remote'a push veya repo aktarımı gerekir.

## Son oynanış düzeltmeleri

- Warrior/Mage klipleri saldırı ve hareket hızına göre oynatılıyor; FBX FPS farkları
  dönüştürmede korunuyor. Bloodbound temposu değişmedi.
- Temel düşman hasarı 0 yerine 8. Kılıç ve Mage normal saldırıları temas anında,
  Mage ultisi ayrı animasyonun büyü çıkarma anında uygulanıyor.
- Dalga sonunda 2 saniye WAVE CLEARED; ölümde ses hemen başlıyor, ilk 2 saniye ölüm
  animasyonu açıkça görünüyor, ardından 2,7 saniye YOU DIED ve sonuç menüsü geliyor.
- `godot/tests/combat_flow_test.gd` hasarı, animasyon temposunu, el VFX’ini ve
  geçiş sürelerini kontrol ediyor.
