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

### 1. Oyun içi donma — ÇÖZÜLDÜ (30 Eylül 2026, `9e08acc`)

Gerçek renderer ve normal/ağır saldırı + yetenek girdileriyle yakalandı.
60 sn önce: 1193 / 1147 / 1228 ms takılmalar, aralar 8.74 / 8.30 sn.
Aynı anlarda senkron GLB yüklemesi; son örnek ölünce zayıf cache boşalıyordu.
PackedScene'ler kalıcı cache'te tutuluyor, düşman modelleri savaştan önce ısıtılıyor.
60 sn sonra: 60 FPS, 80 ms üzeri sıçrama yok. Ham loglar ve kapsam:
`godot/docs/performance/README.md`. İlk açılışta yükleme süresi ve bellekte
kalıcı model maliyeti var; combat sırasında yeniden yüklenmiyor.

### 2. Dalga zorluğu ve XP — ÇÖZÜLDÜ

- `cd5fcff`: Can ve hasar ayrı eğrilerle artıyor; merkezi spawn yolu summon'lara
  da uyguluyor. Grunt HP wave 1/5/10: 30 / 76.8 / 182.55. İlk boss aynı,
  sonraki boss kademeleri büyüyor. Açık multiplier parametresi test/özel spawn
  override'ı olarak korunuyor.
- `0924cde`: XP eşiği 80 + 30*(level-1) + 5*(level-1)^2. Dalga başına en fazla
  bir XP seviyesi; sonraki çubuğun yarısına kadar XP saklanır. Boss ganimeti
  ayrı ödüldür. XP bonusları eşiğe daha erken ulaştırır.

### 3. Boyutlar — ÇÖZÜLDÜ (30 Eylül 2026)

Düşman warrior temel boyu 1.70 → 2.15 m. Elitler bunun 1.12 katı.
Oyuncu ve mevcut/yeni düşmanlar level başına %2.5 görsel büyür; tavan %50.
`BWData.actor_growth` ve `enemy_height` tek ayar noktasıdır.
`tests/actor_growth_test.gd` ve level 1/11 karşılaştırma görüntüleri doğrular.

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

### 5. Kalabalık yerine derli toplu savaş — YAPILDI (30 Eylül 2026)

Dalga başına gövde sayısı yarıdan aza indi (`quota` 12+8w → 5+2w, aynı anda en
fazla 12), eksik baskı gövdelerin kendisine yazıldı: can, hasar, hız ve ödül
katalog satırlarında büyüdü. Harita 72 m kareden 52 m kareye çekildi; bölgeler
duruyor, aralar kısaldı.

Vuruş hissiyatı: bir kılıç darbesi artık önündeki 105° koni içindeki en yakın 3
gövdeyi keser (shockwave yükseltmesinin aldığı her üçüncü darbe hâlâ tam daire ve
6 gövde). Her isabet gövdeyi sersemletir ve geri iter. Düşmanlar kol mesafesinde
durur, oyuncunun içine girmez.

Archer ve yeni `mage` tipi presin içine girmiyor: oyuncunun sağına/soluna 8,6 m
uzaklıkta bir mevzi tutuyorlar (kamera dönmediği için dünya x ekseni ekranın
yatay eksenidir). Archer okunu bırakmadan önce 0,4 s nişan çizgisi gösteriyor.
Mage bir mermi, bir de zamanlı rün kuruyor: fitili görünen bir yapı: üstünden
çekilerek ya da kırılarak etkisiz bırakılabilir. Rünler `world.gd` içindeki
`hazards` listesi; `BWWorld.damage_area` prop ve rünü tek çağrıda kapsıyor.

`tests/skirmish_test.gd` bunların hepsini sürüyor. **Hiçbiri bu makinede
çalıştırılmadı — burada Godot kurulu değil.** Evde sırayla:

    godot --headless --path godot --script tests/test_suite.gd
    godot --headless --path godot --script tests/skirmish_test.gd
    godot --headless --path godot --script tests/wave_field_test.gd
    godot --headless --path godot --script tests/horde_pressure_test.gd
    godot --headless --path godot --script tests/xp_pacing_test.gd
    godot --headless --path godot --script tests/combat_flow_test.gd
    godot --headless --path godot --script tools/balance_table.gd

Son komut `docs/balance.md`'yi yeniden üretir; katalog değiştiği için dosya şu an
eski sayılar duruyor. Sayılar oyunda ölçülmedi: gövde sayısı/hız/standoff ilk
oynanışta ayarlanacak asıl yer.

### 6. Sıradaki iş: Blender objeleri ve VFX

VFX'in yapmacık durmasının kaynağı efektlerin tamamının kod içinde kurulan
additive billboard/quad olması (`scripts/fx.gd`). Rün yapısı da bilerek ilkel bir
kutu olarak bırakıldı (`world.gd` `_plant_rune`): Blender'dan gelecek mesh'in
takılacağı yer orası, prop'lardaki `mesh` alanı mantığıyla aynı.

### Godot import cache tuzağı

Sahneyi editörsüz çalıştırmak `.godot/imported/*.scn` içindeki eski sürümü oynatır;
glb değişse bile. Render almadan önce bir kez:

    godot --path godot --headless --editor --quit

Bu oturumda iki kez günler öncesine ait asset render edilip "doğrulandı" sanıldı.
