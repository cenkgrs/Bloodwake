import 'dart:ui';

import 'package:flame/components.dart';

import '../../combat/projectiles/projectile.dart';
import '../../roughlike_game.dart';
import '../enemy.dart';
import '../enemy_data.dart';

enum _ArcherState { chase, attack, retreat, dead }

/// Ranged kiting AI: closes in until [EnemyData.preferredRange], shoots from
/// there, and backs off if the player gets too close instead of ever going
/// melee.
class ArcherAi extends Component
    with ParentIsA<Enemy>, HasGameReference<RoughlikeGame> {
  ArcherAi({required this.data});

  final EnemyData data;
  double _attackTimer = 0;

  static const double _retreatFactor = 0.6;
  static const Color _boltColor = Color(0xFFC77DFF);

  @override
  void update(double dt) {
    final player = game.player;
    if (parent.isDead || player.isDead) {
      return;
    }

    final toPlayer = player.position - parent.position;
    final distance = toPlayer.length;
    final retreatDistance = data.preferredRange * _retreatFactor;

    final state = distance < retreatDistance
        ? _ArcherState.retreat
        : distance > data.preferredRange
        ? _ArcherState.chase
        : _ArcherState.attack;

    switch (state) {
      case _ArcherState.chase:
        parent.position +=
            (toPlayer / distance) * data.moveSpeed * parent.moveSpeedMultiplier * dt;
      case _ArcherState.retreat:
        parent.position -=
            (toPlayer / distance) * data.moveSpeed * parent.moveSpeedMultiplier * dt;
      case _ArcherState.attack:
        _attackTimer -= dt;
        if (_attackTimer <= 0 && distance > 0) {
          game.world.add(
            Projectile(
              position: parent.position.clone(),
              direction: toPlayer,
              speed: data.projectileSpeed,
              damage: data.damage,
              source: parent,
              maxDistance: data.preferredRange * 1.5,
              color: _boltColor,
            ),
          );
          _attackTimer = data.attackCooldown;
        }
      case _ArcherState.dead:
        break;
    }
  }
}
