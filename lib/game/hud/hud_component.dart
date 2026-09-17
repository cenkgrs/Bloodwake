import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';

import '../roughlike_game.dart';
import '../waves/wave_manager.dart';

/// Compact combat HUD, anchored below the device status bar.
class HudComponent extends PositionComponent
    with HasGameReference<RoughlikeGame> {
  HudComponent({double topInset = 0})
    : super(
        position: Vector2(16, 12 + topInset),
        size: Vector2(270, 122),
        anchor: Anchor.topLeft,
      );

  static final _heading = TextPaint(
    style: const TextStyle(
      color: Color(0xFFF5E9DA),
      fontSize: 15,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.1,
    ),
  );
  static final _label = TextPaint(
    style: const TextStyle(
      color: Color(0xFF9EA8AE),
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
  static final _value = TextPaint(
    style: const TextStyle(
      color: Color(0xFFF3EBDF),
      fontSize: 11,
      fontWeight: FontWeight.bold,
    ),
  );
  static final _accent = TextPaint(
    style: const TextStyle(
      color: Color(0xFFEBC18A),
      fontSize: 10,
      fontWeight: FontWeight.bold,
    ),
  );
  static final _phasePaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFF3C489),
      fontSize: 9,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    ),
  );

  String _wave = '';
  String _phase = '';
  String _health = '';
  String _level = '';
  String _gold = '';
  String _kills = '';
  double _healthFraction = 1;
  double _xpFraction = 0;
  double _shownHealth = 1;
  double _shownXp = 0;

  @override
  void update(double dt) {
    super.update(dt);
    final player = game.player;
    final wave = game.waveManager;
    _wave = 'WAVE ${wave.currentWave.toString().padLeft(2, '0')}';
    _phase = wave.state == WaveState.resting
        ? 'NEXT ${wave.restTimeRemaining.ceil()}s'
        : 'SURVIVE';
    _healthFraction = (player.currentHp / player.maxHp).clamp(0, 1);
    _shownHealth += (_healthFraction - _shownHealth) * (dt * 8).clamp(0, 1);
    _health = '${player.currentHp.ceil()} / ${player.maxHp.ceil()}';
    final xp = player.experience;
    _xpFraction = (xp.xpIntoLevel / xp.xpRequiredForNextLevel).clamp(0, 1);
    _shownXp += (_xpFraction - _shownXp) * (dt * 8).clamp(0, 1);
    _level = 'LV ${xp.level}';
    _gold = '${player.currency.gold} GOLD';
    _kills = '${game.killCount} KILLS';
  }

  @override
  void render(Canvas canvas) {
    const width = 270.0;
    const barWidth = 242.0;
    final panel = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, width, 122),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      panel.shift(const Offset(0, 5)),
      Paint()
        ..color = const Color(0x88000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(panel, Paint()..color = const Color(0xEB101A23));
    canvas.drawRRect(
      panel,
      Paint()
        ..color = const Color(0xFF54606B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 4, 122),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFCD554D),
    );
    _heading.render(canvas, _wave, Vector2(14, 9));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(192, 11, 64, 20),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0x343FB8FF),
    );
    _phasePaint.render(canvas, _phase, Vector2(199, 15));
    canvas.drawRect(
      const Rect.fromLTWH(14, 37, 242, 1),
      Paint()..color = const Color(0xFF42515C),
    );
    _label.render(canvas, 'HEALTH', Vector2(14, 43));
    _value.render(canvas, _health, Vector2(195, 43));
    _bar(
      canvas,
      14,
      60,
      barWidth,
      9,
      _shownHealth,
      _healthFraction < 0.3 ? const Color(0xFFFF755F) : const Color(0xFFCE514A),
    );
    _label.render(canvas, _level, Vector2(14, 75));
    _bar(canvas, 61, 79, 195, 5, _shownXp, const Color(0xFFE7BA70));
    canvas.drawRect(
      const Rect.fromLTWH(14, 94, 242, 1),
      Paint()..color = const Color(0xFF35434D),
    );
    _accent.render(canvas, _gold, Vector2(14, 101));
    _label.render(canvas, '•', Vector2(118, 101));
    _accent.render(canvas, _kills, Vector2(135, 101));
  }

  void _bar(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    double fraction,
    Color color,
  ) {
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, width, height),
      Radius.circular(height / 2),
    );
    canvas.drawRRect(track, Paint()..color = const Color(0xFF34414A));
    if (fraction <= 0) return;
    final fill = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, width * fraction, height),
      Radius.circular(height / 2),
    );
    canvas.drawRRect(
      fill,
      Paint()
        ..shader = Gradient.linear(Offset(x, y), Offset(x + width, y), [
          color,
          color.withValues(alpha: 0.7),
        ]),
    );
  }
}
