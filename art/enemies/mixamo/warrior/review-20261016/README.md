# Warrior crowd / hit feedback review — 2026-10-16

## Current pressure regression

`crowd-pressure.mp4` supersedes the old distance-only crowd review below.
15 fps diagnostic capture, 38 seconds, three overlapping spawn requests and
two player relocations. Minimum centre gap: 1.326 m. Actual contact counts:
20 / 24 / 20; all three re-engage after the final relocation. The test now
rejects Warriors standing in attack range without landing attacks.
Runtime steering is 320 degrees/second and the authored turn plays at 1.2x.
An additional live surrounding-spawn run passed: minimum gap 1.325 m,
contacts 23 / 25 / 19. Both runs require renewed attacks after player relocation.
The currently selected sword recording is the user's `sword_clash-7.wav`,
connected to player/enemy contact markers; the procedural auditions remain rejected.

## Historical review (insufficient combat-liveness coverage)

`EnemyCrowdReview.cs` runs native Unity NavMesh agents on real engine frames.
Three Warriors are requested at the same spawn point. The target stands still,
moves sideways at 14 s, then behind the crowd at 24 s. Total simulation: 38 s.
Capture sampling: 2 fps (this is a diagnostic timelapse, not smooth gameplay).

The one-Warrior practice scene is restored after testing. F8 toggles one/three
Warriors; both sides retain infinite HP and the player has no skill cooldowns.

The separate WarriorAttackReview passed slash markers/sequence/interruptions,
180-degree turns at 30/60/144/240/360 fps, and signed angle sweeps at
30/60/144/360 fps, including attack entry and retargeting during a turn.

Audio auditions live in `../audio-review/`, not Unity Resources. They are
original procedural synthesis and require user approval. The existing sword
sound was explicitly rejected and is NOT wired to enemy Warrior attacks.
