# Bloodwake — senden istenen varlıklar (17–18 Ekim 2026)

Kodda hepsinin yeri hazır: dosya doğru adla doğru klasöre girdiği anda oyun onu kullanır.
Eksik olan şey oyunda sessiz kalır ya da mevcut ortak sesi/modeli kullanmaya devam eder.

- **Ses ve müzik:** `unity/Assets/Bloodwake/Resources/audio/` (WAV ya da OGG, adı tablodaki gibi).
  Varyasyonlu olanlarda `_1`, `_2` … diye numaralandır. Yarısını üretsen de çalışır, olan varyasyonlar dönüşümlü çalar.
- **3D modeller:** Tripo'dan indirdiğin zip'leri `art/environment-incoming/<id>.zip` olarak bırak. İçe aktarmayı,
  ölçeklemeyi ve odalara dağıtmayı ben yapacağım.

Öncelik sırası: **1) ayak sesleri ve düşman sesleri → 2) ortam döngüleri → 3) 3D dekor → 4) müzik varyasyonları → 5) Vesper'ın yeni hareket sesleri.**

---

## 0. YENİ — 18 Ekim gece işinden çıkanlar (önce bunlar)

Sıra: **A) boss animasyonları → B) VFX dokuları → C) yeni hareket sesleri.**

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

### B. VFX dokuları — görsel üretici (Midjourney / DALL·E / benzeri)

