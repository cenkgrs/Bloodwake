enum AbilityBehavior { warCry, fanShot, frostNova, shadowStrike }

enum AbilityIcon { sword, bullets, snowflake, daggers }

class AbilityData {
  const AbilityData({
    required this.id,
    required this.name,
    required this.behavior,
    required this.icon,
    required this.damage,
    required this.cooldown,
    required this.range,
    this.projectileSpeed = 0,
  });

  final String id;
  final String name;
  final AbilityBehavior behavior;
  final AbilityIcon icon;
  final double damage;
  final double cooldown;
  final double projectileSpeed;
  final double range;
}

class AbilityCatalog {
  AbilityCatalog._();

  static const warCry = AbilityData(
    id: 'war_cry',
    name: 'War Cry',
    behavior: AbilityBehavior.warCry,
    icon: AbilityIcon.sword,
    damage: 34,
    cooldown: 6,
    range: 110,
  );
  static const fanShot = AbilityData(
    id: 'fan_shot',
    name: 'Fan Shot',
    behavior: AbilityBehavior.fanShot,
    icon: AbilityIcon.bullets,
    damage: 12,
    cooldown: 5,
    range: 320,
    projectileSpeed: 560,
  );
  static const frostNova = AbilityData(
    id: 'frost_nova',
    name: 'Frost Nova',
    behavior: AbilityBehavior.frostNova,
    icon: AbilityIcon.snowflake,
    damage: 28,
    cooldown: 7,
    range: 125,
  );
  static const shadowStrike = AbilityData(
    id: 'shadow_strike',
    name: 'Shadow Strike',
    behavior: AbilityBehavior.shadowStrike,
    icon: AbilityIcon.daggers,
    damage: 38,
    cooldown: 6,
    range: 135,
  );
}
