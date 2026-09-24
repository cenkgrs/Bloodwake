# Bloodwake handoff — 2026-09-24 checkpoint

## Requested direction
Move the entire game from Flutter/Flame to Godot with PC as the primary
platform, real 3D actors, and an optimized mobile profile later. Preserve
existing game systems. User also requested commits and a concise handoff
so work can continue on another computer.

## Working baseline
Flutter Android build is working. Bloodbound replaces the visible
Gunslinger name (internal ID remains `gunslinger`). Its latest model is
`art/bloodbound/source/bloodbound_animated.glb`, with five animations.
`bloodbound_game.glb` normalizes clip names and removes horizontal run/death
root travel. Original delivery remains untouched. 298 rendered frames feed
five atlases in `assets/images/characters/bloodbound/`. Class preview uses
`portrait.png`. Relevant 11 Flutter tests passed; APK was installed and
observed running on Pixel_7. Single-angle sprites still cannot face upward;
this limitation motivated migration. Do not regenerate the old procedural
Gunslinger and confuse it with the new imported model.

## Godot checkpoint — NOT YET PLAYABLE
`godot/project.godot` targets Godot 4.6.3 standard/GDScript. Godot binary was
downloaded from the official release into `/tmp/bloodwake-godot/` (not in
Git; install Godot 4.6.3 on the next machine).

Created:
- Engine-neutral `godot/data/catalogs.json`: 7 weapons, 4 abilities,
  7 enemies including boss, 22 upgrades, 11 shop items, 9 permanent
  equipment items, 15 skill-tree nodes, extracted from actual Dart code.
- `scripts/data.gd`, `meta.gd`, `run_state.gd`: class stats, wave formulas,
  item/upgrade gates and effects, XP, damage, persistent progression,
  equipment and three loadouts. Not yet validated by Godot.
- Real Bloodbound, existing Assassin and exported existing Warrior GLBs,
  audio, floor texture, title font copied into `godot/assets/`.
- `scenes/main.tscn` exists but references `scripts/main.gd`, which is not
  written yet. This is an intermediate migration checkpoint.

## Next work
1. Build 3D actor/animation layer; inspect model axes, bounds and clips.
2. Port real-time world: movement, aiming, seven weapon behaviors,
   abilities, enemies/support AI, elites, boss phases, telegraphs,
   projectiles, statuses, pickups, endless waves and intermission.
3. Implement menus, class select, HUD, upgrade/shop flow, skill tree,
   armory/loadouts, pause, settings, PC/gamepad and mobile input.
4. Add Godot tests and headless smoke tests; verify real rendered scene.
5. Produce a runnable PC build and document platform export profiles.
6. Update this document and commit the final migration state.

Keep Flutter sources as a reference until Godot parity is validated.
`DEVELOPMENT_PLAN.md` is older and stale: trust current Dart code/tests,
not its claims that persistence or commander enemies do not exist.
