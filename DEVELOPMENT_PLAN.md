# Bloodwake — Development Plan / Handoff Brief

Mobile-first action-roguelite prototype. Flutter + Flame. Package id
`com.silveroaktech.nexus`, working title "Nexus" internally, player-facing
branding "Bloodwake" ("Survive the night. Claim the dawn.").

This document is a snapshot for handing the project to another engineer or
AI assistant — what exists, how it's built, what's deliberately unfinished,
and what a sensible next chunk of work looks like. It reflects the repo as
of the latest commits on `master` (`origin` = `github.com/cenkgrs/Bloodwake`).

## 1. Tech stack

- Flutter (stable channel) + [Flame](https://flame-engine.org/) `^1.38.2`
  for the real-time game layer (world, camera, collisions, components).
- `flame_audio` for SFX.
- Flutter widgets (Material) for menus, HUD overlays, and wave-end screens
  — the game canvas and Flutter UI are two separate layers composited via
  `GameWidget.overlayBuilderMap`.
- No backend yet. No persistence between runs. No state management
  library — plain Dart objects + Flame's component tree + a couple of
  `ValueNotifier`s for Flutter-side reactivity (e.g. `intermissionRevision`).
- Target: Android first (tested on emulator throughout); no iOS-specific
  work done yet, nothing known to block it.

## 2. Architecture & conventions (read before writing code)

The single most important convention in this codebase: **new content is
data, not new classes.** A new weapon, enemy, upgrade, shop item, ability,
or character class is a new `const` entry in a catalog file plus (if it's
genuinely a new *behavior*, not just new numbers) one more `case` in an
existing dispatch switch. Do not create a new component subclass per
content item.

Concretely:
- `WeaponData` (`lib/game/weapons/weapon_data.dart`) + `WeaponCatalog` —
  a `WeaponBehavior` enum (`singleProjectile`, `spread`, `piercing`,
  `chain`, `melee`) is dispatched once in `PlayerWeapons.update()`. Adding
  a 8th weapon that reuses an existing behavior is a new `WeaponData`
  const, nothing else.
- `EnemyData` (`lib/game/enemies/enemy_data.dart`) + `EnemyCatalog` — same
  idea via `AiType`, dispatched in `Enemy.onLoad()` to pick an AI
  component (`ChaseAttackAi`, `ArcherAi`, `AssassinAi`, `HealerAi`,
  `BossAi`).
- `UpgradeData`/`ItemData` (`lib/game/upgrades/`, `lib/game/items/`) — both
  take an `apply(Player)` function reference and an optional
  `isAvailable(Player)` gate (used for synergy upgrades like Chain
  Lightning, weapon-specific items like Gold Sword, and — as of this
  session — for not re-offering a weapon a class already starts with).
- `CharacterClassData` (`lib/game/player/character_class.dart`) —
  starting weapon + a `PlayerStats` factory + a sprite folder path + an
  accent color. That's the entire surface area a class touches.
- `AbilityData` (`lib/game/abilities/ability_data.dart`) — same shape,
  currently only one entry (`spearThrow`), shared by all classes.

Other conventions worth preserving:
- **Missing art/audio never crashes.** `SfxPlayer._safePlay` catches and
  no-ops; `CatalogIcon`/`OverlayBackground`/`ArenaComponent` all have
  `errorBuilder`/try-catch fallbacks to a flat color or a Material icon.
  This is why art has been droppable into `assets/` mid-session with zero
  code changes — keep new art hookups following the same pattern.
- **Data-driven audio routing.** `WeaponSfx` (`lib/game/systems/audio/`)
  maps `WeaponData.id` → asset filename for fire/impact sounds; unmapped
  weapons fall back to generic `shoot.mp3`/`hit.mp3`. `SfxPlayer` also
  throttles high-frequency sounds per-filename (hit, enemy_death,
  shoot_rifle, chain_lightning, sword/orb impact) so a busy wave doesn't
  stack the same sound dozens of times a second.
- **Visual sprite size is independent of collision hitbox size.**
  `Player`'s `CircleHitbox` radius (`GameConstants.playerRadius`) never
  changes; `CharacterSpriteAnimator`'s `displaySize` is a separate,
  purely-cosmetic number. Never conflate the two when tuning art scale.
- **Formulas, not hardcoded thresholds**, for anything wave-number
  related (`WaveManager` — quota, elite chance, boss-every-10th-wave via
  `wave % 10 == 0`, spawn interval). Don't add `if (wave == 7)` special
  cases.
- Prototype visuals lean on procedurally-drawn shapes and `Canvas`
  drawing (HUD bars, arena border, telegraph rings) rather than sprite
  assets where no art exists yet for that element.

## 3. Current feature inventory

**Core loop:** pick a class → survive infinite waves in one arena → wave
clears on kill-quota (not timer) → brief breather with level-up choice(s)
then a gold shop → repeat → boss every 10th wave → death ends the run
(no persistence, no meta-progression).

- **Classes (4):** Warrior (melee/tank), Gunslinger (ranged/DPS), Mage
  (piercing AoE), Assassin (fast/crit, new `Twin Daggers` weapon built
  for it). Each sets starting weapon + a `PlayerStats` flavor + sprite
  folder; otherwise identical rules (see gaps below re: animation).
- **Weapons (7):** Basic Pistol, Rapid Rifle, Shotgun (spread), Magic Orb
  (piercing + slow/chill), Lightning (chain), Sword (melee), Twin Daggers
  (fast melee). Up to `GameConstants.maxWeaponSlots` (4) held at once,
  collected via level-up unlock picks — classes do **not** lock you out
  of other weapons.
- **Enemies (5 + boss):** Grunt/Tank (melee, now with separation-steering
  so a pack surrounds instead of single-filing), Archer (kiting
  projectile), Assassin (dash-vanish-strike), Healer (support, fixed a
  prior softlock), Boss (multi-phase, `BossAi`).
- **Progression:** free level-up picks (upgrade pool, rarity-gated
  common/rare/epic/legendary, one free reroll) + a gold shop (paid,
  limited refresh; items are equipment-flavored, category-tagged
  weapon/gear/relic). Both now surface through a single merged
  `IntermissionOverlay` (see `RoughlikeGame.intermissionRevision`).
- **HUD/UI:** full-screen, edge-to-edge level-up/shop/menu screens with a
  shared dark-fantasy visual language (`BloodwakeTheme`,
  `fantasyText`/Cinzel, `RarityCardShell`), a reskinned main menu and
  class-select screen, soft page transitions (`softRoute`).
- **Audio:** every major trigger (weapon fire/impact, hit, death,
  level-up, purchase, boss phase/death) has a real asset in
  `assets/audio/`, weapon-specific where it matters (see §2).
- **Art:** real generated art for most upgrade/item icons, class sprite
  sheets (idle/run/attack/hit/death) for all 4 classes, a tileable arena
  floor texture, main-menu/shop/level-up background art.
- **Misc systems added this session or just before it:** `HealthPickup`
  (rare healing drop), `AttackTelegraph` (reusable warning-ring before an
  enemy attack lands), camera shake, hit-flash/death-burst VFX.

## 4. Known gaps / incomplete work

Roughly in the order you'll bump into them:

1. **Attack animation is only wired for Warrior**, and only via a
   separate "rig test" asset (`assets/images/characters/warrior_rig_test/`,
   numbered-frame folders) — not the same 5-frame-strip pipeline the
   other three classes use. Gunslinger/Mage/Assassin currently get **no**
   attack pose at all (comment in `character_sprite_animator.dart`:
   generated attack frames shift anatomy/camera angle between frames
   badly enough that firing a fast weapon looked like thrashing, so it's
   intentionally suppressed until a properly-aligned strip exists).
2. **Idle/run for the non-Warrior classes are static, not animated** — a
   workaround (`_loadAnimation`'s `count == 1` branch, picks the middle
   frame) because the generated strips apparently have per-frame
   inconsistency/border artifacts. Warrior's separate rig-test pipeline
   is the fix pattern to extend to the other three once equivalent
   properly-rigged assets exist for them.
3. **Boss balance has never been tuned.** HP/damage/phase thresholds are
   whatever they were set to at initial implementation; explicitly
   flagged early on as a follow-up and never revisited.
4. **No enemy-side use of the new sprite/animation pipeline** — enemies
   are still simple `CircleComponent` shapes with a data-driven color.
5. **No meta-progression.** Currency, unlocks, and stats are entirely
   run-scoped; nothing persists after death. No settings screen, no
   pause menu, no save system.
6. **Single arena, single floor texture, single boss.** No environment
   variety, no second boss, no biome/wave-set changes.
7. **Test coverage is minimal** — `test/widget_test.dart` (main menu
   renders), `test/class_upgrade_test.dart` (class/upgrade interaction),
   `test/health_drop_test.dart` (enemy health-drop data). No tests for
   wave formulas, damage math (crit/armor), or upgrade/item `isAvailable`
   gating.
8. **No finite "run complete" condition** — waves are infinite by design
   (a `Wave X/12`-style mockup was explicitly considered and rejected in
   favor of the current endless+boss-every-10 formula). Revisit only if
   the design direction changes.
9. Daggers (Assassin's weapon) has no dedicated icon or SFX mapping yet —
   both gracefully fall back (generic icon, generic shoot/hit sound), not
   broken, just unpolished.
10. `assets/images/backgrounds/map1test.png` and `shop_bg_old.jpg` are
    superseded leftovers sitting in the repo, unreferenced by code — fine
    to delete whenever convenient.

## 5. Suggested next steps (roughly priority order, not mandatory)

1. **Decide the animation strategy** for the three non-Warrior classes:
   either invest in properly rigged/consistent strips (matching whatever
   made the Warrior rig test work) for all of them, or accept static
   idle art longer-term and prioritize elsewhere. This is a content/art
   pipeline decision more than a code one.
2. **Boss balance pass** — the oldest open item. Needs actual playtesting
   at wave 10/20/30 with a real build, not guesswork.
3. **Enemy visual pass** — bring enemies onto the same sprite pipeline
   the player now has, even if lower-fidelity (fewer frames/states).
4. **Test coverage for game logic** — wave quota/spawn formulas, damage
   rolls (crit, armor mitigation), upgrade/item `isAvailable` gating —
   these are pure-logic and cheap to unit test, and this session's
   ownership-gating bug (weapon unlocks not checking ownership) is a
   good example of the kind of bug that class covers.
5. **Meta-progression** (only once the moment-to-moment loop feels done):
   a persistent currency, unlockable classes/weapons, or run summaries.
   Item catalog was explicitly kept as a single flat file partly with an
   eye toward an eventual remote-config/Supabase source — worth
   revisiting if meta-progression happens.
6. Content breadth once the above is solid: more enemies, a second boss,
   more weapons/upgrades/items following the existing catalog pattern.

## 6. Working conventions (repo/process notes)

- Branch: `master`. Remote: `https://github.com/cenkgrs/Bloodwake.git`.
- Local git identity for this repo only:
  `user.email = cenkgrs@gmail.com` (not global — set with a repo-local
  `git config`, intentionally, don't change global config).
- Commit style: itemized/bulleted body, descriptive subject, **no**
  `Co-Authored-By` trailer.
- Assets follow a "drop file in, no code change needed" contract almost
  everywhere (see §2) — when adding a new content type's art/audio, wire
  the lookup with a graceful fallback *before* the asset exists, the same
  way every existing system does.
