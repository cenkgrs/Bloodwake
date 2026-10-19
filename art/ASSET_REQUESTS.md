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
