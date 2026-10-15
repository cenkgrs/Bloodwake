# Bloodwake Unity devir raporu — 15 Ekim 2026

## Çıkış checkpoint'i — açı geçişi ve kalabalık hareketi

- Warrior'ın 150° altındaki yön değişimleri ve saldırı girişinde doğrudan
  LookRotation kullanması anlık yön sıçramasına neden oluyordu. `WarriorTurn.cs`
  artık 240°/sn kademeli yönelme kullanıyor; yürüyüş bedenin ileri ekseninde,
  saldırı hedefe 12° toleransla yöneldikten sonra başlıyor. 150°+ kaynak dönüş
  animasyonu korunuyor. Bu son düzeltme ve yeni açı tarama testleri yazıldı;
  **yeni testler henüz çalıştırılmadı, görsel onay yok**. Önceki aşağıdaki
  başarı kayıtları bu son açı düzeltmesinin doğrulaması sayılmamalı.
- Son kullanıcı ekran görüntüsünde üç Warrior üst üste geliyor. **Çözülmedi**:
  mevcut `Navigation.cs` ortak oyuncu hedefine BFS kullanıyor; `Move` yalnız
  oda engellerini kontrol ediyor, düşmanlar birbirini engellemiyor.
  Unity AI Navigation 2.0.14 kurulu ama runtime NavMeshAgent kullanılmıyor.
  Sonraki iş: native yol bulma/avoidance, ayrılmış yaklaşma-saldırı noktaları
  ve kişisel alan kontrolünü birlikte ele al; state machine tek başına yetmez.
  Onaylı yürüyüşü ve animasyon kontrollü 180° dönüşü bozma. Üç Warrior ile
  gerçek sahne testi/kayıt ve açı tarama testlerini çalıştır.
- Kullanıcı çıkacağı için geliştirme burada durduruldu ve mevcut halin push'ı
  istendi. Cache/crash/recovery, kare dökümleri ve ayrı deneysel model
  çalışmalarını bu oyun checkpoint'ine dahil etme.

## En son — Inward v2 ve 180° dönüş

- Yeni kaynaklar `slash-20261015/inward-v2.fbx` ve `turn-180.fbx`; kullanıcı dosyaları
  sırasıyla `Stable Sword Inward Slash(1).fbx` ve `Sword And Shield 180 Turn.fbx`.
- Inward artık 44/60 = **0.7333 s**, DAMAGE **24/60 = 0.4000 s**, oynatma 1×.
  Outward v2 (0.6 s / 0.15 s contact) ve onaylı yürüyüş .anim SHA-256 değişmedi.
- `build_warrior_attacks.py -- inward turn` mevcut mesh/rig üzerinde iki klibi
  üretir. `WarriorAttackImport.UpdateInwardAndTurn` yalnız bu ikisini günceller.
- Dönüş 54/60 = **0.9 s**. Importer kaynak pelvis yönünden **180.9978°** yaw ve
  XZ adım hareketini çıkarır; bunları `WarriorCombat/turn.json` içine kaydeder.
  `Warrior_Turn180.anim` üzerinde aynı yaw tekrar yoktur; her örnekte sıfırlanması
  import sırasında doğrulanır. Global yön yalnız `WarriorTurn.cs` ile uygulanır.
- Hedef/navigasyon yönü arkada **150°+** olduğunda normal chase yerine dönüş başlar.
  Kaynak dönüş tarafı korunur (kılıç/kalkan aynalanmaz); bitiş yönü hedefe uyarlanır.
  Dönüşte saldırı/normal yürüyüş yok; kaynak küçük adımı collision-aware Move kullanır.
  Darbe dönüşü keser, o ana kadar dönülmüş yön korunur; bitince takip devam eder.
- Fight-to-idle/toparlanma klibi hâlâ gelmedi. Bu ayrı geçiş işi; global 0.09 s
  crossfade değiştirilmedi. Yeni 180° dosyası önceki bekleyen dönüş işini karşılıyor.
