import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../combat/projectiles/projectile.dart';
import '../../player/player.dart';
import '../../roughlike_game.dart';
import '../../systems/audio/sfx_player.dart';
import '../../systems/damage/damage_event.dart';
import '../../systems/effects/attack_telegraph.dart';
import '../enemy.dart';
import '../enemy_data.dart';

enum _BossAttack { melee, projectile, area }

/// Three-phase boss fight, keyed off remaining HP fraction:
///
/// - Phase 1 (>66% HP): chase, melee on cooldown.
/// - Phase 2 (33-66% HP): hangs back, fires a 3-shot projectile fan.
/// - Phase 3 (<33% HP): holds ground, periodic AoE pulse, summons Grunts.
///
/// Every attack telegraphs first (see AttackTelegraph) and resolves off a
/// [_pendingAttack] captured at telegraph-start — resolving against the
/// *live* phase instead would let an attack that started in one phase
/// land as a different phase's attack if HP crosses a threshold mid-wind-up.
///
/// One boss exists today, so its tuning lives here as constants rather
/// than more EnemyData fields — a second boss would either reuse this
/// wholesale via new data, or earn its own AI component the same way
/// Archer/Assassin/Healer did.
class BossAi extends Component with ParentIsA<Enemy>, HasGameReference<RoughlikeGame> {
  BossAi({required this.data});

  final EnemyData data;
  final Random _random = Random();

  double _attackTimer = 2.5;
  double _summonTimer = _summonCooldown;
  bool _isTelegraphing = false;
  double _telegraphTimer = 0;
  _BossAttack? _pendingAttack;
  int _observedPhase = 1;

  static const double _phase2HpFraction = 0.66;
  static const double _phase3HpFraction = 0.33;
  static const double _telegraphDuration = 0.5;

  static const double _meleeRange = 70;
  static const double _meleeCooldown = 2.0;

  static const double _projectileRange = 520;
  static const double _projectileSpeed = 260;
  static const double _projectileCooldown = 1.6;
  static const int _projectileFanCount = 3;

  static const double _areaRadius = 150;
  static const double _areaCooldown = 2.4;
  static const double _summonCooldown = 7;
  static const int _summonCount = 2;

  int get _phase {
    final fraction = parent.currentHp / parent.maxHp;
    if (fraction > _phase2HpFraction) {
      return 1;
    }
    if (fraction > _phase3HpFraction) {
      return 2;
    }
    return 3;
  }

  @override
  void update(double dt) {
    final player = game.player;
    if (parent.isDead || player.isDead) {
      return;
    }

    if (_isTelegraphing) {
      _telegraphTimer -= dt;
      if (_telegraphTimer <= 0) {
        _resolveAttack(player);
      }
      return;
    }

    final phase = _phase;
    if (phase != _observedPhase) {
      _observedPhase = phase;
      SfxPlayer.bossPhase();
      game.shakeCamera(intensity: 10, duration: 0.3);
    }
    if (phase == 3) {
      _summonTimer -= dt;
      if (_summonTimer <= 0) {
        _summonTimer = _summonCooldown;
        _summonAdds();
      }
    }

    _approachOrHold(phase, player, dt);

    _attackTimer -= dt;
    if (_attackTimer <= 0) {
      _beginTelegraph(phase, player);
    }
  }

  void _approachOrHold(int phase, Player player, double dt) {
    final toPlayer = player.position - parent.position;
    final distance = toPlayer.length;
    if (distance <= 0) {
      return;
    }
    final speed = data.moveSpeed * parent.moveSpeedMultiplier;
    switch (phase) {
      case 1:
        if (distance > _meleeRange) {
          parent.position += (toPlayer / distance) * speed * dt;
        }
      case 2:
        if (distance > _projectileRange * 0.6) {
          parent.position += (toPlayer / distance) * speed * 0.5 * dt;
        }
      default:
        if (distance > _areaRadius * 1.5) {
          parent.position += (toPlayer / distance) * speed * 0.3 * dt;
        }
    }
  }

  void _beginTelegraph(int phase, Player player) {
    final _BossAttack attack;
    final double radius;
    switch (phase) {
      case 1:
        attack = _BossAttack.melee;
        radius = _meleeRange;
      case 2:
        attack = _BossAttack.projectile;
        radius = 26;
      default:
        attack = _BossAttack.area;
        radius = _areaRadius;
    }
    _pendingAttack = attack;
    _isTelegraphing = true;
    _telegraphTimer = _telegraphDuration;
    game.world.add(
      AttackTelegraph(position: parent.position.clone(), radius: radius, duration: _telegraphDuration),
    );
  }

  void _resolveAttack(Player player) {
    _isTelegraphing = false;
    switch (_pendingAttack) {
      case _BossAttack.melee:
        if (parent.position.distanceTo(player.position) <= _meleeRange + player.radius) {
          player.applyDamage(DamageEvent(source: parent, baseDamage: data.damage));
        }
        _attackTimer = _meleeCooldown;
      case _BossAttack.projectile:
        _fireProjectileFan(player);
        _attackTimer = _projectileCooldown;
      case _BossAttack.area:
        if (parent.position.distanceTo(player.position) <= _areaRadius) {
          player.applyDamage(DamageEvent(source: parent, baseDamage: data.damage * 0.75));
        }
        _attackTimer = _areaCooldown;
      case null:
        break;
    }
    _pendingAttack = null;
  }

  void _fireProjectileFan(Player player) {
    final baseDirection = player.position - parent.position;
    if (baseDirection.isZero()) {
      return;
    }
    for (var i = 0; i < _projectileFanCount; i++) {
      final t = _projectileFanCount == 1 ? 0.5 : i / (_projectileFanCount - 1);
      final angleOffset = (t - 0.5) * 0.6;
      final direction = baseDirection.clone()..rotate(angleOffset);
      game.world.add(
        Projectile(
          position: parent.position.clone(),
          direction: direction,
          speed: _projectileSpeed,
          damage: data.damage * 0.6,
          source: parent,
          maxDistance: _projectileRange,
          color: const Color(0xFFFF3B3B),
        ),
      );
    }
  }

  void _summonAdds() {
    for (var i = 0; i < _summonCount; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final offset = Vector2(cos(angle), sin(angle)) * 90;
      game.world.add(Enemy(position: parent.position + offset, data: EnemyCatalog.grunt));
    }
  }
}
