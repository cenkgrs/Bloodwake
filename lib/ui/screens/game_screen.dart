import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/player/character_class.dart';
import '../../game/roughlike_game.dart';
import '../overlays/game_over_overlay.dart';
import '../overlays/intermission_overlay.dart';

/// Hosts the Flame game world. Flutter widgets are reserved for menus, HUD,
/// and overlays layered on top via [GameWidget.overlayBuilderMap]; the
/// real-time simulation itself runs entirely inside [RoughlikeGame].
class GameScreen extends StatefulWidget {
  const GameScreen({required this.characterClass, super.key});

  final CharacterClassData characterClass;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  RoughlikeGame? _game;

  @override
  Widget build(BuildContext context) {
    // No ambient SafeArea here on purpose: the game canvas renders true
    // edge-to-edge so wave-end overlay backgrounds (OverlayBackground) can
    // cover the full screen instead of stopping short at a safe-area
    // boundary and showing the arena in the gap. The insets are captured
    // once here and handed to screen-fixed HUD elements (joystick, skill
    // button, HUD text, boss bar) instead, which add them back in.
    final padding = MediaQuery.paddingOf(context);
    _game ??= RoughlikeGame(
      characterClass: widget.characterClass,
      topInset: padding.top,
      bottomInset: padding.bottom,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B10),
      body: GameWidget<RoughlikeGame>(
        game: _game!,
        overlayBuilderMap: {
          'gameOver': (context, game) =>
              _Entrance(child: GameOverOverlay(game: game)),
          'intermission': (context, game) =>
              _Entrance(child: IntermissionOverlay(game: game)),
        },
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 360),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * 18),
        child: child,
      ),
    ),
    child: child,
  );
}
