# Bloodwake — senden istenen varlıklar (17–19 Ekim 2026)

Teslim edilenler listeden çıkarıldı (19 Ekim: ortam döngüleri, Tripo dekor, ses paketinin çoğu, alev jeti ve diğer VFX dokuları, ayak sesleri, Vesper yer alevi sheet'leri).

Kodda hepsinin yeri hazır: dosya doğru adla doğru klasöre girdiği anda oyun onu kullanır.
Eksik olan şey oyunda sessiz kalır ya da mevcut ortak sesi/modeli kullanmaya devam eder.

- **Ses ve müzik:** `unity/Assets/Bloodwake/Resources/audio/` (WAV ya da OGG, adı tablodaki gibi).
  Varyasyonlu olanlarda `_1`, `_2` … diye numaralandır. Yarısını üretsen de çalışır, olan varyasyonlar dönüşümlü çalar.
- **3D modeller:** Tripo'dan indirdiğin zip'leri `art/environment-incoming/<id>.zip` olarak bırak. İçe aktarmayı,
  ölçeklemeyi ve odalara dağıtmayı ben yapacağım.

Öncelik sırası: **1) düşman sesleri (+ ayak sesi varyasyonları) → 2) müzik varyasyonları → 3) Vesper'ın yeni hareket sesleri.**

---

## 000. YENİ — 19 Ekim akşam: Revenant L1+R2 tek el klibi (Mixamo)

Sanguine Siphon (L1+R2) şu an iki eliyle çırpan `REV_BloodClap` klibini kullanıyor; tek elle çekmesi için Revenant'ta
tek elli bir büyü klibi yok. Mixamo'da Revenant karakterini aç (`art/revenant-noble/source-20261015/` ile aynı rig) ve indir:
**FBX Binary, Without Skin, 60 fps, In Place kapalı.** `art/revenant-noble/siphon-20261019/` içine koy; aktarmayı ben yaparım.

| Dosya adı | Mixamo'da ara | Ne için |
|---|---|---|
| `siphon.fbx` | "Standing 1H Magic Attack 01" (yoksa "Standing 1H Cast Spell 01") | Tek kol öne uzanmış, kanı çekerken tutulan poz |

### Boss saldırı kükremeleri — ElevenLabs Sound Effects

Şu an `boss_grunt_2..4`, senin `boss_grunt` sesinden ffmpeg ile türettiğim varyasyonlar (derin, kısa/sert, çift katman).
Gerçek alternatif istersen aynı adlarla üret, benimkilerin üzerine yaz; kod dördünü dönüşümlü çalar.

| Dosya | Süre | Prompt |
|---|---|---|
| `boss_grunt_2` | 1.6 sn | Huge armored undead knight roaring with effort before a ground slam, deep guttural chest roar, metal armor rattle, dry, no music |
| `boss_grunt_3` | 1.0 sn | Short savage bark of a giant monstrous warrior lunging forward, harsh throat growl cut off abruptly, dry, no music |
| `boss_grunt_4` | 2.0 sn | Bestial cursed giant bellowing a summoning call, layered deep growl and raspy scream, distant bell resonance underneath, dry, no music |

---

## 00. YENİ — 19 Ekim: ses paketi (ElevenLabs Sound Effects)

Hepsi `unity/Assets/Bloodwake/Resources/audio/` içine, **adı tam olarak tablodaki gibi** (WAV ya da OGG, `_1` ekleme).
Kodda hepsi bağlı: dosya girdiği anda çalar. "Darbe anı", sesin zirve yapması gereken saniye; o zamanlamayla üret.
Gerçekçi, kuru (az yankı), oyun içi SFX, müzik yok.

| Dosya | Ne zaman | Süre | Darbe anı | Prompt |
|---|---|---|---|---|
| `vesper_falling_star` | R1 R1 R2 | 1.4 sn | 0.62 | A leap with a spinning blade whoosh, then a greatsword slammed into stone with a huge fiery explosion and falling rubble |

Önceki listeden hâlâ bekleyenler: `boss_roar_1..3` (giriş ekranı), `boss_hurt_1..4` ve düşman sesleri (bölüm 1).

---

