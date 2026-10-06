# Rooms, maps and the hunt

## Flow

Title → class select → **safehouse** → war table (map select) → run intro →
room 1 … room N → boss → **Night Merchant** → night 2 on the same route (harder) → …

Death or abandoning a hunt returns to the safehouse. The safehouse is a walkable
room: the Quartermaster keeps builds and the armory, the Blood Sage keeps the
skill tree, and the War Table lists the maps.

Each room runs `entry → active → cleared` (fights) or `hub` (safehouse, merchant):

- **entry**: the player stands at `EntrySpawn`, the entrance is open behind them,
  nothing spawns for 1.5 s (0.5 s after the opening cinematic).
- **active**: both doors shut; the room fights its `encounter.waves` in turn
  (two waves of five in most rooms, three at the station). Each body rises out
  of the street at an `EnemySpawn_*` marker inside a column of smoke and cannot
  be hit or targeted until it stands. A wave starts 1.6 s after the last one dies.
- **cleared**: only when the last wave has spawned *and* nothing in the room is
  alive (boss adds included). No menu opens. XP is collected.
- **reward**: the `RewardPoint` pedestal lights if there is something to take:
  boss spoils (required — the gate stays shut until claimed) or a blood shrine
  with pending level choices (optional — the exit is already open). Each is
  claimable once per room visit.
- **exit**: walking into `ExitTrigger` while the exit is open fades to the next
  room. Health, build, items, gold and progress live on `BWRun` and carry over;
  enemies, projectiles, drops, telegraphs and effects of the old room are freed.

After the boss the run passes through the merchant room. Goods there last only
for the run. Every night raises the merchant's grade (x1.0, x1.6, x2.2 … effect
strength), drops common stock, adds night-only goods (`minNight` in the items
catalog) and lets owned goods be tempered to the new grade. Enemies scale with
the number of fights entered (`run.wave`), rooms field one extra body per night
from `encounter.perNight`, and the boss gains a tier per night.

## Data

- `data/rooms.json` (and any `data/rooms/*.json`) — the room pool. No upper
  bound; only the active room is built or loaded.
- `data/maps.json` (and any `data/maps/*.json`) — maps. `route` lists the
  ordinary rooms of a night in order; its length is the number of fights before
  the boss, independent of how many rooms the pool holds. A map may instead use
  `draw: {region, count}` to pick that many rooms of a region each night.

Adding a room is a data entry (plus, later, its scene). Adding a map with a
different environment is a new region's rooms plus a map entry; it then appears
on the war table. `tests/room_flow_test.gd` registers a seventh room and a route
for it without touching core code.

Room record fields: `id`, `name`, `region`, `type` (`combat`, `boss`,
`merchant`, `safehouse`), `scene`, `size` [width, depth] of the playable
interior, `light`, `doors.entrance/exit.at`, `markers`, `layout`, `landmarks`,
`hosts`, `encounter {waves, perNight, cap, interval}` (a single `roster` also works). Coordinates are metres,
room-local, origin at the centre of the floor, +x east, −z north.

## Surfaces and the model kit

Grey-box rooms are textured with tileable PBR surfaces from
`tools/gen_room_textures.py` (cobble, ashlar, planks, crate, half-timber,
slate, iron, cloth) in `assets/textures/rooms/`, mapped in world space. Each
piece of the grey box (walls, gates, houses, cargo, stalls, well, troughs,
divider, plinths, hearth, war table, pedestal, landmarks) is replaced by a model
as soon as its file listed in `data/room_kit.json` exists. Prompts and sizes for
every piece: `docs/room_kit_prompts.md`.

## Delivering a room from Blender

Until `scene` points at an existing file the room is grey-boxed from its data.
When the `.glb` exists it is instanced instead, and the loader reads:

| What | Convention |
| --- | --- |
| Markers | Empties named `EntrySpawn`, `EntranceDoor`, `ExitDoor`, `ExitTrigger`, `RewardPoint`, `EnemySpawn_01`…, `BossSpawn`, `BossArenaCenter` |
| ExitTrigger | A mesh or scaled empty; its footprint is the crossing zone. If absent it is derived from `ExitDoor` (6 m wide, 2.4 m deep) |
| Collision | Meshes under a node named `Collision`, meshes named `COL_*`, or `-colonly` objects. Their ground footprints become obstacles and they are hidden |
| Doors | Leaves named `EntranceLeaf_L/_R`, `ExitLeaf_L/_R`, origin on the hinge, modelled closed. Open = ±100° about Y, swinging out of the room |
| Camera side | Anything under `CameraSide` or named `CamWall_*` can be hidden by the camera |

The game has no physics engine: obstacles are axis-aligned footprints, so keep
collision proxies as simple boxes. Navigation is a 1 m flow field built in Godot
from those footprints. Every room is validated on load (`BWRoomArena.check`):
required markers present, points on the floor and outside obstacles, and every
spawn, the reward point and the exit reachable from `EntrySpawn`. Problems are
printed as warnings; missing markers fall back to the data record. The Blender
export alone is not proof a room works — run `tests/room_flow_test.gd` and play
it.

`godot --path godot -- --rooms` captures every room from the play camera, from
overhead and isometrically into `user://`.
