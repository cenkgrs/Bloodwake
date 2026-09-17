import 'package:flutter/material.dart';

import '../theme/bloodwake_theme.dart';
import '../theme/fantasy_text.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xED090D14),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 480,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 44),
              decoration: BoxDecoration(
                color: BloodwakeTheme.panel,
                border: Border.all(color: BloodwakeTheme.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 48,
                    color: BloodwakeTheme.ember,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'THE NIGHT CLAIMS YOU',
                    textAlign: TextAlign.center,
                    style: fantasyText(
                      fontSize: 28,
                      color: BloodwakeTheme.parchment,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(height: 2, width: 74, color: BloodwakeTheme.ember),
                  const SizedBox(height: 18),
                  const Text(
                    'Your run has ended. The next one begins stronger.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BloodwakeTheme.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 38),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'RETURN TO MENU',
                      style: fantasyText(
                        fontSize: 14,
                        color: BloodwakeTheme.parchment,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
