# Bloodwake Unity devir notu — 13 Ekim 2026

## Durum: aktarım tamamlanmadı

Godot'taki oyunun tamamını Unity'ye, mevcut sanat yönünü ve oyun kurallarını
koruyarak taşıyoruz. Kullanıcı mevcut Unity VFX'lerini yetersiz buldu: çoğu
efekt hâlâ basit halka/küre yer tutucusu. Çalışan bir build veya yeşil smoke
testi, görsel/oynanış eşitliği anlamına GELMEZ. Yeni motor için oyunu yeniden
tasarlama veya sadece Warrior içeren bir demo yapma.

## Evde açılış

1. Bu repoda `master` dalını güncelle (`git pull --ff-only`; yerel değişiklik
   varsa önce koru, reset kullanma).
2. Unity Hub üzerinden **Unity 6000.3.25f1** kur, `unity/` klasörünü proje
   olarak ekle. Paketler `Packages/manifest.json` ve kilit dosyasındadır.
3. İlk import bitsin. `Assets/Bloodwake/Scenes/Bloodwake.unity` aç ve Play'e bas.
   **WarriorReview.unity eski model incelemesidir, oyun sahnesi değildir.**
4. Karşılaştırma için **Godot 4.6.3 standard** ile `godot/project.godot` aç.
   Kullanıcının açık Godot editörünü/oyununu kapatma.
5. FBX, materyal, prefab, controller ve .meta dosyaları repoda. İlk çalıştırma
   için Blender veya ham sanat arşivleri gerekmez. Library/Builds Git'te yok.

Windows: Editor Play kullanılabilir; Linux player Windows'ta çalışmaz. Windows
build için Unity Hub'dan ilgili build modülünü kur ve Build Profiles üzerinden
Bloodwake sahnesiyle build al. Mevcut `BuildLinux` komutu yalnız Linux içindir;
Windows build/test bu bilgisayarda doğrulanmadı.

## Kullanıcı kararları (koru)

- Unity Warrior: **godot/assets/models/warrior_player.glb**, önceki versiyon.
  `warrior_v2_player` bozuk bulundu; tekrar seçme. `export_assets.py` önceki
  modeli kullanır. Godot referansındaki visual.gd hâlâ v2'yi seçebilir; Unity
  Warrior için bu tek seçimi körlemesine kopyalama.
- Warrior ve Revenant normal saldırıları karakterin baktığı yöne gider;
  fareyle yönlendirme yok. Yeteneklerin hedeflemesi korunur.
- Düşman can barı tek bar: kalan koyu kırmızı, eksik gri; ölüm anında kaybolur.
- Normal/crit hit-stop 50/75 ms, vuruşun arkasına yerde kalan kan.
- Revenant temel saldırı sesleri mevcut polished/revenant_basic_attack_*.wav.
- Menüleri yeniden çizmek yerine mevcut portre/çerçeve/eskizleri kullan.
- Tamamlanmamış QA build'ini kullanıcı istemeden görünür açma.

## Bu devirde mevcut olanlar

- Beş sınıf, düşman modelleri, sekiz oda, PBR materyaller, kaynak UV ve çarpışma
  aktarımı, kamera sınırları, NPC etkileşimi, oda kapıları, boss/merchant/gece akışı.
- Önceki Warrior modeli; özgün iskelet/klipler korunuyor, root motion kapalı.
- Portre kartlı sınıf ekranı, işlemeli panel/butonlar, üç kartlı ana menü;
  harita, mağaza, ekipman, kalıcı gelişim, ayarlar ekranları.
- Beş karakter için Godot'un iki triptych atlasından altı karelik 4.1 sn
  sinematik; güvenli bölgeye geçiş; harita girişinde 1.8 sn yürüyüş ve
  3.8 sn kamera açılması. Çift tıklama ve geçiş sırasında giriş kilidi.
- Kayıt JSON aktarımı: yol gir, oku, ayrıca onayla. Kaynak kayıt değiştirilmez;
  Unity kayıt değişiminde .bak tutulur. Geçersiz import mevcut veriyi korur.
- WASD/oklar, gamepad hareket/nişan/yetenekler, Tab/Y auto-fire ve F11.
- İşaretin hedef ölünce devri, overkill dışı lifesteal, anlık altın, sağlık
  düşürme kuralları, yanma/kanama, üçüncü vuruş shockwave, chain hit,
  segment tabanlı mermi çarpışması, Revenant hasar kareleri,
  Bloodhound dokuz ulti atışı, boss hücum hareketi ve uyarı geometrisi.

