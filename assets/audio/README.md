# Audio assets

`SfxPlayer` (`lib/game/systems/audio/sfx_player.dart`) is wired at every
trigger point below. Every call is wrapped so a missing file is silently
ignored — nothing crashes if one goes missing. Weapon/ability sounds are
resolved through `WeaponSfx` (`lib/game/systems/audio/weapon_sfx.dart`),
keyed by the same `WeaponData.id` values the weapon catalog already uses —
a weapon with no entry there (including any future weapon) automatically
falls back to the generic sound instead of staying silent.

## General

| File               | Triggered by                                      |
|--------------------|----------------------------------------------------|
| `shoot.mp3`        | Fallback fire sound for any weapon with no dedicated one (see mapping below) |
| `hit.mp3`          | Fallback hit sound for any hit with no dedicated impact sound |
| `enemy_death.mp3`  | An enemy dies                                       |
| `player_hit.mp3`   | The player takes damage                             |
| `game_over.mp3`    | The player dies                                     |
| `level_up.mp3`     | Level-up screen opens                               |
| `upgrade_pick.mp3` | An upgrade card is chosen                           |
| `purchase.mp3`     | An item is bought in the shop                       |
| `boss_phase.mp3`   | The boss transitions to a new phase                 |
| `boss_death.mp3`   | The boss dies                                       |

## Weapon fire/cast sounds (`WeaponSfx.fireSounds`)

Played once per attack cycle, in `PlayerWeapons.update`.

| Weapon         | File                  |
|----------------|------------------------|
| Basic Pistol   | `shoot_pistol.mp3`     |
| Rapid Rifle    | `shoot_rifle.mp3`      |
| Shotgun        | `shoot_shotgun.mp3`    |
| Sword          | `sword_swing.mp3`      |
| Magic Orb      | `magic_orb_cast.mp3`   |
| Lightning      | `lightning_cast.mp3` (also the "initial activation" cue for a Chain Lightning cast — see below) |
| *(unmapped)*   | `shoot.mp3`             |

## Weapon impact sounds (`WeaponSfx.impactSounds`)

Played once per enemy hit, in `Enemy.applyDamage`. Only Sword and Magic Orb
have a dedicated impact — everything else (Pistol/Rifle/Shotgun/Lightning,
and any future weapon) uses the generic `hit.mp3`. A hit never plays both
the generic and a dedicated impact sound for the same moment.

| Weapon         | File                    |
|----------------|--------------------------|
| Sword          | `sword_impact.mp3`       |
| Magic Orb      | `magic_orb_impact.mp3`   |
| *(everything else)* | `hit.mp3`           |

## Chain Lightning

`chain_lightning.mp3` plays for each chain jump *after* the first target —
the first target's hit is the `lightning_cast.mp3` "initial activation"
already covered above, not a separate proc sound.

## Throttling

A survivor-style wave can hit or kill a dozen enemies in the same frame,
so a few sounds are rate-limited per file (`SfxPlayer._throttleMs`) rather
than letting every instance stack on top of each other:

| File                    | Minimum gap between plays |
|--------------------------|---------------------------|
| `hit.mp3`                | 60ms                       |
| `enemy_death.mp3`        | 80ms                       |
| `shoot_rifle.mp3`        | 70ms                       |
| `chain_lightning.mp3`    | 50ms                       |
| `sword_impact.mp3`       | 60ms                       |
| `magic_orb_impact.mp3`   | 60ms                       |

Everything else (level up, purchase, boss phase, single-target casts...)
is naturally rare enough per run that it's never throttled.

Free sources with permissive licenses: freesound.org, kenney.nl (game asset
packs, includes SFX), opengameart.org. `.mp3`, `.wav`, and `.ogg` all work.
