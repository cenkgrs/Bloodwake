import 'package:flame/components.dart';

import '../../roughlike_game.dart';
import '../enemy.dart';
import '../enemy_data.dart';

/// Support AI: never engages the player directly. Keeps its distance and,
/// on a cooldown, heals whichever nearby ally has lost the most HP. No
/// explicit state machine needed — both behaviours run every tick, they
/// don't conflict.
class HealerAi extends Component
    with ParentIsA<Enemy>, HasGameReference<RoughlikeGame> {
  HealerAi({required this.data});

  final EnemyData data;
  double _healTimer = 0;

  @override
  void update(double dt) {
    if (parent.isDead) {
      return;
    }

    final player = game.player;
    final toPlayer = player.position - parent.position;
    final distance = toPlayer.length;
    if (distance > 0 && distance < data.preferredRange) {
      parent.position -=
          (toPlayer / distance) * data.moveSpeed * parent.moveSpeedMultiplier * dt;
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
