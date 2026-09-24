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
113 otomatik denetim geçti; dört yönde hareket ve ana ekranlar görüntüyle
kontrol edildi. Linux ve Windows export presetleri hazır. Linux build çalıştırıldı;
Windows cihaz testi henüz yapılmadı. Bu port oynanabilir bir temel; uzun süreli
oynanış ve denge testi hâlâ gerekli.

## Sonraki işler

1. Kullanıcıyla PC oynanış testi; özellikle silah hissi, kamera, boss dengesi.
2. Warrior ve düşman Warrior için onaylı nihai modelleri bağla. Mevcut Quaternius
   modeli teknik/geçici. Assassin modelinde animasyon yok; Mage görseli geçici.
3. Windows üzerinde build doğrulaması.
4. Mobil export/gerçek cihaz profilleme, LOD/texture bütçesi ve dokunmatik UX.

Orijinal Bloodbound: `art/bloodbound/source/bloodbound_animated.glb`.
İşlenmiş model: `bloodbound_game.glb`; Godot kopyası `godot/assets/models/bloodbound.glb`.
Gunslinger iç kimliği korunur, görünen ad Bloodbound. Eski atlas üretimi Godot için
zorunlu değil. `DEVELOPMENT_PLAN.md` eski Flutter planıdır; güncel durum bu dosyada.

Komutlar, kod haritası, kayıt aktarma ve build adımları `godot/README.md` içinde.
Motor/export templates ve `godot/builds/` Git'te yok; diğer PC'de yeniden kur/üret.
Yerel commit başka PC'ye otomatik ulaşmaz; remote'a push veya repo aktarımı gerekir.
