# Bloodwake — buradan başla (17 Ekim 2026, Windows'a geçiş)

Yeni sohbette Claude'a şunu söyle:

> Bloodwake projesindeyiz. Önce depo kökündeki `HANDOFF.md` dosyasını oku, son durum ve sıradaki işler orada.
> Sonra "Sıradaki işler" listesinin 1. maddesinden devam et.

Ayrıntılı tarihçe `unity/HANDOFF_STATUS.md` içinde (uzun, gerekmedikçe baştan sona okuma). Teknik günlük `unity/README.md`.
Senden beklenen ses, müzik ve 3D model istekleri `art/ASSET_REQUESTS.md` içinde.

---

## Kurulum (Windows)

1. `git pull origin master`. Bütün iş `master`'da; `bloodwake-fixes` ile aynı commit.
2. Unity Hub → **Unity 6000.3.25f1** ile `unity/` klasörünü aç. İlk import uzun sürer.
3. Sahne: `Assets/Bloodwake/Scenes/Bloodwake.unity` → Play. `WarriorReview.unity` eski bir inceleme sahnesi, oyun değil.
4. Animasyon hattı için **Blender** gerekli (Mac'te 4.x kullanıldı). Vesper'ı yeniden üretmek için:
   `blender --background --python art/agile_warrior/build.py`, sonra Unity menüsünden **Bloodwake → Import Vesper**.
5. Mac'teki yerel geliştirme köprüsü (`Assets/Bloodwake/Editor/Dev/`, `/tmp/bloodwake-bridge`) git dışında tutuluyordu,
   Windows'ta yok. Testler editörde elle Play ile ya da Linux smoke build'i ile yapılır (`unity/README.md`).

## Oyunun şu anki durumu

- **Sınıflar:** Warrior, Revenant, Vesper, Mage. Akış: sığınak (War Table, Quartermaster, Blood Sage) → 10 bölgelik zincir → final boss → zafer.
- **Kontroller (gamepad):**
  - R1 düz saldırı, R2 ağır saldırı (Warrior; Vesper ağaçtan açar), kare dash.
  - △ ○ ✕ = 1/2/3. yetenek; yakında NPC veya ödül varsa ✕ etkileşim.
  - Dash sırasında R1: Revenant'ta thrust, Vesper'da kayan yükselen kesik + alev yarım ayı.
  - L1+R1: Tethered Blade. L1/L2 başka bir şey için boş.
  - Saldırı sol çubuğun yönüne gider, hafif nişan yardımı var. Sağ çubuk nişanı ve otomatik saldırı yok.
  - Menüler gamepad ile gezilir. DualSense tuş simgeleri ve titreşim var; Ayarlar'da titreşim aç/kapa.
- **Klavye/fare:** sol tık düz, sağ tık ağır, Shift dash, Q/E/Space yetenekler, F etkileşim, Alt+sol tık Tethered Blade.
- **Performans:** MSAA kapalı (SMAA açık), tek kademe gölge. Ayarlar → Render Quality: HIGH %100 / BALANCED %85 (varsayılan) / PERFORMANCE %70.
  Mac (M2 Air) editörde ~18 ms/kare. Güçlü bir Windows makinede HIGH denenebilir.
- **Düşman tepkileri:**
  - Vurulan düşman sendeleme + 0.6 sn saldıramaz (kombo bölünmez); kombo sonu ve ağır vuruş savurur.
  - Vesper ateşi tutuşturur: yanan düşman ~1.5 sn kıvranıp saldıramaz, sonra yavaş kalır. Yerde kalan alev de tutuşturur.
- **Blood Sage ağacı:**
  - Her sınıfta Güç dalı (rütbeli pasifler); Vesper'da ayrıca Hareket dalı var:
    Heavy Cleave, Second Step (çift dash), Falling Star (R1 R1 R2), Crescent Fan (R2 R2), Tethered Blade (L1+R1).
  - Revenant'ın Hareket dalında şimdilik yalnız Crimson Arrival var; Warrior ve Mage'de Hareket dalı boş.
  - **Essence** run boyunca taşınır, **boss ölünce** kasaya geçer, boss'tan önce ölünce kaybolur.
- **Dekor:** duvar diplerine yoğun sandık/varil/örtü yığınları, zeminde çatlak/yosun/çamur/saman, havada kül, mangallarda kıvılcım.
  Yeni Tripo modelleri `Resources/Environment/Kit01/<id>/<id>.prefab` olarak girince kendiliğinden dağılır (id listesi `RoomClutter.cs` başında).
- **Ses:** ayak sesleri, düşman saldırı/acı/ölüm sesleri, ortam döngüleri, konumlu ateş sesi, savaşta dönüşümlü müzik bağlı.
  Dosyalar `Resources/audio/` içine `art/ASSET_REQUESTS.md`'deki adlarla girene kadar sessiz.

## 18 Ekim (Windows) — eklenenler

- **Akış:** ilk NEW RUN'da Vesper ile prolog (story.json) → doğrudan ilk bölge; sonrakilerde oath ekranı. Sığınakta **Ashen Mirror** ile karakter değişimi.
  Blood Sage ve Quartermaster her dönüşte son run'a göre 50'şer satırdan birini söyler. Bölgeye giriş kapıdan içeri yürür.
- **Dalgalar:** her savaş odası bölgenin havuzundan rastgele 2 turlu kombinasyon çeker (story.json `waveCombos` / `districtPools`). Aynı anda en çok 8 düşman.
- **Boss:** 10 bölgede 10 Bellwarden varyantı (isim, desen, tempo, çağırdıkları). Giriş kartı, ekranın tepesinde can barı.
  Vuruşlarımız onu sendeletmez/saldırısını kesmez, saldırılar arası bekleme ~yok, zemin uyarısı yok. Yürüyüşü ayak izine göre kalibre.
- **Dev kit:** F1 / Select. God mode, cooldown yok, tek vuruş, oda/boss/bölge atlama, essence/altın.
- **Vurma hissi:** titreme + ezilme (HitShake), güçlü flaş, daha uzun hit stop, daha fazla savrulma.
- **Vesper:** dash→R1 çubuğa göre; L1+R1 kılıç gerçekten uçar; R2 R2 beklemesiz; **L1+R2 sol elden alev püskürtme** (≤1 sn).
- **Mage (oyuncu):** R1 ×3 (sağ el küre, sol el ters küre, 30° buz kırıkları), R2 90° kuvvet halkası, R1 R1 R2 buz kuyruklu yıldızı,
  L1+R1 yakala-çek-fırlat, kare = havada süzülme. Model: 19 Ekim sorceress (`art/mage/build_sorceress.py` → Bloodwake → Import Mage Sorceress); ters/zemin klipleri düşman büyücünün Mixamo kliplerinden aynı iskelete pişirilir.
- **Warlock (yeni düşman):** teal büyücü, 30°'lik 5'li yay atışı ve 1 sn hapseden mühür. 3. bölgeden itibaren.
- **Revenant:** dash→R1 önden saplanır ve yumuşak toparlanır; yürüyüş/koşuda daha dik duruş (RevenantPosture).
  Hareket dalı: Crimson Rend (R2), Mist Chain, Hemorrhage (R1 R1 R2), Blood Lance (L1+R1), Sanguine Siphon (L1+R2).
- **Warrior:** saldırılar arası geçişler daha uzun blend.
- Varlık istekleri: `art/ASSET_REQUESTS.md` bölüm 0 (boss Mixamo seti, VFX dokuları, yeni sesler).

## Sıradaki işler (öncelik sırasıyla)

0. **Gelen varlıkları bağla** (`art/ASSET_REQUESTS.md` bölüm 0): boss Mixamo klipleri → MageKitImport gibi kemik adıyla
   enemy_boss controller'a ekle, yürüyüşü koşudan ayır; `art/vfx-incoming/` dokularını alfa'ya çevirip ilgili efektlere bağla.
   Sesler adıyla kendiliğinden çalar.

1. **Vesper'ın yeni hareketleri için gerçek animasyon klipleri (Blender).**
   Kullanıcı bunları istedi ve henüz **yapılmadı**: hareketler şu an mevcut kliplerle ve kodla verilen hareketle çalışıyor.
   Bu klipleri Blender'da (`art/agile_warrior/vesper_animated.blend`, Mixamo iskeleti) gerçek animasyon olarak üret:

   | Hareket | Şu an kullanılan klip |
   |---|---|
   | Heavy Cleave | `Attack2` %145 yavaş |
   | Falling Star | `Ultimate`, ayrıca kodla zıplama ve 360° dönüş |
   | Crescent Fan | `Attack2` |
   | Tethered Blade | `Attack1`, kılıcın uçuşu kodla |
   | Dash→R1 yükselen kesik | `DashAttack` |

   Yapılacaklar:
   - Yeni action'ları `art/agile_warrior/build.py`'de `CLIPS` listesine ekle (mevcut Mixamo action'larından türet ya da kemik keyframe'leriyle yaz).
   - FBX'i yeniden üret, `Editor/VesperImport.cs` içindeki `Required` listesine ekle.
   - `Runtime/VesperMoves.cs` içindeki `Player.Play(...)` çağrılarını yeni kliplere çevir. Darbe anı (contact) zamanlarını kliplerden ölç.
   - Her klibin darbe karesini ve ayak kaymasını oyun kamerasında kontrol et.
2. **Kullanıcı testinden gelecek his ayarları.** İlgili yerler:
   - Düşmanın hit sonrası bekleme süresi `HitAttackDelay` (`EnemyReactions.cs`).
   - Panik süresi ve yanma hızı (`Ignite`).
   - Hit-stop süreleri (`Combat.cs` başı).
   - Savrulma mesafeleri (`HitRecoil.cs`).
   - Yarım ay hızı ve menzili (`VesperMoves.cs`, `LaunchCrescent` çağrıları).
3. **Gelen varlıkları bağla:**
   - Sesler adlarıyla kendiliğinden çalışır. Vesper hareket sesleri için gerekirse `rules.json` "audio"ya darbe anı (impact) ekle.
   - Tripo zip'leri `art/environment-incoming/`'e gelir; `Kit01/crate` örneğindeki gibi klasöre çıkar (model.fbx + dokular + prefab).
4. **Revenant'ın Hareket dalı ve yeni yetenekleri** (Vesper'dan sonra yapılacağı konuşuldu), ardından Warrior ve Mage dalları.
5. `unity/HANDOFF_STATUS.md` → "Açık işler" listesi: Mage VFX kalitesi, düşman/boss davranışları, HUD'un farklı oranlarda kontrolü, platform/build.

