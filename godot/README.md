# Bloodwake — Godot PC port

## Start on another computer

Install Godot **4.6.3 standard**, clone this repository, import `godot/project.godot`,
let the initial asset import finish, then press F5. No Flutter, Blender, .NET or
external Godot plugins are needed to play or edit the checked-in project.

From the repository root, with Godot on PATH:

```sh
godot --headless --editor --path godot --import
godot --path godot
```

## Controls

- WASD / arrows: move; mouse wheel: zoom.
- Left mouse: aim and fire; Tab: toggle automatic fire (initially on).
- Space / E / right mouse: class ability.
- Escape: pause; F11: fullscreen; F3: playtest tools in debug builds.
- Controller: left stick move, right stick aim, RT fire, A ability,
  Y automatic fire, Start pause. Menus also accept standard UI navigation.
- Mobile: floating left joystick and right ability button. Choose the Mobile
  quality profile in Settings to disable shadows/MSAA and reduce effects.

## Systems and code

| System | Source |
| --- | --- |
| Catalogs, class stats, scaling and effect definitions | `data/catalogs.json`, `scripts/data.gd` |
| Districts, props, garrison weights and blocking | `scripts/arena.gd` |
| Class skills and ultimates | `scripts/skills.gd` |
| Transient combat effects | `scripts/fx.gd` |
| Weapons, upgrades, inventory, XP and damage stats | `scripts/run_state.gd` |
| Persistence, skill tree, equipment and three loadouts | `scripts/meta.gd` |
| 3D movement, aiming, weapons, enemies, bosses, waves | `scripts/world.gd` |
| Model loading, bounds, skeletal clips and blending | `scripts/visual.gd` |
| Menus, HUD, shop, rewards, pause, settings | `scripts/main.gd` |
| Touch input | `scripts/touch_controls.gd` |

`data/catalogs.json` holds 7 weapons, 12 abilities, 7 enemy types, 22 upgrades,
11 shop items, 9 permanent equipment items and 15 skill nodes. It was extracted
once from the original Dart catalogs and is the source of truth now.
Distances use 50 legacy pixels per world meter. Each district carries a `garrison`
table that weights what a wave draws there on top of the catalog's own
`spawnWeight`; it shifts the mix rather than choosing it, so nothing the run has
unlocked is ever unreachable in a given district.
Basic grunt melee damage is 8.

Bloodbound uses the user's rigged GLB with idle/run/attack/hit/death clips, normalized
from `art/bloodbound/source/bloodbound_game.glb`. Its internal class ID is still
`gunslinger`. All facings are 3D rotations. The playable Warrior uses the supplied Tripo knight and greatsword with five
Mixamo two-handed clips (Idle, Run, Attack, Hit, Death), built as
`assets/models/warrior_player.glb`. The sword is rigidly skinned to the right hand;
planar root motion is removed. Enemy Warriors retain the Quaternius placeholder. Assassin's current model still needs authored animation clips. The playable Mage
uses the supplied unarmed model with six Mixamo clips, including Ultimate, and
animated right-hand spell VFX. Enemy healers keep their procedural placeholder.

Progression is stored at `user://bloodwake_progression.json`. Settings can import
a legacy progression JSON with confirmation. Phone app storage is not automatically
copied to PC. The user data location can be opened through Godot's project menu.

## Conventions

These four rules carried over from the original project and still hold. They are
what keep the catalogs usable and the content cheap to add.

**New content is data, not a new class.** A weapon, enemy, upgrade, shop item,
ability or skill is a new entry in `data/catalogs.json`, plus - only if it is
genuinely a new *behaviour* rather than new numbers - one more case in an
existing dispatch. `WeaponBehavior` is dispatched once in `world.gd`, enemy
`AiType` once in `_enemy_tick`, and a skill's `behavior` once in `skills.gd`.
Do not add a script per content item.

**Missing art or audio never crashes.** `BWVisual` falls back to a procedural
body when a model is absent, `BWAudio` no-ops on a missing sample, and an empty
`mesh` on a `PROPS` row builds the primitive instead. This is why art can be
dropped into `assets/` mid-session with no code change - wire a new lookup with
its fallback *before* the asset exists, the way every existing system does.

**Visual size and collision size are separate numbers.** A rig's presence height
(`BWVisual.configure`) is cosmetic; what holds bodies apart is the radius on the
enemy row or the `PROPS` row. Never conflate them when tuning scale. `_model`
deliberately lets a mesh spread to `radius * 6` so a branching tree is not
squashed into a shrub, which does mean a wide prop can be walked into before it
blocks - the brazier is the current outlier.

