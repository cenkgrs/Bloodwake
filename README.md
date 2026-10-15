# Bloodwake

## Unity migration — in progress

**Güncel devir (15 Ekim 2026): [unity/HANDOFF_STATUS.md](unity/HANDOFF_STATUS.md).**
Kurulum, doğrulanmış durum, kalan görsel/oynanış işleri ve diğer bilgisayarda
devam adımları burada. Ayrıntılı teknik günlük: [unity/README.md](unity/README.md).

`unity/` is the new Unity 6000.3.25f1 URP project. The existing playable
Godot game remains intact below; this is not yet a completed game port.

The gameplay entry point is `Assets/Bloodwake/Scenes/Bloodwake.unity`.
`WarriorReview.unity` is an old model review, not the migrated game.
Rebuild imported assets with **Bloodwake > Build Imported Game**. The export
scripts preserve the production rigs; Warrior uses the previous
`warrior_player` source (the version before the replacement knight). Use Godot for animation, VFX behavior and existing menus; the user-supplied
ArtDirection images define the overall visual target.

Implemented: five player classes, enemy actors, eight room prefabs, source PBR
textures, world-projected room UVs, collision data, camera bounds, menus,
progression/loadouts, encounters, rewards and the night/merchant loop.
The previous class-screen artwork now supplies the portrait cards, ability
panels and ornamental buttons. All five characters use the original six-frame
entry cinematic; district entry adds the entrance walk and camera pullback.
Settings include explicit, confirmed Godot/Flutter JSON progression import
(the source save is never modified). Keyboard arrows, gamepad movement/aim,
skill bindings and auto-fire are supported alongside mouse/keyboard.
Combat ports include inherited Ruin marks, overkill-capped lifesteal, immediate
gold rewards, burn/bleed, third-swing shockwaves, chain hits, swept projectile
collision, authored Revenant hit frames and Bloodhound ultimate shot events.
The converted room prefabs use `_environment` names to avoid a Resources-key
collision with raw FBX assets. FBX conversion mirrors source X, not Z.

Validation: `Bloodwake.Editor.BuildGame.BuildAndLinux` builds the game and
checks actor/room resources. Run the Linux player with `-batchmode --smoke`
for isolated render captures and class/route checks. Captures go to
`/tmp/bloodwake-*.png`; a passed smoke test is **not** visual or gameplay parity.

Still required before user acceptance: final lighting/UI comparison; complete
combat/VFX and enemy-behavior parity; animation transitions and weapon-contact
review for every class; touch controls and graphics-settings parity.
Do not present the current build as the completed migration.

## Existing playable Godot version

PC-first dark fantasy survivor, built in **Godot 4.6.3 (standard/GDScript)**.
Open `godot/project.godot` in Godot and press F6/F5 to play. The game uses real
3D characters and skeletal animation.

See [Godot setup, controls, conventions and builds](godot/README.md) and
[latest handoff](MIGRATION_STATUS.md).

The game lives in `godot/`. Source art and the Blender/Mixamo pipelines live in
`art/`, which the tools under `godot/tools/` read from and write processed models
back into `godot/assets/`. Local engine caches and exported binaries are not
committed.

This started as a Flutter/Flame prototype. That code has been removed; the Godot
port carries the whole game, and the history is in git if an old decision ever
needs looking up.
