# Bloodhound game-ready animation report

- Source: `source/bloodbound_render.blend`
- Timeline: 60 FPS
- Engine target: Godot GLB; Unity/Unreal FBX also included.
- Root: `GameRoot`, fixed on the horizontal plane.
- Non-deforming sockets: `socket_weapon_R`, `socket_weapon_L`, `socket_bomb_L`.

## Actions

| Action | Frames | Loop | Events |
|---|---:|:---:|---|
| BH_Idle | 1–72 | yes | — |
| BH_Walk_InPlace | 1–32 | yes | — |
| BH_GetHit | 1–18 | no | — |
| BH_Death | 1–60 | no | — |
| BH_FiveShot | 1–42 | no | FIRE_01@10, FIRE_02@14, FIRE_03@18, FIRE_04@22, FIRE_05@26 |
| BH_BombThrow | 1–50 | no | THROW_RELEASE@20 |
| BH_Ultimate_BloodWake | 1–108 | no | ULT_FIRE_01@30, ULT_FIRE_02@36, ULT_FIRE_03@42, ULT_FIRE_04@48, ULT_FIRE_05@54, ULT_FIRE_06@60, ULT_FIRE_07@66, ULT_FIRE_08@72, ULT_FIRE_09@78, ULT_FIRE_10@82 |

## QA

- Loop matrix errors: `{'BH_Idle': 0.0, 'BH_Walk_InPlace': 0.0}` (0.0 means an exact seam).
- Three-angle stills are in `qa/`; each Action has a 3/4 MP4 in `previews/`.
- GLB and FBX are re-imported by `validate_bloodhound_export.py`; see `reimport_validation.json`.

## Known limitations

- The six requested `outputs/bloodhound-*` design references were not present in the workspace.
- The supplied character is a single skinned mesh. Hat, coat, scarf and revolvers cannot be made independent rigid props without destructive mesh/UV/weight surgery; socket bones were added for future engine props.
- Cloth/scarf follow-through is inherited through the supplied skin weights because the rig has no dedicated cloth or accessory bones.
