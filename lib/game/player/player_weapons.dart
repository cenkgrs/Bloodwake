import 'dart:ui';

import 'package:flame/components.dart';

import '../combat/projectiles/projectile.dart';
import '../enemies/enemy.dart';
import '../roughlike_game.dart';
import '../systems/damage/critical_hit.dart';
import '../systems/audio/sfx_player.dart';
import '../systems/damage/damage_event.dart';
import '../systems/effects/lightning_bolt.dart';
import '../systems/effects/melee_slash_effect.dart';
import '../systems/effects/status_effect.dart';
import '../systems/targeting/target_finder.dart';
import '../weapons/weapon_data.dart';
import 'player.dart';

/// Auto-attack slot: fires [weapon] at the nearest enemy in range whenever
/// its cooldown is ready. A player can own several of these at once (one
/// per owned weapon, see Player.addWeapon), each firing independently.
///
/// Dispatches on [WeaponBehavior] — one private `_fire*` method per
/// behavior — rather than every weapon needing its own component. Adding a
/// 7th weapon that reuses an existing behavior is purely data; a genuinely
/// new behavior is one more case here.
class PlayerWeapons extends Component
    with ParentIsA<Player>, HasGameReference<RoughlikeGame> {
  PlayerWeapons({required this.weapon});

  final WeaponData weapon;
  double _cooldownRemaining = 0;

  /// Runtime bonus on top of [WeaponData.chainCount], e.g. from the "Chain
  /// Lightning" upgrade. Lives here (per-slot) rather than mutating the
  /// shared const [WeaponData], since only this player's copy should grow.
  int bonusChainCount = 0;

  /// Runtime multiplier on top of this weapon's damage, e.g. from a
  /// weapon-specific shop item ("Gold Sword" boosting only the Sword).
  /// 1.0 = no bonus. Same reasoning as [bonusChainCount] — per-slot, not on
  /// the shared const [WeaponData].
  double bonusDamageMultiplier = 1;

  static const double _spreadAngle = 0.5;
  static const Color _slowColor = Color(0xFF7EC8E3);

  double get _effectiveRange => weapon.range * parent.stats.attackRange;

  double get _baseDamage => weapon.damage * parent.stats.damage * bonusDamageMultiplier;

  @override
  void update(double dt) {
    if (parent.isDead) {
      return;
    }
    _cooldownRemaining -= dt;
    if (_cooldownRemaining > 0) {
      return;
    }

    final enemies = game.world.children.query<Enemy>();
    final target = findNearestEnemy(enemies, parent.position, _effectiveRange);
    if (target == null) {
      return;
    }

    switch (weapon.behavior) {
      case WeaponBehavior.singleProjectile:
        _fireSingle(target);
      case WeaponBehavior.spread:
        _fireSpread(target);
      case WeaponBehavior.piercing:
        _firePiercing(target);
      case WeaponBehavior.chain:
        _fireChain(target);
      case WeaponBehavior.melee:
        _fireMelee();
    }
    SfxPlayer.shoot();
    _cooldownRemaining = weapon.cooldown / parent.stats.attackSpeed;
  }

  void _fireSingle(Enemy target) {
    final roll = rollDamage(parent.stats, _baseDamage);
    game.world.add(
      Projectile(
        position: parent.position.clone(),
        direction: target.position - parent.position,
        speed: weapon.projectileSpeed,
        damage: roll.damage,
        isCritical: roll.isCritical,
        source: parent,
        maxDistance: _effectiveRange,
      ),
    );
  }

  void _fireSpread(Enemy target) {
    final baseDirection = target.position - parent.position;
    final count = weapon.projectileCount;
    for (var i = 0; i < count; i++) {
      final t = count == 1 ? 0.5 : i / (count - 1);
      final angleOffset = (t - 0.5) * _spreadAngle;
      final direction = baseDirection.clone()..rotate(angleOffset);
      final roll = rollDamage(parent.stats, _baseDamage);
      game.world.add(
        Projectile(
          position: parent.position.clone(),
          direction: direction,
          speed: weapon.projectileSpeed,
          damage: roll.damage,
          isCritical: roll.isCritical,
          source: parent,
          maxDistance: _effectiveRange,
        ),
      );
    }
  }

  void _firePiercing(Enemy target) {
    final roll = rollDamage(parent.stats, _baseDamage);
    game.world.add(
      Projectile(
        position: parent.position.clone(),
        direction: target.position - parent.position,
        speed: weapon.projectileSpeed,
        damage: roll.damage,
        isCritical: roll.isCritical,
        source: parent,
        maxDistance: _effectiveRange,
        pierceCount: weapon.pierceCount,
        color: _slowColor,
        onHitStatusType: StatusEffectType.slow,
        onHitStatusMagnitude: 0.35,
        onHitStatusDuration: 2,
      ),
    );
  }

  void _fireChain(Enemy initialTarget) {
    final hit = <Enemy>{};
    Enemy? current = initialTarget;
    var origin = parent.position.clone();
    var remainingJumps = weapon.chainCount + bonusChainCount + 1;

    while (current != null && remainingJumps > 0) {
      final roll = rollDamage(parent.stats, _baseDamage);
      current.applyDamage(
        DamageEvent(source: parent, baseDamage: roll.damage, isCritical: roll.isCritical),
      );
      current.applyStatusEffect(
        StatusEffectInstance(type: StatusEffectType.burn, duration: 2, magnitude: 4),
      );
      game.world.add(LightningBolt(start: origin, end: current.position.clone()));

      hit.add(current);
      origin = current.position.clone();
      remainingJumps--;

      final remainingEnemies = game.world.children.query<Enemy>().where(
        (e) => !hit.contains(e),
      );
      current = findNearestEnemy(remainingEnemies, origin, _effectiveRange);
    }
  }

  void _fireMelee() {
    final enemies = game.world.children.query<Enemy>();
    final range = _effectiveRange;
    final rangeSquared = range * range;
    for (final enemy in enemies) {
      if (enemy.isDead) {
        continue;
      }
      if (enemy.position.distanceToSquared(parent.position) > rangeSquared) {
        continue;
      }
      final roll = rollDamage(parent.stats, _baseDamage);
      enemy.applyDamage(
        DamageEvent(source: parent, baseDamage: roll.damage, isCritical: roll.isCritical),
      );
    }
    game.world.add(
      MeleeSlashEffect(position: parent.position.clone(), radius: range),
    );
  }
}
