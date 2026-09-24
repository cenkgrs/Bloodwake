# Bloodbound

Dark fantasy redesign of the ranged Gunslinger class. The stable internal
ID remains `CharacterClass.gunslinger`; the display name is Bloodbound.

## Sources

- `source/bloodbound_animated.glb`: latest user delivery with all five clips,
  copied byte-for-byte from Downloads. Do not overwrite during rendering.
- `source/bloodbound_game.glb`: generated version with normalized action
  names and in-place horizontal motion for run/death; helper mesh excluded.
- `source/bloodbound_render.blend`: generated editable render scene.
- `source/bloodbound.glb`: earlier rig-only model, retained for reference.
- `source/bloodbound_animated_original.glb`: earlier four-clip delivery.

Clips map to `idle`, `run`, `attack`, `hit`, `death`. Long prompt-based names
map to attack/hit; `fall` maps to death. Source durations are preserved:
15.333 s idle, 1.25 s run, 0.958 s attack, 0.958 s hit, 3 s death.
Idle/run loop; attack/hit/death play once. Automatic fire does not restart
an active attack clip; later shots can restart a completed one.

The source run travels forward and death travels sideways. Rendering
removes horizontal hip translation through the rest-bone coordinate basis,
preserving vertical movement and rotations. This keeps the sprite anchored
to the game entity. The original source remains untouched.

## Rebuild

```sh
/path/to/blender -b -t 4 --python art/bloodbound/render.py -- --preview
python3 art/bloodbound/package.py --preview
/path/to/blender -b -t 4 --python art/bloodbound/render.py
python3 art/bloodbound/package.py
```

Delete `frames/` before regenerating after a camera, model, or animation
change: completed final frames are reused to support interrupted renders.
All states share one orthographic camera, scale and lighting. Final frames
render at 256 px then downsample to 128 px. Atlases have at most 16 columns;
`animations.json` records frame count, dimensions, duration and loop flags.
The Flame animator consumes the atlases at
`assets/images/characters/bloodbound/`. The selection screen uses a separate
portrait. The GLB is a source asset and is not loaded by the 2D runtime.

Review `review/contact.jpg` or `frames/contact.jpg` and the per-clip GIFs.
The asset test checks actual bundled image decoding, atlas frame bounds,
clip duration and loop/one-shot playback. The old procedural Gunslinger
builder targets the old sprite folder and cannot overwrite these atlases.