Hepsi **siyah arka plan üzerinde** (ben alfa'ya çeviririm), kare, **2048×2048** PNG. Sprite sheet'lerde kareler eşit ızgara olsun, kare numarasını yazma.
`art/vfx-incoming/` içine aşağıdaki adlarla bırak.

| Dosya | Nerede kullanılacak | Prompt |
|---|---|---|
| `blood_slash_sheet.png` | Revenant pençe izleri, Crimson Rend | 4x4 sprite sheet of a single curved claw slash streak animating from thin to full to dissolving, deep arterial crimson with a hot pink-white core, wet glossy blood droplets breaking off the edge, pure black background, game VFX flipbook, no text |
| `blood_splatter_decals.png` | Yere düşen kan lekeleri | 2x2 grid of four different top-down blood splatter stains on pure black, dark crimson to near-black, sharp droplet spray edges, realistic, game decal texture, no text |
| `blood_mist_sheet.png` | Kan sisi, dash, Siphon | 4x4 sprite sheet of a puff of crimson blood mist expanding and fading, soft volumetric, dark red with brighter core, pure black background, game VFX flipbook |
| `arcane_energy_noise.png` | Mage halkası (R2), tether, glide izi | Seamless tileable turbulent arcane energy noise, wispy violet and indigo filaments, grayscale-friendly high contrast, pure black background, game shader texture |
| `rune_circle.png` | Warlock ve düşman büyücü mühürleri | A single ornate occult rune circle seen from directly above, thin glowing white lines, concentric rings with angular runes between them, symmetrical, pure black background, game decal |
| `chain_link_strip.png` | Warlock'un hapseden zincirleri | Seamless horizontal strip of glowing spectral iron chain links, teal-white glow, side view, pure black background, tileable game VFX texture |
| `frost_ground_decal.png` | Buz kuyruklu yıldız, buz kırıkları | Top-down frost and ice crystal bloom on stone seen from above, radial cracks of pale blue ice, white hoarfrost edges, pure black background, game decal |
| `fire_jet_sheet.png` | Vesper alev püskürtme (L1+R2) | 4x4 sprite sheet of a horizontal jet of roaring fire streaming left to right, bright yellow-white core, orange and deep red edges, curling smoke tips, pure black background, game VFX flipbook |

### C. Yeni hareket sesleri — ElevenLabs Sound Effects

Hepsi tek dosya, **adı tam olarak tablodaki gibi** (`_1` ekleme). Gelene kadar ortak sesler çalıyor.

| Dosya | Hareket | Süre | Prompt |
|---|---|---|---|
| `vesper_flame_breath` | Vesper L1+R2 alev püskürtme | 1.2 sn | A roaring jet of fire blasting out of a hand like a flamethrower, steady whooshing burn with crackles, ends with a fiery puff |
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

### Ayak sesleri (en büyük eksik)

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

## 2. Ortam döngüleri — ElevenLabs Sound Effects (Loop açık, 30 sn)

| Dosya | Nerede | Prompt |
|---|---|---|
| `amb_town_night` | Şehir savaş odaları | Seamless loop, cursed medieval town at night, cold wind through narrow streets, distant tolling bell, faint crows, far-off moans, dripping water, no music |
| `amb_sanctuary` | Sığınak | Seamless loop, quiet candlelit stone hall at night, soft hearth crackle, distant wind outside thick walls, occasional creak of wood, no music |
| `amb_boss_square` | Boss meydanı | Seamless loop, ominous open square before a great bell tower, low rumbling wind, deep resonant bell drones, distant thunder, no music |
| `amb_market_night` | Satıcı odası | Seamless loop, abandoned night market, flapping canvas awnings, creaking signs, light wind, a lone lantern buzzing, no music |
| `amb_fire_crackle` | Her mangal/fener kendi yerinde | Seamless loop, close burning brazier, steady crackling wood fire with occasional pops, no wind, no music |

---

## 3. 3D dekor — Tripo

Ortak ayarlar: **low poly (en fazla 5.000 üçgen)**, PBR doku (2048), tek parça obje, tabanı yerde ve ortalanmış.
Stil: karanlık gotik ortaçağ, ıslak taş ve eski ahşap, oyunun mevcut sandık/varil modelleriyle aynı dünya.
Her prompt'un sonuna şunu ekle: `, dark gothic medieval, weathered and grimy, game-ready low poly, PBR, isolated on plain background`

| Zip adı | Boyut (m) | Prompt |
|---|---|---|
| `cart.zip` | 2.3 × 1.4 × 1.3 | Abandoned wooden hand cart with two spoked wheels, broken plank, a torn sack inside |
| `sacks.zip` | 1.1 × 0.75 × 0.9 | Pile of three burlap grain sacks slumped against each other, one split open with spilled grain |
| `hay_bale.zip` | 1.2 × 0.8 × 0.8 | Rectangular bound hay bale, loose straw sticking out, twine bindings |
| `weapon_rack.zip` | 1.5 × 1.7 × 0.5 | Wooden weapon rack against a wall holding rusty spears, a halberd and a dented shield |
| `rubble.zip` | 1.7 × 0.55 × 1.4 | Low pile of broken masonry, cracked stone blocks and timber splinters |
| `coffin.zip` | 2.0 × 0.65 × 0.75 | Plain wooden coffin with a slightly ajar lid, iron nails, dried blood stain |
| `cage.zip` | 1.0 × 1.9 × 1.0 | Tall iron gibbet cage hanging-style standing on the ground, rusted bars, open door |
| `shrine_statue.zip` | 1.2 × 2.6 × 1.2 | Weathered stone statue of a hooded saint on a plinth, face eroded, candles melted at its feet |
| `candles.zip` | 0.6 × 0.45 × 0.6 | Cluster of melted church candles of different heights on the ground, thick wax drips |
| `bones.zip` | 1.0 × 0.25 × 0.8 | Scattered human bones and a skull lying on the ground |
| `banner_pole.zip` | 0.5 × 3.2 × 0.5 | Tall iron pole with a torn crimson banner bearing a bell sigil, frayed edges |
| `firewood.zip` | 1.3 × 0.7 × 0.8 | Stack of split firewood logs with an axe stuck in a chopping block beside it |

Not: kenar dekoru bu kimlikleri zaten arıyor. Model gelince odalara kendiliğinden dağılacak.

---

## 4. Müzik

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

## 5. İsteğe bağlı: Vesper animasyonları (Mixamo)

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
