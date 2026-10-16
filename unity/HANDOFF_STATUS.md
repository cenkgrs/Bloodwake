# Bloodwake Unity devir raporu — 15 Ekim 2026

## 16 Ekim 18:20 — sığınak, training alanı ve rigli NPC'ler canlıda PASS

- Dört kullanıcı GLB'si birleşik `Sanctuary/sanctuary_environment.prefab`
  olarak oyuna alındı; benzersiz Resources anahtarı ham FBX'in dokusuz
  yüklenmesini engelliyor. 4K atlaslar URP Lit Base Map olarak bağlı.
- Satıcı `Unarmed Idle.fbx`, kadın mentor `Idle(1).fbx`; önceki GLB dokuları
  rigli meshlerle eşleştirildi. İki idle döngüsü ve skinned mesh test edildi.
- Training odasında pasif/ölümsüz Warrior, merkeze dönüş ve sekiz kırılabilir
  eşya çalışıyor. Oda/NPC/hasar-reset/kırılma ve canlı render testi PASS.
- Son doğrulama: `/tmp/bloodwake-sanctuary-review/result.txt`; görüntü
  `art/sanctuary/integration-20261016/unity-overview.png`.

## 16 Ekim — sığınak referansları hazır; model/kod entegrasyonu sırada (tarihsel)

- Thrust son mekanik testi PASS: .30 s hamle + .07 s temas pozu; recovery yok;
  .96 m itiş; gerçek konum >.90 m. Bitiş karşılaştırmasına float epsilon eklendi.
  Temas pozu renderı incelendi. Estetik kullanıcı onayı henüz yok.
- Kullanıcı sığınak kodlamasına geçilmesini ve modeller için T-poz istedi;
  imagegen satıcı/mentor T-pozları `art/sanctuary/references/` altında.
- Kullanıcı ardından iki GLB gönderdi (henüz incelenmedi/oyuna aktarılmadı):
  Downloads/medieval fantasy character 3d model.glb;
  Downloads/fantasy character 3d model(1).glb.
- Öncelikli yeni isteği oda eskizleri oldu: merchant-room-v1, mentor-room-v1,
  training-room-v1, entrance-corridor-v1 PNG'leri aynı klasörde, ayrı üretilmiş.
  room-generation-prompts.txt tam promptları ve entegrasyon notlarını içerir.
  Training warrior ve kırılabilir kutular oda mesh'ine gömülmeyecek.
- Sığınak runtime entegrasyonu henüz uygulanmadı. Mevcut StartRun zaten
  town_safehouse'a gider; EnterRoom/SpawnHosts/Interact, DamageEnemy/TickEnemies,
  GameUI/MenuPages incelendi. Yeni odalar/NPC'ler ve reward vermeyen pasif
  respawn olan training Warrior hâlâ yapılacak; tamamlandı diye sunulmamalı.

## 16 Ekim — kullanıcı videosu sonrası thrust okunabilirlik düzeltmesi

- `17-03-59.mp4` incelendi: önceki opak VFX kırmızı çubuk/blok gibi;
  .10 s saldırının .075 s giriş blend'i ve aynı karede idle dönüşü hamleyi
  görünmez yapıyordu. Önceki PASS estetik doğrulama olarak sunulmamalıydı.
- Kaynak ilk .10 s kesilir (önce .30 s idi); kol hamlesi .30 s, ardından
  .07 s TAM TEMAS pozu gösterilir. Sonra çıkılır, recovery oynatılmaz.
  Kaynak dosyada süre 1.066667; runtime yalnız .37 s kullanır, hasar .30 s.
- Opak çubuklar kaldırıldı; `claw_cut.shader` saydam, yumuşak kenarlı,
  incelen/düz kan kesikleri kullanır. Hedef izi .26 s, hareket izi .16 s.
- Yeni inceleme kareleri/video `art/revenant-noble/thrust-20261016/readability-review/`.
  Mekanik test ile görsel beğeni ayrı; kullanıcı onayı henüz yok.

## 16 Ekim — thrust temasında bitiş, daha güçlü itiş ve düz pençe izi

- Runtime .10 s DAMAGE anında thrust'ı bitirir; kalan toparlanma oynatılmaz.
  Kaynak klip korunur, yaklaşma temposu değişmez; attackCd ve pose lock kalkar.
- Thrust recoil öncekinin iki katı: basic x4 (Warrior .48 → .96 m), .36 s.
  Hasar değişmez. Darbe çizgileri genişletildi; vurulan hedefi itilirken takip
  eden dört düz paralel kızıl pençe izi .42 s görünür.
- Yeni test hedefin yalnız recoil değerini değil, gerçek konum değişimini
  ve temas anında hareket/saldırı kilidinin kalkmasını da kontrol eder.

## 16 Ekim 16:35 — Thrust küçülme düzeltmesi ve hazırlık kesimi

- Önceki thrust PASS görsel kalite/ölçek doğrulaması değildi: runtime aynı
  hatalı kliple karşılaştırıldığı için Hips 0.555284 ölçek hatası kaçmıştı.
  Retarget quaternion matrisi hedef rig'in 1.800879 world scale değerini
  kaybediyordu. `build_revenant_thrust.py` artık hedef bind ölçeğini korur;
  tüm kemik local scale değerlerini doğrular. Importer scale curve almaz.
- İlk 18 frame / .30 s hazırlık kesildi; kalan animasyonun temposu korunur.
  Yeni süre .866667 s, DAMAGE .10 s. Parmaklar açık pençe; mesh/doku değişmedi.
- Runtime/editor derlemeleri ve canlı Unity import/test PASS (16:35).
  Test artık hatalı klibi referans almak yerine idle kemik ölçekleri ve
  sekiz uzuv uzunluğunu her adımda karşılaştırır. Dash/thrust/recovery boyunca
  ölçek sabit; tek basic hasarı ve 2x itiş korunuyor.
- 45 kare gerçek oyun renderı, video ve sonuç:
  `art/revenant-noble/thrust-20261016/size-fix-review/`.
  `contact-sheet.png` geçişleri görsel incelendi; `dash-thrust.mp4` 30 FPS.
  Test sonunda practice yeniden başlatıldı. Aşağıdaki 1.1667/.4 süreleri
  tarihsel eski durumdur; güncel süreler yukarıdadır. Kullanıcı görsel onayı
  henüz alınmadı; otomatik PASS estetik onay sayılmaz.

## 16 Ekim — SON REVİZYON: tüm dash hattı + sıvı E PASS; yeni authored thrust aktarımı

- Kullanıcı gövdeye bağlı düz dumanı ve E'nin taş gibi duran parçalarını tekrar
  reddetti. Önceki v2 render/test PASS yeni görselin onayı değildir.
