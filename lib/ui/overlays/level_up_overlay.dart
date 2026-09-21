import 'package:flutter/material.dart';

import '../../game/roughlike_game.dart';
import '../../game/upgrades/upgrade_data.dart';
import '../theme/fantasy_text.dart';
import '../theme/rarity_style.dart';
import '../widgets/catalog_icon.dart';
import '../widgets/overlay_background.dart';
import '../widgets/pop_in.dart';
import '../widgets/rarity_card_shell.dart';
import '../widgets/stat_pill.dart';

/// Shown whenever the player levels up: three random upgrade choices (plus
/// one free reroll), picking one applies it and resumes the game. A full
/// dedicated screen (background art, XP bar, rarity-bordered cards) rather
/// than a modal floating over the paused arena.
class LevelUpOverlay extends StatefulWidget {
  const LevelUpOverlay({required this.game, super.key});

  final RoughlikeGame game;

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay> {
  void _reroll() {
    setState(widget.game.rerollLevelUpChoices);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final rerollsLeft =
        RoughlikeGame.maxLevelUpRerolls - game.levelUpRerollsUsed;
    final xp = game.player.experience;
    final isBossReward = game.isChoosingBossReward;

    return OverlayBackground(
      assetPath: 'assets/images/backgrounds/level_up_bg.png',
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatPill(
                    icon: Icons.monetization_on,
                    value: '${game.player.currency.gold}',
                    color: const Color(0xFFFFD23F),
                  ),
                  StatPill(
                    icon: Icons.whatshot,
                    value: '${game.killCount}',
                    color: const Color(0xFFEF5350),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _XpBar(
                level: xp.level,
                progress: xp.xpIntoLevel / xp.xpRequiredForNextLevel,
              ),
            ),
            const SizedBox(height: 24),
            const _Divider(),
            const SizedBox(height: 10),
            Text(
              isBossReward ? 'BOSS REWARD' : 'LEVEL UP!',
              style: fantasyText(
                fontSize: 32,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isBossReward
                  ? 'Choose a rare or stronger upgrade'
                  : 'Choose an upgrade',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...game.currentUpgradeChoices.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: PopIn(
                            key: ValueKey(
                              '${entry.value.id}_${game.levelUpRerollsUsed}',
                            ),
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
              ),
            ),
            if (!isBossReward)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _RerollButton(rerollsLeft: rerollsLeft, onTap: _reroll),
              )
            else
              const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.level, required this.progress});

  final int level;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: const Color(0x33FFFFFF)),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0, 1),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4FC3F7), Color(0xFF7C4DFF)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF12141E),
              border: Border.all(color: const Color(0xFF7C4DFF), width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x887C4DFF), blurRadius: 8),
              ],
            ),
            child: Text(
              '$level',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RerollButton extends StatelessWidget {
  const _RerollButton({required this.rerollsLeft, required this.onTap});

  final int rerollsLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = rerollsLeft > 0;
    final color = enabled ? Colors.white70 : Colors.white24;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: enabled ? Colors.white38 : Colors.white12,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                'Reroll ($rerollsLeft)',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 50, height: 1, color: Colors.white24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.diamond, size: 10, color: Colors.white38),
        ),
        Container(width: 50, height: 1, color: Colors.white24),
      ],
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
    final style = RarityStyle.of(upgrade.rarity);
    return SizedBox(
      width: 320,
      child: RarityCardShell(
        rarity: upgrade.rarity,
        dimmed: false,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: style.color.withValues(alpha: 0.15),
                  border: Border.all(
                    color: style.color.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: style.color.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: CatalogIcon(
                  assetPath: upgrade.iconAsset,
                  fallbackIcon: iconForUpgradeCategory(upgrade.category),
                  color: style.color,
                  size: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level > 0
                          ? '${upgrade.name} (Lv ${level + 1})'
                          : upgrade.name,
                      style: fantasyText(
                        fontSize: 17,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      upgrade.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