## 0. YENİ — 18 Ekim gece işinden çıkanlar (önce bunlar)

Sıra: **A) boss animasyonları → C) yeni hareket sesleri.** (B, VFX dokuları, 19 Ekim'de geldi ve bağlandı.)

### A. Boss animasyonları — Mixamo (en önemlisi)

Boss şu an tek koşu klibiyle yürüyor (adımlarını kodla zemine oturttum, ama gerçek bir yürüyüş/ağır saldırı seti yok).
Mixamo'da boss karakterini aç (gerekirse `art/enemies/mixamo_upload/boss_mixamo.zip`'i yeniden yükle) ve şunları indir:
**FBX Binary, Without Skin, 30 fps, Keyframe Reduction: none.** Yürüyüş ve dönüşte **In Place açık**, saldırılarda kapalı.
Dosyaları `art/enemies/mixamo/boss/new/` içine aşağıdaki adlarla koy; Unity'ye aktarmayı ben yaparım.

| Dosya adı | Mixamo'da ara | Ne için |
|---|---|---|
| `boss_walk.fbx` | "Great Sword Walk" (In Place) | Yavaş, ağır yaklaşma (koşu yerine çoğu zaman bu) |
| `boss_turn.fbx` | "Great Sword 180 Turn" (In Place) | Arkasına geçince dönme |
| `boss_slash_combo.fbx` | "Great Sword Slash" (birden fazla varsa ikisini de: `_2`) | Amansız kombo saldırısı |
| `boss_jump_attack.fbx` | "Great Sword Jump Attack" | Uzaktan üstüne atlama |
| `boss_kick.fbx` | "Great Sword Kick" | Çok yakındayken itme |
| `boss_taunt.fbx` | "Standing Taunt Battlecry" ya da "Mutant Roaring" | Boss giriş ekranındaki kükreme |

### C. Yeni hareket sesleri — ElevenLabs Sound Effects

Hepsi tek dosya, **adı tam olarak tablodaki gibi** (`_1` ekleme). Gelene kadar ortak sesler çalıyor.

| Dosya | Hareket | Süre | Prompt |
|---|---|---|---|
| `mage_force_ring` | Mage R2 90° halka | 0.9 sn | A deep magical force wave released in a sweep, low thump then a rushing violet energy whoosh spreading outward |
| `mage_ice_shards` | Mage 3. R1 buz kırıkları | 1.0 sn | Rows of ice crystals bursting up out of stone in quick succession, sharp cracking and shattering, cold glassy chimes |
| `mage_ice_comet` | Mage R1 R1 R2 | 1.6 sn | A huge boulder of ice whistling down from the sky and smashing into the ground, deep impact, explosion of shattering ice |
| `mage_grip` | Mage L1+R1 yakala-fırlat | 1.0 sn | A crackling magical tether snapping onto a body and yanking it, electric hum, then a heavy whoosh as it is hurled |
| `mage_glide` | Mage kare (süzülme) | 0.5 sn | A soft magical levitation whoosh, airy shimmer, quick glide through the air |
| `warlock_attack` | Warlock 5'li yay atışı | 0.7 sn | A sinister sorcerer casting a fan of bolts, raspy whispered syllables without words, five quick hissing magic shots |
| `warlock_bind_cast` | Warlock mühür çizimi | 1.0 sn | Eerie occult chanting without words and a rising ghostly hum as a rune circle draws itself on the ground |
| `warlock_bind_snap` | Mühür kapanınca | 0.6 sn | Spectral chains snapping taut around a body, metallic clank and an echoing magical lock |
| `revenant_rend` | Revenant R2 Crimson Rend | 0.8 sn | Two vicious claw slashes tearing flesh in an X, wet ripping and a spray of blood |
| `revenant_hemorrhage` | Revenant R1 R1 R2 | 1.0 sn | A sharp hand clap followed by several wet blood bursts popping around the listener |
| `revenant_blood_lance` | Revenant L1+R1 | 0.7 sn | A spear of liquid blood launched with a sharp whoosh and a wet piercing impact |
| `revenant_siphon` | Revenant L1+R2 | 1.2 sn | A dark draining hum with wet blood being pulled through the air in streams, heartbeat underneath |

