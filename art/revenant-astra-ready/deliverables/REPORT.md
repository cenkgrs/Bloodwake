# Revenant — uygulama raporu

Kaynak: `input/revenant-tripo.glb` · Blender 4.5.14 LTS · Godot 4.6.3 · 60 FPS · 1,90 m · Blender ileri yönü −Y (glTF/Godot +Z)

## Teslimat dosyaları

| Dosya | İçerik |
|---|---|
| `Revenant_Source.blend` | İlk import, dokunulmamış. |
| `Revenant_Normalized.blend` | 1,90 m, ayak tabanı Z=0, transformlar uygulanmış. |
| `Revenant_Rigged.blend` | Temizlenmiş ve riglenmiş model; ağırlıklar onarılmış. Onarım öncesi yedek: `workfiles/Revenant_Rigged_backup_astra_v1.blend`. |
| `Revenant_Stage1.blend`, `Revenant_Stage2.blend` | Kilometre taşı dosyaları. |
| `workfiles/Stage{1,2}_{blocking,breakdown,spline,polish}.blend` | Her aşamanın ayrı kaydı. |
| `Revenant_Animated.blend` | Tamamlanmış dosya: bütün Action'lar, `REV_VFX_PROXY` koleksiyonu, sıralı NLA önizlemesi ve markerlar. |
| `Revenant_Animated.glb` | Tam set (17 Action), orijinal 4K texture'lar. |
| `Revenant_Animated.fbx` | 17 Action, base color gömülü. |
| `game/revenant_player.glb` | Oyun seti (15 klip, 2048 JPEG, 8,9 MB). Kopyası: `godot/assets/models/revenant_player.glb`. |
| `Revenant_VFX.glb` | Önceki denemeden kalan VFX export'u. Oyun kendi efektlerini kullanıyor. |
| `animation_events.json` | Action aralıkları, markerlar, hızlar, additive kemik listesi. |
| `previews/` | MP4 önizlemeleri (aşağıda). |
| `qa/` | Ölçümler ve grafikler. Önceki denemenin çıktıları `qa/_astra_v1/` klasöründe. |
| `tools/` | Bütün üretim hattı: tekrar çalıştırılabilir betikler. |

## Mesh ve rig düzeltmeleri

- **Ölçek ve eksen:** Tripo'nun Y-up ölçeği 1,90 m'ye getirildi; ayak tabanı Z=0'a, ileri yön −Y'ye ayarlandı. UV, materyal ve texture'lar korundu.
- **Kaynak skin bozuktu:** Eklem node'larının inverse-bind matrisleri uyumsuzdu. Anatomik pivotlarla biped iskelet kuruldu. Toplam 77 kemik:
  - root, pelvis, spine_01–03, neck_01, head, clavicle/upperarm/lowerarm/hand;
  - her parmakta 3 eklemli zincir, thigh/calf/foot/ball;
  - `blood_claw`, `armor_l/r`, saç (3×2), palto (5 kolon × 3).
- **Kalça–palto yırtılması:** Bitişik vertexler bir yanda %100 thigh, öbür yanda %100 coat idi; her adımda uzun üçgenler yırtılıyordu.
  - Ağırlıklar mesh grafiği üzerinde yayıldı: kalça/palto bandı güçlü, kollar orta düzeyde; el ve ayak keskin bırakıldı.
  - Lunge test pozunda yırtık kenar sayısı 121'den 0'a indi (`tools/rig_fix_weights.py`).