- Dash: gövde sisinde yırtık kan damarları, yol boyunca her .45 m'de sabit kalan
  1.05 s sis, .9 s ince/ıslak kan iplikleri ve 1.12 s kanlı zemin izi.
  İzler başlangıç-varış arasını kaplar; duman sadece oyuncuyu takip etmez.
  Gövde opaklığı azaltıldı. Kızıl iplikler gerçek eğri mesh, zemin izi yeni
  `dash_trace.shader`. Damla kalıntıları da yaklaşık 1 s tutulur.
- E artık BloodBombShards çağırmaz: Space ile aynı Wet blood malzemesi ve
  BloodVolume eğri geometrisinin öne yönlendirilmiş 43 kollu, .78 s sıvı basınç
  dalgası. 64 ince/uzayan kan damlası destekler. Avuç başlangıcı/90°/gerçek
  hasar menzili korunur; efekt mevcut alanı daha yoğun doldurur, gameplay
  menzil/hasar/itiş/ses değişmedi. Eski taş shader/helper kullanılmıyor.
- Runtime/editor Roslyn derlemeleri PASS. Yeni dash/E canlı RevenantDashReview
  testi GEÇTİ: tüm hatta sis/zemin izi, süre/cleanup, 43 sıvı kol/64 damla,
  genişlik ve 90° geometri, mevcut dash oyun mantığı. Oyun renderları incelendi:
  `art/revenant/dash_review_20261016/dash-path-v3.png` ve `e-liquid-v3.png`.
  Bu test sırasında thrust henüz devre dışıydı; yeni klibe PASS sayılmaz.
- Kullanıcı `/home/cenkargevim/Downloads/Upward Thrust.fbx` verdi; yalnız kılıç
  kavrayan eli pençe gibi açmamızı istedi. `unity/build_revenant_thrust.py`
  mevcut noble rig'e klibi bake eder, sağ elin 15 finger joint kavramasını
  %12'ye (thumb %22) indirir; wrist/arm/spine mocap korunur. Planar Hips root
  motion in-place yapılır, dikey korunur. Mesh/UV/oyun dokuları değişmez.
- Kaynak tempo 60 FPS, 1..71 frame = 1.166667 s korunur. Hasar marker .4 s,
  elde ileri uzanışın %96'ya ilk ulaşımı. Runtime sabit .46/.16 yerine bu
  klibin süresi/marker'ını okur. İlk .075 s giriş blend'i var, procedural
  arm IK yok; hasar 1 basic, recoil 2 basic. Gerçek animasyon varsa kombo açılır.
- Kaynak kopyası, rapor, review blend ve gerçek mesh üstünde `contact.png`,
  `claw.png`: `art/revenant-noble/thrust-20261016/`. Renderlar incelendi ve açık
  pençe önizlemesi kullanıcıya gösterildi. Animasyon-only FBX + thrust.json:
  `Resources/Animations/RevenantCombat/`. `RevenantThrustImport` .anim'i oluşturup
  noble controller'a bağlar. `Library/RevenantThrustImport.request` = `review`
  kuyruğu çalıştı: import PASS (1.166667/.4). 16:20:22 canlı Unity testi de PASS:
  orijinal tempo/contact, açık pençe, tek basic hasarı, 2× ileri itiş, buffer,
  pause/duvar/ölüm ve yeni dash/E aynı tur doğrulandı. `unity-contact.png`,
  `unity-recovery.png`, `unity-test-result.txt` aynı thrust review klasöründe.
  Sonunda fresh tek Warrior practice açıldı. Son ek QA 16:24:08'de PASS:
  runtime RightHand/RightForeArm/Spine2/iki ayak pozu doğrudan authored clip
  örneklemesiyle .01 m/1° toleransta aynı. Thrust klibi gerçekten oynuyor;
  idle/yanlış sample değil. Pending request kalmadı.
- Yeni importer derlendikten sonra `Library/BloodwakeAssetRefresh.request`
  tek-seferlik AssetDatabase.Refresh tetikler; ileriki iterasyonlarda tekrar
  kullanıcıdan focus istemeden derleme yapılabilir. Sürekli otomatik poll-import yok.
- OBJ teslim edildi. Alttaki "FBX bekliyor" kayıtları geçmiş durumu anlatır.

## 16 Ekim — GÜNCEL: Shift dash sis revizyonu, thrust FBX bekliyor, doğru OBJ teslimi

- Konseptler uygulamaya alındı. Kullanıcı ilk dash'in ince zemin izini ve
  prosedürel IK thrust pozunu REDDETTİ. Yeniden bunlara dönme.
- `RevenantDash.cs`: Revenant Shift / gamepad L shoulder, fiziksel 3.2 m hareket,
  .24 s ease-out, normal .85 s cooldown (practice 0). Duvarlar mevcut swept
  Move ile korunur. Pause/hitstop hareketi ve süreleri dondurur. Teleport/Hide
  ya da yeni invulnerability yok; öne eğik Run silüeti tutulur.
- Yeni dash: gövdeyle birlikte taşınan 8 katmanlı kızıl sis (`dash_mist.shader`),
  hareket hattına dökülen hacimli sis, sağ/sol/arkaya uzayan ıslak kan damlaları;
  bulut varıştan sonra .22 s içinde dağılır. Önceki küçük zemin stamp'leri yok.
  Oyun içi render `art/revenant/dash_review_20261016/dash-cloud-v2.png`.
  Görsel incelendi; kullanıcı henüz bu revizyonu onaylamadı.
- Kol/bilek/spine zorlayan thrust IK SİLİNDİ. Gerçek `REV_ClawThrust` klibi
  mevcut olmadığı için özel kombo kapalı, HUD'da thrust vaadi yok. Dash sırasında
  tıklanan normal saldırı varışa buffer edilir. Kullanıcı doğru tek kollu ileri
  hamle Mixamo FBX'ine bakacağını söyledi. Klip gelince pose/contact/duration
  yeniden kalibre edilecek. Mevcut Double Dagger Stab/Mutant Punch kaynağı
  tek kollu düz pençe thrust yerine geçirilmedi. 2× temel itiş kodu korunuyor
  ama gerçek klip eklenene kadar erişilemez; şu an thrust tamamlandı DENME.
- `Crimson Arrival · Revenant`: sadece Revenant, tek seviye/15 cost, sonraki
  run'da varışta 1.25 m alana %65 basic hasarı açar. Kilitliyken dash hasarsız.
  Practice F9 geçici hasar toggle (save değiştirmez), F8 tek/üç Warrior aynı.
  Meta import maxLevel'e göre clamp; sınıfa özel skill başka sınıfa uygulanmaz.