- Unity import ve derleme başarılı. Saldırı sırası/1× hız/tek hasar/iptal testleri
  yeni Inward ile 30/60/144 fps'de yeniden geçti. Dönüş 30/60/144/240/360 fps'de
  tam 180° tamamlandı (en büyük kare dönüşü sırasıyla 13.01/6.51/2.71/1.63/1.08°).
  Dönüşte saldırı yok, kemik yaw'ı ikinci kez dönmüyor, bitince ilerleme yönüyle
  bakış aynı. 90° hedefte dönüş tetiklenmeme ve darbe ile yön sıçramadan kesilme
  kontrolleri geçti. İlk testte guard pozunun pelvis açısı dönüş hatası sanıldı;
  aktif dönüş ve çıkış blend'i ayrı doğrulandı; güncel bütün testler geçti.
- 360 kare / 12 s test kaydı ve CSV `review/turn-frames/`; oynatılabilir video
  `art/enemies/mixamo/warrior/slash-20261015/review/warrior-inward-v2-turn180.mp4`.
  Dönüş ve sonrasındaki yürüyüş kareleri görsel olarak incelendi. Test bittikten
  sonra practice konumları/sonsuz can geri yüklendi; Unity practice açık bırakıldı.

## En son — Enemy Warrior Outward → Inward düz saldırıları

- Kullanıcı ilk Outward'ı fazla yavaş buldu; `Stable Sword Outward Slash(1).fbx`
  ile **v2** güncellendi. Kaynak `outward-v2.fbx`, 36/60 = **0.6000 s**. Uzun
  hazırlık yok; vuruş marker'ı **9/60 = 0.1500 s** (ilk dosyadaki 0.75 s değil).
  `build_warrior_attacks.py -- outward` yalnız bunu üretir; `UpdateOutward` yalnız
  bunu Unity'ye aktarır. Inward ve onaylı yürüyüş değiştirilmedi.
- V2 yeniden test edildi: 30/60/144 fps sıra/hız/tek hasar, dört iptal senaryosu
  ve 240 kare sahne kaydı geçti (`WARRIOR_ATTACK_REVIEW_PASSED .../v2-frames`).
  İlk v2 denemesinde henüz yenilenmemiş editör assembly'si eski 0.75 s marker'ını
  yazınca test hasarsız kaldı; derleme sonrası UpdateOutward yeniden çalıştırılıp
  güncel 0.15 s marker ile bütün testler tekrar geçirildi. Yürüyüş/Inward .anim
  SHA-256 değerleri güncelleme öncesi/sonrası birebir aynı.
- Kullanıcı sert saldırı→yürüyüş geçişi için fight-to-idle klibi göndermeyi önerdi;
  kısa kılıç-kalkan attack→idle/guard toparlanması istendi. Henüz dosya yok;
  mevcut 0.09 s crossfade bu turda değiştirilmedi.
- Kullanıcının `Stable Sword Outward Slash.fbx` / `Stable Sword Inward Slash.fbx`
  dosyaları `art/enemies/mixamo/warrior/slash-20261015/` altında saklandı.
- `build_warrior_attacks.py` mevcut enemy Warrior rigine aktarıyor; mesh, doku,
  ekipman ve kullanıcı onaylı yürüyüş değişmedi. Kaynak hız 60 fps, ilk Outward 56/60
  (0.9333 s; v2 ile değişti), Inward 61/60 (1.0167 s), oynatma **1×**.
- `WarriorAttackImport.cs` yeni klipleri `Animations/WarriorCombat` altında üretir;
  controller'a iki ayrı non-loop state ekler, eski Attack yedek olarak durur.
  BuildGame bu importu korur. Güncel DAMAGE: Outward **0.15 s**, Inward **0.45 s**.
- Yalnız enemy grunt `EnemyCombat.WarriorMelee` yolunu kullanır. Her başlatılan
  saldırıda Pattern sırayla Outward/Inward değişir; isabet/ıskalama sıralamayı bozmaz.
  Hasar animasyon event'inden bir kez gelir; ImpactVersion, canlılık, menzil ve açı
  kontrolü var. Mevcut attackCooldown, hasar, menzil ve diğer düşmanlar korunur.
- Unity derleme/import başarılı. `WarriorAttackReview` gerçek TickEnemies + Animator
  event relay yoluyla 30/60/144 fps'de dört saldırılık sıra, 1× hız, tam klip kilidi,
  tek hasar ve event zamanı kontrollerini geçti. Kesilme, menzil dışı, arkaya geçme,
  ölüm hasar iptal testleri geçti. İlk kayıt aracındaki boş transition clip listesi
  hatası giderildi; tekrar kayıt 240 kare tamamlandı: WARRIOR_ATTACK_REVIEW_PASSED.