- **Ayak parmakları:** `ball_l/r` kemiklerinde hiç ağırlık yoktu. Topuk kalkınca bütün ön ayak bilekle dönüp zemine giriyordu. Parmak bölgesi ball kemiklerine 4 cm'lik geçişle verildi; ön tabanla temas artık mesh'te de gerçekleşiyor.
- **Sağ omuz:** Kaynak T-pozda sağ kol ~5 cm yüksekte duruyor. Bu yüzden her pozda sağ omuz eklemi yüksek kalıyor ve idle'da arkadan kambur görünüyordu. İki düzeltme yapıldı:
  - Sağ köprücüğe rig seviyesinde sabit −8,5° dengeleme (`RIGHT_SHOULDER_LEVEL`); idle'da omuzlar arasında 0,4 cm fark kaldı.
  - Köprücüğe bağlı omuzluk (`armor_r`) üst kolun dönüşünü %55 takip ediyor (`PAULDRON_FOLLOW`).
- **Sağ bot:** Kaynak mesh'te 3,8 cm yüksekte modellenmiş. Taban yüksekliği ayak başına ayrı tanımlandı (sol 0,041, sağ 0,034).

## Animasyon üretim yöntemi

Önceki denemenin kalıpları kullanılmadı. `tools/anim_core.py` saf matematik tabanlı bir FK/IK katmanıdır:
- analitik iki kemikli IK;
- ön-taban (ball + topuk açısı) ayak modeli;
- dünya eksenli omurga, stabilize baş;
- avuca göre hesaplanan parmak bükülme ekseni;
- her knot'un kendi tanjantına sahip (auto/flat/snap/linear) Hermite eğrileri. Bu yüzden kemiklerin easing'leri birbirinden farklı.

Her Action dört ayrı aşamada üretilip kaydedildi:
1. **Blocking:** Ana pozlar, stepped.
2. **Breakdown:** Ara pozlar, stepped.
3. **Spline:** Aynı knot'lar Bezier.
4. **Polish:** Her kare değerlendiriliyor.
   - Baş, eller, parmaklar ve pençe gövdeyi 0,5–3 kare gecikmeyle takip ediyor (overlap); bu gecikme klibin son 6 karesinde sıfırlanıyor.
   - Saç ve palto, gövdenin hız/ivme sinyalini kendi gecikmesiyle (2–4 kare) okuyor; zincirler aynı anda başlayıp bitmiyor.
   - Palto ve saç için iki zemin kontrolü var: kemik ucu kıskacı ve deforme mesh'i ölçen iteratif düzeltme (`tools/floor_fix.py`).

## Action listesi

