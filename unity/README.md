# Bloodwake Unity teknik devir notu — 15 Ekim 2026

Kısa ve güncel diğer bilgisayar devir özeti: [HANDOFF_STATUS.md](HANDOFF_STATUS.md).

## Durum: aktarım tamamlanmadı

Godot'taki oyunun tamamını Unity'ye, mevcut sanat yönünü ve oyun kurallarını
koruyarak taşıyoruz. Kullanıcı mevcut Unity VFX'lerini yetersiz buldu: çoğu
efekt hâlâ basit halka/küre yer tutucusu. Çalışan bir build veya yeşil smoke
testi, görsel/oynanış eşitliği anlamına GELMEZ. Yeni motor için oyunu yeniden
tasarlama veya sadece Warrior içeren bir demo yapma.

## Güncel görsel hedef — kullanıcının 13 Ekim kararı

Godot genel görüntü/ışık/model sunumu için hedef DEĞİLDİR. VFX davranışı,
animasyonlar ve mevcut menü/UI için referanstır; oynanış kuralları korunur.
Görsel hedef `ArtDirection/` içindeki kullanıcı referanslarıdır: ıslak ayrıntılı
kaldırım, soğuk ay ışığı/sıcak ateş karşıtlığı, okunabilen metal/kumaş, hacimli
sıvı kan. Mage mor kristal/buz, Warrior taş/toz/kıvılcım, Gunslinger namlu
parlaması/iz/duman dili kullanır. Warrior `warrior_player` kalır.
Referanslar hedef tasarımlardır, elde edilmiş oyun görüntüsü diye sunulmaz.
Kabul gerçek Bloodwake sahnesindeki hareketli oyun kamerasından yapılır;
model inceleme sahnesi veya yeşil test tek başına yeterli değildir.

## Bu oturumdaki ilerleme

Revenant GLB/shader VFX aktarımı, gerçek animation event eşleşmeleri,
hareketli saldırı/darbe katmanları ve ölüm geçişi eklendi. Warrior saldırı,
whirl ve zemin çarpma efektleri de geliştirildi; önceki model korundu. Kaynak eşleme,
test kapsamı ve kalan farklar: [Revenant kontrol kaydı](REVENANT_STATUS.md).
Görsel eşitlik ve genel aktarım hâlâ tamamlanmadı.

Son düzeltme: Mage'in eldeki orb/kabuk/enerji izi, atış orbu ve Q/E/Space
VFX bağlantıları geri geldi; 14 Mage çalışma kontrolü ve gerçek Unity görüntüleri
alındı. Elden çıkan merminin gövdeyi ıskalama sorunu, ExitGlow saydamlığı ve
karakter dolgu ışığı düzeltildi. Diğer sınıf/düşman/boss ve genel kalite farkları
kapanmış sayılmamalı; ayrıntı kontrol kaydında.

## 14 Ekim — düşman ve boss saldırı sunumu

Boss uyarıları ince çizgiden yönlü saydam alanlara geçti: normal vuruş/süpürme
sektörü, 8 m × 2 m hücum yolu, büyü için gerçek atış yönlerinde üç 1.1 m hat,
slam ve çağırma için farklı renkli daireler. İç ilerleme hazırlık süresini izler;
duraklatma/hit-stop sırasında donabilir. Alan darbesi boss hazırlığını keserse
uyarı hemen kaldırılır, gecikmiş hasar gelmez.

Temasa kılıç izi/kıvılcım, slam taş/toz kırılması, hücum toz izi, büyü çıkış
parlaması ve çağrılan düşmanların belirme etkisi eklendi. Düşman büyücünün alan
uyarısı ve patlaması da aynı zamanlama sistemini kullanıyor. Hasar alanı,
sektör açıları, menziller ve normal temas süreleri değiştirilmedi.

13 boss/uyarı kontrolü ve mevcut 66 varlık, 28 olay zamanı, 37 Revenant,
14 Mage, 23 hareket ve 50 oynanış sözleşmesi geçti. Bu, tüm düşman/boss
animasyonlarının veya genel görsel hedefin tamamlandığı anlamına gelmez.

