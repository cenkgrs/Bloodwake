import 'dart:ui';

import 'package:flame/components.dart';

/// Purely visual: a ring that expands and fades at the melee weapon's hit
/// radius. No collision or gameplay logic — damage is already applied by
/// the time this spawns.
class MeleeSlashEffect extends PositionComponent {
  MeleeSlashEffect({required Vector2 position, required this.radius})
    : super(position: position, anchor: Anchor.center, priority: 5);

  final double radius;
  double _age = 0;

  static const double lifetime = 0.2;
  static final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0xFFE8E8E8);

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / lifetime).clamp(0, 1).toDouble();
    canvas.drawCircle(
      Offset.zero,
      radius * (0.5 + t * 0.5),
      _paint..color = _paint.color.withValues(alpha: 1 - t),
    );
  }
}
