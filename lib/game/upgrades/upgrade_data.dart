import '../player/player.dart';

enum UpgradeCategory {
  offense,
  defense,
  mobility,
  critical,
  elemental,
  utility,
  weapon,
  special,
}

enum UpgradeRarity { common, rare, epic }

/// Data-driven upgrade offered on level-up. [apply] takes the whole
/// [Player] rather than just PlayerStats — most upgrades only touch
/// `player.stats`, but weapon-unlock upgrades need `player.addWeapon(...)`
/// and synergy upgrades need a specific weapon slot, so the hook has to be
/// wide enough for all three without three different upgrade classes.
///
/// [apply] is a top-level function reference, not a closure capturing
/// state, so instances stay const. [isAvailable] gates synergy upgrades
/// that only make sense once a prerequisite is met (e.g. "Chain Lightning"
/// requires already owning the Lightning weapon) — null means always
/// available.
class UpgradeData {
  const UpgradeData({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.rarity,
    required this.maxLevel,
    required this.apply,
    this.isAvailable,
  });

  final String id;
  final String name;
  final String description;
  final UpgradeCategory category;
  final UpgradeRarity rarity;
  final int maxLevel;
  final void Function(Player player) apply;
  final bool Function(Player player)? isAvailable;
}