- Video: `art/enemies/mixamo/warrior/slash-20261015/review/warrior-outward-inward.mp4`.
  Güncel v2 video aynı klasörde `warrior-outward-inward-v2.mp4`.
  Gateyard practice yeniden açıldı; test sonrası sonsuz can ayarı geri yüklendi.
- Sonraki turda 180° dönüş geldi (üstte). E VFX hâlâ ayrı açık iş.

## En son — Enemy Warrior yürüyüşü kullanıcı onaylı

- Kullanıcı yeni yürüyüşü **“çok güzel olmuş”** diye onayladı; bu hali korunacak.
- `Sword And Shield Walk.fbx` in-place, `(1).fbx` ilerleyen sürüm. Orijinaller
  `art/enemies/mixamo/warrior/walk-20261015/` altında; 65/60 = 1.08333 s döngü.
- `build_warrior_walk.py` mevcut düşman rigine yalnız yeni animasyon üretir;
  mesh, doku, ekipman, Idle/Attack/Hit/Death korunur. Retarget world matrislerinde
  target rest scale korunmalı: unit rotation matrix bacakları kısaltıyordu, düzeltildi.
- Yeni `WarriorWalkImport` / `Warrior_ShieldWalk` state'i yalnız grunt düşmanda
  kullanılır; oyuncu Warrior ve diğer düşmanlar etkilenmez. Eski Run klibi silinmedi.
- Ölçülen 1.8 m referans hız 1.56931 m/sn; döngü mesafesi 1.70008 m.
  Gerçek boyut 2.15×1.173 m için nominal hız 2.1986 m/sn. AI takip hızı 1.8 m/sn
  korunuyor, oynatma yaklaşık 0.8187×. Kod gerçek yer değiştirmeden tempo hesaplar;
  slow/aura ve collision sliding de hesaba katılır.
- Planted toe median residual: sol 0.0071, sağ 0.0653 m/sn referans ölçekte.
  Unity imported foot travel 0.8044 m. Ayrı `test_warrior_walk.py` FBX roundtrip
  testi 3 mm toleransta geçmedi (maksimum fark 0.06865 m); export/sample koordinat
  eşleşmesi henüz araştırılmadı. Canlı testlerden ayrı açık doğrulama işi; kullanıcı
  onaylı hareketi bu testi geçirmek için körlemesine değiştirmeyin.
- Canlı `WarriorMotionCapture`: 30/60/144/240/360 fps yön testi, normal/0.3 slow/1.22 aura
  hız eşleme ve aktif klip testi geçti. 240 Hz simülasyonda 360 kare 4 yön takip kaydı
  `art/enemies/mixamo/warrior/walk-20261015/review/frames/` altında. Root/chest yönü
  dört fazda hedefe pozitif; engel çevresinde navigasyon yönü hedef vektöründen sapabilir.
- Yürüyüş onayı korunmalı. Yeni düz saldırı FBX'leri sonraki turda geldi ve yukarıdaki
  Outward/Inward entegrasyonuyla işlendi; **180° dönüş** dosyası hâlâ bekleniyor.
- E Blood Bomb görünüşü kullanıcı tarafından referanstan hâlâ uzak bulundu;
  görsel onaylı değil, ayrı açık iş olarak kalıyor.

## Son yerel çalışma — Noble Revenant / E Blood Bomb (henüz commit değil)

- Aktif oyuncu artık `Actors/revenant_noble.prefab`; önceki model korunuyor.
  Kullanıcının Tripo ZIP + altı Mixamo FBX kaynağı `art/revenant-noble/source-20261015/`.
  Mesh 49.831 üçgen; azaltılmadı. ZIP yalnız basecolor JPEG içeriyor; 8192×8192
  dosya byte-for-byte korunuyor, yüz veya başka doku boyanmadı. Yeni normal/PBR haritası uydurulmadı.
- `build_revenant_noble.py`: kaynak Mixamo iskeletinde altı klip, 1.8 m normalizasyon,
  yatay root-motion temizliği. Düz saldırılar ve Q hâlâ önceki rigden geçici retarget;
  kullanıcı yeni düz saldırıları henüz göndermedi.
