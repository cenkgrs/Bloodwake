import '../player/player.dart';
import '../upgrades/upgrade_data.dart' show UpgradeRarity;

/// Shop tab grouping — purely presentational (which category chip an item
/// shows under), unrelated to how it's rolled or applied.
enum ItemCategory { weapon, gear, relic }

/// Data-driven shop item. Same `apply(Player)` shape as UpgradeData (see
/// that class for why) — the difference is entirely in how it's offered:
/// upgrades are free random level-up picks, items are gold purchases in
/// the wave-end shop, capped by GameConstants.maxItemSlots instead of a
/// per-item max level.
///
/// [isAvailable] gates weapon-specific items ("Gold Sword" only makes sense
/// once Sword is owned) the same way UpgradeData does for Chain Lightning —
/// null means always offerable.
class ItemData {
  const ItemData({
    required this.id,
    required this.name,
    required this.description,
    required this.rarity,
    required this.cost,
    required this.category,
    required this.apply,
    this.isAvailable,
  });

  final String id;
  final String name;
  final String description;
  final UpgradeRarity rarity;
  final int cost;
  final ItemCategory category;
  final void Function(Player player) apply;
  final bool Function(Player player)? isAvailable;

  /// Looked up as `assets/images/icons/items/<id>.png` by convention — see
  /// that folder's README. Missing file is expected until art lands;
  /// CatalogIcon falls back to a rarity-tinted Material icon.
  String get iconAsset => 'assets/images/icons/items/$id.png';
}
