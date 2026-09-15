import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';

import '../enemies/enemy.dart';
import '../enemies/enemy_data.dart';
import '../roughlike_game.dart';

/// Top-center HP bar, visible only while a boss is alive. Screen-fixed
/// (added to camera.viewport like the rest of the HUD), so its x position
/// is recomputed from the viewport width each frame rather than set once —
/// simplest way to stay centered if the window/screen resizes.
class BossHealthBar extends PositionComponent with HasGameReference<RoughlikeGame> {
  BossHealthBar() : super(size: Vector2(320, 22), anchor: Anchor.topCenter);

  late final TextComponent _label;
  Enemy? _boss;

  static final Paint _bgPaint = Paint()..color = const Color(0xFF1A1D26);
  static final Paint _fillPaint = Paint()..color = const Color(0xFF8B1A2B);
  static final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFF3A3F4B);
  static final _labelStyle = TextPaint(
    style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13, fontWeight: FontWeight.bold),
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _label = TextComponent(
      text: '',
      textRenderer: _labelStyle,
      position: Vector2(size.x / 2, -18),
      anchor: Anchor.topCenter,
    );
    add(_label);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position
      ..x = game.camera.viewport.size.x / 2
      ..y = 20;
    _boss = _findBoss();
    _label.text = _boss == null ? '' : 'BOSS';
  }

  Enemy? _findBoss() {
    for (final enemy in game.world.children.query<Enemy>()) {
      if (enemy.data.type == EnemyType.boss && !enemy.isDead) {
        return enemy;
      }
    }
    return null;
  }

  @override
  void render(Canvas canvas) {
    final boss = _boss;
    if (boss == null) {
      return;
    }
    final rect = size.toRect();
    canvas.drawRect(rect, _bgPaint);
    final fraction = (boss.currentHp / boss.maxHp).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x * fraction, size.y), _fillPaint);
    canvas.drawRect(rect, _borderPaint);
  }
}
