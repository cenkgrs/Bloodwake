import 'package:flutter/material.dart';

import '../../game/items/item_data.dart' show ItemCategory;
import '../../game/upgrades/upgrade_data.dart' show UpgradeCategory;

IconData iconForUpgradeCategory(UpgradeCategory category) => switch (category) {
  UpgradeCategory.offense => Icons.local_fire_department,
  UpgradeCategory.defense => Icons.shield,
  UpgradeCategory.mobility => Icons.directions_run,
  UpgradeCategory.critical => Icons.center_focus_strong,
  UpgradeCategory.elemental => Icons.bolt,
  UpgradeCategory.utility => Icons.auto_fix_high,
  UpgradeCategory.weapon => Icons.gavel,
  UpgradeCategory.special => Icons.auto_awesome,
};

IconData iconForItemCategory(ItemCategory category) => switch (category) {
  ItemCategory.weapon => Icons.gavel,
  ItemCategory.gear => Icons.shield,
  ItemCategory.relic => Icons.diamond,
};

/// Renders a catalog entry's icon: looks for real art at [assetPath] first
/// (see assets/images/icons/README.md for the expected filenames), and
/// falls back to a category-tinted Material icon when it's missing — the
/// screen reads correctly before any art has been dropped in, the same
/// way SfxPlayer no-ops on a missing sound file instead of crashing.
class CatalogIcon extends StatelessWidget {
  const CatalogIcon({
    required this.assetPath,
    required this.fallbackIcon,
    required this.color,
    this.size = 48,
    this.fit = BoxFit.contain,
    super.key,
  });

  final String assetPath;
  final IconData fallbackIcon;
  final Color color;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Icon(fallbackIcon, size: size * 0.65, color: color),
    );
  }
}