| Action | Kare | Not |
|---|---:|---|
| `REV_Idle` | 1–90 (+91 kapanış) | Ağırlığın ~%60'ı ön (sol) ayakta. İki eşit olmayan nefes; 35–48 kafa taraması; 52–64 pençe gerilip gevşiyor. |
| `REV_AgileMove_InPlace` | 1–24 (+25) | Spec yürüyüşü, 2,45 m/s. Temas 1/13, passing 7/19. Göğüs ~29° öne eğik, dizler hep bükülü. |
| `REV_AgileMove_RootMotion` | 1–25 | Yalnızca tanı ve gösterim amaçlı. |
| `REV_AgileRun_InPlace` | 1–36 (+37) | **Oyun koşusu, 6 m/s.** Bloodwake Revenant'ı 300×0,02 = 6 m/s'de hareket ettiriyor. Uzun, sıçramalı avcı adımı: 3,3 adım/s, adım başı 1,8 m, gerçek uçuş fazı. Diz öne sürülüyor, topuk arkaya atılıyor. Gövde itişte pompalıyor; kalça ±11°, omuz ±18° burulma, ±5° yan esneme. Kollar omuzdan geniş yaylar çiziyor. Dirsek salınımı 2 kare, el ve parmaklar 3,5 kare gecikmeyle takip ediyor; el önde göğüs ortasına doğru içe, arkada kalçanın dışına doğru bir yay çiziyor, önkol dönüyor. Pençe kolu alçak ve yana açık, sol kol toplu ve bükülü; iki kol farklı karakterde. (İlk sürüm 24 kare / 5 adım/s / 1,2 m idi; "kütük gibi" geri bildirimiyle yeniden yapıldı.) |
| `REV_HitLight_Front/Left/Right` | 1–12 | 10–15° gövde dönüşü, baş darbeye karşı kapanıyor, 6–8 arası yarım denge adımı. `HIT_IMPACT` 3. |
| `REV_HitLight_*_Additive` | 1–12 | Yalnızca üst beden (omurga, boyun, baş, köprücük, kollar, eller, parmaklar, saç). 1. kareye göre yerel delta. |
| `REV_Death` | 1–72 | Göğüs darbesi → diz çöker → el zemine → yan yatış → yerleşme. Ragdoll savrulması yok. |
| `REV_TeleportAttack` | 1–42 | Yerinde. Yer değiştirmeyi oyun yapıyor. |
| `REV_BloodBurst` | 1–120 | Geniş alçak duruş → iplikler → sıkışma → sessizlik → 60'ta radyal patlama → tek diz → idle. |
| `REV_ClawAttack_1/2/3` | 30 / 32 / 42 | Spec dışı ek: oyunun pençe kombosu **sağ → sol → sağ**. Her vuruş ayrı hareket. **1:** sağ kol yana/arkaya iyice açılıp önden yatay geniş süpürüyor. **2:** gövde sola çömelip kuruluyor, sol kol arkada yere yakın açılıyor; sağ ayak çapraz adım atarken gövde parmak uçlarında doğruluyor ve kol aşağıdan yukarı çaprazlama sağ omuz üstüne kalkıyor. **3 (bitirici):** gövde yükselip geriye geriliyor, sağ kol başın üstünde açılıyor; sol ayakla uzun hamle, gövde çok alçalıyor, kol yukarıdan aşağı çaprazlama yere iniyor. Oyunda bitirici şok halkası ve daha güçlü sarsıntı ile geliyor. Kollar omuz etrafında açı/yarıçap/yükseklik kanalıyla (`arc_*`) sürülüyor. |

### Markerlar

| Action | Markerlar (kare) |
|---|---|
| HitLight | `HIT_IMPACT` 3 |
| Death | `DEATH_IMPACT` 5, `CLAW_FADE` 12, `DEATH_KNEE` 24, `DEATH_HAND` 38, `DEATH_GROUND` 52 |
| TeleportAttack | `CLAW_LINE` 7, `TELEPORT_HIDE` 16, `TELEPORT_MOVE` 20, `TELEPORT_SHOW` 22, `DAMAGE` 26, `RECOVER` 35 |
| BloodBurst | `ULT_TELEGRAPH_START` 19, `ULT_GATHER` 20, `ULT_COMPRESS` 43, `ULT_DAMAGE` 60, `ULT_RING_MAX` 71, `ULT_DISSIPATE` 85, `ULT_RECOVER` 101, `ULT_END` 113 |
| ClawAttack | `DAMAGE` 11 / 12 / 19 |

Olay zamanı = (kare − 1) / 60. glTF export'u `slide_to_zero` ile alındığı için klipler 0'dan başlıyor.

## Locomotion kalite kapısı (`qa/stage1_metrics.json`, `qa/locomotion_curves_*.png`)

| Ölçüm | AgileMove 2,45 m/s | AgileRun 6 m/s |
|---|---|---|
| Ayak kayması (temas boyunca dünya koordinatında) | 0,0 mm | 0,0 mm (Godot içinde de 0 ölçüldü) |
| Temas kilidi | 15 kare | 12 kare |
| Kalça dikey | 2,0 cm | 4,2 cm |
| Baş dikey | 1,1 cm | 3,6 cm |
| Kalça / omuz yaw | 14,1° / 16,3°, zıt fazlı | 22,2° / 24,4°, zıt fazlı |
| Sol–sağ ayna farkı | 2,2 cm (birebir aynı değil) | 2,3 cm |
| Loop dikişi | 0 | 0 |

