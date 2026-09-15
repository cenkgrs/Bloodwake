import 'dart:ui';

import 'package:flame/components.dart';

import '../../roughlike_game.dart';

/// XP pickup dropped by dead enemies. Drifts toward the player once inside
/// their pickup radius and is collected on contact. No leveling/threshold
/// logic here — that's PlayerExperience's job, reached via Player.gainXp.
class XpGem extends PositionComponent with HasGameReference<RoughlikeGame> {
  XpGem({required Vector2 position, required this.value})
    : super(position: position, size: Vector2.all(10), anchor: Anchor.center);

  final int value;

  static const double _collectDistance = 14;
  static const double _magnetSpeed = 320;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      CircleComponent(
        radius: 5,
        anchor: Anchor.center,
        position: size / 2,
        paint: Paint()..color = const Color(0xFF6FFFB0),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    final player = game.player;
    final toPlayer = player.position - position;
    final distance = toPlayer.length;

    if (distance <= _collectDistance) {
      player.gainXp(value);
      removeFromParent();
      return;
    }

    if (distance <= player.stats.pickupRadius) {
      position += (toPlayer / distance) * _magnetSpeed * dt;
    }
  }
}
