# Current in-game Noble Revenant — OBJ

This is exported directly from the Unity character used by ActorView:
`unity/Assets/Bloodwake/Resources/Models/revenant_noble/revenant_noble.fbx`.
It is NOT the older Revenant/assassin model.

- `Revenant_Noble_Current.obj`: original rest/bind pose, 49,831 faces, UVs preserved.
- `Revenant_Noble_Current_Mixamo.zip`: OBJ + MTL + original 8K base-color texture.
- `preview.png`: render of the exported OBJ after reimport, not the source FBX.
- `validation.json`: source checksum and round-trip geometry validation.

Height normalized to 1.8 metres, feet at the origin, Y-up OBJ. OBJ has no skeleton
or animation. The original texture is already JPEG; it was copied byte-for-byte,
not converted, resized or recompressed. Game source assets were not changed.

Reproduce with Blender using `../export_current_obj.py`.