- Önemli bulunan hata: Blender 4.5 all-actions FBX exportunda farklı Action slot
  isimleri, klip adı mevcutken Idle/Run/Walk'u sabit poza çeviriyordu. Bütün slotlar
  aynı hedef rig kimliğine bağlandı. `test_revenant_noble_motion.py` artık build sonunda
  dışa aktarılan FBX'i tekrar açıp gerçek kemik hareketini ölçer. Idle 0.0148 m baş,
  Run 1.0978 m ve Walk 1.1444 m ayak hareketi kontrolü geçti.
- Unity importer ayrıca gerçek import edilmiş klipleri SampleAnimation ile doğruluyor:
  Idle 0.0147 m, Run 1.1488 m, Walk 1.1680 m bounding excursion. Bunlar yürüme hızı
  değil, klibin donuk olmadığını kanıtlayan kemik hareketi ölçümleri.
- `Idle.fbx` → Idle, `Run.fbx` → Run, `Sneak Walk.fbx` → Walk. Runtime anahtarları
  uyumluluk için eski `REV_NeutralIdle/REV_StandardRun/REV_SwaggerWalk` isimlerinde;
  bunlar eski Mixamo dosyalarının kullanıldığı anlamına gelmez. Klavyede WASD koşu,
  sol Ctrl + WASD yürüyüş. 1.8 m kaynakta stride: walk 1.96218, run 4.08527 m/s.
- E: `Standing 2H Magic Attack 05`, ilk el teması frame 24 / 0.3833 s event.
  İki elin ortasından ileri ±45° (toplam 90°), 4 m menzilli Blood Bomb.
  Hasar ve ilk flash aynı event'te; zeminden yükselen eski fountain E'den kaldırıldı.
  Yan/arka taraf hasar almaz. Space hâlâ 360° ulti; yeni Area Attack klibinde
  kolların açılması frame 51 / 0.8333 s. Q davranışı değişmedi.
- ImageGen konsepti `art/vfx/references/revenant_blood_bomb/concept-v1.png`, tam prompt
  aynı klasör `GENERATION.md`. Bu konsepttir; gerçek oyun kaydıyla karıştırma.
  `BloodBombVfx.cs` + `Vfx/blood_bomb.shader`: üç akışkan yüzey, ileri koni damlacıkları,
  el temasında parıltı. İlk uygulama; görsel beğeni henüz kullanıcı onaylı değil.
- E/Q/Space kan lekeleri 2.5 s tutar, ardından 0.6 s solar. Normal darbe lekesi
  varsayılanı ayrıca değiştirilmedi. E damlalarının zemine düşüşü de aynı lekeyi üretir.
- `NobleRevenantCapture`: canlı sahne animasyon event'leri + gerçek skill callback'leri,
  deterministik VFX saati. E/Space tek hasar, E aynı kare flash/hasar (30 Hz kayıtta
  başlangıçtan 0.400 s, el-konum farkı 0.051 m), 90° ön/yan/arka/menzil ve leke
  tutma süresi kontrolleri geçti. Üç locomotion state'i aktif modelde doğrulandı.
  Bu kayıt yerinde animasyon incelemesidir; engellerde/yön değişiminde bütün oynanış
  hareketlerinin manuel onaylandığı anlamına gelmez.
- Son kalıcı kayıtlar `art/revenant-noble/reviews/`, Unity log `Logs/noble-review.log`.
  Test bitiminde practice yeniden açılmalı: test efektleri/konumları normal oyuna taşınmasın.
  `revenant-e-and-animations-v4.mp4`: 13 s, gerçek oyun kamerası; E, Space, Run,
  Walk, geçici üç düz saldırı ve Dying sırasıyla. Kayıt sonunda play-stop/restart
  sırasında Unity native FMOD `AudioManager::EngineThreadStarted/TLSAllocator`
  SIGSEGV verdi; kayıt ve dosyalar korunuyor. Yeni editör oturumu logu
  `Logs/noble-practice-restart.log`; bu bir C# derleme hatası değildi.
  Yeniden açılış tamamlandı ve `BLOODWAKE_PRACTICE_READY` doğrulandı; test sahnesi
  yeni oturumda tek Warrior / sınırsız can / cooldown yok durumunda açık bırakıldı.
- `RevenantNobleImport.Build` özel event'leri kurar. Genel `BuildGame` artık bu modeli
  özel importera yönlendirir; generic import ile event'leri silmez.
  `unity/data-overrides.json` ve Godot→Unity veri exporter değişikliği E bağını sonraki
  exportlarda korur; Godot oyununun sınıfını değiştirmez. Override JSON/runtime eşliği
  kontrol edildi; bu oturumda Godot çalıştırılabilir dosyası bulunmadığından exporter
  Godot içinde yeniden çalıştırılmadı.


