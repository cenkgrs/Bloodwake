import 'package:flame/components.dart';

import '../../roughlike_game.dart';
import '../enemy.dart';

/// Push-apart force so a crowd of chasing enemies spreads into a ring
/// around the player instead of jamming into a single-file line behind
/// whichever one reached melee range first (each later arrival used to
/// walk the same straight line to the player and get physically blocked
/// by the one in front). Every other alive enemy closer than
/// [separationRadius] pushes [self] away, scaled by how deep the overlap
/// is — enemies further than that ignore each other entirely.
Vector2 separationForce(
  RoughlikeGame game,
  Enemy self,
  double separationRadius,
) {
  final force = Vector2.zero();
  for (final other in game.world.children.query<Enemy>()) {
    if (identical(other, self) || other.isDead) {
      continue;
    }
    final offset = self.position - other.position;
    final distance = offset.length;
    if (distance > 0 && distance < separationRadius) {
      force.add(offset * ((separationRadius - distance) / (separationRadius * distance)));
    }
  }
  return force;
}
