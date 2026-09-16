import 'package:flutter/material.dart';

import '../../game/upgrades/upgrade_data.dart' show UpgradeRarity;

/// Visual language for a rarity tier — border/glow color and the label
/// text shown on a card. One lookup table shared by upgrade and item
/// cards so a rarity always reads the same way everywhere.
class RarityStyle {
  const RarityStyle({required this.color, required this.glow, required this.label});

  final Color color;
  final Color glow;
  final String label;

  static RarityStyle of(UpgradeRarity rarity) => switch (rarity) {
    UpgradeRarity.common => const RarityStyle(
      color: Color(0xFFD7DEE6),
      glow: Color(0x40D7DEE6),
      label: 'COMMON',
    ),
    UpgradeRarity.rare => const RarityStyle(
      color: Color(0xFF4FC3F7),
      glow: Color(0x554FC3F7),
      label: 'RARE',
    ),
    UpgradeRarity.epic => const RarityStyle(
      color: Color(0xFFB388FF),
      glow: Color(0x55B388FF),
      label: 'EPIC',
    ),
    UpgradeRarity.legendary => const RarityStyle(
      color: Color(0xFFFFC94A),
      glow: Color(0x66FFC94A),
      label: 'LEGENDARY',
    ),
  };
}
