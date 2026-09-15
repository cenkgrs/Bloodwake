import 'dart:ui';

import 'package:flame/components.dart';

/// Warning ring that grows to full [radius] over [duration], then
/// disappears right as the real attack should land. Purely visual — the
/// attacker resolves the actual hit on its own timer, this just gives the
/// player something to see and react to. Reusable by any enemy that needs
/// to telegraph, not boss-specific.
class AttackTelegraph extends PositionComponent {
  AttackTelegraph({required Vector2 position, required this.radius, required this.duration})
    : super(position: position, anchor: Anchor.center, priority: 4);

  final double radius;
  final double duration;
  double _age = 0;

  static final Paint _fillPaint = Paint()..color = const Color(0x33FF3B3B);
  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFFFF3B3B);

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / duration).clamp(0, 1).toDouble();
    final currentRadius = radius * t;
    canvas.drawCircle(Offset.zero, currentRadius, _fillPaint);
    canvas.drawCircle(Offset.zero, currentRadius, _strokePaint);
  }
}
