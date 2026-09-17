import 'package:flutter/material.dart';

import '../theme/bloodwake_theme.dart';
import '../theme/fantasy_text.dart';
import 'class_select_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/backgrounds/map1.png', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xE90B1017),
                  Color(0xB8141D27),
                  Color(0xF20B1017),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 650),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              color: BloodwakeTheme.gold,
                              size: 48,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'BLOODWAKE',
                              textAlign: TextAlign.center,
                              style: fantasyText(
                                fontSize: constraints.maxWidth < 600 ? 38 : 64,
                                color: BloodwakeTheme.parchment,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 100,
                              height: 2,
                              color: BloodwakeTheme.ember,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'SURVIVE THE NIGHT. CLAIM THE DAWN.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: BloodwakeTheme.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.3,
                              ),
                            ),
                            const SizedBox(height: 58),
                            SizedBox(
                              width: 290,
                              child: FilledButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ClassSelectScreen(),
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_forward, size: 19),
                                label: Text(
                                  'BEGIN RUN',
                                  style: fantasyText(
                                    fontSize: 16,
                                    color: BloodwakeTheme.parchment,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'ONE LIFE  •  ENDLESS WAVES',
                              style: TextStyle(
                                color: BloodwakeTheme.gold,
                                fontSize: 10,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