## Önemli dosyalar (unity/Assets/Bloodwake/)

| Dosya | İçerik |
|---|---|
| `Runtime/GameLoop.cs` | Girdi eşlemesi (gamepad/klavye), oyun döngüsü |
| `Runtime/GamepadInput.cs` | Cihaz algılama, menü odağı, DualSense simgeleri, titreşim, nişan yardımı |
| `Runtime/Combat.cs`, `HitRecoil.cs`, `EnemyReactions.cs` | Saldırı, hasar, savrulma, sendeleme, tutuşma/panik, yerde kalan ateş |
| `Runtime/VesperMoves.cs`, `FlameCrescent.cs` | Vesper'ın dash→R1 hamlesi ve ağaç hareketleri, alev yarım ayı |
| `Runtime/SkillTree.cs` | Blood Sage ağacı ekranı, essence taşıma/kasaya alma |
| `Resources/Data/catalogs.json` (`skills`), `rules.json` (`effects`, `audio`) | Ağaç düğümleri, pasif etkileri, ses tablosu |
| `Runtime/RoomClutter.cs`, `RoomAmbience.cs` | Oda dekoru, zemin detayları, parçacıklar |
| `Runtime/AudioWorld.cs` | Ayak sesleri, ortam sesleri, müzik varyantları |
| `Runtime/GameplayLighting.cs`, `Assets/Settings/PC_RPAsset.asset` | Işık, post-process, render kalitesi |
