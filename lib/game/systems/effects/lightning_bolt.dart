import 'dart:ui';

import 'package:flame/components.dart';

/// Purely visual: a brief line between two points, gone after [lifetime].
/// Lightning's damage is applied directly by whatever fires it — this
/// component carries no collision or gameplay logic at all.
class LightningBolt extends PositionComponent {
  LightningBolt({required Vector2 start, required Vector2 end})
    : _localEnd = end - start,
      super(position: start, priority: 10);

  final Vector2 _localEnd;
  double _age = 0;

  static const double lifetime = 0.15;
  static final Paint _paint = Paint()
    ..color = const Color(0xFFBFEFFF)
    ..strokeWidth = 3;

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
    final fade = (1 - _age / lifetime).clamp(0, 1).toDouble();
    canvas.drawLine(
      Offset.zero,
      _localEnd.toOffset(),
      _paint..color = _paint.color.withValues(alpha: fade),
    );
  }
}
