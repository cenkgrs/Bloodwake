# Bloodwake Warrior — character production brief

Status: art direction only. `warrior_art_direction.png` is a visual reference,
not a 3D model or a verified orthographic turnaround. The back view in the
generated reference is inaccurate; the modeler must design the actual back.

## Free-source evaluation (September 2026)

The official Quaternius CC0 RPG Characters Warrior `.blend` and Animated Knight
accessories are saved under `source/`. Blender render code is in
`render_preview.py`; `preview/compare.html` plays the 22-frame idle/run/attack
test. The source has one real rig and coherent motion. It fails this project's
visual acceptance gate: the body is lightly armored, the head/helmet has no
closed visor, the silhouette lacks the original heavy plate and crimson cloth,
and the low-poly detail disappears at game scale. For an explicit in-game
playtest, the Warrior animator temporarily loads the rig test PNG frames from
`assets/images/characters/warrior_rig_test/`. This is a motion/technical
reference, not approved production art.

Next art step using only free tools: remodel and texture the existing rig in
Blender to match `warrior_art_direction.png`, then use the same render camera
and action pipeline. Recheck all five actions over the actual arena before
changing the Flame asset loader.

Source references and licenses:

- Quaternius RPG Characters (CC0): https://quaternius.com/packs/rpgcharacters.html
- Quaternius Animated Knight accessories (CC0): https://quaternius.com/packs/knightcharacter.html
- OpenGameArt Knight by crownjoshua (CC0, `source/OGA_Knight.blend`):
  https://opengameart.org/content/knight-rigged-mid-poly . This file has more
  armor geometry, but its older Rigify rig reports missing bone constraint
  targets in Blender 4.5 and contains no gameplay walk/attack actions. It is
  a geometry reference, not a ready animation replacement.

## Goal

Replace the current unrelated AI-generated PNG frames with animation rendered
from one rigged character. Preserve the recognizable blackened plate armor,
layered pauldrons, crimson cloth, closed helmet, red ember details, and heavy
one-handed sword. The character must read at the game's current ~96 world-unit
display size over dark blue-gray cobblestones.

## Source deliverables

- Editable native 3D scene, mesh, textures, materials, armature, and sword.
- One shared rig for every animation. No pose-by-pose AI redraws.
- Separate actions: idle, run, sword attack, hit, death. Root/feet remain
  aligned; the run cycle loops without a visible jump.
- Sword attack has anticipation, impact, and recovery. Export the impact frame
  index so game damage/VFX can synchronize with it.
- Armor plates follow the body without intersections; cloth has secondary
  motion; sword remains attached to the hand.
- Source license permits commercial game distribution and derivative work.

## Render contract for Flame

- Orthographic 3/4 top-down camera, locked for every action and direction.
- Transparent RGBA PNG frames. No floor, fake checkerboard, rectangle, border,
  baked contact shadow, vignette, or text. The game draws the contact shadow.
- Same canvas size, subject scale, camera angle, lighting, and foot anchor in
  every frame. Keep source frames at least 256x256 before atlas packing.
- Start with one facing direction for a motion-quality review, then render
  the gameplay directions from the same model. A horizontal flip is acceptable
  only after verifying sword hand and armor asymmetry.
- Review at 100%, 50%, and final in-game scale over `assets/images/backgrounds/map1.png`.

## Acceptance gate

1. Idle holds the same anatomy and silhouette for a full loop.
2. Run looks grounded, with no sliding or size change.
3. Attack has readable wind-up and recovery; gameplay hit timing matches impact.
4. Switching idle/run/attack/hit/death does not jump camera, foot anchor, or
   character scale.
5. No gray fringe or rectangular artifact is visible over both light and dark
   areas of the arena.
6. Inspect the exported sequence in the actual Flutter game before accepting
   the art. A still image or concept sheet does not satisfy this gate.

## Current project state

The runtime currently reads `assets/images/characters/warrior/{idle,run,attack,hit,death}.png`
as five-frame strips. Idle/run are held on one frame and automatic attack pose
playback is disabled because the existing frames change anatomy and camera.
The new asset format and playback timing should be implemented when source
animations exist, preserving the old strips only as a reversible fallback.
