import 'package:flame/components.dart';

import '../../roughlike_game.dart';
import '../enemy.dart';
import '../enemy_data.dart';

/// Support AI: never attacks the player directly. Keeps its distance and,
/// on a cooldown, heals whichever nearby ally has lost the most HP.
///
/// Still drifts closer when far beyond [_driftRange] — a Healer that spawns
/// out of weapon range and only ever retreats-if-too-close has no reason to
/// ever approach if the player stands still. Left alone, a Healer as the
/// last enemy of a wave could sit unreachable forever and the wave would
/// never clear. Drifting is slow (not a chase), so it still reads as
/// "avoids the fight" rather than "attacks".
class HealerAi extends Component
    with ParentIsA<Enemy>, HasGameReference<RoughlikeGame> {
  HealerAi({required this.data});

  final EnemyData data;
  double _healTimer = 0;

  static const double _driftRangeFactor = 1.5;
  static const double _driftSpeedFactor = 0.4;

  @override
  void update(double dt) {
    if (parent.isDead) {
      return;
    }

    final player = game.player;
    final toPlayer = player.position - parent.position;
    final distance = toPlayer.length;
    final speed = data.moveSpeed * parent.moveSpeedMultiplier;
    if (distance > 0) {
      if (distance < data.preferredRange) {
        parent.position -= (toPlayer / distance) * speed * dt;
      } else if (distance > data.preferredRange * _driftRangeFactor) {
        parent.position += (toPlayer / distance) * speed * _driftSpeedFactor * dt;
      }
    }

    _healTimer -= dt;
    if (_healTimer <= 0) {
      _healTimer = data.attackCooldown;
      _findMostDamagedAlly()?.heal(data.healAmount);
    }
  }

  Enemy? _findMostDamagedAlly() {
    Enemy? best;
    var bestMissingHp = 0.0;
    final supportRadiusSquared = data.supportRadius * data.supportRadius;
    for (final enemy in game.world.children.query<Enemy>()) {
      if (identical(enemy, parent) || enemy.isDead) {
        continue;
      }
      if (enemy.position.distanceToSquared(parent.position) >
          supportRadiusSquared) {
        continue;
      }
      final missing = enemy.maxHp - enemy.currentHp;
      if (missing > bestMissingHp) {
        bestMissingHp = missing;
        best = enemy;
      }
    }
    return best;
  }
}
