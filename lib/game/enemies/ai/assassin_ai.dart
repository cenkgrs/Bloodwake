import 'dart:math';

import 'package:flame/components.dart';

import '../../roughlike_game.dart';
import '../../systems/damage/damage_event.dart';
import '../enemy.dart';
import '../enemy_data.dart';

enum _AssassinState { chase, reposition, dash, attack, retreat, dead }

/// Hit-and-run AI: closes in, briefly vanishes and reappears at a random
/// point near the player, dashes in for a strike, then retreats before
/// looping back to chase again.
class AssassinAi extends Component
    with ParentIsA<Enemy>, HasGameReference<RoughlikeGame> {
  AssassinAi({required this.data});

  final EnemyData data;
  final Random _random = Random();

  _AssassinState _state = _AssassinState.chase;
  double _phaseTimer = 0;
  double _attackTimer = 0;
  final Vector2 _dashTarget = Vector2.zero();

  static const double _repositionDuration = 0.35;
  static const double _repositionDistance = 160;
  static const double _dashSpeedMultiplier = 4.5;
  static const double _retreatDuration = 0.7;
  static const double _retreatSpeedMultiplier = 1.3;

  @override
  void update(double dt) {
    final player = game.player;
    if (parent.isDead || player.isDead) {
      _state = _AssassinState.dead;
      return;
    }

    final toPlayer = player.position - parent.position;
    final distance = toPlayer.length;

    switch (_state) {
      case _AssassinState.chase:
        if (distance <= data.attackRange) {
          _state = _AssassinState.attack;
        } else if (distance <= _repositionDistance) {
          _beginReposition(player.position);
        } else if (distance > 0) {
          parent.position +=
              (toPlayer / distance) * data.moveSpeed * parent.moveSpeedMultiplier * dt;
        }

      case _AssassinState.reposition:
        _phaseTimer -= dt;
        if (_phaseTimer <= 0) {
          parent.position.setFrom(_dashTarget);
          parent.setHidden(false);
          _state = _AssassinState.dash;
        }

      case _AssassinState.dash:
        final freshToPlayer = player.position - parent.position;
        final freshDistance = freshToPlayer.length;
        if (freshDistance <= data.attackRange) {
          _state = _AssassinState.attack;
        } else if (freshDistance > 0) {
          parent.position +=
              (freshToPlayer / freshDistance) *
              data.moveSpeed *
              _dashSpeedMultiplier *
              parent.moveSpeedMultiplier *
              dt;
        }

      case _AssassinState.attack:
        _attackTimer -= dt;
        if (_attackTimer <= 0) {
          player.applyDamage(
            DamageEvent(source: parent, baseDamage: data.damage),
          );
          _attackTimer = data.attackCooldown;
          _phaseTimer = _retreatDuration;
          _state = _AssassinState.retreat;
        }

      case _AssassinState.retreat:
        _phaseTimer -= dt;
        if (distance > 0) {
          parent.position -=
              (toPlayer / distance) * data.moveSpeed * _retreatSpeedMultiplier * dt;
        }
        if (_phaseTimer <= 0) {
          _state = _AssassinState.chase;
        }

      case _AssassinState.dead:
        break;
    }
  }

  void _beginReposition(Vector2 playerPosition) {
    final angle = _random.nextDouble() * 2 * pi;
    _dashTarget
      ..setValues(cos(angle), sin(angle))
      ..scale(_repositionDistance)
      ..add(playerPosition);
    _phaseTimer = _repositionDuration;
    parent.setHidden(true);
    _state = _AssassinState.reposition;
  }
}