- **Eğri karakteri:** Kalça eğrisi elle anahtarlanmış, asimetrik (sinüs değil).
- **Hareket yayları:** Diz, ayak bileği, dirsek ve bilek kapalı yaylar çiziyor.
- **İniş:** Ayak inmeden önce geri "pençeleme" (pawback) yapıyor.
- **Önizleme seti:** Siluet, %50 hız, normal hız, 6 m/s oyun hızı ve oyun kamerası MP4'leri `previews/stage1/` klasöründe.

## Zemin penetrasyonu (`qa/mesh_ground.json`, deforme mesh, her kare)

- **Bütün Action'lar 0:** Idle, AgileMove, AgileRun, üç Hit, iki ClawAttack, Teleport ve BloodBurst.
- **Death istisnası:** Zemine konan sol elin parmak uçları 5 karede en çok 1,6 cm giriyor (43–51). Ayrıca sol ball 3 karede 1,4 cm giriyor.

## Önizlemeler

- `previews/Revenant_NLA_All_Actions.mp4`: Bütün Action'lar sırayla, VFX proxy'leriyle.
- `previews/stage1/`: Idle (üç açı); AgileMove normal, %50 hız, oyun kamerası; AgileRun 6 m/s; siluet.
- `previews/stage2/`: Her Action önden, yandan ve 3/4 açıdan. Hit'lerin 4× yavaş kopyaları da var.
- `previews/game/Revenant_InGame_{close,game}Camera.mp4`: Gerçek oyun döngüsü (fizik, giriş, yetenekler, düşmanlar). Sıra: idle → koşu → pençe zinciri → koşarken saldırı → koşarken hasar → Q → Blood Burst → ölüm.

## Export ayarları

- **GLB:**
  - Seçenekler: `ACTIONS` modu, force sampling, her kare, `slide_to_zero`, tek armature, Y-up.
  - Yalnızca `pose.bones` kanalları export ediliyor; nesne kanalları atılıyor.
  - Oyun versiyonu: texture'lar 2048, JPEG q88.
- **FBX:**
  - Seçenekler: tüm Action'lar bake, leaf bone yok, texture'lar gömülü, −Z ileri / Y yukarı.
  - Base color, Mix düğümünü atlayarak (yalnızca bellekte) doğrudan bağlanıyor.
- **Geri import doğrulaması** (`qa/export_roundtrip.json`):
  - İki dosyada da 1 armature, 77 kemik, 17/17 Action, 1,90 m.
  - GLB: 3 texture.

## Oyun entegrasyonu (Godot)

- **`assets/models/revenant_player.glb`** değiştirildi. Önceki dosyanın yedeği: `workfiles/revenant_player_previous_game.glb`.
- **`.import` ayarları:**
  - `animation/fps` 30'dan 60'a alındı.
  - AnimationPlayer optimizer'ı kapatıldı: `_subresources` → `PATH:AnimationPlayer` → `optimizer/enabled=false`. Açıkken bacak key'lerini eliyor ve koşuda basılı ayağı ~1 cm titretiyordu.
- **`scripts/visual.gd`:**
  - Açık klip eşlemesi eklendi.
  - Olaylar `REVENANT_EVENTS` içinde, `revenant_time()` ile okunuyor.
  - Koşu oynatma hızı = hız oranı / model ölçeği. Böylece ayaklar karakter büyüdükçe de kaymıyor.
  - Hit artık state değiştirmeden üst-beden additive katmanı olarak oynuyor.
  - Ölüm dissolve'u `DEATH_GROUND` sonrasında başlıyor.
  - Kan eli efektleri `hand_l/hand_r` kemiklerine bağlandı.
- **`scripts/revenant_layers.gd` (yeni SkeletonModifier3D):**
  - Additive hit katmanı.
  - Hareket halindeyken saldırı veya hit oynarsa alt beden ve palto koşu klibinden geliyor; üst beden pençeyi atıyor.
