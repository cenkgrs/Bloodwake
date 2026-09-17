import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';

import '../roughlike_game.dart';
import '../waves/wave_manager.dart';

/// Screen-fixed combat readout with an opaque plate over the arena.
class HudComponent extends PositionComponent
    with HasGameReference<RoughlikeGame> {
  HudComponent({double topInset = 0})
    : super(position: Vector2(16, 16 + topInset), anchor: Anchor.topLeft);

  static final _title = TextPaint(
    style: const TextStyle(
      color: Color(0xFFF1E7D5),
      fontSize: 15,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.3,
    ),
  );
  static final _label = TextPaint(
    style: const TextStyle(
      color: Color(0xFFB9C1C2),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
  );
  static final _value = TextPaint(
    style: const TextStyle(
      color: Color(0xFFE8D8C4),
      fontSize: 11,
      fontWeight: FontWeight.bold,
    ),
  );
  static final _gold = TextPaint(
    style: const TextStyle(
      color: Color(0xFFD8B579),
      fontSize: 11,
      fontWeight: FontWeight.bold,
    ),
  );

  static final _panelPaint = Paint()..color = const Color(0xE90B131B);
  static final _borderPaint = Paint()
    ..color = const Color(0xFF687077)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  static final _trackPaint = Paint()..color = const Color(0xFF263039);
  static final _healthPaint = Paint()..color = const Color(0xFFBD463F);
  static final _lowHealthPaint = Paint()..color = const Color(0xFFE46A53);
  static final _experiencePaint = Paint()..color = const Color(0xFFD4B378);
  static final _linePaint = Paint()..color = const Color(0xFF46515A);

  String _wave = '';
  String _phase = '';
  String _health = '';
  String _level = '';
  String _resources = '';
  double _healthFraction = 1;
  double _experienceFraction = 0;

  @override
  void update(double dt) {
    super.update(dt);
    final player = game.player;
    final wave = game.waveManager;
    _wave = 'WAVE ${wave.currentWave.toString().padLeft(2, '0')}';
    _phase = wave.state == WaveState.resting
        ? 'NEXT IN ${wave.restTimeRemaining.ceil()}s'
        : 'SURVIVE';
    _healthFraction = (player.currentHp / player.maxHp).clamp(0, 1);
    _health = '${player.currentHp.ceil()} / ${player.maxHp.ceil()}';
    final xp = player.experience;
    _experienceFraction = (xp.xpIntoLevel / xp.xpRequiredForNextLevel).clamp(
      0,
      1,
    );
    _level = 'LEVEL ${xp.level}';
    _resources = 'GOLD ${player.currency.gold}    •    KILLS ${game.killCount}';
  }

  @override
  void render(Canvas canvas) {
    const width = 304.0;
    const barWidth = 280.0;
    final panel = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, width, 132),
      const Radius.circular(6),
    );
    canvas.drawRRect(panel, _panelPaint);
    canvas.drawRRect(panel, _borderPaint);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 4, 132), _healthPaint);
    _title.render(canvas, _wave, Vector2(13, 9));
    _gold.render(canvas, _phase, Vector2(209, 13));
    canvas.drawRect(const Rect.fromLTWH(13, 35, 278, 1), _linePaint);
    _label.render(canvas, 'HEALTH', Vector2(13, 42));
    _value.render(canvas, _health, Vector2(215, 42));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 60, barWidth, 10),
        const Radius.circular(2),
      ),
      _trackPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(13, 60, barWidth * _healthFraction, 10),
        const Radius.circular(2),
      ),
      _healthFraction < 0.3 ? _lowHealthPaint : _healthPaint,
    );
    _label.render(canvas, _level, Vector2(13, 76));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 94, barWidth, 6),
        const Radius.circular(2),
      ),
      _trackPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(13, 94, barWidth * _experienceFraction, 6),
        const Radius.circular(2),
      ),
      _experiencePaint,
    );
    _gold.render(canvas, _resources, Vector2(13, 108));
  }
}
