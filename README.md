# Bloodwake

**Güncel devir (15 Ekim 2026): [unity/HANDOFF_STATUS.md](unity/HANDOFF_STATUS.md).**
Kurulum, doğrulanmış durum, kalan görsel/oynanış işleri ve diğer bilgisayarda
devam adımları burada. Ayrıntılı teknik günlük: [unity/README.md](unity/README.md).

`unity/` is the Unity 6000.3.25f1 URP project and the only game in this
repository. The earlier Godot and Flutter versions were removed; their history
is in git.

The gameplay entry point is `Assets/Bloodwake/Scenes/Bloodwake.unity`.
`WarriorReview.unity` is an old model review, not the game.
Rebuild imported assets with **Bloodwake > Build Imported Game**. Warrior uses
the `warrior_player` source (the version before the replacement knight). The
user-supplied ArtDirection images define the overall visual target.

Implemented: four player classes (Revenant, Vesper, Warrior, Mage), enemy
actors, eight room prefabs, source PBR textures, world-projected room UVs,
collision data, camera bounds, menus, progression/loadouts, encounters, rewards
and the district loop: the war table enters the route directly, each
route → boss → merchant pass is one harder district, and the tenth boss wins the run. The class-screen artwork supplies the portrait
cards, ability panels and ornamental buttons. All characters use the six-frame
entry cinematic; district entry adds the entrance walk and camera pullback.
Keyboard arrows, gamepad movement/aim, skill bindings and auto-fire are
supported alongside mouse/keyboard. Combat includes inherited Ruin marks,
overkill-capped lifesteal, immediate gold rewards, burn/bleed, third-swing
shockwaves, chain hits, swept projectile collision and authored Revenant hit
frames. The converted room prefabs use `_environment` names to avoid a
Resources-key collision with raw FBX assets. FBX conversion mirrors source X,
not Z.

Validation: `Bloodwake.Editor.BuildGame.BuildAndLinux` builds the game and
checks actor/room resources. Run the Linux player with `-batchmode --smoke`
for isolated render captures and class/route checks. Captures go to
`/tmp/bloodwake-*.png`; a passed smoke test is **not** visual or gameplay
acceptance.

Still required before user acceptance: final lighting/UI comparison; complete
combat/VFX and enemy-behavior review; animation transitions and weapon-contact
review for every class; touch controls and graphics settings.

Source art and the Blender/Mixamo pipelines live in `art/`; the scripts under
`unity/` read from there and write processed models into
`unity/Assets/Bloodwake/Resources/`.