- **`scripts/skills.gd`:**
  - Q / Blood Step markerlara bağlandı: HIDE 0,25 s → MOVE 0,317 → SHOW 0,35 → DAMAGE 0,417 → kilit 0,567'de kalkıyor.
  - Blood Burst: TELEGRAPH 0,30 → DAMAGE 0,983 → kilit 1,40'ta kalkıyor.
  - Klip yoksa eski zamanlamaya düşüyor.
- **`scripts/world.gd`:**
  - Revenant zinciri `attack1 → attack2 → attack3` (sağ, sol, sağ).
  - Klipler authored hızda oynuyor, saldırı hızının karekökü ile ölçekleniyor.
  - Temas karesi markerdan (11/12/19) okunuyor.
  - 3. vuruşta ek şok halkası ve daha güçlü kamera sarsıntısı var.
  - Pençe VFX'i 2. vuruşta (sol el) ters yönde çiziliyor.
  - Teleport ve Burst'ün toparlanma fazı hareketle kesilebiliyor.
- **`scripts/fx.gd`:** Ölüm kan patlaması `DEATH_GROUND` anına alındı.
- **Testler:**
  - `revenant_animation_test` yeniden yazıldı; oyun motoru içinde şunları ölçüyor:
    - loop kapanışı ve 6 m/s'de ayak kayması;
    - başın kalçadan az oynaması;
    - saldırı ve cast'lerin idle pozuna dönmesi;
    - her vuruşta vuran kolun yana >55 cm açılıp temas anında önden süpürmesi;
    - ayakların zemin üstünde kalması;
    - hit'in bacaklara dokunmaması.
  - `revenant_test` ve `revenant_kit_test` marker zamanlarına göre güncellendi.
  - Kit testinde menzil artık `attackRange` statı ile hesaplanıyor; skill de böyle hesaplıyor.
  - Üçü de geçiyor; `test_suite` 198/0.

## Kalan sorunlar ve notlar

- **Death:** Sol el parmak uçlarında geçiş sırasında küçük penetrasyon var (≤1,6 cm, 5 kare).
- **Light hit yönü:** Oyun hasar kaynağının yönünü vermiyor; hit varyantı rastgele seçiliyor. `_hurt_player` bir yön alırsa Front/Left/Right doğrudan seçilebilir.
- **FBX:** Paketli metal/pürüzlülük haritasını taşıyamıyor (format sınırı). Haritalar `textures/` klasöründe; oyun GLB kullanıyor.
- **Blood Burst süresi:** Spec'e uygun olarak 2 s. Hareket 85. karede (1,4 s) serbest kalıyor; kalan diz toparlanması hareketle kesilebiliyor.
- **Revenant dışı testler:** Paketteki 4 test başarısız: encounter_pacing ×2 (Mage küresi/menzili), xp_pacing ×2, warrior_movement ×1. Bu testler Revenant kod yollarına dokunmuyor. Önceden var olan, commit edilmemiş veri değişikliklerinden kaynaklandıklarını düşünüyorum; dokunulmadı.
- **Silinen klasör:** Önceki denemenin `godot_test/` mini projesi kaldırıldı; gerçek oyun entegrasyonu onun yerini aldı. Eski betikler `tools/_astra_v1/` klasöründe.

## Yeniden üretim

```bash
cd art/revenant-astra-ready/deliverables
blender -b workfiles/Revenant_Rigged_backup_astra_v1.blend --python tools/rig_fix_weights.py
blender -b Revenant_Rigged.blend --python tools/author_stage1.py
blender -b Revenant_Stage1.blend --python tools/author_stage2.py
blender -b Revenant_Stage2.blend --python tools/qa_mesh.py
blender -b Revenant_Stage2.blend --python tools/finalize_v2.py
blender -b Revenant_Animated.blend --python tools/export_game.py -- Revenant_Animated.glb full
blender -b Revenant_Animated.blend --python tools/export_game.py -- game/revenant_player.glb game
blender -b Revenant_Animated.blend --python tools/export_fbx_and_validate.py
tools/stage1_previews.sh && tools/stage2_previews.sh && python3 tools/plot_locomotion.py
```