## 14 Ekim — Mage buz hacmi

Buz meshleri daha kalın asimetrik kamalara dönüştürüldü. Rastgele dağılmış
levhalar yerine ortak tabanlı kümeler, büyük/küçük parçalar ve aralıklı yüksek
çıkıntılar kullanılıyor. Shader'daki keskin çatlak çizgileri azaltıldı; yarı
saydam yüzeyde donuk iç yoğunluk ve ışık geçişi hissi eklendi. Sis başlangıç
mesafesi/hızı değişken; düzenli beyaz halka yerine alçak bulutlar yayılıyor.
Meteor ve sıçramanın mor paleti, eldeki orb ve hasar zamanları korunuyor.
Frost Nova hareketli kaydı, meteor/sıçrama kareleri ve 14 Mage orb kontrolü
alındı. İlk fazla opak sürüm yumuşatıldı. Görsel hedef hâlâ tamamlanmadı;
fiziksel refraction ve GPU kare maliyeti doğrulanmış değil.

## 14 Ekim — Revenant sıvı hareketi

`BloodVolumeVfx` sabit boru geometrisinin Y ölçeğini büyütmek yerine 19 düzensiz
jet/yüzeyi eğri boyunca açar; uç parçaları ayrılır, sıvı dışarı taşınırken aşağı
iner. Damlalar hız yönüne döner ve kaybolmadan önce küçülür. Kan izi artık
ışık/yansımaya tepki veren koyu bir yüzeydir; düzenli çiçek biçimi gürültülü
kenarla değiştirildi. Kaynak Revenant animation event ve hasar zamanları aynı.
Dinamik geometri duraklatma ve hit-stop zamanını izler, ömrü sonunda mesh silinir.

İlk geniş yüzey denemesi yaprak gibi göründüğü için daraltıldı. Güncel hareket
referansa doğru bir adımdır; fotogerçek sıvı görünümü veya tüm görsel hedef
elde edilmiş değildir. Dinamik mesh maliyeti ayrıca ölçülmeli. Son kontrol: 37 Revenant çalışma,
28 olay zamanı, 14 Mage, 23 hareket, 66 veri/varlık ve 50 oynanış sözleşmesi geçti.

## 14 Ekim — oda yansımaları

Elle oluşturulan yansıma küpü yerine Unity’nin kendi filtreli HDR yansıması
kullanılıyor. Odaya girişte yalnız bir kez hesaplanır; her kare yenilenmez.
Kalite profillerindeki kapalı yansıma ayarı açıldı. GPU dokusu siyah değil ve
pürüzlülük mipleri ölçümle doğrulandı; eski derinlik tamponu uyarısı giderildi.
Karakter malzemelerinde genel normal/smoothness azaltma denemesi yeterince
belirgin görsel kazanç vermediği için kaynak değerler korundu. Model/ışık
sunumunun referans kalitesine ulaştığı henüz iddia edilmiyor.

## 14 Ekim — büyük alan darbelerine tepki

Frost Nova, meteor, Mage/Warrior sıçrama inişi, War Cry, Powder Charge ve
Revenant Blood Burst artık patlama merkezinden dışarı doğru savurur. Yaşayan
normal düşman: 48 cm / 0.56 sn tepki; tank: 20 cm / 0.44 sn; boss: 8 cm /
0.32 sn. Hareket ilk 0.28 sn içinde yavaşlayarak tamamlanır (boss 0.18 sn).
Gövde darbe pozu toparlanma boyunca sürer, duvar çarpışması korunur.
Alan darbesi o sırada hazırlanan yakın/uzak saldırıyı, destek büyüsünü ve
assassin/boss hücumunu keser; önceden bırakılan düşman alan tuzakları sürer.
Küçük takip vuruşları uzun tepkiyi kısaltmaz. Normal vuruş, whirl ve kısa
teleport vuruşlarının combo menzilini koruyan kısa geri tepmesi devam eder.

