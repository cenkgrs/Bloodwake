import 'package:flutter/material.dart';

import '../../game/roughlike_game.dart';
import 'level_up_overlay.dart';
import 'shop_overlay.dart';

class IntermissionOverlay extends StatelessWidget {
  const IntermissionOverlay({required this.game, super.key});

  final RoughlikeGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.intermissionRevision,
      builder: (context, revision, _) {
        final screen = game.intermissionScreen;
        final Widget child = switch (screen) {
          'levelUp' => LevelUpOverlay(key: ValueKey(revision), game: game),
          'shop' => ShopOverlay(key: ValueKey(revision), game: game),
          _ => SizedBox.expand(key: ValueKey(revision)),
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          reverseDuration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: child,
        );
      },
    );
  }
}
