import 'package:flame/components.dart';

import '../../input/input_provider.dart';
import 'player.dart';
import 'player_stats.dart';

/// Translates [InputProvider] intent into player position updates.
///
/// Keeps the player within the arena bounds by clamping — this is the
/// prototype's collision foundation for the world boundary. Per-entity
/// collision (enemies, projectiles, pickups) is handled separately via the
/// [Player]'s circle hitbox once those systems exist.
class PlayerMovement extends Component with ParentIsA<Player> {
  PlayerMovement({
    required this.inputProvider,
    required this.stats,
    required Vector2 arenaSize,
  }) : _arenaSize = arenaSize;

  final InputProvider inputProvider;
  final PlayerStats stats;
  final Vector2 _arenaSize;

  @override
  void update(double dt) {
    if (parent.isDead) {
      return;
    }
    final direction = inputProvider.movementDirection;
    if (direction.isZero()) {
      return;
    }
    parent.facingDirection = direction.normalized();

    final radius = parent.radius;
    final next = parent.position + direction * stats.moveSpeed * dt;
    next.x = next.x.clamp(radius, _arenaSize.x - radius);
    next.y = next.y.clamp(radius, _arenaSize.y - radius);
    parent.position = next;
  }
}
