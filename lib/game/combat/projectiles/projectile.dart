import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../enemies/enemy.dart';
import '../../player/player.dart';
import '../../systems/damage/damage_event.dart';
import '../../systems/effects/status_effect.dart';

/// A straight-line hitscan-speed projectile, fired by either the player
/// (weapon/ability) or an enemy (Archer). Only ever damages the faction
/// opposite its [source] — no friendly fire, since nothing needs it yet.
///
/// Covers "single projectile" and "piercing" (Magic Orb) behaviour via
/// [pierceCount] — a normal shot is just a piercing one with count 0.
/// Optionally applies a fresh [StatusEffectInstance] to everything it hits.
class Projectile extends PositionComponent with CollisionCallbacks {
  Projectile({
    required Vector2 position,
    required Vector2 direction,
    required this.speed,
    required this.damage,
    required this.source,
    required this.maxDistance,
    this.isCritical = false,
    this.color = const Color(0xFFFFE066),
    this.pierceCount = 0,
    this.onHitStatusType,
    this.onHitStatusMagnitude = 0,
    this.onHitStatusDuration = 0,
  }) : _direction = direction.normalized(),
       super(position: position, size: Vector2.all(8), anchor: Anchor.center);

  final Vector2 _direction;
  final double speed;
  final double damage;
  final Object source;
  final double maxDistance;
  final bool isCritical;
  final Color color;
  final int pierceCount;
  final StatusEffectType? onHitStatusType;
  final double onHitStatusMagnitude;
  final double onHitStatusDuration;

  double _traveled = 0;
  int _hitsSoFar = 0;
  final Set<Enemy> _alreadyHit = {};

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      CircleComponent(
        radius: 4,
        anchor: Anchor.center,
        position: size / 2,
        paint: Paint()..color = color,
      ),
    );
    add(CircleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    super.update(dt);
    final step = _direction * speed * dt;
    position += step;
    _traveled += step.length;
    if (_traveled >= maxDistance) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (source is Player && other is Enemy && !other.isDead) {
      if (!_alreadyHit.add(other)) {
        return;
      }
      other.applyDamage(
        DamageEvent(source: source, baseDamage: damage, isCritical: isCritical),
      );
      _applyStatusEffect(other);
      _applyLifesteal();
      _hitsSoFar++;
      if (_hitsSoFar > pierceCount) {
        removeFromParent();
      }
    } else if (source is Enemy && other is Player && !other.isDead) {
      other.applyDamage(DamageEvent(source: source, baseDamage: damage));
      removeFromParent();
    }
  }

  void _applyStatusEffect(Enemy target) {
    final type = onHitStatusType;
    if (type == null) {
      return;
    }
    target.applyStatusEffect(
      StatusEffectInstance(
        type: type,
        duration: onHitStatusDuration,
        magnitude: onHitStatusMagnitude,
      ),
    );
  }

  void _applyLifesteal() {
    final attacker = source;
    if (attacker is! Player || attacker.stats.lifesteal <= 0) {
      return;
    }
    final healAmount = damage * attacker.stats.lifesteal;
    attacker.stats.hp = (attacker.stats.hp + healAmount).clamp(
      0,
      attacker.stats.maxHp,
    );
  }
}