## Öncelikli kalan işler / kabul ölçütleri

1. **VFX — en yüksek öncelik.** Godot `scripts/fx.gd`, `skills.gd`, `boss.gd`,
   `visual.gd`, `shaders/`, `assets/vfx/` ve `art/vfx/` esas alınmalı.
   Revenant claw/burst GLB'leri ve prosedürel glow, slash, beam, trail, impact,
   spark, muzzle, meteor, grenade, frost, rune, mark, summon, death, floating
   damage text ve ışık efektleri eksik/yer tutucu. Unity export şu anda vfx
   GLB'lerini çevirmiyor. VFX çizilip hasar/klip olayıyla senkronize edilmeli;
   hepsini ortak kırmızı halka ile temsil etmek kabul değil.
2. Her sınıf için idle/run/normal/ağır/Q/E/Space/hit/death karşılaştırması.
   Godot ve Unity aynı kamera/oda/saldırı anında görüntülenmeli. Özellikle
   Warrior kayma/kılıç eli ve Revenant claw temasları. Unity controller'ları
   var ama runtime CrossFade ile sürülüyor; editörde anlaşılır animasyon
   geçişleri ve locomotion blend yapısı henüz tam eşlenmedi.
3. AI eşitliği: kaynak world.gd/boss.gd ile windup/recovery/stagger,
   assassin pusu-kaçış, support/rally, tank, elite/rise, boss kiting charge,
   summon rotaları. Mevcut boss/AI kısmi ve smoke bütün davranışları sınamaz.
4. Tüm silah davranışları/bağımsız cooldown, satın alma/upgrade havuzları,
   sınıf yetenekleri ve hasar alanları kaynakla karşılaştırılmalı. Burn/bleed
   bağlama şu an sınıf varsayımlarına dayanıyor; çoklu silah için gözden geçir.
5. Işık ve materyaller: Unity hâlâ Godot'tan karanlık; özel shader/VFX
   portu bitmeden sadece pozlamayı artırıp tamamlandı sayma.
6. Menü okunurluğu, hover/gamepad seçimi, farklı ekran oranları; ayarlar
   kalite profili, dokunmatik kontrol, death/room/reward geçişleri eksik.
   Runtime UI çoğunlukla kodla kuruluyor; artist-editable prefab konusu açık.
7. Ses bankası/kanal seviyesi, müzik fade/duck, performans ve materyal yaşam
   döngüsü (Effects.Mat dinamik materyal üretiyor) kontrol edilmeli.
8. Gerçek oyuncu testi ve Windows doğrulaması. Yalnız otomatik testle bitirme.

Bir karakteri uçtan uca bitirip görsel olarak doğrula, sonra diğerlerine geç.
Her efekt için kaynak fonksiyon, Unity karşılığı, tetikleme zamanı ve test
durumu kaydı tut. Henüz yok / kısmi / doğrulandı ayrımını koru.

## Kaynak haritası

- Godot oyun: `godot/scripts/{world,skills,fx,boss,visual,run_intro,main,ui}.gd`.
- Sanat: `art/ui-class-screen/class-screen-implemented-preview-v2.png`,
  `godot/assets/ui/portraits`, `class_screen`, `loading_cinematics`.
- Unity: `Assets/Bloodwake/Runtime` altındaki partial BloodwakeGame dosyaları.
- UI: GameUI, MenuPages, GameHUD; giriş: CharacterIntro +
  Resources/CharacterCinematic.shader.
- Oyun: Combat, ClassSkills, EnemyCombat, RoomFlow, RoomInteractions,
  RoomCamera, Navigation, Pickups, RunState, GameData.
- Aktarım: export_assets.py, export_rooms.py, material_manifest.py;
  Godot tools/export_unity_data.gd ve export_unity_rooms.gd.
- Editor: BuildGame.cs, SourceMaterials.cs. Resources/Controllers düzenlenebilir.

Önemli tuzaklar: FBX dönüşümü **X'i aynalar, Z'yi değil**. Oda prefab Resource
anahtarı `id_environment`; FBX ile aynı ad olmamalı. GLTF baseColor lineardır,
Unity Color gamma dönüşümü SourceMaterials'te yapılır. Procedural triplanar
oda UV'leri Blender export'unda bake edilir. `glTF_not_exported` collection
iskelet kontrol küresidir; model export'una katma. Scene/root'u değiştiren
EnterRoom/StartRun, combat coroutine'lerini durdurur; giriş ve test sürücüleri
bu nedenle ayrı GameObject'lerdedir.