23 hareket/tepki kontrolü, 66 veri/varlık, 28 Revenant olay zamanı, 34 Revenant,
14 Mage çalışma kontrolü ve 50 oynanış sözleşmesi geçti. Bunlar görsel hedefe
ulaşıldığı anlamına gelmez; genel aktarım ve görsel kalite çalışması sürüyor.

## 14 Ekim — yeni çevre modelleri ve hareket düzeltmeleri

Kullanıcının üç bina FBX/PBR paketi `Resources/Environment/Kit01/` içine alındı.
`EnvironmentDressing` sekiz odada House/Backdrop gruplarını metre ölçekli
binalarla değiştirir; oynanabilir sınırı, kapı boşluklarını ve çarpışma verisini
korur. Cargo yığınları yeni sandık/fıçıları kullanır. Sekiz odanın bina sınırları
ve görüntüleri kontrol edildi. Küçük Shed, istasyon/çan kulesi
gibi özel yapılar hâlâ eski kaynak geometrisini kullanıyor. Kullanıcının kalan
duvar, ateşlik, fener, örtülü masa ve demir kapı modelleri de `EnvironmentDetails`
ile yerleştirildi. Tek parça kapı kaynak FBX korunarak çerçeve ve iki kanada
ayrıldı; çıkış kapısı savaş bitince açılır. Kapalı/açık durum kontrolü geçti.
Kaynak ZIP'lere dokunulmadı; `sources.json` ve `building-sources.json` hashleri saklar.

Düşman yönü gerçek konum değişimine bağlandı; navigasyon hücreleri ve köşe
boşluğu düzeltildi. Hasar geri tepmesi normal düşmanda en fazla 12 cm, tankta
5.5 cm, bossta 2.5 cm; yakın dövüş combo menzilinde kalacak şekilde kısılır.
Sekiz mantıksal hareket/geri tepme kontrolü geçti; tüm düşman/boss animasyonları
hareketli kamera incelemesinden geçmiş sayılmaz.

Kullanıcının yeni UI izniyle saydam gotik can çerçevesi ImageGen ile üretildi
ve dinamik can/portre HUD'ına bağlandı. Mevcut menüler ve resimli girişler
korundu. Beş sınıfın yüz kırpımı ayrı ayarlandı ve aynı ekranda sınıf değişince
önceki portrenin kalması düzeltildi.

ImageGen built-in ile `ArtDirection/mage-vfx-phases-v2.png` ve
`combat-vfx-phases-v2.png` tasarım sayfaları üretildi; tam promptlar aynı klasörde
`vfx-prompts-v2.json`. Bunlar hedef tasarımdır, oyun görüntüsü değildir.
Mage kristalleri düzensiz, alçak buz levhalarına çevrildi; çatlak ve yansıma
shaderı, meteor/sıçrama hareket izleri ve düşük sis katmanı yenilendi. Warrior
zemin darbesine ince sıcak çatlaklar, Gunslinger namlusuna kısa ışık kolları ve
ortak dumana düzensiz yoğunluk eklendi. Gerçek Unity kareleri kontrol edildi;
şekil doğallığı, yoğunluk, düşman tepkisi ve görsel kalite henüz kabul hedefinde değil.

Son izole doğrulama: 66 data/asset, 28 event zamanı, 34 Revenant, 14 Mage,
8 hareket/geri tepme, 50 davranış kontrolü ve beş sınıf smoke geçti (exit 0).
Ek olarak sekiz odada yeni bina sınır kutularının oyun alanını kesmediği
kontrol edildi. URP render graph hedef depth-buffer uyarısı açık; testler
bunu görsel kabul veya tamamlanmış optimizasyon diye değerlendirmez.

## 14 Ekim — referans karşılaştırmasının ikinci geçişi

Aşırı aktör dolgu ışığı azaltıldı; ay ışığı, sıcak yerel ışık ve soğuk kenar ışığı
ayrıştırıldı. Mage nova düzenli tel kafes görünümünden kırık buz levhaları,
zemin çatlakları ve yayılan sis katmanına geçti. Warrior parçaları taş dokusu
kullanıyor; Revenant kan kolları inceltildi ve balistik damlalar eklendi.
Gunslinger mermileri ince, sivrilen ışık izi kullanıyor. Bunlar hedefe yaklaşım;
karakter/çevre ayrıntısı ve bütün VFX henüz görsel kabul seviyesinde değil.

