import 'package:flutter/material.dart';

import '../../game/roughlike_game.dart';
import '../../game/upgrades/upgrade_data.dart';
import '../widgets/pop_in.dart';

/// Shown whenever the player levels up: three random upgrade choices,
/// picking one applies it and resumes the game. Cards stagger in via
/// [PopIn]; styling itself stays plain — rarity colors/icons are a later
/// polish pass.
class LevelUpOverlay extends StatelessWidget {
  const LevelUpOverlay({required this.game, super.key});

  final RoughlikeGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xD0000000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LEVEL UP!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Level ${game.player.experience.level}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 32),
            ...game.currentUpgradeChoices.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: PopIn(
                  key: ValueKey(entry.value.id),
                  delay: Duration(milliseconds: entry.key * 70),
                  child: _UpgradeCard(
                    upgrade: entry.value,
                    level: game.player.upgrades.levelOf(entry.value),
                    onTap: () => game.chooseUpgrade(entry.value),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.upgrade,
    required this.level,
    required this.onTap,
  });

  final UpgradeData upgrade;
  final int level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1D26),
          side: const BorderSide(color: Color(0xFF3A3F4B)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level > 0 ? '${upgrade.name} (Lv ${level + 1})' : upgrade.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    upgrade.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