## 15 Ekim yerel çalışma — karakter dokuları / hareket (henüz commit değil)

- Aktif Unity karakter dokuları için `restore_character_textures.py` orijinal,
  UV eşleşmesi doğrulanmış kaynaklardan 13 aktör / 69 bağlantıyı 4K PNG üretir.
  JPEG'i PNG diye yeniden adlandırmaz; kaynak JPEG ise yalnız ek kaybı önler.
  Kaynak eşlemeleri ve önceki çözünürlükler `character-texture-audit.json` içinde.
- `test_character_textures.py`: 69/69 PNG, 4096 çözünürlük ve eski haritalarla
  aynı UV/doku içeriği kontrolü geçti (korelasyon > 0.999).
- Unity `CHARACTER_TEXTURE_RESTORE_COMPLETE`: 13 aktör / 69 gerçek materyal
  bağlantısı 4096x4096 olarak doğrulandı. Revenant aynı kare/poz/ışık karşılaştırması
  `/tmp/bloodwake-revenant-textures/{previous,restored}.png`; eski lekeli/parlak
  kumaş görünümü yeni haritalarda belirgin şekilde azaldı. Bu, genel ışık/oyun
  kamerası sunumunun bütünüyle onaylandığı anlamına gelmez.
- Unity menüsü: `Bloodwake/Restore Original Character Textures` materyalleri
  günceller. Kaynak PNG korunur, GPU importu CompressedHQ/100, Crunch kapalı,
  çözünürlük tavanı 8192 (4K kaynak büyütülmez). Normal haritaları lineer NormalMap;
  glTF B metallic / G roughness, Unity R metallic / A smoothness olarak paketlenir.
- `export_assets.py` sonunda kaynak doku restorasyonu zorunlu. Godot karakter
  üretim betiklerinden 2K küçültme kaldırıldı, sonraki GLB dışa aktarımı PNG.
  Mevcut eski Godot GLB dosyalarının mesh/rig/animasyonları yeniden üretilmedi;
  Unity materyalleri artık bu GLB'lerdeki küçültülmüş dokulara dayanmaz.
- Revenant kaynak FBX ve Unity FBX: ikisinde de 101244 üçgen, smooth yüzler ve UV
  var. Geometri azaltımı yok; kaynak 4K PNG, eski oyun dokuları 2K JPEG idi.
- Warrior takip yönünde FPS hatası bulundu: kare hareketi <1 cm olduğunda dönüş
  atlanıyordu (>180 fps). EnemyCombat yönü normalize ederek bunu düzeltiyor.
  MotionChecks'e 30/60/144/240/360 fps arkaya geçiş regresyonu eklendi.
  Canlı practice sahnesindeki WarriorMotionCapture aynı beş FPS testini geçti;
  240 Hz simülasyon kaydı `/tmp/bloodwake-warrior-fixed-facing/` altında.
  Koşu klibini ~0.3 hızda oynatma denemesi kullanıcı tarafından reddedildi ve
  geri alındı; mevcut koşunun adım/mesafe uyumu hâlâ ayrı doğrulama gerektiriyor.
- GateyardCombatPractice: tek Warrior, iki taraf sınırsız can, yetenek cooldown yok.
  Revenant idle/run kullanıcı onaylı yeni Mixamo klipleri; yürüme hızı adım mesafesine
  göre ayarlı. Onaylanmamış ses taslaklarını oyuna ekleme.

## Durum

Aktarım **tamamlanmadı**. Unity sürümü `6000.3.25f1`, açılacak oyun sahnesi
`Assets/Bloodwake/Scenes/Bloodwake.unity`. `WarriorReview.unity` yalnız eski
inceleme sahnesidir. Genel görsel hedef Godot görüntüsü değil,
`unity/ArtDirection/` altındaki kullanıcı referanslarıdır. Godot yalnız VFX
davranışı, animasyon, menü/UI ve oynanış kuralları için kaynaktır.

Kullanıcının korunmasını istediği kararlar:

- Warrior modeli `warrior_player` olarak kalacak.
- Mevcut menüler ve resimli karakter/harita girişleri korunacak.
- Referanslardaki ıslak taş, soğuk ortam/sıcak ateş dengesi, kaliteli model
  okunabilirliği ve sınıfa özgü yoğun VFX hedeflenecek.