---

## 1. Ses efektleri — ElevenLabs Sound Effects

Ortak kural: gerçekçi, kuru (fazla yankısız), oyun içi kısa SFX. Müzik yok. "Prompt influence" yüksek, süreyi elle ayarla.

### Ayak sesleri

Her birinden **1 tane geldi** (`_1`), oyunda çalıyor. Aynı adım her seferinde tekrar etmesin diye `_2`, `_3` … varyasyonları ekleyebilirsin.
**Dikkat:** dosya adı `player_step_2.wav` gibi tek numara olmalı; `player_step_1..6.wav` adını oyun bulamaz.

| Dosyalar | Ne zaman | Süre | Prompt |
|---|---|---|---|
| `player_step_1..6` | Oyuncu koşarken her adım | 0.3 sn | Single footstep of a heavy armored boot on wet cobblestone, running pace, leather creak and a faint metal clink, close and dry, one step only |
| `player_step_walk_1..6` | Revenant yürürken | 0.4 sn | Single slow footstep of a leather boot on wet cobblestone, quiet and deliberate, slight splash, one step only |
| `armored_step_1..6` | Zırhlı düşmanlar (grunt, tank) | 0.35 sn | Single footstep of a soldier in full plate armor on stone, heavy boot thud with rattling plates, one step only |
| `enemy_step_1..6` | Hafif düşmanlar (okçu, büyücü, suikastçı) | 0.3 sn | Single light footstep of a cloth and leather clad figure on stone, soft scuff, one step only |
| `boss_step_1..4` | Boss | 0.8 sn | Single colossal footstep of a giant armored creature on stone, deep ground thud with debris and chain rattle, one step only |

### Düşman sesleri

Her düşman tipi için 3 dosya ailesi: `<tip>_attack_1..3` (saldırıya başlarken), `<tip>_hurt_1..4` (vurulunca), `<tip>_death_1..3` (ölünce).
Tipler: `grunt`, `archer`, `tank`, `assassin`, `mage`, `healer`, `commander`, ayrıca `boss_roar_1..3` ve `boss_hurt_1..4`.

| Aile | Süre | Prompt |
|---|---|---|
| `grunt_attack` | 0.6 sn | Undead soldier's guttural war grunt as he swings a sword, hoarse and raspy, armor clank, no words |
| `grunt_hurt` | 0.4 sn | Undead soldier hit by a blade, short pained hoarse groan, armor rattle, no words |
| `grunt_death` | 1.2 sn | Undead soldier dying, choking rasp fading out, armored body collapsing onto stone |
| `archer_attack` | 0.6 sn | Bow drawn and released, creak of the string then a sharp twang and arrow whoosh |
| `archer_hurt` | 0.4 sn | Lean hooded archer struck, sharp pained hiss, leather rustle, no words |
| `archer_death` | 1.0 sn | Hooded archer dying with a breathy gasp, bow clattering onto stone |
| `tank_attack` | 0.8 sn | Huge armored brute heaving a massive weapon, deep strained roar, heavy plate grind, no words |
| `tank_hurt` | 0.5 sn | Huge armored brute hit, deep bellowing grunt, plates clanging |
| `tank_death` | 1.6 sn | Huge armored brute collapsing, long dying groan, enormous metal crash on stone |
| `assassin_attack` | 0.4 sn | Quick dagger lunge, sharp exhale and fast cloth whoosh, no words |
| `assassin_hurt` | 0.3 sn | Agile cloaked killer struck, short sharp hiss of pain |
| `assassin_death` | 0.9 sn | Cloaked killer dying, faint gasp, daggers dropping on stone |
| `mage_attack` | 0.8 sn | Dark sorcerer casting, raspy whispered incantation without real words, rising magical hum |
| `mage_hurt` | 0.4 sn | Robed dark sorcerer struck, strained hiss, robes flapping |
| `mage_death` | 1.4 sn | Dark sorcerer dying, distorted fading whisper and a magical energy dissipating |
| `healer_attack` | 0.8 sn | Corrupted priestess chanting a short wordless hymn, eerie choral hum |
| `healer_hurt` | 0.4 sn | Corrupted priestess struck, short pained cry, no words |
| `healer_death` | 1.2 sn | Corrupted priestess dying, mournful fading wail |
| `commander_attack` | 0.8 sn | Undead knight commander bellowing a war cry with no words, metallic echoing voice |
| `commander_hurt` | 0.4 sn | Undead knight commander struck, angry metallic grunt |
| `commander_death` | 1.6 sn | Undead knight commander dying, long metallic groan, heavy armor falling |
| `boss_roar` | 2.0 sn | Colossal bell-bound demon roaring, deep layered monstrous roar with a cracked church bell ringing inside it |
| `boss_hurt` | 0.6 sn | Colossal demon struck, deep furious grunt with metallic resonance |

