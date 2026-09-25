# Enemy asset import

User archive: `/home/cenkargevim/Desktop/Cenk/Enemies.zip`.

- `source/`: original FBXs, PBR textures, and reference sheets (unchanged).
- `mixamo_upload/<id>/`: character OBJ, MTL, diffuse texture; no weapon or skeleton.
- `mixamo_upload/<id>_mixamo.zip`: one complete package to upload to Mixamo.
- `weapons_obj/<id>/`: separate weapon OBJ, MTL, diffuse texture.
- `weapons_obj/<id>_weapon.zip`: portable weapon package.
- `manifest.json`: source paths, mesh counts, UV and conversion metadata.
- `preview/`: front renders of exported geometry and supplied weapon references.

Rebuild with Blender:

```sh
blender -b -t 4 --python godot/tools/prepare_enemy_obj.py
```

All 14 OBJ files have been checked for nonempty geometry, finite vertices, UVs,
resolvable MTL/texture references, and valid ZIP archives. Characters are grounded,
centered, and exported at 1.8 m in Y-up coordinates. Original PBR maps remain in
`source/` for the final Godot materials; the upload ZIP uses diffuse only.

Runtime mapping: Warrior -> grunt, Assasin -> assassin; other IDs retain their
lowercase names. The duplicate Healer.zip inside the archive was skipped because
the expanded Healer source directory is already present.

Mixamo rigging/animation and final runtime integration are in progress. Static
OBJ conversion alone is not a rigged/animated runtime asset.

## Integrated characters

- Warrior (`grunt`): 65-bone Mixamo rig; Idle, Run, Attack, Hit, Death; original armor PBR and rigid right-hand sword. Runtime `enemy_warrior.glb`. Attack 0.45 s, run 0.65 s, death 2.2 s.
- Healer: 65-bone Mixamo rig, five magic/locomotion/reaction clips, original PBR and left-hand lantern staff; right hand casts spells.
- Other five characters: static conversion complete; Mixamo rig and integration pending.

Build a character: `blender -b -t 4 --python godot/tools/build_mixamo_enemy.py -- warrior`.
The per-character `mixamo/<id>/clips.json` selects the downloaded FBXs and records weapon placement.
