import '../player/player_stats.dart';

enum EquipmentSlot { armor, boots, charm }

class EquipmentData {
  const EquipmentData({
    required this.id,
    required this.name,
    required this.description,
    required this.slot,
    required this.cost,
    required this.apply,
  });
  final String id;
  final String name;
  final String description;
  final EquipmentSlot slot;
  final int cost;
  final void Function(PlayerStats) apply;
}

void _bloodplate(PlayerStats s) {
  s.maxHp += 22;
  s.hp += 22;
  s.armor += 0.04;
}

void _shadowCloak(PlayerStats s) {
  s.moveSpeed += 18;
  s.dodgeChance += 0.04;
}

void _stormRobe(PlayerStats s) {
  s.damage += 0.07;
  s.attackRange += 0.07;
}

void _ironGreaves(PlayerStats s) {
  s.armor += 0.03;
  s.maxHp += 10;
  s.hp += 10;
}

void _hunterBoots(PlayerStats s) {
  s.moveSpeed += 22;
  s.pickupRadius += 25;
}

void _arcaneSteps(PlayerStats s) {
  s.moveSpeed += 12;
  s.attackSpeed += 0.06;
}

void _emberSigil(PlayerStats s) => s.damage += 0.10;
void _leechPendant(PlayerStats s) => s.lifesteal += 0.025;
void _scholarRune(PlayerStats s) => s.xpMultiplier += 0.12;

class EquipmentCatalog {
  EquipmentCatalog._();
  static const all = <EquipmentData>[
    EquipmentData(
      id: 'bloodplate',
      name: 'Bloodplate',
      description: '+22 HP, +4% armor',
      slot: EquipmentSlot.armor,
      cost: 12,
      apply: _bloodplate,
    ),
    EquipmentData(
      id: 'shadow_cloak',
      name: 'Shadow Cloak',
      description: '+18 speed, +4% dodge',
      slot: EquipmentSlot.armor,
      cost: 12,
      apply: _shadowCloak,
    ),
    EquipmentData(
      id: 'storm_robe',
      name: 'Storm Robe',
      description: '+7% damage and range',
      slot: EquipmentSlot.armor,
      cost: 14,
      apply: _stormRobe,
    ),
    EquipmentData(
      id: 'iron_greaves',
      name: 'Iron Greaves',
      description: '+10 HP, +3% armor',
      slot: EquipmentSlot.boots,
      cost: 8,
      apply: _ironGreaves,
    ),
    EquipmentData(
      id: 'hunter_boots',
      name: 'Hunter Boots',
      description: '+22 speed, +25 pickup radius',
      slot: EquipmentSlot.boots,
      cost: 8,
      apply: _hunterBoots,
    ),
    EquipmentData(
      id: 'arcane_steps',
      name: 'Arcane Steps',
      description: '+12 speed, +6% attack speed',
      slot: EquipmentSlot.boots,
      cost: 10,
      apply: _arcaneSteps,
    ),
    EquipmentData(
      id: 'ember_sigil',
      name: 'Ember Sigil',
      description: '+10% damage',
      slot: EquipmentSlot.charm,
      cost: 8,
      apply: _emberSigil,
    ),
    EquipmentData(
      id: 'leech_pendant',
      name: 'Leech Pendant',
      description: '+2.5% lifesteal',
      slot: EquipmentSlot.charm,
      cost: 10,
      apply: _leechPendant,
    ),
    EquipmentData(
      id: 'scholar_rune',
      name: 'Scholar Rune',
      description: '+12% XP gain',
      slot: EquipmentSlot.charm,
      cost: 8,
      apply: _scholarRune,
    ),
  ];

  static EquipmentData? byId(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }
}
