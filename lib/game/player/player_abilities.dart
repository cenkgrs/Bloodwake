import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants/game_constants.dart';
import '../abilities/ability_data.dart';
import '../combat/projectiles/projectile.dart';
import '../enemies/enemy.dart';
import '../roughlike_game.dart';
import '../systems/audio/sfx_player.dart';
import '../systems/damage/critical_hit.dart';
import '../systems/damage/damage_event.dart';
import '../systems/effects/melee_slash_effect.dart';
import '../systems/effects/status_effect.dart';
import 'player.dart';

/// Manually triggered ability on its own cooldown, independent of the
/// auto-firing weapon. [activate] is called by whatever input source reads
/// player intent (today: the skill button's aim-and-release gesture) — this
/// class only knows "fire this direction now", not how that direction was
/// chosen.
class PlayerAbilities extends Component
    with ParentIsA<Player>, HasGameReference<RoughlikeGame> {
  PlayerAbilities({required this.ability});

  final AbilityData ability;
  double _cooldownRemaining = 0;

  bool get isReady => _cooldownRemaining <= 0;
  double get cooldownRemaining => _cooldownRemaining.clamp(0, ability.cooldown);

  @override
  void update(double dt) {
    if (_cooldownRemaining > 0) {
      _cooldownRemaining -= dt;
    }
  }

  void activate(Vector2 direction) {
    if (parent.isDead || !isReady || direction.isZero()) {
      return;
    }
    switch (ability.behavior) {
      case AbilityBehavior.warCry:
        _areaDamage(const Color(0xFFFFA24A));
      case AbilityBehavior.fanShot:
        _fanShot(direction);
      case AbilityBehavior.frostNova:
        _areaDamage(const Color(0xFF8FDEFF), slow: true);
      case AbilityBehavior.shadowStrike:
        final destination =
            parent.position + direction.normalized() * ability.range;
        parent.position = Vector2(
          destination.x.clamp(0, GameConstants.arenaSize.x),
          destination.y.clamp(0, GameConstants.arenaSize.y),
        );
        _areaDamage(const Color(0xFFB897FF), radius: 65);
    }
    SfxPlayer.shoot();
    parent.triggerAttackAnim();
    _cooldownRemaining = ability.cooldown;
  }

  void _areaDamage(Color color, {bool slow = false, double? radius}) {
    final hitRadius = (radius ?? ability.range) * parent.stats.attackRange;
    for (final enemy in game.world.children.query<Enemy>()) {
      if (enemy.isDead ||
          enemy.position.distanceToSquared(parent.position) >
              hitRadius * hitRadius) {
        continue;
      }
      final roll = rollDamage(
        parent.stats,
        ability.damage * parent.stats.damage,
      );
      enemy.applyDamage(
        DamageEvent(
          source: parent,
          baseDamage: roll.damage,
          isCritical: roll.isCritical,
        ),
      );
      if (slow) {
        enemy.applyStatusEffect(
          StatusEffectInstance(
            type: StatusEffectType.slow,
            duration: 3,
            magnitude: 0.45,
          ),
        );
      }
    }
    game.world.add(
      MeleeSlashEffect(
        position: parent.position.clone(),
        radius: hitRadius,
        color: color,
      ),
    );
  }

  void _fanShot(Vector2 direction) {
    for (var i = -2; i <= 2; i++) {
      final shotDirection = direction.clone()..rotate(i * 0.16);
      final roll = rollDamage(
        parent.stats,
        ability.damage * parent.stats.damage,
      );
      game.world.add(
        Projectile(
          position: parent.position.clone(),
          direction: shotDirection,
          speed: ability.projectileSpeed,
          damage: roll.damage,
          isCritical: roll.isCritical,
          source: parent,
          maxDistance: ability.range * parent.stats.attackRange,
          color: const Color(0xFFFFD27A),
        ),
      );
    }
  }
}
