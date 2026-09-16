import 'package:flutter/material.dart';

import '../../game/upgrades/upgrade_data.dart' show UpgradeRarity;
import '../theme/rarity_style.dart';

/// Shared card chrome for upgrade/item cards: a rarity-tinted gradient
/// background, a thick glowing border, and the "◆ RARITY ◆" label row —
/// used by both LevelUpOverlay and ShopOverlay so a rarity tier reads the
/// same everywhere instead of each screen hand-rolling its own thin,
/// barely-colored outline.
class RarityCardShell extends StatelessWidget {
  const RarityCardShell({
    required this.rarity,
    required this.dimmed,
    required this.child,
    this.onTap,
    super.key,
  });

  final UpgradeRarity rarity;
  final bool dimmed;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RarityStyle.of(rarity);
    final color = dimmed ? style.color.withValues(alpha: 0.35) : style.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: dimmed ? 0.05 : 0.28),
                const Color(0xF00E101A),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
            boxShadow: dimmed
                ? null
                : [BoxShadow(color: style.glow, blurRadius: 20, spreadRadius: 1)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.diamond, size: 8, color: color),
                    const SizedBox(width: 6),
                    Text(
                      style.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.diamond, size: 8, color: color),
                  ],
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
