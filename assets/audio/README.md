# Audio assets

`SfxPlayer` (`lib/game/systems/audio/sfx_player.dart`) is already wired at every
trigger point below. Every call is wrapped so a missing file is silently
ignored — nothing crashes today because none of these exist yet. Drop a file
with the exact name in this folder and it activates immediately, no code
changes needed.

| File              | Triggered by                                      |
|--------------------|----------------------------------------------------|
| `shoot.mp3`        | Player weapon/ability fires                        |
| `hit.mp3`          | An enemy takes damage                               |
| `enemy_death.mp3`  | An enemy dies                                       |
| `player_hit.mp3`   | The player takes damage                             |
| `game_over.mp3`    | The player dies                                     |
| `level_up.mp3`     | Level-up screen opens                               |
| `upgrade_pick.mp3` | An upgrade card is chosen                           |
| `purchase.mp3`     | An item is bought in the shop                       |
| `boss_phase.mp3`   | The boss transitions to a new phase                 |
| `boss_death.mp3`   | The boss dies                                       |

Free sources with permissive licenses: freesound.org, kenney.nl (game asset
packs, includes SFX), opengameart.org. `.mp3`, `.wav`, and `.ogg` all work.
