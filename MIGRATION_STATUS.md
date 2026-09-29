# Bloodwake — devir notu (24 Eylül 2026)

Proje tamamen `godot/` içindeki Godot 4.6.3 standard/GDScript projesi.
Hedef önce PC, sonra ölçülerek optimize edilecek mobil sürüm. Flutter/Flame
prototipi silindi; geçmişi git'te duruyor. Yeni bilgisayarda `godot/project.godot`
dosyasını açıp ilk import sonrası F5 ile çalıştır.

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
Gunslinger iç kimliği korunur, görünen ad Bloodbound. `DEVELOPMENT_PLAN.md` silindi;
hâlâ geçerli olan tasarım kuralları `godot/README.md` içindeki Conventions bölümüne
taşındı.

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

## Devir: evde devam edilecek işler (29 Eylül 2026)

Bu oturumda bitenler commit'li (`c8449f2`..`9a4dc50`, hepsi master'da, push YOK —
evdeki PC'ye ulaşması için `git push` gerekiyor). Aşağıdakiler açık.

### 1. Oyun içi donma — AÇIK, sebebi bulunamadı

**Belirti (Cenk):** wave'in ortasında, saldırı yaparken oyun kısa süre kilitleniyor.
"7-8 saniyede bir" ifadesi farazi, ölçülmüş değil. Wave geçişinde DEĞİL.

Ölçüm için `godot/tools/perf_probe.gd` yazıldı (commit'lenmedi, untracked):

    godot --path godot --script tools/perf_probe.gd

Oyunu 120 sn kendi kendine oynatıp 80 ms üstü her kareyi, 5 sn'de bir de
wave/level/düşman sayısını basar. Gerçek ekran gerekir; headless render yapmadığı
için renderer kaynaklı bir takılma orada hiç görünmez.

Bulunanlar:
- Probe 60 fps sabit gidiyor ve Cenk'in tarif ettiği donmayı ÜRETEMİYOR. Eksik olan
  muhtemelen gerçek girdi: sol/sağ tık saldırıları, yetenekler ve onların VFX'i.
  Probe sadece `auto_fire` kullanıyor.
- Ayrı ve gerçek bir sorun ölçüldü: bir düşman tipinin modeli ilk kez yüklenirken
  `BWVisual.configure` **1191 ms** sürüyor (`CONFIGURE grunt 1191.6 ms`).
  Sebep `visual.gd:45` — `load()` sonucu yerel değişkende, `instantiate()` sonrası
  PackedScene referansı düşüyor, yani sahne önbellekte tutulmuyor. Statik bir
  sözlükte cache'lemek doğru düzeltme. Bu Cenk'in şikayeti değil ama giderilmeli.

Sıradaki adım: probe'a gerçek saldırı/yetenek girdisi ekleyip donmayı yakalamak.
Yakalanmadan bir şey "düzeltilmemeli" — bu oturumda wave geçişi sanılıp yanlış
teşhis kondu.

### 2. Zorluk eğrisi — AÇIK, hiç başlanmadı

Cenk: "4-5 wave sonra oyun kolaylaşıyor, boss wave'inde gelen 10 düşmanı tek
hareketle siliyorum."

- Düşman canı/hasarı wave ile artmalı. Şu an tek çarpan
  `data.gd:40` → `"multiplier":1+(wave-1)*0.08` ve `spawn_enemy` onu maxHp ile
  damage'a uyguluyor. %8 lineer artış açıkça yetersiz.
- Seviye atlama çok hızlı: `run_state.gd:41` → eşik `20+(level-1)*15`. Wave başına
  4-5 seçim çıkıyor. Hedef: **wave başına en fazla ~1 seviye**.
- İkisi birbirine bağlı; XP eğrisini düzeltmeden düşman gücünü artırmak yanıltır.

### 3. Boyut sorunları — AÇIK

- Düşman warrior aşırı küçük duruyor. Boy `world.gd:317`'de `configure(...)`'a
  geçilen sabitlerden geliyor (`3.5` boss / `2.3` tank / `1.9` elit / `1.7` diğer);
  `enemy_warrior.glb` muhtemelen bu ölçekle uyuşmuyor.
- Cenk seviye arttıkça hem oyuncunun hem düşmanların büyümesini istiyor. Şu an
  oyuncu boyu `world.gd:98`'de sabit `2.05`.

### 4. Warrior Whirl klibi — Cenk'te

`shield_thrust` kaldırıldı, yerine `whirl` geldi (`522137c`). Kod hazır, klip yok.
Cenk Blender'da yapacak; dosya **`art/warrior/source/mixamo/Warrior Whirl.fbx`**
olarak konacak. Pipeline onu `reexported` listesinde bekliyor, yani leaf bone / fps /
nesne kanalı tuzaklarını otomatik hallediyor. Klip gelene kadar cast jenerik savurma
klibine düşüyor ve build `MISSING CLIP Whirl` basıyor.

Klip şartları: gövde yerinde dönsün (ileri kaymasın), ~1.2-2 sn, kılıcı dosyaya
koymaya gerek yok (pipeline kendi takıyor).

### Dikkat: kılıç tutuşu elle taşınıyor

`build_mixamo_warrior.py` içindeki `GRIP` matrisi `art/warrior/source/4slah.blend`
dosyasındaki Child Of constraint'inden okundu ve **sabit olarak gömüldü**. Blender'da
tutuş değişirse bu matris kendiliğinden güncellenmez. Yeniden okuyan bir araç
yazılması konuşuldu, yazılmadı.

### Godot import cache tuzağı

Sahneyi editörsüz çalıştırmak `.godot/imported/*.scn` içindeki eski sürümü oynatır;
glb değişse bile. Render almadan önce bir kez:

    godot --path godot --headless --editor --quit

Bu oturumda iki kez günler öncesine ait asset render edilip "doğrulandı" sanıldı.
