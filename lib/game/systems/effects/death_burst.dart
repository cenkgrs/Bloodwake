import 'dart:ui';

import 'package:flame/components.dart';

/// Expanding, fading circle in the dead enemy's own color — replaces an
/// instant pop-out-of-existence with something that reads as "destroyed"
/// rather than "despawned".
class DeathBurst extends PositionComponent {
  DeathBurst({required Vector2 position, required this.color, required this.startRadius})
    : super(position: position, anchor: Anchor.center, priority: 3);

  final Color color;
  final double startRadius;
  double _age = 0;

  static const double lifetime = 0.3;

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
    final radius = startRadius * (1 + t * 1.8);
    final paint = Paint()..color = color.withValues(alpha: (1 - t) * 0.8);
    canvas.drawCircle(Offset.zero, radius, paint);
  }
}
