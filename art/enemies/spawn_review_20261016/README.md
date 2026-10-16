# Red-mist enemy emergence — Unity validation, 16 October 2026

Latest revision: `soft/` contains the softened, mist-feathered opening after
the user rejected the hard outline. Its result also verifies Noble Revenant
Space starts 15% into its existing clip, with matching audio offset and actual
animation contact event. The captures at the root of this folder are the
earlier hard-rim version, retained only for comparison.

Actual Gateyard camera renders from `EnemyEmergenceReview`, not concept art.
Frames use a deterministic 1/60 s game/effect step inside the running Unity
editor. 008 warning; 029 head emerging; 044 torso; 071 nearly standing;
140 effects gone. Player was moved aside for the capture. `result.txt` records
the successful logic checks. No continuous real-time video was recorded.

Review entry: Bloodwake > Tests > Enemy emergence review. Also accepts
`Library/EnemyEmergenceReview.request`; consumed immediately. Batch entry:
`Bloodwake.Editor.EnemyEmergenceReview.RunBatch` (only with this project closed
in another editor). Captures are initially written to
`/tmp/bloodwake-enemy-emergence` and copied here after review.

Checks: hidden anticipation, below-floor visual offset, root position and
NavMesh stability, no early movement/attack, damage/recoil immunity, grounded
finish, damage enabled afterward, pause/hit-stop VFX clock, effect cleanup,
monotonic rise and total duration at 30/60/144/360 FPS. At completion the
test restores fresh Revenant/one-Warrior infinite-HP practice.