- E: 25 sivri, asimetrik blood-glass parçası için yeni transparan/fasetli shader;
  90° el hizası korunur. Görsel parçalar düşmana değince kırılır; bu ikinci
  hasar vermez. Mevcut clap damage zamanı ve onaylı sesler değişmedi.
- Runtime ve editor Roslyn derlemeleri PASS. 15:58 canlı Unity
  `RevenantDashReview` PASS: 30/60/144/360 FPS mesafe/süre, gövde takip eden sis,
  kan yayılımı/shader/cleanup, yetenek kilidi/hasar/sınıf/save, normal saldırı
  buffer, pause/hitstop, duvar, ölüm reset, E 25 parça/cleanup. Önceki
  Missing follow-up window hatası float .24 sınır epsilon'u ile düzeltildi;
  eski failure dosyası test başında temizleniyor. Fresh practice açıldı.
- İstenen OBJ doğrudan **oyunda kullanılan**
  `Resources/Models/revenant_noble/revenant_noble.fbx` kaynağından REST bind
  pozunda çıkarıldı; eski Revenant değil. `art/revenant-noble/mixamo-current-20261016/`
  içinde `Revenant_Noble_Current.obj`, MTL, değişmeden kopyalanmış orijinal 8K
  JPEG, Mixamo ZIP ve yeniden import edilen OBJ'nin preview.png'si var.
  49,831 yüz/UV korunumu, 1.8 m ölçek ve doku byte eşitliği doğrulandı.
  `validation.json` kaynak SHA256 içerir; `export_current_obj.py` tekrar üretir.
- Bu tur commit/push yok. Alttaki konsept aşaması geçmiş kayıttır. Hub işi bekliyor.

## 16 Ekim — GEÇMİŞ: flash +%15, E / Shift dash / dash-thrust KONSEPT AŞAMASI

- Kullanıcı .28 düşman flash'ını %15 artırdı: GÜNCEL .322. Süre .16 s,
  .025 s tutuş ve oyuncu .12/.09 s aynı. Test beklentileri güncellendi;
  runtime/editor Roslyn derlemeleri ve güncel CombatReadabilityReview
  canlı Unity testi geçti. Practice restart edildi; tek Warrior hazır.
- Kullanıcı mevcut E kan-cam VFX'ini beğenmedi; önce ImageGen tasarım ve
  onay istedi. Yeni E veya dash kodu BU TUR YAZILMADI. Mevcut E/Q korunur.
