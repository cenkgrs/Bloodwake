# Altar environment assets

Five user-supplied props, copied from `art/enviroment/altar/` (original spelling).
Original archives and GLBs are preserved in `source/`.

Runtime GLBs: `godot/assets/models/environment/altar/`.
- pillar: broken gothic column, used in courtyard and Blood Altar.
- brazier: iron bowl, keeps the arena's ember glow and PC light.
- bones: scattered bone piles, used in ossuary and Blood Altar.
- urn: clay pot, retains breakable behavior.
- altar: one stone altar at the Blood Altar district, offset from the fight centre.

Each GLB contains one upright, grounded mesh, no camera, light or added platform.
Original PBR materials are retained; runtime textures are capped at 1024 pixels
and geometry at approximately 8000 triangles. Godot fits each mesh to its existing
height and collision footprint. Extracted texture files are kept alongside GLBs
because the project's Godot import settings reference them.

Rebuild locally (no API calls):
`blender -b -t 4 --python godot/tools/build_altar_props.py`

Checks: `godot --headless --path godot --script res://tests/altar_props_test.gd`.
Capture the actual game camera: `godot --path godot --script res://tools/preview_altar.gd`.
Result: `ingame_preview.png`.
