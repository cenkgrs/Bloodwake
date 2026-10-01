# Arcane VFX

The supplied designs are in `references/`. Runtime effects use four small Godot
Compatibility shaders; no generated illustration is pasted over gameplay.

- Player: cyan/turquoise energy, deep-blue accents. Enemy mage: magenta energy,
  violet shadows and crimson trails. The hand, projectile and impact share a palette.
- Orb: moving energy core, three rotating curved shell pieces, crossed streaming
  plasma sheets and a small halo. Enemy bolt retains its original 0.16 m hit radius;
  the player orb retains 0.5 m. Damage, projectile speed and range are unchanged.
- Nova and meteor impact: concentric etched glyphs, expanding pressure front,
  irregular rising flame crown and small fading motes. Nova has a short charge
  sigil during its existing animation windup. Rings stay within the ability radius.
- Melee: tapered crescent instead of a rectangular glow. Common healing pulses
  and shockwaves use a broken wavefront instead of a filled light blob.
- Ground rune markers are removed immediately when the rune is destroyed or the
  wave clears. Effect tweens belong to their transient nodes.

`godot/tools/vfx_compare.gd` renders repeatable effect scenarios to `VFX_SHOT_DIR`.
`preview/` contains real in-game captures. `vfx_stress.gd` exercises twelve mixed
projectiles per second and an arcane blast every 0.75 seconds. On the local RTX 4090,
Compatibility renderer, the 10-second sample after a 2-second warmup had 601 frames:
mean 16.67 ms, p99 17.21 ms, maximum 20.34 ms, no frames above 80 ms, and up to 20
simultaneous projectiles. This is a local test, not a minimum-spec guarantee.

Validation: VFX lifecycle (PC and reduced profile), enemy mage, mage movement,
class kit, combat flow and skirmish suites. Low profile reduces tail sheets, flame
crown pieces and particles; transient cleanup is checked for both profiles.
