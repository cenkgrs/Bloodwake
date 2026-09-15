import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/roughlike_game.dart';
import '../overlays/game_over_overlay.dart';
import '../overlays/level_up_overlay.dart';
import '../overlays/shop_overlay.dart';

/// Hosts the Flame game world. Flutter widgets are reserved for menus, HUD,
/// and overlays layered on top via [GameWidget.overlayBuilderMap]; the
/// real-time simulation itself runs entirely inside [RoughlikeGame].
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final RoughlikeGame _game;

  @override
  void initState() {
    super.initState();
    _game = RoughlikeGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B10),
      body: SafeArea(
        child: GameWidget<RoughlikeGame>(
          game: _game,
          overlayBuilderMap: {
            'gameOver': (context, _) => const GameOverOverlay(),
            'levelUp': (context, game) => LevelUpOverlay(game: game),
            'shop': (context, game) => ShopOverlay(game: game),
          },
        ),
      ),
    );
  }
}
