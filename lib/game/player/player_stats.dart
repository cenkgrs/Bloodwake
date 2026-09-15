/// Mutable player attribute block.
///
/// [damage], [attackSpeed], [attackRange] are global multipliers (1.0 =
/// 100%), matching how upgrades/items describe themselves ("+10% Damage"
/// adds 0.1) — weapons carry their own base numbers and get scaled by
/// these, they aren't replaced by them. [armor] and [dodgeChance] are
/// fractions (0.15 = 15%); [regenPerSecond] is flat HP/s.
class PlayerStats {
  PlayerStats({
    this.maxHp = 100,
    this.moveSpeed = 220,
    this.damage = 1.0,
    this.attackSpeed = 1.0,
    this.attackRange = 1.0,
    this.criticalChance = 0.05,
    this.criticalDamage = 1.5,
    this.armor = 0,
    this.dodgeChance = 0,
    this.lifesteal = 0,
    this.xpMultiplier = 1.0,
    this.pickupRadius = 80,
    this.regenPerSecond = 0,
    this.bonusGoldPerKill = 0,
    this.hasSecondWind = false,
  }) : hp = maxHp;

  double hp;
  double maxHp;
  double moveSpeed;
  double damage;
  double attackSpeed;
  double attackRange;
  double criticalChance;
  double criticalDamage;
  double armor;
  double dodgeChance;
  double lifesteal;
  double xpMultiplier;
  double pickupRadius;
  double regenPerSecond;
  int bonusGoldPerKill;

  /// One-time save from a lethal hit, consumed by Player.applyDamage. Set
  /// by the "Second Wind" item.
  bool hasSecondWind;
}
