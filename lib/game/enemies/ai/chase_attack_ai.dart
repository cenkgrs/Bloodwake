import 'package:flame/components.dart';

import '../../roughlike_game.dart';
import '../../systems/damage/damage_event.dart';
import '../enemy.dart';
import '../enemy_data.dart';
import 'separation.dart';

/// Private to this file on purpose — Assassin/Archer/Healer each have their
/// own state shape (dash, reposition, kite, heal...) that don't overlap
/// with this one, so sharing a single enum across all AI components would
/// force every switch to handle states it never uses.
enum _ChaseState { chase, attack, dead }

/// Minimal state machine for melee enemies: close the distance to the
/// player, then attack on cooldown once in range. Used by Grunt and Tank —
/// the only difference between them is their [EnemyData] numbers.
///
/// While chasing, movement blends the straight line to the player with
/// [separationForce] from other enemies. Without it, a pack all walking
/// the same straight line collides and queues up behind whoever got there
/// first — a single-file line the player can trivially funnel-kill one at
/// a time. With it, new arrivals get pushed sideways around whoever is
/// already close to the player, so the pack spreads into a surrounding
/// ring instead.
class ChaseAttackAi extends Component
    with ParentIsA<Enemy>, HasGameReference<RoughlikeGame> {
  ChaseAttackAi({required this.data});

  final EnemyData data;
  _ChaseState _state = _ChaseState.chase;
  double _attackTimer = 0;

  /// How far apart enemies of this size try to keep from each other while
  /// closing in — scales with the enemy's own radius so Tanks (bigger)
  /// claim more personal space than Grunts.
  double get _separationRadius => data.radius * 3.5;
  static const double _separationWeight = 1.4;

  @override
  void update(double dt) {
    final player = game.player;
    if (parent.isDead || player.isDead) {
      _state = _ChaseState.dead;
      return;
    }

    final toPlayer = player.position - parent.position;
    final distance = toPlayer.length;
    _state = distance <= data.attackRange
        ? _ChaseState.attack
        : _ChaseState.chase;

    switch (_state) {
      case _ChaseState.chase:
        final seek = toPlayer / distance;
        final separation = separationForce(game, parent, _separationRadius)
          ..scale(_separationWeight);
        final moveDir = seek + separation;
        if (moveDir.length2 > 0) {
          moveDir.normalize();
        } else {
          moveDir.setFrom(seek);
        }
        parent.position += moveDir * data.moveSpeed * parent.moveSpeedMultiplier * dt;
      case _ChaseState.attack:
        _attackTimer -= dt;
        if (_attackTimer <= 0) {
          player.applyDamage(
            DamageEvent(source: parent, baseDamage: data.damage),
          );
          _attackTimer = data.attackCooldown;
        }
      case _ChaseState.dead:
        break;
    }
  }
}
