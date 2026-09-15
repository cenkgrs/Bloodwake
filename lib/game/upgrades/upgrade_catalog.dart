import '../../core/constants/game_constants.dart';
import '../player/player.dart';
import '../weapons/weapon_data.dart';
import 'upgrade_data.dart';

void _sharpened(Player p) => p.stats.damage += 0.10;
void _rapidFireStat(Player p) => p.stats.attackSpeed += 0.12;
void _vitality(Player p) {
  p.stats.maxHp += 20;
  p.stats.hp += 20;
}

void _predator(Player p) => p.stats.criticalChance += 0.05;
void _vampirism(Player p) => p.stats.lifesteal += 0.02;
void _swift(Player p) => p.stats.moveSpeed *= 1.08;

void _unlockRapidRifle(Player p) => p.addWeapon(WeaponCatalog.rapidRifle);
void _unlockShotgun(Player p) => p.addWeapon(WeaponCatalog.shotgun);
void _unlockMagicOrb(Player p) => p.addWeapon(WeaponCatalog.magicOrb);
void _unlockLightning(Player p) => p.addWeapon(WeaponCatalog.lightning);
void _unlockSword(Player p) => p.addWeapon(WeaponCatalog.sword);

/// Gates every "new weapon" upgrade — once all slots are full, unlocks stop
/// being offered instead of a pick silently doing nothing.
bool _hasWeaponSlotRoom(Player p) => p.weaponSlotCount < GameConstants.maxWeaponSlots;

bool _ownsLightning(Player p) => p.ownsWeapon(WeaponCatalog.lightning.id);
void _chainLightning(Player p) {
  p.weaponSlot(WeaponCatalog.lightning.id)?.bonusChainCount += 1;
}

/// The upgrade pool: global stat boosts, one-time weapon unlocks (picking
/// one adds that weapon as an extra always-firing slot, up to
/// GameConstants.maxWeaponSlots — see Player.addWeapon), and a
/// build-synergy upgrade that only appears once its prerequisite weapon is
/// owned. More synergy upgrades (Bleed, Tank builds from the design doc)
/// are more entries here with their own [UpgradeData.isAvailable] check,
/// not a new system.
class UpgradeCatalog {
  UpgradeCatalog._();

  static const sharpened = UpgradeData(
    id: 'sharpened',
    name: 'Sharpened',
    description: '+10% Damage',
    category: UpgradeCategory.offense,
    rarity: UpgradeRarity.common,
    maxLevel: 5,
    apply: _sharpened,
  );

  static const rapidFireStat = UpgradeData(
    id: 'rapid_fire_stat',
    name: 'Rapid Fire',
    description: '+12% Attack Speed',
    category: UpgradeCategory.offense,
    rarity: UpgradeRarity.common,
    maxLevel: 5,
    apply: _rapidFireStat,
  );

  static const vitality = UpgradeData(
    id: 'vitality',
    name: 'Vitality',
    description: '+20 Max HP',
    category: UpgradeCategory.defense,
    rarity: UpgradeRarity.common,
    maxLevel: 5,
    apply: _vitality,
  );

  static const predator = UpgradeData(
    id: 'predator',
    name: 'Predator',
    description: '+5% Critical Chance',
    category: UpgradeCategory.critical,
    rarity: UpgradeRarity.rare,
    maxLevel: 5,
    apply: _predator,
  );

  static const vampirism = UpgradeData(
    id: 'vampirism',
    name: 'Vampirism',
    description: '+2% Lifesteal',
    category: UpgradeCategory.utility,
    rarity: UpgradeRarity.rare,
    maxLevel: 5,
    apply: _vampirism,
  );

  static const swift = UpgradeData(
    id: 'swift',
    name: 'Swift',
    description: '+8% Movement Speed',
    category: UpgradeCategory.mobility,
    rarity: UpgradeRarity.common,
    maxLevel: 5,
    apply: _swift,
  );

  static const unlockRapidRifle = UpgradeData(
    id: 'unlock_rapid_rifle',
    name: 'Rapid Rifle',
    description: 'New weapon: fast, low-damage auto-fire',
    category: UpgradeCategory.weapon,
    rarity: UpgradeRarity.rare,
    maxLevel: 1,
    apply: _unlockRapidRifle,
    isAvailable: _hasWeaponSlotRoom,
  );

  static const unlockShotgun = UpgradeData(
    id: 'unlock_shotgun',
    name: 'Shotgun',
    description: 'New weapon: 5-pellet close-range spread',
    category: UpgradeCategory.weapon,
    rarity: UpgradeRarity.rare,
    maxLevel: 1,
    apply: _unlockShotgun,
    isAvailable: _hasWeaponSlotRoom,
  );

  static const unlockMagicOrb = UpgradeData(
    id: 'unlock_magic_orb',
    name: 'Magic Orb',
    description: 'New weapon: slow orb, pierces and chills',
    category: UpgradeCategory.weapon,
    rarity: UpgradeRarity.rare,
    maxLevel: 1,
    apply: _unlockMagicOrb,
    isAvailable: _hasWeaponSlotRoom,
  );

  static const unlockLightning = UpgradeData(
    id: 'unlock_lightning',
    name: 'Lightning',
    description: 'New weapon: instant strike, arcs to nearby foes',
    category: UpgradeCategory.weapon,
    rarity: UpgradeRarity.rare,
    maxLevel: 1,
    apply: _unlockLightning,
    isAvailable: _hasWeaponSlotRoom,
  );

  static const unlockSword = UpgradeData(
    id: 'unlock_sword',
    name: 'Sword',
    description: 'New weapon: melee burst around you',
    category: UpgradeCategory.weapon,
    rarity: UpgradeRarity.rare,
    maxLevel: 1,
    apply: _unlockSword,
    isAvailable: _hasWeaponSlotRoom,
  );

  static const chainLightning = UpgradeData(
    id: 'chain_lightning',
    name: 'Chain Lightning',
    description: '+1 Lightning chain target',
    category: UpgradeCategory.elemental,
    rarity: UpgradeRarity.epic,
    maxLevel: 3,
    apply: _chainLightning,
    isAvailable: _ownsLightning,
  );

  static const List<UpgradeData> all = [
    sharpened,
    rapidFireStat,
    vitality,
    predator,
    vampirism,
    swift,
    unlockRapidRifle,
    unlockShotgun,
    unlockMagicOrb,
    unlockLightning,
    unlockSword,
    chainLightning,
  ];
}
