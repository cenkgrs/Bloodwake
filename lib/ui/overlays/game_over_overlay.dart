import 'package:flutter/material.dart';

import '../theme/bloodwake_theme.dart';
import '../theme/fantasy_text.dart';
import '../../game/roughlike_game.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({required this.game, super.key});

  final RoughlikeGame game;

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final title = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.shield_outlined,
          size: 42,
          color: BloodwakeTheme.ember,
        ),
        const SizedBox(height: 14),
        Text(
          'THE NIGHT CLAIMS YOU',
          textAlign: TextAlign.center,
          style: fantasyText(
            fontSize: landscape ? 24 : 28,
            color: BloodwakeTheme.parchment,
          ),
        ),
        const SizedBox(height: 14),
        Container(height: 2, width: 74, color: BloodwakeTheme.ember),
      ],
    );
    final summary = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Your run has ended. The next one begins stronger.',
          textAlign: TextAlign.center,
          style: TextStyle(color: BloodwakeTheme.muted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        Text(
          'WAVE ${game.waveManager.currentWave}  •  ${game.killCount} KILLS',
          style: const TextStyle(color: BloodwakeTheme.muted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(
          '+${game.essenceEarned} ESSENCE',
          style: fantasyText(fontSize: 20, color: BloodwakeTheme.gold),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'RETURN TO MENU',
            style: fantasyText(fontSize: 14, color: BloodwakeTheme.parchment),
          ),
        ),
      ],
    );
    return ColoredBox(
      color: const Color(0xED090D14),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: landscape ? 760 : 480,
              padding: EdgeInsets.symmetric(
                horizontal: 32,
                vertical: landscape ? 22 : 44,
              ),
              decoration: BoxDecoration(
                color: BloodwakeTheme.panel,
                border: Border.all(color: BloodwakeTheme.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: landscape
                  ? Row(
                      children: [
                        Expanded(child: title),
                        Container(
                          width: 1,
                          height: 180,
                          color: BloodwakeTheme.line,
                        ),
                        const SizedBox(width: 30),
                        Expanded(child: summary),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [title, const SizedBox(height: 18), summary],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