**Formulas, not hardcoded thresholds**, for anything keyed to the wave number.
`BWData.wave_rules` derives quota, cap, interval, elite odds and the multiplier
from the wave, and the boss is `wave % 10 == 0`. Do not add an `if wave == 7`.

### Repo and commits

Git identity is set per repository, not globally - a clone starts without it,
and `.git/config` is not something a push carries:

```sh
git config --local user.email "cenkgrs@gmail.com"
git config --local user.name "Cenk Gürses"
```

Commit messages take a descriptive subject and an itemized body. No
`Co-Authored-By` trailer.

## Verification

```sh
godot --headless --path godot --script tests/test_suite.gd
godot --headless --path godot --script tests/combat_flow_test.gd
godot --headless --path godot --script tests/class_kit_test.gd
godot --headless --path godot --script tests/wave_field_test.gd
godot --headless --path godot --script tests/enemy_asset_test.gd
godot --headless --path godot --script tests/altar_props_test.gd
godot --headless --path godot -- --smoke
godot --path godot -- --qa
```

Each suite prints its own count and exits non-zero on a failure. `test_suite`
checks catalogs, upgrade gates, purchases, XP, persistence, equipment, all
class/enemy instantiation and intermission flow. `combat_flow` covers damage,
animation tempo and the wave/death transitions. `class_kit` drives all eight
bound skills, and `wave_field` covers the district tour, the wave-gated spawn
pool, elite scaling and the burn/bleed/slow timers. `--smoke` runs a short combat
session and exits. `--qa` captures menus, four movement directions, boss, upgrades
and shop in `user://`. Run tests with isolated `XDG_DATA_HOME` on Linux to avoid
using personal progression.

## Export

Install the matching 4.6.3 export templates using Godot's editor. Then:

```sh
mkdir -p godot/builds/linux godot/builds/windows
godot --headless --path godot --export-release 'Linux PC'
godot --headless --path godot --export-release 'Windows PC'
```

Each output embeds its PCK. Builds go to `builds/` and are ignored by Git.
Linux has been run locally; Windows must be tested on an actual Windows machine.
Android/iOS packaging, touch device verification, profiling, LODs and final mobile
budgets remain a later milestone. The Mobile profile is a starting point, not a
measured performance guarantee. Both profiles currently use Compatibility rendering.

## Art provenance

The Warrior technical source and helmet are from Quaternius CC0 packs:
https://quaternius.com/packs/rpgcharacters.html and
https://quaternius.com/packs/knightcharacter.html. See
`../art/warrior/PRODUCTION_BRIEF.md` for the original assessment and art requirements.
The Bloodbound model was supplied by the project owner. Other assets are carried
from the existing project. `tools/export_warrior.py` rebuilds the technical Warrior
from the stored Blender sources; Blender is optional for normal development.

Rebuild the supplied Warrior with Blender:

```sh
blender -b -t 4 --python godot/tools/build_mixamo_warrior.py
```

Sources live in `art/warrior/source/{knight,greatsword,mixamo}`. The original sword
has 980,133 vertices; the runtime mesh has 7,843 before glTF vertex splitting.
The supplied Mixamo skin is reused and matching bone names are checked on export.
Both Mixamo builders normalize per-file FPS to 60 FPS before export, preserving
real clip durations even when inputs mix 30 and 60 FPS. Warrior and Mage runtime
attacks fit 0.45 seconds or 85% of the upgraded weapon interval, whichever is
shorter; hit reactions take 0.22 seconds. Locomotion cycles fit 0.62/0.72 seconds
and follow movement-speed upgrades. Bloodbound retains its original playback.
Sword damage and Mage projectiles resolve at the attack contact frame (32%).
Mage Ultimate casts at 0.45 seconds into its separate 0.9-second clip.

Wave completion shows WAVE CLEARED over the live arena for 2 seconds before the
upgrade/shop flow. Death starts game_over audio immediately and shows the body unobstructed for
2 seconds, followed by YOU DIED for 2.7 seconds before the results menu. Transition callbacks cannot replace a newer run or menu.

Rebuild Mage and run combat regressions:

```sh
blender -b -t 4 --python godot/tools/build_mixamo_mage.py
godot --headless --path godot --script tests/combat_flow_test.gd
```