### Vesper'ın yeni hareketleri

Şu an ortak Vesper seslerini kullanıyorlar; bunlar gelince kendilerininkini kullanacaklar. "Darbe anı" sesin zirve yapması gereken an.

| Dosya | Hareket | Süre | Darbe anı | Prompt |
|---|---|---|---|---|
| `vesper_rising_crescent` | Dash → R1: kayarak yükselen kesik, ileri giden alev yarım ayı | 1.0 sn | 0.32 sn | Greatsword dragged scraping over stone then ripped upward, a roaring crescent of fire launched forward and rushing away, sparks |
| `vesper_heavy_cleave` | R2: ağır iki elli kesik | 1.0 sn | 0.45 sn | Slow heavy two-handed greatsword cleave, deep powerful whoosh, flame roaring along the blade, armor strain |
| `vesper_crescent_fan` | R2 R2: yere yatay alev yarım ayı | 1.2 sn | 0.45 sn | Wide horizontal greatsword sweep releasing a flat wave of fire that roars outward, crackling flames spreading |
| `vesper_falling_star` | R1 R1 R2: zıplayıp dönerek yere saplama | 1.4 sn | 0.62 sn | Leap with a spinning blade whoosh, then a greatsword slammed into stone with a huge fiery explosion and rubble |
| `vesper_blade_throw` | L1+R1: kılıcı fırlatma | 0.9 sn | 0.18 sn | Greatsword hurled spinning through the air, rhythmic whirring blade with a burning flame trail |
| `vesper_blade_catch` | Kılıç ele dönünce | 0.4 sn | 0.02 sn | Heavy greatsword slapping back into an armored gauntlet, metal clank and a flame flare |

---

## 2. Müzik

ElevenLabs Music ya da benzeri. Her parça **döngüye uygun** olmalı (sonu başına bağlanır), 2–3 dakika, OGG.
Ortak üslup: karanlık gotik orkestra, düşük yaylılar, erkek koro (sözsüz), kilise çanı, savaş davulları; Bloodborne / Diablo atmosferi.

| Dosya | Nerede | Prompt |
|---|---|---|
| `music_combat_2.ogg` | Savaş odaları (mevcut `music_combat` ile dönüşümlü) | Dark gothic orchestral combat loop, 140 BPM, driving taiko and timpani, staccato low strings, ominous wordless male choir, cracked church bells, relentless and tense, seamless loop |
| `music_combat_3.ogg` | Savaş odaları | Dark gothic battle loop, 128 BPM, distorted cello ostinato, heavy war drums, eerie female vocalise, rising dread, seamless loop |
| `music_combat_4.ogg` | Savaş odaları | Grim medieval action loop, 150 BPM, hurdy-gurdy and low brass, pounding drums, chanting monks, frantic and bloody, seamless loop |
| `music_explore.ogg` | Oda temizlendikten sonra | Quiet haunting ambient loop, 70 BPM, solo cello and distant bells, soft drones, sorrowful calm after battle, seamless loop |
| `music_safehouse.ogg` | Sığınak | Melancholic sanctuary theme, warm candlelit mood, harp and low strings, soft wordless choir, hopeful but sad, seamless loop |
| `music_market.ogg` | Satıcı | Eerie night market theme, slow lute and dulcimer, creaky and mysterious, seamless loop |
| `music_boss_2.ogg` | Boss (mevcutla dönüşümlü) | Epic gothic boss battle loop, 160 BPM, massive organ and full choir, colossal bell hits, brutal percussion, seamless loop |

