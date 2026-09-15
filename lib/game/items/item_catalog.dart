import '../player/player.dart';
import '../upgrades/upgrade_data.dart' show UpgradeRarity;
import 'item_data.dart';

void _armorPlating(Player p) => p.stats.armor += 0.15;
void _evasionCharm(Player p) => p.stats.dodgeChance += 0.10;
void _scope(Player p) => p.stats.attackRange += 0.20;
void _magnet(Player p) => p.stats.pickupRadius *= 1.4;
void _xpBooster(Player p) => p.stats.xpMultiplier += 0.25;
void _regeneration(Player p) => p.stats.regenPerSecond += 2;
void _luckyCoin(Player p) => p.stats.bonusGoldPerKill += 2;
void _secondWind(Player p) => p.stats.hasSecondWind = true;

/// The shop pool: every entry finally gives a purpose to a PlayerStats
/// field that's existed since M01 but nothing ever read (armor,
/// dodgeChance, attackRange, xpMultiplier) — items are deliberately not a
/// second copy of the free skill-upgrade pool, they unlock mechanics
/// upgrades don't touch. Catalog size doubles as the practical slot count
/// (GameConstants.maxWeaponSlots' item counterpart): own all of them and
/// the shop has nothing left to offer.
class ItemCatalog {
  ItemCatalog._();

  static const armorPlating = ItemData(
    id: 'armor_plating',
    name: 'Armor Plating',
    description: '+15% Armor (reduces incoming damage)',
    rarity: UpgradeRarity.common,
    cost: 15,
    apply: _armorPlating,
  );

  static const evasionCharm = ItemData(
    id: 'evasion_charm',
    name: 'Evasion Charm',
    description: '+10% Dodge Chance',
    rarity: UpgradeRarity.common,
    cost: 15,
    apply: _evasionCharm,
  );

  static const scope = ItemData(
    id: 'scope',
    name: 'Scope',
    description: '+20% Attack Range',
    rarity: UpgradeRarity.common,
    cost: 15,
    apply: _scope,
  );

  static const magnet = ItemData(
    id: 'magnet',
    name: 'Magnet',
    description: '+40% Pickup Radius',
    rarity: UpgradeRarity.common,
    cost: 15,
    apply: _magnet,
  );

  static const xpBooster = ItemData(
    id: 'xp_booster',
    name: 'XP Booster',
    description: '+25% XP gained',
    rarity: UpgradeRarity.rare,
    cost: 30,
    apply: _xpBooster,
  );

  static const regeneration = ItemData(
    id: 'regeneration',
    name: 'Regeneration',
    description: '+2 HP regen per second',
    rarity: UpgradeRarity.rare,
    cost: 30,
    apply: _regeneration,
  );

  static const luckyCoin = ItemData(
    id: 'lucky_coin',
    name: 'Lucky Coin',
    description: '+2 Gold per kill',
    rarity: UpgradeRarity.rare,
    cost: 30,
    apply: _luckyCoin,
  );

  static const secondWind = ItemData(
    id: 'second_wind',
    name: 'Second Wind',
    description: 'Survive one lethal hit at 1 HP (once per run)',
    rarity: UpgradeRarity.epic,
    cost: 60,
    apply: _secondWind,
  );

  static const List<ItemData> all = [
    armorPlating,
    evasionCharm,
    scope,
    magnet,
    xpBooster,
    regeneration,
    luckyCoin,
    secondWind,
  ];
}