- Yeşil testler veya çalışan build, görsel aktarım tamamlandı diye sunulmayacak.
- Kabul gerçek `Bloodwake.unity` oyun kamerasındaki hareketli görüntüyle yapılacak.

## Bu push'taki uygulanmış işler

### Karakter, saldırı ve VFX

- Revenant normal saldırıları, teleport, mark, ultimate hazırlık/temas/dağılma,
  kan hacmi, sıçrama, ölüm çözünmesi ve animation-event eşleşmeleri geliştirildi.
  Hazırlıkta kötü görünen kusursuz zemin halkaları kaldırıldı; kan ellerine
  çekilen parçacıklar ve kırık yönlü izler kullanılıyor.
- Mage'in eldeki orbu yeniden kuruldu. Orb gerçek sağ el kemiğini izliyor;
  çekirdek, dönen kabuk, enerji noktaları, mermi kuyruğu, meteor, sıçrama,
  kristal patlama ve sis katmanları var. Oyuncu/düşman Mage orbları ayrılıyor.
- Warrior `warrior_player` korunarak saldırı yayı, whirl, sıçrama, taş/toz ve
  sıcak darbe sunumu geliştirildi.
- Gunslinger namlu efekti canlı silah soketini izliyor. Önceki çift/sabit flaş
  kaldırıldı. Beşli normal atış ve dokuz yönlü ultimate temasları klip boyunca
  dağıtıldı; balistik iz, kovan, duman, kıvılcım ve yönlü kan tepkisi eklendi.
- Düşman ve boss saldırılarında gerçek hasar alanını gösteren sektör/hat
  uyarıları, temas efektleri, çağırma görünümü ve kesilebilir hazırlık akışı var.

### Oynanış ve hareket

- Düşman takip yönü gerçek yer değiştirmeden hesaplanıyor. Engel çevresindeki
  hareket için hücre maliyetli yol bulma ve görüş hattı yumuşatma kullanılıyor;
  çapraz koşup yerinde kalma sorunu azaltıldı.
- Normal vuruş geri tepmesi en kısa yakın dövüş menzilini koruyacak şekilde
  sınırlandırıldı. Büyük alan saldırıları normal düşmanları yaklaşık 0,48 m
  savurup daha uzun tepki verdiriyor; tank ve boss daha az hareket ediyor.
  Hazırlanmakta olan düşman saldırıları ağır darbeyle iptal ediliyor.
- Mage mermileri el yüksekliğinden çıktığı için düşmanı ıskalamaması amacıyla
  düşmanın dikey gövde eksenine karşı swept çarpışma kullanıyor.

### Sunum, HUD ve çevre

- URP sunumu ACES/SMAA, oda yansıma probu, ıslak taş varyasyonu ve karaktere
  özel dolgu ışığıyla geliştirildi. Modellerin malzemeleri metal/kumaş/deri
  ayrımını daha okunur kılacak şekilde güncellendi.
- Sol üst portre kırpımı sınıfa göre yüz merkezli yapıldı; sınıf değişiminde
  HUD yenilenmesi düzeltildi. Alt yetenek çerçeveleri ve ikon sunumu yenilendi.
- Kullanıcının bina, kapı, duvar, brazier, fener, sandık, fıçı ve örtülü masa
  modelleri sahneye bağlandı. Kapı kanatları ayrı pivotlarla açılıyor; eski
  siyah cargo platformları kaldırıldı ve kümeler daha düzensiz yerleştirildi.
- Kullanıcının son kuyu modeli PBR haritalarıyla eklendi, 3,35 m yüksekliğe
  normalize edildi ve `town_well_03` içindeki geçici kuyu/çatı yerine geçti.
  Tek mesh içindeki karanlık açıklığın üstüne özel, hareketli yansıma tepkili
  `WellWater` yüzeyi yerleştirildi.
- Menü müziği, savaş müziği ve geçiş/duck davranışı güncellendi. Dinleme ve
  miksaj kabulü henüz yapılmadı.

## Son doğrulama

Son izole Unity QA çalışması `exit 0` verdi:

- 66 data/asset kontrolü
- 28 Revenant olay zamanı kontrolü
- 37 Revenant çalışma kontrolü
- 14 Mage çalışma kontrolü
- 23 hareket/geri tepme kontrolü
- 13 düşman/boss VFX kontrolü
- Beş sınıf ve runtime smoke akışı

