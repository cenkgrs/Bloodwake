import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../roughlike_game.dart';

/// Rare healing drop. It waits for an injured player and expires after a while.
class HealthPickup extends PositionComponent
    with HasGameReference<RoughlikeGame> {
  HealthPickup({required Vector2 position, required this.amount})
    : super(
        position: position,
        size: Vector2.all(20),
        anchor: Anchor.center,
        priority: 4,
      );

  final double amount;
  double _age = 0;
  static const double lifetime = 25;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= lifetime) {
      removeFromParent();
      return;
    }
    final player = game.player;
    if (player.isDead || player.currentHp >= player.maxHp) return;
    final towardPlayer = player.position - position;
    final distance = towardPlayer.length;
    if (distance <= 18) {
      player.heal(amount);
      removeFromParent();
    } else if (distance <= player.stats.pickupRadius) {
      position += towardPlayer / distance * 300 * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final pulse = 1 + math.sin(_age * 6) * 0.08;
    final alpha = _age > lifetime - 5
        ? ((lifetime - _age) / 5).clamp(0, 1).toDouble()
        : 1.0;
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(
      center,
      11 * pulse,
      Paint()..color = const Color(0xFFFA554F).withValues(alpha: alpha * 0.35),
    );
    canvas.drawCircle(
      center,
      8 * pulse,
      Paint()..color = const Color(0xFFD92E3A).withValues(alpha: alpha),
    );
    final cross = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center + const Offset(-4, 0),
      center + const Offset(4, 0),
      cross,
    );
    canvas.drawLine(
      center + const Offset(0, -4),
      center + const Offset(0, 4),
      cross,
    );
  }
}
