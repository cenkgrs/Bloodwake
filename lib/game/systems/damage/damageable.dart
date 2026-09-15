import 'damage_event.dart';

/// Anything that can receive a [DamageEvent] — the player, an enemy, a
/// destructible prop later on. Weapons and projectiles target this
/// interface, never a concrete `Player` or `Enemy` type, so combat code
/// doesn't need to know what it's hitting.
abstract class Damageable {
  double get currentHp;
  double get maxHp;
  bool get isDead;

  void applyDamage(DamageEvent event);
}
