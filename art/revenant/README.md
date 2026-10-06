# Revenant — authored motion and blood claws

> **Current runtime model (Oct 2026):** `godot/assets/models/revenant_player.glb` is now
> built from the Tripo model in `art/revenant-astra-ready/` — see
> `art/revenant-astra-ready/deliverables/REPORT.md` for the rig, the REV_* clips, their
> event markers and how the game reads them. Everything below describes the previous
> Mixamo-based model (its last export is kept at
> `art/revenant-astra-ready/deliverables/workfiles/revenant_player_previous_game.glb`).

The current runtime model is `godot/assets/models/revenant_player.glb`.
The editable Blender project is `blender/revenant_authored.blend`.
The user-provided kit reference is `concept/revenant-kit-reference.jpg`.

Rebuild with Blender 4.5 or newer from the repository root:

```sh
blender -b -t 4 --python godot/tools/author_revenant.py
blender -b -t 4 --python godot/tools/build_revenant_vfx.py
```

`source/revenant_rigged_base.glb` is the immutable snapshot of the supplied,
previously rigged model. Rebuilding never uses its own output as input. The
original model and Mixamo files remain in `source/`.

## Motion

The builder samples the supplied full-body `Mutant Swiping.fbx`, validates identical rest
transforms against the skin and re-times the entire movement including wind-up,
step, shoulder/hip turn and follow-through. Attack2 mirrors the motion and blends
the endpoints into the common ready pose. Source wrists, fingers, elbows and legs
stay coordinated. Small spine/head offsets strengthen forward commitment.

- Idle: an upright, restrained 3.2-second breathing loop based on the reference.
- Run: a brisk stalking stride, retaining the supplied leg cycle with reduced crouch and arm swing; played over 0.72 seconds.
- Hit: short backward chest/head recoil, returning to the upright stance.
- Death: a 2.2-second collapse, followed by shader-driven blood disintegration.
- Attack1: 1.0-second source timeline, contact at 38%.
- Attack2: 1.033-second source timeline, contact at 42%.
- Teleport: a separate wind-up and late arrival swipe, contact at 0.34 seconds in gameplay.
- Ultimate: gather inward, spread both arms and lift the head, then recover.
- Dash: retained in the asset as a legacy clip; Space now casts Blood Burst.

Base gameplay plays the claws over approximately 0.58 / 0.60 seconds. Upgrades
scale this with the square root of attack-speed gain. The existing cancel window
lets the next strike start before full recovery. The former shared 1.5x combo
multiplier and cooldown cap no longer compress the whole movement to ~0.3s.

55% of the source's horizontal root movement is preserved as a visual lunge
that returns to the ready pose. Existing world collision and damage queries
remain authoritative. The Blender source retains nine selectable clips.

## Effects

`blender/revenant_claws.blend` contains three tapered claw ribbons and nine
irregular secondary ribbons. The exported GLB has longitudinal UVs for runtime
reveal, hot red cores, softer filaments and fade. Godot adds impact particles,
a short flash and fading blood stains. There are no baked Blender lights or
simulation dependencies. Mobile hides the secondary ribbon layer.

`BWFx.revenant_claws` scales with weapon reach at twice the previous horizontal visual size, reverses the reveal for the
second strike, and adds a radial wave on the existing shockwave upgrade. Impact
bursts occur only for reached targets. All effect nodes clean themselves up.

## Reference kit

- Q / Blood Step: 6 m target range, 6 s cooldown, 2.2 m landing radius, 32 base damage.
  At 0.12 s the body vanishes; at 0.24 s it reappears; at 0.34 s one area hit resolves.
  The 0.6 s cast gates movement and other casts. Immunity ends at landing contact.
  A blocked endpoint backs off toward the caster; the blink can pass obstacles,
  but its landing stays free and inside range and arena bounds.
- Space / Blood Burst: 0.5 s charge, one radial hit, 1.1 s total cast;
  3.6 m radius, 60 base damage, 10 s cooldown. No invulnerability during charge.
- E / Mark of Ruin: existing second skill retained.

Damage/range upgrades still apply. Death or a stopped run cancels delayed damage.
Both casts clear pending ordinary strikes. Movement/weapon locks end on recovery.

`blender/revenant_blood_burst.blend` contains the radial blood fountain used for
arrival and ultimate effects. Hand glows and sparse red particles follow both
hand bones. Damage adds a red impact; death swaps only this character's body
materials to a textured, noisy dissolve over 0.65–2.2 seconds. Other actors keep
their existing materials and abilities.

## Verify / preview

```sh
godot --headless --editor --path godot --import
godot --headless --path godot --script tests/revenant_test.gd
godot --headless --path godot --script tests/revenant_animation_test.gd
godot --headless --path godot --script tests/revenant_kit_test.gd
godot --path godot --fixed-fps 30 --resolution 960x720 --script tools/revenant_motion_preview.gd
```

The preview writes deterministic PNG frames under `preview/motion/`. It uses the
actual Godot model and effect shaders; the last strike is slowed for inspection.
`preview/revenant-revised.mp4` is the encoded review copy. Gameplay behavior,
root recovery, loop continuity, supporting-foot contact and VFX cleanup are covered by the
tests. Artistic quality still needs playtest feedback.

Full kit review: `tools/revenant_kit_preview.gd` (run at `--fixed-fps 30`) writes `preview/kit_review/`; the review video is `preview/revenant-kit.mp4`.
