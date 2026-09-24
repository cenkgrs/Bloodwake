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
| Weapons, upgrades, inventory, XP and damage stats | `scripts/run_state.gd` |
| Persistence, skill tree, equipment and three loadouts | `scripts/meta.gd` |
| 3D movement, aiming, weapons, enemies, bosses, waves | `scripts/world.gd` |
| Model loading, bounds, skeletal clips and blending | `scripts/visual.gd` |
| Menus, HUD, shop, rewards, pause, settings | `scripts/main.gd` |
| Touch input | `scripts/touch_controls.gd` |

The Dart catalogs were extracted with `tools/migrate_catalogs.py`: 7 weapons,
4 abilities, 7 enemy types, 22 upgrades, 11 shop items, 9 permanent equipment
items and 15 skill nodes. Distances use 50 legacy pixels per world meter.
Basic grunt melee damage is 8 (also updated in the source Dart catalog). The port is playable, but this is not a claim of pixel-perfect or
exhaustively verified behavioral equivalence with Flutter.

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

## Verification

```sh
godot --headless --path godot --script tests/test_suite.gd
godot --headless --path godot -- --smoke
godot --path godot -- --qa
```

The suite checks catalogs, upgrade gates, purchases, XP, persistence, equipment,
all class/enemy instantiation and intermission flow. `--smoke` runs a short combat
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
