import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';

import '../roughlike_game.dart';
import '../waves/wave_manager.dart';

/// Minimal always-on readout: wave, timer, HP, XP, kill count. Styled bars
/// and layout polish land in M08; this stays plain text until there's a
/// reason to invest in it.
class HudComponent extends PositionComponent
    with HasGameReference<RoughlikeGame> {
  HudComponent() : super(position: Vector2(16, 16), anchor: Anchor.topLeft);

  late final TextComponent _text;

  static final _style = TextPaint(
    style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _text = TextComponent(text: '', textRenderer: _style);
    add(_text);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final player = game.player;
    final wave = game.waveManager;
    // Not showing the exact enemies-left count on purpose — not knowing
    // how many are left to clear keeps the tension up. Re-enable by
    // uncommenting _enemiesLeft below and using it in the spawning branch.
    final waveLine = wave.state == WaveState.resting
        ? 'Wave ${wave.currentWave} clear!   Next wave in ${wave.restTimeRemaining.ceil()}s'
        : 'Wave ${wave.currentWave}';
    final xp = player.experience;
    _text.text =
        '$waveLine\n'
        'HP  ${player.currentHp.ceil()}/${player.maxHp.ceil()}   '
        'Lv ${xp.level}  XP ${xp.xpIntoLevel}/${xp.xpRequiredForNextLevel}\n'
        'Gold ${player.currency.gold}   Kills  ${game.killCount}';
  }

  // int _enemiesLeft(WaveManager wave) {
  //   final aliveCount = game.world.children.query<Enemy>().length;
  //   return (wave.waveEnemyQuota - wave.enemiesSpawnedThisWave) + aliveCount;
  // }
}
