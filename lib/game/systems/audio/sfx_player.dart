import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// Every sound trigger point in the game, wired now so dropping a file into
/// assets/audio/ (see the README there) activates it with no code changes.
/// Every call is caught — none of the files exist yet, and a missing asset
/// must never crash or interrupt gameplay, today or after some files exist
/// and others still don't.
class SfxPlayer {
  SfxPlayer._();

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

  static void _play(String fileName, {double volume = 1}) {
    // Fire-and-forget: gameplay never waits on audio.
    unawaited(_safePlay(fileName, volume));
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
