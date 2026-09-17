import 'dart:ui';

import '../weapons/weapon_data.dart';
import '../abilities/ability_data.dart';
import 'player_stats.dart';

enum CharacterClass { warrior, gunslinger, mage, assassin }

/// Data-driven class definition: visual identity (sprite folder, accent
/// color), starting loadout (weapon), and stat flavor — the same
/// "numbers + a small factory, not a subclass" shape as WeaponData/
/// EnemyData/UpgradeData. Picking a class at run start only sets these
/// three things; the rest of the game (weapon slots, upgrades, shop) is
/// unchanged and still shared across all four.
class CharacterClassData {
  const CharacterClassData({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.accentColor,
    required this.startingWeapon,
    required this.startingAbility,
    required this.createStats,
  });

  final CharacterClass id;
  final String name;
  final String tagline;
  final String description;
  final Color accentColor;
  final WeaponData startingWeapon;
  final AbilityData startingAbility;

  /// Fresh [PlayerStats] for a run with this class — a factory rather than
  /// a shared const instance since PlayerStats is mutable (upgrades/items
  /// mutate it in place through a run).
  final PlayerStats Function() createStats;

  /// `assets/images/characters/<id>` — see that folder's README for the
  /// expected `idle/run/attack/hit/death.png` files.
  String get spriteFolder => 'assets/images/characters/${id.name}';
}

class CharacterClassCatalog {
  CharacterClassCatalog._();

  static final warrior = CharacterClassData(
    id: CharacterClass.warrior,
    name: 'Warrior',
    tagline: 'MELEE · DURABLE · CLOSE COMBAT',
    description:
        'Heavily armored frontline fighter. High HP and armor, '
        'trades mobility for the ability to stand and take a hit.',
    accentColor: const Color(0xFFE05C5C),
    startingWeapon: WeaponCatalog.sword,
    startingAbility: AbilityCatalog.warCry,
    createStats: () => PlayerStats(maxHp: 130, moveSpeed: 200, armor: 0.10),
  );

  static final gunslinger = CharacterClassData(
    id: CharacterClass.gunslinger,
    name: 'Gunslinger',
    tagline: 'RANGED · HIGH DPS · MOBILITY',
    description:
        'Fast-firing ranged hunter. Outruns and outguns anything '
        'that gets close, but can\'t take much punishment.',
    accentColor: const Color(0xFFE0A73F),
    startingWeapon: WeaponCatalog.rapidRifle,
    startingAbility: AbilityCatalog.fanShot,
    createStats: () =>
        PlayerStats(maxHp: 90, moveSpeed: 235, attackSpeed: 1.15),
  );

  static final mage = CharacterClassData(
    id: CharacterClass.mage,
    name: 'Mage',
    tagline: 'AREA DAMAGE · ELEMENTAL · CONTROL',
    description:
        'Channels a piercing, chilling orb that punishes groups. '
        'Hits hard from range, but has the least HP of any class.',
    accentColor: const Color(0xFF7C4DFF),
    startingWeapon: WeaponCatalog.magicOrb,
    startingAbility: AbilityCatalog.frostNova,
    createStats: () => PlayerStats(maxHp: 85, moveSpeed: 215, damage: 1.20),
  );

  static final assassin = CharacterClassData(
    id: CharacterClass.assassin,
    name: 'Assassin',
    tagline: 'FAST · HIGH CRIT · EVASION',
    description:
        'Twin daggers, blistering attack speed, and a real chance '
        'to simply not be there when the hit lands.',
    accentColor: const Color(0xFF4CD98A),
    startingWeapon: WeaponCatalog.daggers,
    startingAbility: AbilityCatalog.shadowStrike,
    createStats: () => PlayerStats(
      maxHp: 80,
      moveSpeed: 245,
      criticalChance: 0.15,
      criticalDamage: 1.8,
      dodgeChance: 0.08,
    ),
  );

  static final List<CharacterClassData> all = [
    warrior,
    gunslinger,
    mage,
    assassin,
  ];
}
