import 'package:flutter/material.dart';

import '../../game/player/character_class.dart';
import '../theme/fantasy_text.dart';
import 'game_screen.dart';

/// Shown after "Start Run", before the game itself: pick one of the four
/// classes in [CharacterClassCatalog]. The choice only sets three things —
/// starting weapon, stat flavor, and which sprite folder the player's
/// CharacterSpriteAnimator loads (see character_class.dart) — everything
/// else (weapon slots, upgrades, shop) is unchanged and still shared.
class ClassSelectScreen extends StatelessWidget {
  const ClassSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B10),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              'CHOOSE YOUR CLASS',
              style: fantasyText(fontSize: 26, color: Colors.white, letterSpacing: 3),
            ),
            const SizedBox(height: 6),
            const Text(
              'Same world. Different paths.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                children: [
                  for (final classData in CharacterClassCatalog.all)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ClassCard(
                        classData: classData,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GameScreen(characterClass: classData),
                            ),
                          );
                        },
                      ),
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

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.classData, required this.onTap});

  final CharacterClassData classData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = classData.accentColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.20), const Color(0xF00E101A)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 1.5),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16)],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: color.withValues(alpha: 0.15),
                  border: Border.all(color: color.withValues(alpha: 0.7)),
                ),
                child: _ClassPreview(spriteFolder: classData.spriteFolder, size: 84),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classData.name,
                      style: fantasyText(fontSize: 19, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      classData.tagline,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      classData.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3),
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

/// Crops the idle animation strip down to just its first frame (leftmost
/// 128x128 of the 640x128 sheet) for a static thumbnail — the animated
/// version only ever appears once the run actually starts.
class _ClassPreview extends StatelessWidget {
  const _ClassPreview({required this.spriteFolder, required this.size});

  final String spriteFolder;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        maxWidth: size * 5,
        minWidth: size * 5,
        maxHeight: size,
        minHeight: size,
        alignment: Alignment.centerLeft,
        child: Image.asset(
          '$spriteFolder/idle.png',
          width: size * 5,
          height: size,
          fit: BoxFit.fill,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
