/// Weapon-id -> dedicated sound asset lookup. Keyed by the same stable ids
/// WeaponData already uses (see weapon_data.dart) instead of a parallel
/// enum, so a new weapon never needs a second place to register its id.
///
/// A weapon id with no entry in a given map isn't an error — it just means
/// that weapon has no dedicated sound for that moment (yet, or ever), and
/// the caller (SfxPlayer) falls back to the generic shoot/hit sound. That
/// covers every current and future weapon automatically: nothing here
/// needs to change for a new weapon to at least make *a* sound.
class WeaponSfx {
  WeaponSfx._();

  /// Played once when a weapon fires (PlayerWeapons.update, after the
  /// attack resolves). For Lightning this doubles as the "initial
  /// activation" cue — see SfxPlayer.chainLightningProc for the sound each
  /// extra chain jump beyond the first target gets instead.
  static const Map<String, String> fireSounds = {
    'basic_pistol': 'shoot_pistol.mp3',
    'rapid_rifle': 'shoot_rifle.mp3',
    'shotgun': 'shoot_shotgun.mp3',
    'sword': 'sword_swing.mp3',
    'magic_orb': 'magic_orb_cast.mp3',
    'lightning': 'lightning_cast.mp3',
  };

  /// Played once per enemy hit (Enemy.applyDamage), instead of the generic
  /// hit sound, for weapons whose impact should sound distinct from a
  /// plain projectile hit. Deliberately not exhaustive — Pistol/Rifle/
  /// Shotgun/Lightning all still use the generic hit.mp3 sting, since
  /// nothing in the brief asked for e.g. shoot_pistol_impact.mp3.
  static const Map<String, String> impactSounds = {
    'sword': 'sword_impact.mp3',
    'magic_orb': 'magic_orb_impact.mp3',
  };
}