- ImageGen (built-in) ile üç ayrı tasarım:
  `art/vfx/references/revenant_combat_design_20261016/e-bloodglass-v2.png`
  (avuç temasından 90° öne yarı saydam keskin kan-cam kırıkları),
  `dash-crimson-mist-v1.png` (Shift; görünür, öne eğik gövde,
  kızıl sis ve etrafa kan damlaları; teleport değil),
  `dash-thrust-combo-v1.png` (dash ardından sol tık; tek pençeli el düz
  ileri thrust, normal düz atak itiş mesafesinin 2×'si, HASAR 2× değil).
- ÖNEMLİ kullanıcı takip mesajı: oyundaki koşu zaten öne eğik olduğundan
  ilk taslaktaki öne eğik dash daha mantıklı; v1 yönü tercih edildi. V2'nin
  dik gövdesi ELENDİ. Koşu→dash doğal geçiş ve görünür gövde korunmalı.
  Bu tercih henüz uygulama onayı değil. Çizimdeki itiş okları şematik;
  gerçek uygulama oranı 2× olacak.
- Revenant yetenek ağacında açılınca dash'in hasar vermesi isteniyor;
  tasarımda VARIŞ noktası hasarı varsayıldı ve kullanıcıya açıkça söylendi.
  Temel dash hareket-only. Mesafe/cooldown/i-frame/kombo input penceresi
  henüz belirlenmedi. Kullanıcı konseptleri onaylamadan uygulamaya geçme.
- Tam promptlar/mode/sürüm notları aynı klasörde GENERATION.md içinde.
  Tüm konseptler onay bekliyor; 3D/animasyon üretimi yapılmadı. Push yok.

## 16 Ekim — Q tüm geçiş hattı, E sivri kan-cam parçaları, düşman flash ayarı

- Q `DAMAGE` artık yalnız varış çemberini değil, gerçek BlinkDestination ile
  kısıtlanmış başlangıç→varış hattını da tarar. .75 m yarı genişlik + .4 m
  gövde payı; varış alanı korunur. İniş boş olsa da yol üzerindeki TÜM düşmanlar
  hasar/flash/stagger/recoil alır. Hat+varış birleşiminde tek hasar; doğuş
  bağışıklığı korunur. Yol üzerindeki kırılabilir kutular da etkilenir.
- E için son kullanıcı tercihi: parfüm gibi püskürme değil, kandan oluşmuş
  sivri cam parçaları. Üç transparan fan katmanı devre dışı; el hizasından
  90° öne 25 asimetrik, sivri/fasetli parça. Space'in Wet blood malzemesi
  ortak kullanılır. 84 küçük damla → 18 daha iri destek damlası. VFX ömrü
  .68 s, kalıntılar 2.5 s. E hasar geometrisi/zamanı/itişi ve onaylı E v7,
  Q, Space ses dosyaları değişmedi. Space'in mevcut hacim geometrisi aynı.
- İlk flash denemesi 1.35 güç/.20 s fazla beyaz bulundu (KULLANMA).
  Güncel düşman flash: .28 güç/.16 s; ilk .025 s kısa tutuş, sonra smooth
  fade. Emission maskesi sadece düşman darbesi sırasında beyaza alınır,
  böylece koyu maske darbeyi yutmaz; bitişte orijinal geri yüklenir.
  Oyuncu .12 güç/.09 s ve eski karesel fade aynen korunur.
- `CombatReadabilityReview` menü/request testi eklendi. Boş iniş + üç ara
  hedef, hat/varış birleşimi, tek hasar, dışarıdaki ve doğmakta olan hedefler,
  practice sonsuz HP'de flash, oyuncu ayarı, fade/restoration, E konisi,
  mesh/malzeme ve temizleme kontrol edilir. Renderlar yerel review klasöründe.
- Son runtime/editor Roslyn derlemeleri ve 15:08:56 canlı Unity testi GEÇTİ:
  Q boş varış + üç yol hedefi, birleşim/tek hasar, doğuş bağışıklığı; .28
  hafif flash, oyuncu aynı, tutuş/fade; 25 sivri parça/90°/temizlenme.
  Mesh winding dış yüzey normalleri için düzeltildi. Güncel renderlar
  `art/revenant/combat_readability_20261016/flash-contact.png` (zırh detayı
  görünür, beyaz silüet yok) ve `e-shards-16.png` (sivri bordo parçalar).
  result.txt güncel PASS. Test sonunda fresh tek Warrior practice açıldı;
  pending request yok. Hot reload sonrası practice restart edildi.
- Hub/dönüş evi hâlâ bekliyor. Bu tur commit/push yok.

## 16 Ekim — yarık yumuşatma + Revenant Space başından %15 kırpma

- Kullanıcı yarık sınırını fazla net/köşeli buldu. Shader'daki dar kırmızı
  kontur ve yüksek frekanslı kırık sınır kaldırıldı; geniş feather, düşük
  frekanslı bulut ve yumuşak kırmızı pus eklendi. Sis/AI süreleri değişmedi.
- Noble Revenant Space artık kaynağın ilk %15'ini atlayarak başlar:
  74/60 s klipte .185 s offset, kalan süre 1.0483 s. Orijinal FBX klibi
  korunur; ActorView crossfade başlangıç offset'i kullanır, playback 1x.
  Action lock ve MarkerTime kalan süreye göre hesaplanır. Diğer klipler aynı.
- ULT_DAMAGE fiziksel el-açma marker'ı yerinde kalır, cast'e göre .8333 →
  .6483 s olur. Kesilen bölümdeki telegraph/gather cast'te hemen başlatılır.
  Onaylı Space WAV değiştirilmedi; SoundFrom aynı .185 s offsetten başlar,
  böylece patlama sesi aynı oranda öne gelir, pitch/ton/seviye değişmez.
- Runtime ve editor Roslyn derlemeleri geçti. Güncellenen canlı test
  `/tmp/bloodwake-enemy-emergence-soft` GEÇTİ: shader/render, gerçek
  Space marker'ı, action lock ve AudioSource başlangıcı doğrulandı.
  Log: `SPACE_TRIM_PASSED skip=0.1850s contact=0.6583s lock=1.0483s audio-pitch=1`.
  Gerçek event .6583 s (120 Hz test adımı/crossfade dahil), beklenen .6483 s
  ile tolerans içinde. Kontur kaldırılmış render incelendi; kareler ve PASS
  sonucu `art/enemies/spawn_review_20261016/soft/` içinde. Test sonunda
  fresh Revenant/tek Warrior practice yeniden kuruldu, pending request yok.
- Açık Play Mode'daki domain reload mevcut serialize edilmeyen oyun/müzik
  durumunu kaybettirdi; test sahnesi restart edilerek doğrulandı. Son kodu
  denerken de hot reload yerine practice'i yeniden başlatmak gerekir.

## 16 Ekim — kırmızı sisli yerden doğuş EKLENDİ / Unity testi geçti; E v7 onaylı

- Kullanıcı E v7'yi onayladı. Single WAV birebir `revenant_e_blood_bomb.wav`
  olarak aktarıldı; `cmp` geçti. Q/Space ve E playback gain/pitch aynı.
- Dönüş evi öncesi yeni öncelik: düşmanlar yeraltındaki delik/yarıktan kırmızı
  sis içinde yükselsin. Godot `world.gd::_rise/_rise_tick`, `fx.gd::spawn_smoke`
  incelendi. Unity'de ortak `SpawnEnemy` artık bu akışı başlatır; normal dalga,
  practice/F8 ve boss çağırdığı minyonlar dahil, boss gövdesi de ölçeklenir.
- ActorView: .35 s hazırlık + .9 s cubic ease-out yükselme. Sadece modelin
  görsel pivotu boyu+.25 m derinden kalkar; gameplay root/NavMesh/yeni spawn
  yer rezervasyonu y=0'da sabit. İlk .35 s model gizli; sonunda offset tam 0.
- EnemyVfx: zeminde procedural `spawn_rift` shader ile siyah, kırmızı kenarlı
  geçici yarık; 18 düşük opaklık kırmızı sis pufu + 8 küçük yükselen kor.
  Gerçek zemin geometrisi delinmez, görsel illüzyondur. En geç 2.1 s temizlenir.
  Ortak efekt saati pause/hit-stop ile durur, oda değişince roomRoot ile silinir.
- Doğarken AI/atak/turn/status sayaçları bekler, ajan yerinde durur. Godot gibi
  hasar/itiş bağışıklığı; melee/projectile/chain/ricochet/mark/alan hedeflemeleri
  çıkan gövdeyi atlar, görünmez hedef mermi tüketmez. Can barı çıkışta açılır.
  Bitişte .35 s saldırı cooldown; mevcut hareket/stride/turn ayarları aynı.
- `EnemyEmergenceReview` canlı açık editörde çalıştırıldı ve GEÇTİ:
  hazırlık/yükselme/root sabitliği/NavMesh duruşu/erken AI yok/hasar ve itiş
  bağışıklığı/sonrasında hasar/efekt temizliği/pause-hitstop clock;
  ayrıca 30/60/144/360 FPS süre ve monoton yükselme testleri.
  Yeni shader hatasız import edildi. Runtime ve editor Roslyn derlemeleri geçti.
- Gerçek Gateyard renderları kontrol edildi: `art/enemies/spawn_review_20261016/`
  `spawn-029.png` baş çıkışı, `spawn-044.png` gövde, `spawn-071.png` tamamlanma,
  `spawn-140.png` efekt temizlenmesi; result.txt test sonucu. Sonunda tek Warrior
  Revenant practice yeniden kuruldu. F8 bir/üç Warrior değiştirerek yeni doğuşu
  kullanıcı test edebilir.
- Batch editör ikinci instance yüzünden açılamadı; aynı proje açık olan mevcut
  editör kullanıldı, kilit aşma/ikinci checkout yok. Bu editörün gerçek logu
  `/home/cenkargevim/.config/unity3d/Editor-prev.log` (20802 fd kontrolüyle bulundu).
  Test request tüketildi, SessionState kapandı; bekleyen otomatik test yok.
- Sonraki madde hâlâ aşağıdaki dönüş evi. Bu tur hub başlamadı. Commit/push yok.

## 16 Ekim — E v7: son kan patlaması v6 üzerinden +%30

- Kullanıcı yalnız kan patlamasını %30 daha artırdı. Gerçek v6 single'ın
  aynı son bölümüne 1.30x gain uygulandı (plato v4'e göre 1.625x).
  Pençe v6'daki -%10 ayarında ve diğer bölümler örnek bazında aynı.
  EQ/sample/süre/timing/normalizasyon değişmedi.
- `art/revenant/audio_review_e_v7/e_v7_burst_plus30_preview.wav` iki tekrar,
  `e_v7_burst_plus30_single.wav` tek kullanım. Script/hash/ölçümler yanında.
- Dinleme adayı; **henüz Unity'ye aktarılmadı**. Runtime E v1; Q/Space aynı.

## 16 Ekim — E v6: yalnız küçük ses yüksekliği ayarı (ONAY BEKLİYOR)

- Kullanıcı v5'i uzak buldu; özellikle `e_v1_then_v4_comparison.wav` sonundaki
  kan patlaması bölümünü yükselt, pençeyi **çok az** azalt, ses değişmesin dedi.
- `art/revenant/audio_review_e_v6/`: gerçek v4 dosyası, kullanıcının adını
  verdiği karşılaştırmanın ikinci sesiyle PCM birebirliği doğrulanarak alındı.
  Sadece volume envelope: ilk pençe bölümü -%10, son patlama bölümü +%25.
  Yeni sample, EQ, pitch, süre/timing, normalizasyon veya stem remix yok.
  V5'teki ufak organik sample'ı aşırı yükseltme yaklaşımı kullanılmadı.
- `e_v6_volume_only_preview.wav` yeni adayı iki kez;
  `e_v4_then_v6_comparison.wav` önce değişmemiş v4 sonra v6 çalar.
  Single ayrıca var. **Henüz runtime değiştirilmedi, E hâlâ v1.**
  Q/Space aynı. V5 reddedildi; aşağıdaki bölümler tarihçe.

## 16 Ekim — E v5: beğenilen v4, kan önde / pençe arkada (ONAY BEKLİYOR)

- Kullanıcı v4'ü çok daha iyi buldu; sadece pençe kanı bastırdığı için ses
  yoğunluğu/yüksekliği hiyerarşisinin tersini istedi. Yeni tasarım yapılmadı.
- `art/revenant/audio_review_e_v5/`: v1'in deterministik pençe ve kısa kan
  stem'leri yeniden kuruldu, aynı v4 işlemi uygulandı. Gerçek v4 mixinden
  çıkarılıp yalnız bu iki katman yeniden dengelendi: pençe .25 gain (-12 dB),
  mevcut kan katmanı headroom sınırında artırıldı. Kan RMS pençeden 3.4 dB
  yüksek. Diğer katmanlar matematiksel olarak değişmeden kaldı.
- `e_blood_forward_v5_preview.wav` yeni adayı iki kez çalar;
  `e_v4_then_v5_comparison.wav` önce v4, sonra v5. Single ayrıca mevcut.
  PCM16 stereo48k, -4 dBTP. Script/README/hash/ölçümler aynı klasörde.
- Henüz oyun dosyaları değiştirilmedi: runtime E hâlâ v1; Q/Space aynı.
  V5 dinleme onayından sonra yalnız E single dosyasını değiştirmek yeterli.

## 16 Ekim — E için ilk sese dönüş, küçük v4 revizyonu (ONAY BEKLİYOR)

- Kullanıcı v3'ü de uzak buldu: ilk E hepsinden iyi; yalnız ilk sesi biraz
  patlamaya yaklaştırmak istemiş. Yeni kaynak/ayrı bomba tasarımı yapılmadı.
- `art/revenant/audio_review_e_v4/`: doğrudan onaylı E v1 single üstünde
  .33–.85 s temas bölgesi EQ/gövde düzenlemesi, tiz pençe kenarı azaltma,
  kendi alt/orta gövdesinin hafif uzatılması. Kan/hazırlık/timing korunur.
  .33 s öncesi ve .85 s sonrası örnekler birebir aynı. Global gain yok;
  temas yerel seviyesi orijinal true-peak tavanıyla sınırlandı.
- Karşılaştırma `e_v1_then_v4_comparison.wav`: **ÖNCE İLK E, SONRA V4**.
  Bu dosya aynı sesi iki kez tekrarlamaz. V4 single ayrı dosya.
- Henüz runtime değiştirilmedi: E v1 oyunda; Q/Space aynı. V2 ve V3
  reddedildi; aşağıdaki onay bekliyor ifadeleri tarihçedir.

## 16 Ekim — E v2 reddedildi (balon); v3 patlama sample adayı

- Kullanıcı E v2'yi balon patlamasına benzetti. V2'nin kısa procedural
  transient'i terk edildi. `art/revenant/audio_review_e_v3/` yeni adayı:
  CC0 EZduzziteh explosion1 + NenadSimic Muffled Distant Explosion gövdesi,
  kısa kan dokusu; pençe yok. Kaynak/lisans/script/hash aynı klasörde.
- NenadSimic kaynağı gerçek bomba saha kaydı değil, pes log drum/reverb
  tabanlı tasarlanmış efekttir. İlk yorumdaki "gerçek patlama kaydı" ifadesi
  sonuç için teknik provenance olarak kullanılmamalı.
- .3833 s temas, yaklaşık 1.2 s patlama gövdesi/kuyruğu, stereo PCM48k,
  -4.5 dBTP. Preview aynı adayı iki kez çalar. **Onay bekliyor.**
- Runtime değiştirilmedi: E hâlâ v1; Q/Space aynı. V2 aşağıda tarihçe.

## 16 Ekim — E revizyonu: pençesiz basınç/kan bombası v2, ONAY BEKLİYOR

- Kullanıcı oyunda E v1'in pençesini gereksiz buldu; kan temalı ses/basınç
  bombası istedi. Q ve Space için yeni değişiklik istemedi.
- `art/revenant/audio_review_e_v2/e_pressure_bomb_v2_preview.wav`: aynı
  aday iki kez; kısa basınç hazırlığı, tok geniş bant patlama, alt frekans
  gövdesi ve arka planda kısa kan püskürmesi. **Hiç pençe sample'ı yok.**
- Kaynak: özgün procedural katmanlar + önceki CC0 squishsplat kaydının
  kısa/filtreli bölümü. Uzun cıvık/slurp/damla kuyruğu yok. Script, README,
  kaynak hash'i, ölçümler, single ve üç timeline stem aynı klasörde.
- E .3833 s temasına hizalı, stereo 48 kHz PCM16, -4.5 dBTP.
  **Yeni aday henüz oyuna eklenmedi; E runtime hâlâ v1.** Q ve Space
  dosyaları/bağlantıları değiştirilmedi. Dinleme onayı sonrası E'yi değiştir.

## 16 Ekim — E ve Space onaylandı, oyuna bağlandı

- Kullanıcı "sesleri aktar ... gayet güzeller" dedi. E/Space v1 **single**
  dosyaları birebir Resources/audio'ya kopyalandı: `revenant_e_blood_bomb.wav`
  ve `revenant_space_blood_burst.wav`. Preview tekrarları oyuna taşınmadı.
- Cast başlangıcında bir kez, onaylı seviye/pitch korunarak çalarlar:
  db 0 / pitch 1, 48 kHz stereo PCM, normalization kapalı.
  Darbeler dosyada E .3833 s / Space .8333 s'ye hizalı.
- Yalnız Revenant E ve Space'in eski generic cast/blast çağrıları kaldırıldı;
  Q, diğer sınıflar, hasar/VFX ve geri itiş değişmedi.
- Ses sistemi Q gibi gerçek zamanlı: hit-stop/pause animasyonu durdururken
  tam ses klibi devam eder. Canlı oyun/senkron testi henüz yapılmadı.
- Runtime kurulu Unity Roslyn/proje referanslarıyla hatasız derlendi;
  iki WAV için birebir `cmp`, JSON parse ve `git diff --check` geçti.
  Eski onay bekliyor notları aşağıda tarihçe.
- Sonraki istenen aşama aşağıdaki dönüş evi konseptleri. Bu ses aktarımında
  hub veya ücretli 3D üretimi başlatılmadı. Commit/push yok.

## 16 Ekim — Q onaylandı/bağlandı; E ve Space dinleme denemeleri hazır

- Kullanıcı Q v3 için "mükemmel" dedi. Onaylı single dosyası birebir
  `Resources/audio/revenant_q_mist_claw.wav` olarak kopyalandı; PCM/stereo,
  gain 1, pitch 1. Q cast başlangıcında bir kez çalar; önceki generic launch
  ve landing yalnız Q yolundan kaldırıldı. Diğer sınıflar değişmedi.
- Q tek dosyası normal hızda .4167 s DAMAGE anına hizalıdır; mevcut ses
  sistemi gerçek zamanda çalar. Hit-stop/pause sırasında ses ile animasyon
  ayrı saatler kullanır; canlı senkron/oynanış testi henüz yapılmadı.
- Runtime kurulu Unity Roslyn ve proje referanslarıyla hatasız derlendi
  (`/tmp/RecoveryCheck.rsp`). Bu sonuç Unity'de canlı test yerine geçmez.
- `art/revenant/audio_review_e_space_v1/`: E ve Space için ayrı preview,
  single ve cast-relative gather/impact WAV'ları, üretim scripti, README,
  hash/ölçümler. Her preview aynı adayı iki kez çalar. E .3833 s el teması,
  Space .8333 s ulti açılışı: noble importer marker'ları kullanıldı.
- Mevcut pençe C + özgün basınç/darbe katmanları, çok düşük CC0 organik
  doku. E kısa/tok; Space uzun hazırlık/daha pes gövde/geniş kuyruk.
  48 kHz stereo PCM16; E -4.5, Space -4 dBTP, mono kaybı <.04 dB.
- **E/Space onay bekliyor, oyuna eklenmedi.** Dinleme geri bildirimi sonrası
  ilerle. Commit/push yapılmadı. Aşağıdaki eski Q onay bekliyor notları tarihçe.

## Sonraki aşama — ölüm sonrası dönüş evi (seslerden SONRA)

Kullanıcı bu kapsamı açıkça istedi; henüz tasarım/üretim/entegrasyon yapılmadı:

1. Oyuncunun ölümden sonra döndüğü, odaları koridorlarla bağlı bir ev/sığınak.
   Odaların **tamamı önce ImageGen ile**, eşya ve dekor bakımından dolu dolu
   tasarlanacak. Bloodwake'in karanlık/gotik sanat dili korunacak.
2. Ayrı satıcı odası ve satıcı NPC; ayrı yetenek/güçlenme odası ve kadın NPC.
   Kadın karakter tur sonlarında oyuncuyu güçlendiren sistemi sunacak.
   İki NPC'nin 3D modelleri üretilecek ve evin ilgili odalarına yerleştirilecek.
   Tripo ücretli üretiminden önce skill gereği maliyet/dry-run ve açık onay.
3. Koridorların sonunda eğitim odası: tepki vermeyen/saldırmayan Warrior
   hedefi; hasar alır, çok uzaklaşınca merkezine döner, ölünce başlangıç
   yerinde yeniden doğar. Oyuncu yeni tura girmeden pratik yapabilir.
   Çok sayıda kırılabilir eşya; mevcut materyal renkli parçacık/tahta sesi
   sistemiyle birleştirilecek. Reset uzaklığı henüz seçilmedi.
4. Diyalog ekranı referansı:
   `/tmp/codex-clipboard-20913167-3623-4d2f-8a4e-bc7200678d5f.png`.
   Solda **hem oyuncunun hem konuşulan NPC'nin** ImageGen portreleri,
   sağda konuşmalar. Referansın açık/köy renkleri zorunlu değil, yerleşim
   Bloodwake estetiğine uyarlanacak. Portreler güzel/özenli illüstrasyon.
5. Sıra: ses adaylarını dinlet/onaylat → odaların görsel konseptleri →
   karakter görselleri/3D üretim → hub, NPC etkileşimi, eğitim ve diyalog UI.

## 16 Ekim — Q v3: sis geçişi + mevcut pençe (ONAY BEKLİYOR)

- Kullanıcı v2 varışını fazla cıvık buldu; düz kombo sonundaki pençe fikrini
  istedi. V2 departure seviyesi/zamanlaması korundu; varıştaki bütün
  splat/slurp/damlacık katmanları çıkarıldı. Mevcut polished
  `revenant_basic_attack_c.wav` orijinal pitch/hızda .58 gain ile eklendi.
- Runtime aslında A/B/C'yi her saldırıda rastgele seçiyor, sabit bir finisher
  sesi yok; bu ayrıntı kullanıcıya söylendi. V3'te C bilinçli aday olarak seçildi.
- `art/revenant/audio_review_q_v3/q_mist_claw_v3_preview.wav` aynı sesi iki kez
  çalar. Pençe başlangıcı .2031 s, en güçlü anı Q DAMAGE .4167 s.
  PCM16/48 kHz stereo, -4.25 dBTP; taşma yok, önceki departure korunma
  kontrolü geçti. Script, ölçümler ve provenance aynı klasörde.
- V3 dinleme onayı bekliyor; Unity ses bağlantıları hâlâ değiştirilmedi.

## 16 Ekim — Revenant Q ses denemesi v2 (ONAY BEKLİYOR)

- Kullanıcı Q/E/Space sesleri için sırayla dinleyip onaylayarak ilerlemeyi
  kabul etti; önce Q hazırlandı. Oyun ses bağlantıları değiştirilmedi.
- `art/revenant/audio_review_q_v2/q_bloodstep_v2_preview.wav`: aynı Q iki
  kez, 4.1 s toplam. Tek kullanım ve departure/arrival stem'leri aynı klasörde.
  Hide .250 s / damage .417 s marker'larına göre sıvı çekilmesi + geçiş +
  ıslak varış darbesi. 48 kHz stereo PCM16, -4 dBTP; mono uyumu ve decode
  doğrulandı. Dinleyerek kalite onayı kullanıcıdan bekleniyor.
- EZduzziteh / OpenGameArt Squish Sounds Effects CC0 kayıtları işlendi;
  kaynaklar, lisans bağlantısı, SHA-256 ve yeniden üretim scripti review
  klasöründe. Önceki reddedilmiş procedural Q/Space dosyaları değiştirilmedi.
- Bu yeni Q henüz Unity Resources'a kopyalanmadı. E ve Space yeni denemeleri
  henüz hazırlanmadı; Q geri bildiriminden sonra sırayla devam edilmeli.

## 16 Ekim — darbeden sonra yeniden yaklaşma beklemesi

- Kullanıcı geri itildikten sonra düşmanın yeniden yaklaşmasından önceki
  boşluğu biraz artırmak istedi. `PostImpactRecovery=.2f` eklendi:
  normal darbe toplam hareket kilidi .50 → .70 s, sıradan düşmanda alan
  darbesi .56 → .76 s. Bu sayaçlar vuruş anından başlar; geri itilme
  bittikten sonraki boşluk .20 s uzar. Hit animasyonunun oynatma süresi,
  geri itiş süresi/mesafesi ve flash değişmedi. Canlı sahne testi bekliyor.

## 16 Ekim — kırılabilir kasa/varil: kod hazır, canlı doğrulama BEKLİYOR

- Kullanıcı Gateyard ortasındaki tahta eşyaların yeteneklerle kırılmasını,
  kendi renginde parçalar saçmasını ve tahta kırılma sesi istedi.
  Eski sistem yalnız `godot/scripts/arena.gd` içindeydi; Unity'ye bağlı değildi.
- `BreakableCargo.cs`: EnvironmentDressing'in gerçek kasa/varil modellerine
  bağlandı; üst üste desteklenen iki kasa birlikte kırılır. Kaynak PBR materyal
  ve dokusunu paylaşan 16 tahta parçası savrulur, yerden seker; 4 s kalıp 5 s'de
  temizlenir. Oda başına 256 parça sınırı; parçalarda engel collider'ı yok.
- E 90° koni, Q/Space ve diğer alan hasarları, normal yakın saldırı ve
  oyuncu mermi sweep'i kırılmayı tetikler. Hasarsız mark ve düşman atışları
  bağlanmadı. Nesneler deneme için tek temasla kırılır; loot eklenmedi.
- İthal yığının geniş collision footprint'i yerine canlı parçaların bounds'u
  kullanılır. Kırılanların engeli anında kalkar; LateUpdate'te bir kez NavMesh
  yenilenir, mevcut düşman ajanları yeniden bağlanır. Bu eşleştirme ve canlı
  navigation testi henüz doğrulanmadı; testte özellikle kontrol edilir.
- `art/audio/build_wood_break.py` özgün procedural tahta snap/çıtırdama üretir;
  `Resources/audio/wood_break.wav` .82 s / mono 44.1 kHz. Üçüncü taraf ses
  kullanılmadı. Bu ilk ses denemesi, kullanıcı ses kalitesini onaylamadı.
- Oyun ve editör/test kaynakları Unity'nin kurulu Roslyn'i ve mevcut assembly
  referanslarıyla `/tmp/CargoCheck-Assembly-CSharp*.rsp` üzerinden hatasız
  derlendi. Unity editörü yeni dosyaları henüz import etmedi: ekran kilitli.
  Kilit ekranını aşmaya çalışılmadı; kullanıcıdan kilidi açması istendi.
- Devam: kilit açılınca editörde Refresh, yeni DLL zamanlarını doğrula,
  `Library/BloodwakeOpenPractice.request` içine `play` ve
  `Library/CargoBreakReview.request` içine `/tmp/bloodwake-cargo-break-v1`
  yaz. Test gerçek E animasyonu/teması, arka koni reddi, source materyal,
  ses, Q/Space/sweep, collider kaldırılması, agent bağlantısı ve parça
  temizlenmesini sınar; sonunda practice'i taze kasalarla yeniden açar.
  Bekleyen test isteği sürpriz çalışmaması için kaldırıldı. **Canlı test geçti
  veya sahne hazır denmedi.** Henüz push/commit yok.

## 16 Ekim — saldırı baskısı, çevresel spawn, hızlı dönüş ve beceri itişi

- Kullanıcının 11:15 videosu önceki mesafe testinin yetersizliğini gösterdi:
  yaklaşmış düşmanlar saldırmak yerine slot hizalıyor, boş saldırı noktası
  varken daha yakın dış bekleme noktası seçilebiliyordu. Aşağıdaki eski crowd
  testinin geçmesi bu davranışı doğrulamıyordu; bu bölüm onu geçersiz kılar.
- Warrior yaklaşma/yüzünü dönme/saldırı/toparlanma/kısa yeniden konumlanma
  niyetleri ayrıldı. Menzile gelince oyuncuya dönüp saldırmak öncelikli.
  Her iki saldırı arasında uygun boşluk varsa kısa 24° yan adım denenir.
  Yaklaşma çemberi 24 açıda aranır; boş iç nokta her zaman dış bekleme
  noktasından önceliklidir. Gövde ve rezervasyon mesafeleri korunur,
  tıkanmada kısa güvenli adım ve yerel yan yaklaşma kullanılır.
- Normal düşman dalgaları artık oyuncu etrafında 5.1–8.5 m mesafede,
  farklı açılarda, gövdeye/duvara girmeyen ve tam NavMesh yolu bulunan
  noktalarda doğar. Uygun nokta yoksa sonra yeniden denenir; uzak oda
  köşesine fallback yok. Boss'un özel doğma noktası korunur. F8 de aynı
  çevresel doğma seçicisini kullanır.
- Kullanıcının isteğiyle Warrior yönelme 240 → 320°/sn, 180° klip oynatma
  1 → 1.2x (0.9 → 0.75 s). Yürüyüş hızı/stride ve saldırı klipleri değişmedi.
  30/60/144/240/360 fps dönüş ve 30/60/144/360 fps açı taraması geçti;
  dönüş süresi, kaynak pelvis yönü, kesilme ve hedef değişimi de kontrol edildi.
- `EnemyCrowdReview` artık gerçek saldırı/temas sayısını ve yakın menzilde
  boş beklemeyi ölçer. `/tmp/bloodwake-crowd-pressure-v6`: üç aynı-konum
  spawn isteği ve iki hedef değişimiyle 38 s geçti; en küçük gövde merkez
  aralığı 1.326 m, temaslar 20/24/20. Son hedef değişiminden sonra her
  düşman tekrar saldırdı. Kayıt: `art/enemies/mixamo/warrior/review-20261016/crowd-pressure.mp4`
  (15 fps, teşhis kamerası). Önceki başarısız denemeler bu sonuçla değiştirilmiştir.
- Yeni çevresel spawn ile ayrı canlı test de geçti:
  `/tmp/bloodwake-crowd-pressure-v7-surround`, 38 s, minimum merkez aralığı
  1.325 m, temaslar 23/25/19. Hızlı dönüşün tam saldırı/marker/animasyon
  regresyonu `/tmp/bloodwake-warrior-turn-320` altında başarılı tamamlandı.
  Son test bitince practice tek Warrior / Revenant olarak geri yüklendi.
- Düşman flash'ı practice ölümsüzlüğünde de tetiklenir. İlk render karesinden
  önce sönmesini önlemek için pulse karesi korunur; düşman süresi .10 → .14 s,
  kuvvet .38 aynı. Oyuncu .12 / .09 s düşük ayarı korunur. Önce/sonra render
  ve emission property kontrolü geçti (`v6/flash-before.jpg`, `flash-hit.jpg`).
- Revenant E alan itişi 1.5x: normal düşmanda .48 → .72 m. Space 2.5x:
  1.20 m. Tank/boss dirençleri aynı oranda korunur. Normal saldırı, Q ve
  diğer sınıfların alan itişleri değişmedi; duvar/gövde çarpışması devam eder.
  Süreler/toparlanma aynı; yalnız mesafe büyütüldü. Mesafe parametre testi geçti.
- Bu değişiklikler yerel; henüz commit/push yok. Testler Gateyard odası ve
  üç Warrior ile sınırlı; bütün odalar/büyük sürüler için kapsam iddiası yok.

## 16 Ekim — kullanıcının seçtiği Warrior kılıç sesi (yerel deneme)

- Kullanıcı iki sentetik denemeyi reddetti ve Downloads içindeki
  `326868__johnbuhr__sword_clash-7.wav` dosyasını hem düşman hem oyuncu Warrior
  için denememizi istedi. `Resources/audio/warrior_sword_clash_user.wav` kaynakla
  SHA-256 birebir aynı: `0a096881ed57372237aa2d1b334565560fc5c3709887e54ac3220b3d8ac02166`.
  1.170068 s / 44.1 kHz mono; PCM import, kırpma/normalize/pitch değişimi yok.
  Mevcut ses havuzunun varsayılan -5 dB seviyesiyle çalar.
- Oyuncu Warrior'ın eski başlangıç sword_swing çağrısı kaldırıldı; yeni kayıt
  `MeleeContact` temas anında çalar (normal kombo ve heavy). Düşman grunt'ta
  Outward/Inward DAMAGE marker'ında bir kez çalar; marker iptal olursa ses de yok.
  Boş savurmada da çalar. Ortak flesh/player_hit ve diğer sınıf sesleri korunur.
- `WarriorSwordAudioReview` oyuncu temas gecikmesi, iki düşman klibi ve kesilmiş
  saldırıda ses iptalini geçti. Test animasyon geçişini gerçek küçük adımlarla
  örnekler. Practice tekrar tek Warrior / Revenant halinde açık.
- Bu kullanıcı tarafından sağlanan deneme kaydıdır; lisans bilgisi dosyayla
  verilmedi. Yayına çıkmadan lisans/attribution ayrıca doğrulanmalı.

## 16 Ekim — kalabalık hareketi ve darbe flash'ı (yerel, henüz push değil)

- `EnemyNavigation.cs`: kurulu Unity AI Navigation ile collision metadata/floor
  kaynaklarından oda bazlı runtime NavMesh oluşturulur. NavMeshAgent pozisyon
  ve rotasyonu doğrudan uygulamaz; mevcut animasyon kontrollü motor korunur.
  Çoklu düşmanda native desiredVelocity/kaçınma, Warrior'larda sabit tahsisli
  yaklaşma noktaları (6 iç nokta, doluysa dış bekleme halkaları) kullanılır.
  Tek düşman mevcut deterministik chase/yönelim yolunda kalır.
- Warrior gövde yarıçapı 0.65 m; MoveEnemy süpürülmüş disk kontrolüyle diğer
  yaşayan düşmanların içinden geçişi önler. Aynı spawn isteği boş yakın konuma
  yerleştirilir. Dönüş/recoil de bu kontrolü kullanır. Kilitli/sendeleyen/dönen
  aktörün ajanı durur; ölümde devre dışı, oda/menü/oyun kapanışında mesh temizlenir.
  Boss charge / Assassin teleport gibi özel beceri hareketleri yeniden tasarlanmadı.
- Onaylı yürüyüş ve saldırı animasyon asset'leri değiştirilmedi. Önceki checkpoint'in
  240°/sn yönelme düzeltmesi şimdi test edildi: +/-16 açı 30/60/144/360 fps,
  saldırı girişi ve dönüş sırasında hedef değişimi geçti. Önceki 180° dönüş,
  Outward/Inward sıra/marker/iptal testleri de geçti. Kayıt: /tmp/bloodwake-warrior-angles-20261016.
- `EnemyCrowdReview`: gerçek engine frame'lerinde üç aynı-konum spawn isteği,
  sabit/yan/arka hedef senaryosu toplam 38 s geçti. Son test minimum merkez
  mesafesi **1.325 m**; üçü de son hedefe 2 m içine ulaştı. 77 görüntü ve
  2 fps teşhis videosu `art/enemies/mixamo/warrior/review-20261016/`.
  Bu sınırlı Gateyard testi; bütün odalar veya çok büyük sürüler doğrulanmadı.
- Practice başlangıçta yine tek Warrior. **F8** tek/üç Warrior geçişidir;
  sonsuz can ve cooldown'sız yetenekler korunur. Test bitişi tek düşmana döner.
- `HitFlash.cs`: yalnız model renderer'larında actor-local materyal kopyaları
  ve property block; dokular/shared materyaller değiştirilmez. Düşman 0.38 / 0.10 s.
  Oyuncu ilk 0.85 / 0.14 s halini fazla parlak buldu; **0.12 / 0.09 s** oldu.
  Gerçek hasar/kaçınma/dokunulmazlık ve practice ölümsüzlük geri bildirimi testleri
  geçti. DoT her frame flash tetiklemez. Kullanıcının son düşük seviyeye onayı beklenir.
- Kullanıcı mevcut sword sesini açıkça reddetti; eklenen çağrı kaldırıldı,
  enemy Warrior'a eski ses bağlanmadı. `audio-review/build_sword_review.py`
  tamamen yeni procedural dry/weighted WAV denemeleri üretir; kullanıcıya sunuldu,
  Unity Resources dışında, **onaylanmadı ve oyuna eklenmedi**.
- İlk derlemedeki çift LateUpdate ve flash property-block başlangıç hatası
  düzeltildi; son derleme ve yukarıdaki testler başarılı. E VFX ayrı açık iş.

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
