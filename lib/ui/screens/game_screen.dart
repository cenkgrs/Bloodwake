import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  Future<void> _openDeveloperPanel() async {
    final game = _game;
    if (game == null || !game.isLoaded) return;
    final wasPaused = game.paused;
    game.pauseEngine();
    final waveController = TextEditingController(
      text: '${game.waveManager.currentWave}',
    );
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bug_report, color: Color(0xFFD8B579)),
              SizedBox(width: 10),
              Text('PLAYTEST LAB'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Current wave: ${game.waveManager.currentWave}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: waveController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Jump to wave',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      'wave:${int.tryParse(waveController.text) ?? 1}',
                    );
                  },
                  child: const Text('START WAVE'),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, 'wave:10');
                  },
                  child: const Text('START BOSS — WAVE 10'),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, 'upgrades');
                  },
                  child: const Text('OPEN 5 UPGRADE PICKS'),
                ),
                const Divider(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.monetization_on, size: 18),
                      label: const Text('+500 GOLD'),
                      onPressed: () {
                        game.debugGrantGold();
                        setDialogState(() {});
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.favorite, size: 18),
                      label: const Text('FULL HEAL'),
                      onPressed: () {
                        game.debugHealPlayer();
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Gold: ${game.player.currency.gold}  •  '
                  'HP: ${game.player.currentHp.round()}/${game.player.maxHp.round()}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      ),
    );
    waveController.dispose();
    // Mutating Flame overlays while Flutter is still unmounting this dialog
    // caused the inherited-element assertion shown by the playtest build.
    // Apply the requested action only after showDialog has fully returned.
    if (action case final String value when value.startsWith('wave:')) {
      game.debugStartWave(int.tryParse(value.substring(5)) ?? 1);
    } else if (action == 'upgrades') {
      game.debugOpenUpgradePicker();
    }
    if (!wasPaused && game.intermissionScreen.isEmpty) {
      game.resumeEngine();
    }
  }

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
      body: Stack(
        children: [
          GameWidget<RoughlikeGame>(
            game: _game!,
            overlayBuilderMap: {
              'gameOver': (context, game) =>
                  _Entrance(child: GameOverOverlay(game: game)),
              'intermission': (context, game) =>
                  _Entrance(child: IntermissionOverlay(game: game)),
            },
          ),
          if (kDebugMode)
            Positioned(
              top: padding.top + 8,
              right: 10,
              child: Material(
                color: const Color(0xCC161B24),
                shape: const CircleBorder(
                  side: BorderSide(color: Color(0x88D8B579)),
                ),
                child: IconButton(
                  tooltip: 'Playtest Lab',
                  onPressed: _openDeveloperPanel,
                  icon: const Icon(
                    Icons.bug_report,
                    size: 20,
                    color: Color(0xFFD8B579),
                  ),
                ),
              ),
            ),
        ],
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