---

## 3. İsteğe bağlı: Vesper animasyonları (Mixamo)

Yeni hareketler şu an mevcut kliplerle ve kodla kurulu hareketle çalışıyor:
- Falling Star = havaya sıçrayıp dönme + Ultimate'ın yere saplanma karesi.
- Tethered Blade = kılıcın gerçekten uçup dönmesi.

Daha doğal dursun istersen Mixamo'dan şunları **Without Skin, 60 fps, In Place kapalı** indirip `art/agile_warrior/source/animations/` içine aynı adla koy, Blender hattına ben eklerim:

| Dosya adı | Mixamo'da ara |
|---|---|
| `HeavyCleave.fbx` | "Great Sword Slash" (yavaş, iki elli) |
| `FallingStar.fbx` | "Great Sword Jump Attack" |
| `CrescentFan.fbx` | "Great Sword High Spin Attack" |
| `BladeThrow.fbx` | "Throw" ya da "Great Sword Kick" |

## 4. YENİ — 23 Ekim: ikinci harita, THE HOLLOW KEEP (kale içi)

Kale haritası şu an oynanabilir durumda ama geçici malzemeyle: duvarlar, sütunlar ve mobilya kutu geometri ile oda dokularından kuruldu (`Runtime/KeepInterior.cs`). Düşmanlar kasaba düşmanlarının soluk, soğuk tonlu "hayalet garnizon" versiyonları; sesler, kendi dosyaları gelene kadar kasabanınkileri çalıyor. Aşağıdakiler geldikçe yerine oturtulacak, kod hazır.

### Ses (ElevenLabs) → `unity/Assets/Bloodwake/Resources/audio/`
| Dosya | İstek |
|---|---|
| `amb_keep_halls_1.wav` | Taş koridorlarda boğuk rüzgâr uğultusu, uzakta zincir şıngırtısı ve yankılanan damla sesi, 60 sn döngü |
| `amb_keep_throne_1.wav` | Geniş boş taş salon, derin yankı, alçak organ benzeri drone, 60 sn döngü |
| `amb_undercroft_1.wav` | Mahzen: su damlası, uzak fısıltı, mum çıtırtısı, 45 sn döngü |
| `music_keep.wav` | Karanlık gotik savaş müziği, kasabadakinden daha soğuk: koro, çan, gergin yaylılar, döngü |
| `music_keep_boss.wav` | Kale bossu: ağır davul, organ, koro, döngü |
| `music_undercroft.wav` | Sakin ama tedirgin tüccar müziği, tek çello ve harp, döngü |

### 3D — kale kiti (Tripo, 4K PBR, FBX) → `art/environment-incoming/<id>.zip`

**27 Ekim güncellemesi.** Kale şu an kutu geometri. Kasabayla arasındaki kalite farkını kapatmak için aşağıdaki parçalar lazım.
Kasaba eşyalarında yaptığın gibi: önce konsept görseli üret (tek obje, düz gri arka plan, 3/4 açı, sahne yok), sonra Tripo'da 4K PBR FBX al, zip'i `<id>.zip` adıyla bırak.
İçe aktarma, ölçek ve odalara yerleştirme benden.

**Ölçüler önemli:** kale 1 m'lik ızgaraya kurulu. Duvar parçaları birbirine eklenerek dizilecek, o yüzden **yan kenarları düz ve kesik** olmalı (köşe süsü, kule, uçta kemer yok). Arka yüzü görünmüyor, düz olabilir.

Tüm konsept görsellerine şu stil cümlesini ekle:
`dark gothic medieval castle interior, weathered cold grey ashlar stone, iron fittings, dark fantasy ARPG asset, single object, plain grey background, 3/4 view, PBR`

