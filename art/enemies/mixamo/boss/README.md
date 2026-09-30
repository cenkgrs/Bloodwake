# Blood Warden boss

The user supplied the character and lava greatsword in `Enemies.zip`, and uploaded
and rigged the boss in Mixamo. On 2026-09-29 the Great Sword Pack, Roar, and the
individual Great Sword Downward Slash were downloaded against that boss rig.
`clips.json` is the reproducible source-to-animation mapping and weapon attachment.

Build with Blender: `blender -b -t 4 --python godot/tools/build_mixamo_enemy.py -- boss`.
Import with Godot 4.6: `godot --headless --editor --path godot --import`.
The GLB includes ten clips and a right-hand weighted sword, at 1.8 m source height
(the game scales this boss to 3.5 m). Root motion is removed; gameplay owns movement.

The repeating pattern is Quick Strike → Sweep → Hex Volley → Charge → Heavy Slam
→ Summon. Health does not select phases. If a melee step cannot reach the player
for 2.5 seconds, an extra charge closes the gap without consuming that step.

| Attack | Source | Warning | Recovery | Damage multiplier |
| --- | --- | --- | --- | --- |
| Quick Strike | Great Sword Hilt Melee | 0.38 s; 70° sector, 2.8 m | 0.42 s | 1.0 |
| Heavy Slam | Great Sword Downward Slash | 1.25 s; 4.2 m circle | 0.90 s | 2.0 |
| Sweep | Great Sword High Spin Attack | 0.80 s; 270° sector, 3.8 m | 0.65 s | 1.2 |
| Charge | Great Sword Slide Attack | 0.90 s; 8 × 2 m lane | 0.60 s after 0.60 s lunge | 1.35, once |
| Hex Volley | Great Sword Casting | 1.00 s; three fixed aiming rays | 0.65 s | 0.7 per missile |
| Summon | Roar | 1.50 s; green ring + ten spawn portals | 0.80 s | Ten grunts; no direct damage |

`godot/scripts/boss.gd` owns the timings and contact fractions. Directions lock at
the start of warnings; normal hits cannot interrupt the performance; death cancels
pending damage and warnings. Each summon adds ten grunts, including when earlier adds are still alive; there
is no hidden periodic timer. Charge stops at obstacles and checks the swept movement segment.

Validation:
- `godot --headless --path godot --script res://tests/boss_pattern_test.gd`
- `godot --headless --path godot --script res://tests/enemy_asset_test.gd`
- `godot --path godot --script res://tools/preview_boss.gd` captures four warnings.
- `godot --path godot --script res://tools/preview_boss.gd -- --play` starts a boss fight.

The boss now has 2700 base HP. The HUD displays only its name and health.
Ground tells use an additive procedural ember shader: fixed collision borders,
flickering inner glow and faint fractures; impacts expand and fade with sparks.

Base damage is 65 (quick strike 65, slam 130, sweep 78, charge 87.75,
volley 45.5 per missile, before player armor). Summon portals alternate 4.6 m
and 6 m from the boss to spread the ten arrivals around it.

Ordinary enemies have stable direct/left/right pursuit roles, predict up to
1.5 seconds of measured player travel, and collapse their flank offsets near
melee contact. Two of every three ordinary arrivals prefer the escape direction;
the existing wave quota and spawn interval remain authoritative. Alternate arrival
bearings avoid crowding and keep at least 7.5 m away even at arena corners.

Boss summons now use a separate two-waypoint approach: two adds rush directly,
eight fan out 4.4–5.6 m to their spawn-side flank, then move to a front-side
position before joining ordinary melee pursuit. Their approach gets a 1.35x
speed factor outside 2.5 m to compensate for the longer route. Each waypoint
has a seven-second timeout so blocked adds cannot orbit forever. Normal wave
units do not receive these routes or the speed factor.

`tests/summon_motion_test.gd` advances the actual summoned enemies for nine
seconds and checks sustained bilateral spread, reaching the front and returning
to melee. `tools/preview_summon.gd` captures their approach with arena obstacles.
