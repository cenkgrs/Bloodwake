import '../player/player.dart';
import '../upgrades/upgrade_data.dart' show UpgradeRarity;
import '../weapons/weapon_data.dart';
import 'item_data.dart';

void _platinumArmor(Player p) {
  p.stats.armor += 0.10;
  p.stats.maxHp += 20;
  p.stats.hp += 20;
}

void _swiftBoots(Player p) {
  p.stats.moveSpeed *= 1.15;
  p.stats.dodgeChance += 0.10;
}

void _huntersScope(Player p) {
  p.stats.attackRange += 0.20;
  p.stats.criticalChance += 0.05;
}

void _vampiricAmulet(Player p) {
  p.stats.lifesteal += 0.03;
  p.stats.regenPerSecond += 2;
}

void _luckyCharm(Player p) {
  p.stats.bonusGoldPerKill += 3;
  p.stats.xpMultiplier += 0.20;
}

void _guardianAngel(Player p) => p.stats.hasSecondWind = true;

bool _ownsSword(Player p) => p.ownsWeapon(WeaponCatalog.sword.id);
void _goldSword(Player p) {
  final slot = p.weaponSlot(WeaponCatalog.sword.id);
  if (slot != null) {
    slot.bonusDamageMultiplier *= 1.3;
  }
}

bool _ownsLightning(Player p) => p.ownsWeapon(WeaponCatalog.lightning.id);
void _thunderCore(Player p) {
  final slot = p.weaponSlot(WeaponCatalog.lightning.id);
  if (slot != null) {
    slot.bonusDamageMultiplier *= 1.25;
  }
}

/// The shop pool. Deliberately styled as equipment (a named piece with 1-2
/// combined properties) rather than a second copy of the free skill-upgrade
/// pool — "Platinum Armor" (+armor, +HP), not an abstract "+10% Armor"
/// card. Two entries ("Gold Sword", "Thunder Core") boost a specific
/// already-owned weapon instead of a global stat, via
/// PlayerWeapons.bonusDamageMultiplier — the same slot-scoped-bonus pattern
/// Chain Lightning (a free upgrade) already uses for chain count.
///
/// This file is the entire editable surface for shop content: add, remove,
/// or retune an item by editing/adding an entry here and listing it in
/// [all] — nothing else needs to change. If this ever moves to a remote
/// config (Supabase or similar), this file is what a fetched item list
/// would need to match the shape of.
class ItemCatalog {
  ItemCatalog._();

  static const platinumArmor = ItemData(
    id: 'platinum_armor',
    name: 'Platinum Armor',
    description: '+10% Armor, +20 Max HP',
    rarity: UpgradeRarity.common,
    cost: 20,
    category: ItemCategory.gear,
    apply: _platinumArmor,
  );

  static const swiftBoots = ItemData(
    id: 'swift_boots',
    name: 'Swift Boots',
    description: '+15% Move Speed, +10% Dodge Chance',
    rarity: UpgradeRarity.common,
    cost: 20,
    category: ItemCategory.gear,
    apply: _swiftBoots,
  );

  static const huntersScope = ItemData(
    id: 'hunters_scope',
    name: "Hunter's Scope",
    description: '+20% Attack Range, +5% Critical Chance',
    rarity: UpgradeRarity.common,
    cost: 20,
    category: ItemCategory.gear,
    apply: _huntersScope,
  );

  static const vampiricAmulet = ItemData(
    id: 'vampiric_amulet',
    name: 'Vampiric Amulet',
    description: '+3% Lifesteal, +2 HP regen per second',
    rarity: UpgradeRarity.rare,
    cost: 35,
    category: ItemCategory.relic,
    apply: _vampiricAmulet,
  );

  static const luckyCharm = ItemData(
    id: 'lucky_charm',
    name: 'Lucky Charm',
    description: '+3 Gold per kill, +20% XP gained',
    rarity: UpgradeRarity.rare,
    cost: 35,
    category: ItemCategory.relic,
    apply: _luckyCharm,
  );

  static const guardianAngel = ItemData(
    id: 'guardian_angel',
    name: 'Guardian Angel',
    description: 'Survive one lethal hit at 1 HP (once per run)',
    rarity: UpgradeRarity.legendary,
    cost: 65,
    category: ItemCategory.relic,
    apply: _guardianAngel,
  );

  static const goldSword = ItemData(
    id: 'gold_sword',
    name: 'Gold Sword',
    description: '+30% Sword damage',
    rarity: UpgradeRarity.rare,
    cost: 35,
    category: ItemCategory.weapon,
    apply: _goldSword,
    isAvailable: _ownsSword,
  );

  static const thunderCore = ItemData(
    id: 'thunder_core',
    name: 'Thunder Core',
    description: '+25% Lightning damage',
    rarity: UpgradeRarity.rare,
    cost: 35,
    category: ItemCategory.weapon,
    apply: _thunderCore,
    isAvailable: _ownsLightning,
  );

  static const List<ItemData> all = [
    platinumArmor,
    swiftBoots,
    huntersScope,
    vampiricAmulet,
    luckyCharm,
    guardianAngel,
    goldSword,
    thunderCore,
  ];
}
