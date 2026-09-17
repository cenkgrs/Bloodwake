import '../player/player.dart';
import '../player/character_class.dart';
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

bool _warrior(Player p) => p.characterClass.id == CharacterClass.warrior;
bool _gunslinger(Player p) => p.characterClass.id == CharacterClass.gunslinger;
bool _mage(Player p) => p.characterClass.id == CharacterClass.mage;
bool _assassin(Player p) => p.characterClass.id == CharacterClass.assassin;

void _greatsword(Player p) =>
    p.weaponSlot(WeaponCatalog.sword.id)?.bonusRangeMultiplier += 0.25;
void _stormBlade(Player p) =>
    p.weaponSlot(WeaponCatalog.sword.id)?.bonusChainCount += 1;
void _shockwave(Player p) =>
    p.weaponSlot(WeaponCatalog.sword.id)?.shockwaveRadius += 35;
void _rifleTempo(Player p) =>
    p.weaponSlot(WeaponCatalog.rapidRifle.id)?.bonusAttackSpeedMultiplier +=
        0.18;
void _rifleCaliber(Player p) =>
    p.weaponSlot(WeaponCatalog.rapidRifle.id)?.bonusDamageMultiplier += 0.20;
void _rifleRange(Player p) =>
    p.weaponSlot(WeaponCatalog.rapidRifle.id)?.bonusRangeMultiplier += 0.15;
void _orbPierce(Player p) =>
    p.weaponSlot(WeaponCatalog.magicOrb.id)?.bonusPierceCount += 1;
void _orbPower(Player p) =>
    p.weaponSlot(WeaponCatalog.magicOrb.id)?.bonusDamageMultiplier += 0.25;
void _orbRange(Player p) =>
    p.weaponSlot(WeaponCatalog.magicOrb.id)?.bonusRangeMultiplier += 0.20;
void _daggerTempo(Player p) =>
    p.weaponSlot(WeaponCatalog.daggers.id)?.bonusAttackSpeedMultiplier += 0.18;
void _daggerReach(Player p) =>
    p.weaponSlot(WeaponCatalog.daggers.id)?.bonusRangeMultiplier += 0.20;
void _daggerEdge(Player p) =>
    p.weaponSlot(WeaponCatalog.daggers.id)?.bonusDamageMultiplier += 0.20;

/// Shared stat boosts and weapon upgrades gated by the selected class.
/// Every class improves its starting weapon instead of unlocking unrelated
/// weapons during a run.
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

  static const greatsword = UpgradeData(
    id: 'greatsword',
    name: 'Greatsword',
    description: '+25% sword reach and larger slash',
    category: UpgradeCategory.weapon,
    rarity: UpgradeRarity.rare,
    maxLevel: 3,
    apply: _greatsword,
    isAvailable: _warrior,
  );
  static const stormBlade = UpgradeData(
    id: 'storm_blade',
    name: 'Storm Blade',
    description: 'Sword hits arc lightning to +1 nearby enemy',
    category: UpgradeCategory.elemental,
    rarity: UpgradeRarity.epic,
    maxLevel: 3,
    apply: _stormBlade,
    isAvailable: _warrior,
  );
  static const shockwave = UpgradeData(
    id: 'shockwave',
    name: 'Shockwave',
    description: 'Every 3rd sword swing hits a wider area',
    category: UpgradeCategory.weapon,
    rarity: UpgradeRarity.epic,
    maxLevel: 3,
    apply: _shockwave,
    isAvailable: _warrior,
  );
  static const rifleTempo = UpgradeData(
    id: 'rifle_tempo',
    name: 'Trigger Tempo',
    description: '+18% rifle fire rate',
    category: UpgradeCategory.weapon,
    rarity: UpgradeRarity.rare,
    maxLevel: 3,
    apply: _rifleTempo,
    isAvailable: _gunslinger,
  );
  static const rifleCaliber = UpgradeData(
    id: 'rifle_caliber',
    name: 'Heavy Caliber',
    description: '+20% rifle damage',
    category: UpgradeCategory.weapon,
    rarity: UpgradeRarity.rare,
    maxLevel: 3,
    apply: _rifleCaliber,
    isAvailable: _gunslinger,
  );
  static const rifleRange = UpgradeData(
    id: 'rifle_range',
    name: 'Long Barrel',
    description: '+15% rifle range',
    category: UpgradeCategory.weapon,
    rarity: UpgradeRarity.rare,
    maxLevel: 3,
    apply: _rifleRange,
    isAvailable: _gunslinger,
  );
  static const orbPierce = UpgradeData(
    id: 'orb_pierce',
    name: 'Piercing Orb',
    description: 'Magic orb pierces +1 enemy',
    category: UpgradeCategory.elemental,
    rarity: UpgradeRarity.rare,
    maxLevel: 3,
    apply: _orbPierce,
    isAvailable: _mage,
  );
  static const orbPower = UpgradeData(
    id: 'orb_power',
    name: 'Arcane Focus',
    description: '+25% magic orb damage',
    category: UpgradeCategory.elemental,
    rarity: UpgradeRarity.rare,
    maxLevel: 3,
    apply: _orbPower,
    isAvailable: _mage,
  );
  static const orbRange = UpgradeData(
    id: 'orb_range',
    name: 'Far Sight',
    description: '+20% magic orb range',
    category: UpgradeCategory.elemental,
    rarity: UpgradeRarity.rare,
    maxLevel: 3,
    apply: _orbRange,
    isAvailable: _mage,
  );
  static const daggerTempo = UpgradeData(
    id: 'dagger_tempo',
    name: 'Flurry',
    description: '+18% dagger attack speed',
    category: UpgradeCategory.weapon,
    rarity: UpgradeRarity.rare,
    maxLevel: 3,
    apply: _daggerTempo,
    isAvailable: _assassin,
  );
  static const daggerReach = UpgradeData(
    id: 'dagger_reach',
    name: 'Long Blades',
    description: '+20% dagger reach and larger slash',
    category: UpgradeCategory.weapon,
    rarity: UpgradeRarity.rare,
    maxLevel: 3,
    apply: _daggerReach,
    isAvailable: _assassin,
  );
  static const daggerEdge = UpgradeData(
    id: 'dagger_edge',
    name: 'Razor Edge',
    description: '+20% dagger damage',
    category: UpgradeCategory.weapon,
    rarity: UpgradeRarity.rare,
    maxLevel: 3,
    apply: _daggerEdge,
    isAvailable: _assassin,
  );

  static const List<UpgradeData> all = [
    sharpened,
    rapidFireStat,
    vitality,
    predator,
    vampirism,
    swift,
    greatsword,
    stormBlade,
    shockwave,
    rifleTempo,
    rifleCaliber,
    rifleRange,
    orbPierce,
    orbPower,
    orbRange,
    daggerTempo,
    daggerReach,
    daggerEdge,
  ];
}