## Test / build

Son yerel Linux doğrulaması: **66 data/asset + 50 runtime contract** geçti.
Beş sınıf, sinematik kilidi, safehouse/district girişleri, bir tam gece,
merchant ve ikinci gece; ayrıca seçili hasar/kayıt kuralları. Bu sayı tam
özellik kapsamı veya görsel eşitlik değildir. Boss/VFX kapsamı yetersizdir.

Editor'de normal çalışma için yeniden export zorunlu değil. Prefab/ithalat
yenilemek gerekirse değişikliklerini koruyarak `Bloodwake > Build Imported
Game` kullan; işlem import/prefab ve ana sahneyi yeniden yazar.

Linux CLI (Unity yürütülebilirinin tam yolunu yerel kuruluma göre seç):

```bash
Unity -batchmode -nographics -quit -projectPath /ABS/REPO/unity -executeMethod Bloodwake.Editor.BuildGame.BuildAndLinux -logFile /tmp/bloodwake-build.log
/ABS/REPO/unity/Builds/Linux/Bloodwake.x86_64 -batchmode --smoke -logFile /tmp/bloodwake-smoke.log
```

Yalnız runtime kod değişikliğinde BuildLinux yeterli. Açık editörün kilitlediği
projede batch build çalıştırma; ayrı doğrulama kopyası kullan. Başarı logları:
`BLOODWAKE_DATA_ASSET_CHECKS 66 passed`, `BLOODWAKE_LINUX_BUILD_READY`,
`BLOODWAKE_RUNTIME_SMOKE_PASSED`. Capture çıktıları `/tmp/bloodwake-*.png`;
oynanış capture'ları HUD içermez, menüler içerir. Fontların offscreen render
keskinliği gerçek pencereyle ayrıca kontrol edilmeli.

Godot oda referansı: `Godot --path /ABS/REPO/godot -- --rooms`.
Test kayıtlarının kişisel save'i etkilememesi için ayrı XDG_DATA_HOME ve
XDG_CONFIG_HOME kullan. Unity smoke rota testi oyun profilini kalıcı yazmaz;
kayıt import testleri bellekte yapılır.

## Taşınmayan yerel dosyalar

Motor kurulumları, Library/Temp/Builds, /tmp log ve ekran görüntüleri, ham
Blender dosyaları ve art altındaki yeni büyük deneme/teslim arşivleri bu
devir için push kapsamı dışında. Üretim modelleri, runtime dokular, sesler,
UI atlasları, Unity importları ve küçük Revenant animation_events referansı
depoda; çalıştırma için iş bilgisayarının Downloads veya /tmp'sine güvenme.

## Evde yeni sohbete verilecek prompt

> Bloodwake Godot → Unity aktarımına devam et. Önce unity/README.md ve kök
> README.md dosyalarını oku; eski MIGRATION_STATUS.md tarihsel referanstır.
> Unity 6000.3.25f1 projesi unity/, oyun sahnesi Bloodwake.unity; WarriorReview
> değil. Godot'u yanda görsel/oynanış referansı olarak aç. Warrior önceki
> warrior_player.glb olarak kalacak, warrior_v2_player'a dönme. Öncelik eksik
> VFX: Godot fx.gd/skills.gd/boss.gd/visual.gd ve mevcut efekt varlıklarından
> aktar, basit halkalarla geçiştirme. Önce Revenant'ın normal saldırı/Q/E/Space,
> temas, kan ve ölüm efektlerini animasyon olaylarıyla eşleştirip aynı sahnede
> karşılaştır; ardından diğer sınıflar ve düşman/boss efektlerini tamamla.
> Mevcut menü eskizlerini, resimli giriş geçişlerini ve oyun kurallarını koru.
> Kalan AI, animasyon geçişi, ses, UI ve performans farklarını devir notundaki
> sırayla kapat. Her aşamada derle, uygun testleri ekle, görüntüyle doğrula;
> smoke geçmesini tüm aktarım bitti diye sunma. Görünür oyunu sadece istediğimde
> aç; QA'yı ayrı proje kopyasında ve görünmez çalıştır. Kaynak Godot'u, kayıtları
> ve mevcut değişiklikleri koru. Önce mevcut durumu doğrula, sonra uygulamaya başla.
