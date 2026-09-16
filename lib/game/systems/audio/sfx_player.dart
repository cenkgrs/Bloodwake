import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import 'weapon_sfx.dart';

/// Every sound trigger point in the game, wired now so dropping a file into
/// assets/audio/ (see the README there) activates it with no code changes.
/// Every call is caught — a missing asset must never crash or interrupt
/// gameplay, whether none of the files exist yet or only some do.
class SfxPlayer {
  SfxPlayer._();

  /// Minimum gap between two plays of the *same* file, in milliseconds.
  /// Only sounds that can plausibly fire many times in one frame/second in
  /// this survivor-style game need an entry — a high fire-rate weapon, a
  /// melee swing or piercing shot hitting several enemies at once, a wave
  /// of enemies dying together, or a burst of Chain Lightning jumps that
  /// all resolve in the same update. Everything else (level up, purchase,
  /// boss phase...) is rare enough by nature that it never needs throttling.
  static const Map<String, int> _throttleMs = {
    'hit.mp3': 60,
    'shoot_rifle.mp3': 70,
    'chain_lightning.mp3': 50,
    'enemy_death.mp3': 80,
    'sword_impact.mp3': 60,
    'magic_orb_impact.mp3': 60,
  };

  static final Map<String, int> _lastPlayedAtMs = {};

  static void shoot() => _play('shoot.mp3', volume: 0.5);
  static void hit() => _play('hit.mp3', volume: 0.4);
  static void enemyDeath() => _play('enemy_death.mp3');
  static void playerHit() => _play('player_hit.mp3');
  static void gameOver() => _play('game_over.mp3');
  static void levelUp() => _play('level_up.mp3');
  static void upgradePick() => _play('upgrade_pick.mp3');
  static void purchase() => _play('purchase.mp3');
  static void bossPhase() => _play('boss_phase.mp3');
  static void bossDeath() => _play('boss_death.mp3');

  /// Called once per weapon attack cycle (PlayerWeapons.update). Resolves
  /// [weaponId] — a [WeaponData.id] — to its dedicated cast/fire sound via
  /// [WeaponSfx.fireSounds]. A weapon with no entry there, including any
  /// future weapon added without updating that map, falls back to the
  /// generic [shoot] sound rather than staying silent.
  static void weaponFire(String? weaponId) {
    final asset = weaponId == null ? null : WeaponSfx.fireSounds[weaponId];
    if (asset == null) {
      shoot();
    } else {
      _play(asset, volume: 0.5);
    }
  }

  /// Called once per enemy hit (Enemy.applyDamage). Resolves [weaponId] to
  /// its dedicated impact sound via [WeaponSfx.impactSounds] (Sword, Magic
  /// Orb); everything else — no weapon attached, or a weapon with no
  /// mapped impact sound — plays the generic [hit] sound instead. Only
  /// ever one or the other for a given hit, never both, so a busy fight
  /// doesn't double up the same moment.
  static void weaponImpact(String? weaponId) {
    final asset = weaponId == null ? null : WeaponSfx.impactSounds[weaponId];
    if (asset == null) {
      hit();
    } else {
      _play(asset, volume: 0.4);
    }
  }

  /// Chain Lightning's extra jumps beyond the first target. The first
  /// target's hit is already covered by [weaponFire]'s lightning_cast (the
  /// "initial activation"); this is only for each subsequent arc, and is
  /// throttled like everything else high-frequency — a single cast can
  /// jump several times in one update, effectively simultaneously.
  static void chainLightningProc() => _play('chain_lightning.mp3', volume: 0.4);

  static void _play(String fileName, {double volume = 1}) {
    if (_isThrottled(fileName)) {
      return;
    }
    // Fire-and-forget: gameplay never waits on audio.
    unawaited(_safePlay(fileName, volume));
  }

  static bool _isThrottled(String fileName) {
    final minGapMs = _throttleMs[fileName];
    if (minGapMs == null) {
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastPlayed = _lastPlayedAtMs[fileName];
    if (lastPlayed != null && now - lastPlayed < minGapMs) {
      return true;
    }
    _lastPlayedAtMs[fileName] = now;
    return false;
  }

  static Future<void> _safePlay(String fileName, double volume) async {
    try {
      await FlameAudio.play(fileName, volume: volume);
    } catch (error) {
      // Missing/broken file — silently skip, never interrupt gameplay.
      if (kDebugMode) {
        debugPrint('SfxPlayer: skipping "$fileName" ($error)');
      }
    }
  }
}
