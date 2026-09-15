import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';

import '../roughlike_game.dart';
import '../waves/wave_manager.dart';

/// Always-on readout: wave/timer, an HP bar, an XP bar, gold and kills.
/// Bars replace the M00-M07 plain-number HP/XP line — first real "Better
/// UI" pass (M08); everything still drawn directly rather than through a
/// widget toolkit, since it's screen-fixed Flame content like the rest of
/// the HUD.
class HudComponent extends PositionComponent with HasGameReference<RoughlikeGame> {
  HudComponent() : super(position: Vector2(16, 16), anchor: Anchor.topLeft);

  static const double _barWidth = 200;
  static const double _hpBarHeight = 14;
  static const double _xpBarHeight = 7;

  static final _labelStyle = TextPaint(
    style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 15),
  );
  static final _smallStyle = TextPaint(
    style: const TextStyle(color: Color(0xFFB8BCC8), fontSize: 13),
  );

  static final Paint _hpBgPaint = Paint()..color = const Color(0xFF1A1D26);
  static final Paint _hpFillPaint = Paint()..color = const Color(0xFF3FB950);
  static final Paint _hpFillLowPaint = Paint()..color = const Color(0xFFDB4437);
  static final Paint _xpBgPaint = Paint()..color = const Color(0xFF1A1D26);
  static final Paint _xpFillPaint = Paint()..color = const Color(0xFF4A90E2);
  static final Paint _barBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = const Color(0xFF3A3F4B);

  String _waveLine = '';
  String _bottomLine = '';
  String _hpLabel = '';
  String _xpLabel = '';
  double _hpFraction = 1;
  double _xpFraction = 0;

  @override
  void update(double dt) {
    super.update(dt);
    final player = game.player;
    final wave = game.waveManager;
    // Not showing the exact enemies-left count on purpose — not knowing
    // how many are left to clear keeps the tension up. Re-enable by
    // uncommenting _enemiesLeft below and using it in the spawning branch.
    _waveLine = wave.state == WaveState.resting
        ? 'Wave ${wave.currentWave} clear!   Next wave in ${wave.restTimeRemaining.ceil()}s'
        : 'Wave ${wave.currentWave}';

    _hpFraction = (player.currentHp / player.maxHp).clamp(0, 1);
    _hpLabel = 'HP ${player.currentHp.ceil()}/${player.maxHp.ceil()}';

    final xp = player.experience;
    _xpFraction = (xp.xpIntoLevel / xp.xpRequiredForNextLevel).clamp(0, 1);
    _xpLabel = 'Lv ${xp.level}';

    _bottomLine = 'Gold ${player.currency.gold}   Kills  ${game.killCount}';
  }

  @override
  void render(Canvas canvas) {
    _labelStyle.render(canvas, _waveLine, Vector2.zero());

    const hpBarY = 26.0;
    final hpRect = Rect.fromLTWH(0, hpBarY, _barWidth, _hpBarHeight);
    canvas.drawRect(hpRect, _hpBgPaint);
    canvas.drawRect(
      Rect.fromLTWH(0, hpBarY, _barWidth * _hpFraction, _hpBarHeight),
      _hpFraction > 0.3 ? _hpFillPaint : _hpFillLowPaint,
    );
    canvas.drawRect(hpRect, _barBorderPaint);
    _smallStyle.render(canvas, _hpLabel, Vector2(_barWidth + 8, hpBarY - 1));

    final xpBarY = hpBarY + _hpBarHeight + 6;
    final xpRect = Rect.fromLTWH(0, xpBarY, _barWidth, _xpBarHeight);
    canvas.drawRect(xpRect, _xpBgPaint);
    canvas.drawRect(
      Rect.fromLTWH(0, xpBarY, _barWidth * _xpFraction, _xpBarHeight),
      _xpFillPaint,
    );
    canvas.drawRect(xpRect, _barBorderPaint);
    _smallStyle.render(canvas, _xpLabel, Vector2(_barWidth + 8, xpBarY - 3));

    _smallStyle.render(canvas, _bottomLine, Vector2(0, xpBarY + _xpBarHeight + 8));
  }

  // int _enemiesLeft(WaveManager wave) {
  //   final aliveCount = game.world.children.query<Enemy>().length;
  //   return (wave.waveEnemyQuota - wave.enemiesSpawnedThisWave) + aliveCount;
  // }
}