Bu testler kod/varlık sözleşmelerini ve temel akışı doğrular. GPU performansı,
Windows build'i, serbest oyuncu testi veya ArtDirection seviyesinde görsel kabul
kanıtı değildir. Kontrollü kare ve film çıktıları yerel QA klasöründeydi; büyük,
yeniden üretilebilir ham kareler depoya eklenmedi.

## Açık işler — öncelik sırası

1. **Mage VFX kalite geçişi:** Referans tasarımlarına göre orb hacmi, meteor,
   kristal çeşitliliği, kırılma, sis ve düşman temas tepkileri gerçek hareketli
   kayıtta yeniden ayarlanmalı. Mevcut efekt çalışıyor fakat hedef yoğunluğun
   ve doğallığın gerisinde.
2. **Revenant ultimate hazırlığı:** Zemin halkaları kaldırıldı; elde toplanan
   kanın akış şekli, hacmi ve animasyonla senkronu farklı kamera yönlerinde
   tekrar incelenmeli.
3. **Warrior/Gunslinger hareketli temas kontrolü:** Efektler gelişti, fakat her
   saldırı klibinin el/silah temas karesi ve ayak kayması tek tek kabul edilmedi.
4. **Düşman ve bosslar:** Tüm rol davranışlarının windup/recovery/stagger
   dengesi, kalabalık çarpışma yönlenmesi ve her saldırının özgün VFX'i tamamlanmalı.
5. **Çevre sanat geçişi:** Yeni modeller kullanılmasına rağmen bazı eski
   yapılar, boş meydanlar, düşük dekor yoğunluğu ve karanlık malzemeler sürüyor.
   Bağımsız cargo ipi modeli henüz teslim edilmedi. Kuyu sahnede çalışıyor;
   meydanın genel ışığı ve dekor kompozisyonu hâlâ kabul bekliyor.
6. **HUD/UI:** Portre ve ikonlar farklı en-boy oranları, gamepad ve yüksek DPI
   altında yeniden kontrol edilmeli. Runtime UI'nın artist-editable prefab
   yapısına taşınması açık.
7. **Ses ve performans:** Müzik/SFX miksajı kulakla kabul edilmeli; yeni shader,
   dinamik mesh, ışık ve yansıma maliyetleri gerçek GPU'da ölçülmeli.
8. **Platform:** Windows çalıştırma, grafik kalite seçenekleri, gamepad akışı ve
   gerçek kullanıcı oyun testi yapılmalı.

## Diğer bilgisayarda devam

1. Bu depoyu çek ve Unity Hub'dan **Unity 6000.3.25f1** ile `unity/` klasörünü aç.
2. Unity paket/asset importunun bitmesini bekle.
3. `Assets/Bloodwake/Scenes/Bloodwake.unity` sahnesini aç; `WarriorReview` açma.
4. İlk olarak Mage ile gerçek oyun kaydı alıp yukarıdaki birinci açık maddeyi
   ArtDirection referanslarıyla karşılaştır.
5. İthal varlıkları yeniden üretmek gerekirse Unity menüsündeki
   `Bloodwake > Build Imported Game` komutunu kullan. Bu komut sahne/prefabları
   yeniden yazabildiği için önce çalışma ağacını kontrol et.
6. Ana kaynak ve ayrıntılı teknik notlar için `unity/README.md` ve
   `unity/REVENANT_STATUS.md` dosyalarını oku.

## Önemli dosyalar

- Oyun akışı: `Assets/Bloodwake/Runtime/BloodwakeGame.cs`, `GameLoop.cs`,
  `RoomFlow.cs`
- Sınıf VFX: `RevenantVfx.cs`, `MageVfx.cs`, `ClassVfx.cs`, `CombatVfx.cs`
- Düşmanlar: `EnemyCombat.cs`, `EnemyVfx.cs`, `Navigation.cs`, `HitRecoil.cs`
- Sunum: `GameplayLighting.cs`, `RoomPresentation.cs`, `GameHUD.cs`, `GameUI.cs`
- Çevre: `EnvironmentDressing.cs`, `EnvironmentDetails.cs`, `CourtyardWell.cs`
- Testler: `Assets/Bloodwake/Editor/Tests/`
- Görsel hedefler: `unity/ArtDirection/`
