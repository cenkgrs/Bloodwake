import 'package:flame/components.dart';

import '../../roughlike_game.dart';
import '../enemy.dart';
import '../enemy_data.dart';

/// Keeps behind the front line and periodically empowers nearby allies.
/// Killing it quickly removes the pack's speed and damage advantage.
class CommanderAi extends Component
    with ParentIsA<Enemy>, HasGameReference<RoughlikeGame> {
  CommanderAi({required this.data});

  final EnemyData data;
  double _commandTimer = 0;

  static const double _retreatFactor = 0.65;
  static const double _driftFactor = 1.45;
  static const double _driftSpeed = 0.45;

  @override
  void update(double dt) {
    if (parent.isDead || game.player.isDead) return;

    final toPlayer = game.player.position - parent.position;
    final distance = toPlayer.length;
    final speed = data.moveSpeed * parent.moveSpeedMultiplier;
    if (distance > 0) {
      if (distance < data.preferredRange * _retreatFactor) {
        parent.position -= (toPlayer / distance) * speed * dt;
      } else if (distance > data.preferredRange * _driftFactor) {
        parent.position += (toPlayer / distance) * speed * _driftSpeed * dt;
      }
    }

    _commandTimer -= dt;
    if (_commandTimer <= 0) {
      _commandTimer = data.attackCooldown;
      _empowerNearbyAllies();
    }
  }

  void _empowerNearbyAllies() {
    final radiusSquared = data.supportRadius * data.supportRadius;
    for (final ally in game.world.children.query<Enemy>()) {
      if (identical(ally, parent) ||
          ally.isDead ||
          ally.data.type == EnemyType.commander ||
          ally.data.type == EnemyType.boss ||
          ally.position.distanceToSquared(parent.position) > radiusSquared) {
        continue;
      }
      ally.applyCommandAura(
        duration: data.auraDuration,
        moveSpeedBonus: data.auraMoveSpeedBonus,
        damageBonus: data.auraDamageBonus,
      );
    }
  }
}
