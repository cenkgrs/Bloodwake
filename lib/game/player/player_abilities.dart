import 'package:flame/components.dart';

import '../abilities/ability_data.dart';
import '../combat/projectiles/projectile.dart';
import '../roughlike_game.dart';
import '../systems/damage/critical_hit.dart';
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
    final roll = rollDamage(parent.stats, ability.damage * parent.stats.damage);
    game.world.add(
      Projectile(
        position: parent.position.clone(),
        direction: direction,
        speed: ability.projectileSpeed,
        damage: roll.damage,
        isCritical: roll.isCritical,
        source: parent,
        maxDistance: ability.range * parent.stats.attackRange,
      ),
    );
    _cooldownRemaining = ability.cooldown;
  }
}
