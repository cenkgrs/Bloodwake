# Character sprites

Looked up by `CharacterSpriteAnimator` (`lib/game/player/character_sprite_animator.dart`)
via each class's `spriteFolder` in `CharacterClassCatalog`
(`lib/game/player/character_class.dart`).

## Structure (extendable — add a new folder + catalog entry for a new class)

```
assets/images/characters/<class>/
  idle.png
  run.png
  attack.png
  hit.png
  death.png
```

Each file: PNG, transparent background, 640x128 — a horizontal strip of
exactly 5 frames, 128x128 each, pseudo-isometric 3/4 top-down. Character
stays centered and at the same scale/baseline across all 5 frames of a
file (see the generation prompt this pack was built from, kept below for
reuse when adding a new class).

Adding a new class is data-only once its 5 files exist: a new
`CharacterClassData` entry in `CharacterClassCatalog` pointing at its
folder — no changes needed in the animator itself.

## Current classes

- `warrior` — melee, durable, close combat
- `gunslinger` — ranged, high DPS, mobility
- `mage` — area damage, elemental, control
- `assassin` — fast, high crit, evasion
