/// Data-driven manual ability, same spirit as [WeaponData] but triggered by
/// the player (skill button) instead of firing automatically. New abilities
/// are new [AbilityData] constants; the firing code stays generic.
class AbilityData {
  const AbilityData({
    required this.id,
    required this.name,
    required this.damage,
    required this.cooldown,
    required this.projectileSpeed,
    required this.range,
  });

  final String id;
  final String name;
  final double damage;
  final double cooldown;
  final double projectileSpeed;
  final double range;
}

class AbilityCatalog {
  AbilityCatalog._();

  static const spearThrow = AbilityData(
    id: 'spear_throw',
    name: 'Spear Throw',
    damage: 30,
    cooldown: 2.5,
    projectileSpeed: 720,
    range: 420,
  );
}