#### Öncelik 1 — yapı (en büyük fark bunlardan gelir)
| id | Ölçü (G×Y×D) | Konsept isteği |
|---|---|---|
| `keep_wall` | 2 × 4.5 × 0.7 m | Straight castle interior wall section, large cut ashlar blocks, moulded stone plinth at the base, plain flat cut sides so sections tile side by side |
| `keep_wall_window` | 2 × 4.5 × 0.7 m | Same wall section with one tall narrow pointed-arch window opening in the middle, deep stone reveal, no glass |
| `keep_parapet` | 2 × 1.6 × 0.7 m | Low crenellated stone parapet wall section, two merlons on top, worn edges, flat cut sides to tile |
| `keep_pillar` | 1 × 4.5 × 1 m | Gothic stone column, square base, octagonal shaft, carved capital |
| `keep_pilaster` | 0.8 × 4.5 × 0.4 m | Half-column pilaster to stand against a wall, base and capital, flat back |
| `keep_arch_door` | 5 × 5 × 1 m | Pointed stone archway doorframe, heavy voussoirs, empty opening (gate sits inside) |
| `keep_portcullis` | 4.5 × 4 × 0.2 m | Iron portcullis grid, spiked bottom, rusty |

#### Öncelik 2 — odalara kimlik veren eşyalar
| id | Ölçü | Konsept isteği | Oda |
|---|---|---|---|
| `keep_throne` | 2 × 3.5 × 1.5 m | Tall-backed iron and stone throne, spikes on the back, cracked | Taht |
| `keep_altar` | 3 × 1.2 × 1.4 m | Stone altar block with carved front panel, cloth runner | Şapel |
| `keep_pew` | 2.2 × 1.1 × 0.6 m | Old wooden church pew, high back | Şapel |
| `keep_candelabrum` | 0.6 × 2 × 0.6 m | Tall standing iron candelabrum, three candles, melted wax | Şapel, taht |
| `keep_chandelier` | 2 × 1 × 2 m | Iron ring chandelier with candles, hanging chains | Salon |
| `keep_long_table` | 1.6 × 0.9 × 6 m | Long rough feast table, heavy legs, plates and goblets on it | Salon |
| `keep_chair` | 0.5 × 1.1 × 0.5 m | Heavy wooden high-back chair | Salon |
| `keep_armor_stand` | 0.8 × 2 × 0.6 m | Full suit of dark plate armour on a wooden stand, helm, halberd beside | Cephanelik, taht |
| `keep_training_dummy` | 1.2 × 1.9 × 0.5 m | Straw-stuffed sack training dummy on a post, cross arm | Cephanelik |
| `keep_anvil` | 1.2 × 0.9 × 0.6 m | Blacksmith anvil on a tree stump, hammer on it | Cephanelik |
| `keep_cell_bars` | 2.4 × 2.6 × 0.2 m | Iron prison cell bars with a barred door | Zindan |
| `keep_torture_rack` | 2.4 × 1 × 1 m | Medieval wooden torture rack with rollers and chains | Zindan |
| `keep_stocks` | 1.8 × 1.2 × 0.4 m | Wooden pillory stocks, three holes | Zindan |
| `keep_torch_sconce` | 0.3 × 0.7 × 0.4 m | Iron wall bracket holding an unlit torch (alevi ben eklerim) | Her oda |
| `keep_banner` | 1 × 3 × 0.1 m | Long torn dark red hanging banner on an iron rod, faded crest | Her oda |
| `keep_fallen_column` | 3.5 × 1 × 1 m | Broken gothic column lying on its side in drums, rubble | Şapel, taht |

#### Öncelik 3 — zemin ve duvar dokusu
Tripo değil, dokular: kale zemini ve duvarı için tekrarlanabilir (tileable) 4K PBR set.
Albedo, normal ve roughness gerekli, mümkünse AO da.
- `keep_floor`: büyük aşınmış taş döşeme
- `keep_ashlar`: soğuk gri kesme taş duvar

Ücretsiz CC0 kaynaklar (ambientCG, Poly Haven) yeterli; istersen ben indiririm, onay vermen yeterli.

### Düşman modelleri (Tripo + Mixamo, isteğe bağlı)
Şimdilik var olan modellerin renklendirilmiş halleri kullanılıyor. Kendine özgü görünsün istersen: Hollow Halberdier (teberli zırhlı iskelet muhafız), Hollow Knight (ağır plaka zırhlı şövalye), Garrison Crossbow, Watch Wraith (yarı saydam hayalet), Black Chaplain (cüppeli rahip), ve boss Ser Caldren (kırık taçlı dev şövalye).
