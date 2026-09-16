/// How a weapon's attack resolves once a target is chosen. A weapon is
/// numbers plus one of these tags, never bespoke firing code — that's what
/// keeps six weapons from becoming six copy-pasted combat systems. The
/// dispatch lives in PlayerWeapons, one method per behavior.
enum WeaponBehavior { singleProjectile, spread, piercing, chain, melee }

/// Data-driven weapon definition.
class WeaponData {
  const WeaponData({
    required this.id,
    required this.name,
    required this.damage,
    required this.attacksPerSecond,
    required this.range,
    required this.projectileSpeed,
    this.behavior = WeaponBehavior.singleProjectile,
    this.projectileCount = 1,
    this.pierceCount = 0,
    this.chainCount = 0,
  });

  final String id;
  final String name;
  final double damage;
  final double attacksPerSecond;
  final double range;
  final double projectileSpeed;
  final WeaponBehavior behavior;

  /// Pellets per shot — only [WeaponBehavior.spread] reads this.
  final int projectileCount;

  /// Extra enemies a [WeaponBehavior.piercing] shot can hit before it dies.
  final int pierceCount;

  /// Extra jumps a [WeaponBehavior.chain] hit arcs to after the first.
  final int chainCount;

  double get cooldown => 1 / attacksPerSecond;
}

class WeaponCatalog {
  WeaponCatalog._();

  static const basicPistol = WeaponData(
    id: 'basic_pistol',
    name: 'Basic Pistol',
    damage: 12,
    attacksPerSecond: 2,
    range: 260,
    projectileSpeed: 480,
  );

  static const rapidRifle = WeaponData(
    id: 'rapid_rifle',
    name: 'Rapid Rifle',
    damage: 5,
    attacksPerSecond: 6,
    range: 340,
    projectileSpeed: 620,
  );

  static const shotgun = WeaponData(
    id: 'shotgun',
    name: 'Shotgun',
    damage: 7,
    attacksPerSecond: 1.2,
    range: 160,
    projectileSpeed: 420,
    behavior: WeaponBehavior.spread,
    projectileCount: 5,
  );

  static const magicOrb = WeaponData(
    id: 'magic_orb',
    name: 'Magic Orb',
    damage: 16,
    attacksPerSecond: 0.9,
    range: 300,
    projectileSpeed: 180,
    behavior: WeaponBehavior.piercing,
    pierceCount: 3,
  );

  static const lightning = WeaponData(
    id: 'lightning',
    name: 'Lightning',
    damage: 10,
    attacksPerSecond: 1.4,
    range: 240,
    projectileSpeed: 0,
    behavior: WeaponBehavior.chain,
    chainCount: 2,
  );

  static const sword = WeaponData(
    id: 'sword',
    name: 'Sword',
    damage: 20,
    attacksPerSecond: 1.6,
    range: 55,
    projectileSpeed: 0,
    behavior: WeaponBehavior.melee,
  );

  /// Assassin's starting weapon — light and fast rather than heavy like
  /// Sword: lower damage per hit, shorter reach, but attacks noticeably
  /// more often, matching a "fast/high crit" class instead of duplicating
  /// Warrior's numbers with a different sprite.
  static const daggers = WeaponData(
    id: 'daggers',
    name: 'Twin Daggers',
    damage: 9,
    attacksPerSecond: 2.4,
    range: 45,
    projectileSpeed: 0,
    behavior: WeaponBehavior.melee,
  );

  static const List<WeaponData> all = [
    basicPistol,
    rapidRifle,
    shotgun,
    magicOrb,
    lightning,
    sword,
    daggers,
  ];
}
