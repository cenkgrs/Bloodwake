import 'package:flutter/material.dart';

/// Bare-bones death screen. Run statistics (§21: kills, damage dealt,
/// survival time, gold/XP earned) replace this once those systems exist;
/// for M01 the only thing to prove is that death is reachable and visible.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xB0000000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'YOU DIED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('BACK TO MENU'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