Hasar animasyonuna 0.28 saniyelik, normal düşmanda 7 dereceye kadar görsel
tepki eklendi. Konumu ayrıca itmez; önceki 12 cm/menzil sınırı korunur.
Donma ve toparlanma dahil hareket kontrol sayısı 11 oldu. ImageGen built-in
`Presentation/HUD/skill-frame-v3.png` çerçevesi alt üç yetenek yuvasına bağlandı;
prompt `ArtDirection/skill-frame-v3-prompt.json`. Ana menüler/girişler değişmedi.
Sokak ve duvar diplerindeki küçük eski sandık/fıçı geometrileri de yenilendi.

Dört sınıf için 30 fps kontrollü savaş kayıtları alındı: düşman saldırıları
bastırılır, gerçek hasar/animasyon/VFX çalışır. Bu kayıtlar performans ölçümü
veya serbest oynanış testi değildir. Ana proje ile QA aynı C#/shader kaynaklarını
kullanır. URP depth-buffer uyarısı açık. GPU optimizasyonu henüz ölçülmedi.

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
   damage text ve ışık efektleri eksik/yer tutucu. Revenant VFX GLB aktarımı eklendi; diğer efektler
   ve görsel eşitlik incelemesi sürüyor. VFX çizilip hasar/klip olayıyla senkronize edilmeli;
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

Görsel hedef kontrolünde yalnız durağan bir yakın plan yeterli değildir: yürüyüş,
saldırı, yetenek, kalabalık çatışma ve farklı yönlerde aynı oyun kamerasından
model ayrıntısı/efekt okunabilirliği incelenecek. ArtDirection görselleri hedeftir;
mevcut Unity çıktısının bu seviyeye ulaştığı anlamına gelmez. İlk ışık/malzeme
ve sınıf efekti çalışmasının sınırları REVENANT_STATUS.md içinde kayıtlıdır.

### 14 Ekim — zemin yüzey çeşitliliği
WetStone artık geniş ölçekli mineral/kir rengi ve pürüzlülük farklılığı kullanıyor.
Islak bölgelerde normal kabartısı azalıyor; aydınlatma ve depth-normal geçişleri aynı hesabı kullanıyor.
İlk kararan deneme elendi, taş parlaklığı yeniden dengelendi. Ayrı Unity QA projesinde
aynı kamera ile önce/sonra görüntüsü alındı; shader hatası olmadan çıktı üretildi.
Bu kontrol durağandır: hareket/performance kabulü ve referanstaki kırık taş geometrisi
henüz doğrulanmadı. Çevre modellerinin koyuluğu bu değişiklikle çözülmüş sayılmaz.

### 14 Ekim — karakter dolgu ışığı
Karakterlerin rendering layer 2 üzerindeki dolgu ışığı .85'ten 1.6'ya yükseltildi;
rengi daha nötr (.9,.91,1) yapıldı. Çevre ışıkları ve orijinal modeller korunuyor.
Dört sınıfta aynı kamera önce/sonra durağan karşılaştırması ve yön değiştirerek
yürüme + yetenek için kontrollü Unity kayıtları üretildi. Bu kayıtlar serbest
oynanış veya GPU performans ölçümü değildir; genel referans kalitesi eksiktir.

### 14 Ekim — kullanıcının yer halkası geri bildirimi
Revenant Charge artık zemin sigili üretmiyor: 28 kan damlası animasyondaki sol/sağ
ele çekiliyor, iki küçük el parıltısı hazırlanmayı destekliyor. Burst, Gate ve geniş
Claws içindeki dekoratif Surface çağrıları kaldırıldı. BloodVolume daha geniş
yatay yayılım, farklı yükseklikte kollar ve akışa dik kesit kullanıyor.
90 karelik kontrollü kayıt alındı. Diğer sınıfların daire efektleri ve zemindeki
kalıcı oda motifi henüz bu düzenleme kapsamında çözülmedi. Kullanıcı bu daire
görünümünü beğenmiyor; sonraki efekt incelemelerinde temel görsel kısıttır.

