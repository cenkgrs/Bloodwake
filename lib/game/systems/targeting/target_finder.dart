import 'package:flame/components.dart';

import '../../enemies/enemy.dart';

/// Returns the closest living enemy to [from] within [maxRange], or null.
/// Shared by weapons picking an auto-attack target today, and by anything
/// else that needs "nearest enemy" later (turrets, AoE center, minimap).
Enemy? findNearestEnemy(
  Iterable<Enemy> enemies,
  Vector2 from,
  double maxRange,
) {
  Enemy? nearest;
  var nearestDistanceSquared = maxRange * maxRange;
  for (final enemy in enemies) {
    if (enemy.isDead) {
      continue;
    }
    final distanceSquared = enemy.position.distanceToSquared(from);
    if (distanceSquared <= nearestDistanceSquared) {
      nearest = enemy;
      nearestDistanceSquared = distanceSquared;
    }
  }
  return nearest;
}
