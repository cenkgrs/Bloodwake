import 'package:flutter/material.dart';

import '../../game/player/character_class.dart';
import '../theme/bloodwake_theme.dart';
import '../theme/fantasy_text.dart';
import 'game_screen.dart';
import '../widgets/soft_route.dart';

class ClassSelectScreen extends StatelessWidget {
  const ClassSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/backgrounds/map1.png', fit: BoxFit.cover),
          const ColoredBox(color: Color(0xDA0B1017)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 790;
                final landscape = constraints.maxWidth > constraints.maxHeight;
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 48 : 20,
                        landscape ? 4 : 16,
                        wide ? 48 : 20,
                        12,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back, size: 17),
                                label: const Text('BACK'),
                                style: TextButton.styleFrom(
                                  foregroundColor: BloodwakeTheme.muted,
                                ),
                              ),
                              SizedBox(height: landscape ? 0 : 12),
                              if (!landscape) ...[
                                const Text(
                                  'THE FIRST CHOICE',
                                  style: TextStyle(
                                    color: BloodwakeTheme.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Text(
                                'Choose your survivor',
                                style: fantasyText(
                                  fontSize: landscape ? 25 : (wide ? 34 : 26),
                                  color: BloodwakeTheme.parchment,
                                ),
                              ),
                              if (!landscape) ...[
                                const SizedBox(height: 7),
                                const Text(
                                  'Each path begins with a different weapon and fighting style.',
                                  style: TextStyle(
                                    color: BloodwakeTheme.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              SizedBox(height: landscape ? 8 : 22),
                              Container(
                                height: 1,
                                color: BloodwakeTheme.line.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 48 : 20,
                        8,
                        wide ? 48 : 20,
                        32,
                      ),
                      sliver: SliverLayoutBuilder(
                        builder: (context, sliverConstraints) {
                          final columns = landscape ? 4 : (wide ? 2 : 1);
                          return SliverGrid.builder(
                            itemCount: CharacterClassCatalog.all.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  mainAxisExtent: landscape
                                      ? 245
                                      : (wide ? 210 : 190),
                                ),
                            itemBuilder: (context, index) {
                              final data = CharacterClassCatalog.all[index];
                              return _ClassCard(
                                classData: data,
                                compact: landscape,
                                onTap: () => Navigator.of(context).push(
                                  softRoute(GameScreen(characterClass: data)),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.classData,
    required this.onTap,
    this.compact = false,
  });

  final CharacterClassData classData;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = classData.accentColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Ink(
          decoration: BoxDecoration(
            color: BloodwakeTheme.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: BloodwakeTheme.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x6C000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: compact
              ? Column(
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  color.withValues(alpha: 0.27),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          _ClassPreview(classData: classData),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: Column(
                        children: [
                          Text(
                            classData.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: fantasyText(
                              fontSize: 14,
                              color: BloodwakeTheme.parchment,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            classData.tagline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'SELECT',
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(5),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 135,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  color.withValues(alpha: 0.27),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          _ClassPreview(classData: classData),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 18, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              classData.name.toUpperCase(),
                              style: fantasyText(
                                fontSize: 19,
                                color: BloodwakeTheme.parchment,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              classData.tagline,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Expanded(
                              child: Text(
                                classData.description,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: BloodwakeTheme.muted,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'SELECT CLASS',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Icon(
                                  Icons.arrow_forward,
                                  size: 14,
                                  color: color,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ClassPreview extends StatelessWidget {
  const _ClassPreview({required this.classData});

  final CharacterClassData classData;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) => OverflowBox(
          maxWidth: constraints.maxWidth * 5,
          minWidth: constraints.maxWidth * 5,
          maxHeight: constraints.maxHeight,
          minHeight: constraints.maxHeight,
          alignment: Alignment.centerLeft,
          child: Image.asset(
            '${classData.spriteFolder}/idle.png',
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
