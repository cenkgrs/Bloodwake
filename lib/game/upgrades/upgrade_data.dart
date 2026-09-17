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

enum UpgradeRarity { common, rare, epic, legendary }

/// Data-driven upgrade offered on level-up. [apply] takes the whole
/// [Player] rather than just PlayerStats — most upgrades only touch
/// `player.stats`, while class weapon upgrades modify the starting weapon's
/// runtime slot.
///
/// [apply] is a top-level function reference, not a closure capturing
/// state, so instances stay const. [isAvailable] gates upgrades by class;
/// null means the upgrade is shared by every class.
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

  /// Looked up as `assets/images/icons/upgrades/<id>.png` by convention —
  /// see that folder's README. No file there yet is expected, not an
  /// error: CatalogIcon falls back to a category-tinted Material icon
  /// until real art is dropped in, same as SfxPlayer treats missing audio.
  String get iconAsset => 'assets/images/icons/upgrades/$id.png';
}