Kalıcı arena çemberinin kaynağı ayrıca doğrulandı: `town_gateyard_01` içindeki
7,2 m düz `_MeshInstance3D_1099` / `Material_16` çıkartmasıydı. RoomPresentation
bu tür merkezdeki düz 5–10 m combat çıkartmalarını kapatıyor. Genel `Effects.Ring`
artık tam çember yerine on bir kırık, yönlü çatlak çiziyor. Mage hedef hazırlıkları
sekiz düzensiz arcane damarı kullanıyor; Revenant mark, büyülü mermi teması ve
düşman çağırma/hostile rune temaslarındaki dekoratif Surface halkaları kaldırıldı.
Boss hasar alanının gerçek yönünü gösteren uyarılar oynanış bilgisi olduğu için
korundu. Dört sınıfta 90'ar kare hareketli kayıt alındı. Mevcut doğrulama 66
data/asset, 37 Revenant, 14 Mage, 23 hareket, 13 düşman VFX ve 50 runtime
contract kontrolünün geçtiğini gösterir; bu sonuç görsel kabul değildir.

### 14 Ekim — Gunslinger atış sunumu

Gunslinger’ın hareket eden kısa mermi çizgisi küçültüldü; bir atış tamamlandığında
namludan son konuma uzanan 0,13 saniyelik ince balistik iz oluşuyor. Önceki iki
üst üste billboard flaş kaldırıldı; tek, kısa ve üç boyutlu namlu parlaması canlı
`WeaponSocket` konum ve dönüşünü izliyor. Her sağ/sol silah atışı aynı soketten
pirinç kovan fırlatıyor ve beş dünya-uzayı duman katmanı bırakıyor.
Düşman teması on dört kıvılcım, duman ve mermi yönünde kan sıçraması üretiyor.
Normal beşli volley temasları 41 karelik `BH_FiveShot` boyunca 5/13/21/29/37;
dokuz yönlü ultimate temasları 107 karelik `BH_Ultimate_BloodWake` boyunca
17/28/39/50/61/72/83/94/103 karelerine dağıtıldı. Her mermi güncel namlu kemiği
ve güncel nişan yönünü alıyor. Yedi düzensiz konumlu gerçek düşmana karşı 210
karelik, normal oyun güncellemesi açık kayıtla incelendi. Son doğrulamada 66 data/asset, 37 Revenant,
14 Mage, 23 hareket, 13 düşman VFX, beş sınıf smoke ve 50 runtime contract geçti.
Bu kayıt serbest oynanış/GPU testi değildir ve genel görsel kabulü kanıtlamaz.

### 14 Ekim — kullanıcı kuyu modelinin entegrasyonu

Kullanıcının `medieval well` FBX modeli renk, normal, metalik ve pürüzlülük
haritalarıyla `Environment/Kit01/well` kaynağına alındı. İthalat 3,35 m dünya
yüksekliğine normalize ediyor ve modeli zemin merkezli prefab olarak kaydediyor.
Well Square açıldığında önceki düşük ayrıntılı kuyu parçaları ve geçici prosedürel
çatı kapatılıyor; tamamlanmış model mevcut 2,8 m oynanış/collision ayak izine
yerleşiyor. Model tek mesh olduğu için karanlık kalan kuyu ağzına ayrı, hafif
hareketli normal ve yansıma tepkisi kullanan `WellWater` yüzeyi eklendi.
Bloodwake.unity içinde geniş oyun kamerası ve yakın oyun kamerasıyla ölçek,
zemin birleşimi, çatı silueti ve PBR haritaları kontrol edildi. Bu çevre varlığı
doğrulamasıdır; meydanın genel ışık ve dekor yoğunluğu hedef kaliteye ulaşmış
sayılmaz.
