import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'character_class.dart';
import 'player.dart';

enum _CharAnimState { idle, run, attack, hit, death }

/// Renders the player as a real animated character instead of a flat
/// circle: picks [characterClass]'s sprite folder (see that folder's
/// README for the expected files) and drives a 5-state machine
/// (idle/run/attack/hit/death) from what the player is actually doing.
///
/// Purely visual — sized independently of [Player]'s collision circle
/// (GameConstants.playerRadius), so swapping in real art here never
/// touches hitbox size, movement, or balance.
///
/// State priority when several could apply at once: death > hit > attack >
/// run > idle. A player who gets hit mid-swing should visibly flinch, not
/// keep swinging through it; death always wins outright.
class CharacterSpriteAnimator extends SpriteAnimationGroupComponent<_CharAnimState>
    with ParentIsA<Player> {
  CharacterSpriteAnimator({required this.characterClass, required double displaySize})
    : super(size: Vector2.all(displaySize), anchor: Anchor.center);

  final CharacterClassData characterClass;

  static const double _idleStepTime = 0.18;
  static const double _runStepTime = 0.10;
  static const double _attackStepTime = 0.07;
  static const double _hitStepTime = 0.06;
  static const double _deathStepTime = 0.12;
  static const int _frameCount = 5;

  /// How long the attack/hit poses hold before falling back to idle/run —
  /// roughly one play-through of that animation's 5 frames at its step
  /// time, so a fast weapon doesn't visibly cut its own swing short.
  static const double _attackHoldDuration = _attackStepTime * _frameCount;
  static const double _hitHoldDuration = _hitStepTime * _frameCount;

  /// Ignore movement jitter under this squared distance per frame when
  /// deciding idle vs run — avoids flickering between the two from
  /// sub-pixel position noise while standing still.
  static const double _movementEpsilonSquared = 0.25;

  double _attackTimer = 0;
  double _hitTimer = 0;
  Vector2? _lastPosition;
  bool _deathTriggered = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final folder = characterClass.spriteFolder;
    animations = {
      _CharAnimState.idle: await _loadAnimation('$folder/idle.png', _idleStepTime),
      _CharAnimState.run: await _loadAnimation('$folder/run.png', _runStepTime),
      _CharAnimState.attack: await _loadAnimation('$folder/attack.png', _attackStepTime),
      _CharAnimState.hit: await _loadAnimation('$folder/hit.png', _hitStepTime, loop: false),
      _CharAnimState.death: await _loadAnimation('$folder/death.png', _deathStepTime, loop: false),
    };
    current = _CharAnimState.idle;
  }

  Future<SpriteAnimation> _loadAnimation(
    String assetPath,
    double stepTime, {
    bool loop = true,
  }) async {
    final bytes = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final sheet = SpriteSheet(image: frame.image, srcSize: Vector2.all(128));
    return sheet.createAnimation(row: 0, stepTime: stepTime, loop: loop, to: _frameCount);
  }

  /// Called by PlayerWeapons/PlayerAbilities whenever an attack fires.
  void triggerAttack() => _attackTimer = _attackHoldDuration;

  /// Called by Player.applyDamage on a real (non-dodged) hit.
  void triggerHit() => _hitTimer = _hitHoldDuration;

  @override
  void update(double dt) {
    super.update(dt);
    if (animations == null) {
      return;
    }

    if (parent.isDead) {
      if (!_deathTriggered) {
        _deathTriggered = true;
        current = _CharAnimState.death;
      }
      return;
    }

    if (_hitTimer > 0) {
      _hitTimer -= dt;
      current = _CharAnimState.hit;
      _applyFacing();
      return;
    }

    if (_attackTimer > 0) {
      _attackTimer -= dt;
      current = _CharAnimState.attack;
      _applyFacing();
      return;
    }

    final position = parent.position;
    final moving = _lastPosition != null &&
        position.distanceToSquared(_lastPosition!) > _movementEpsilonSquared;
    _lastPosition = position.clone();
    current = moving ? _CharAnimState.run : _CharAnimState.idle;
    _applyFacing();
  }

  /// Flips the sprite horizontally to face the player's last movement
  /// direction. Pure vertical movement (dx ~ 0) leaves the previous
  /// horizontal facing alone instead of snapping to a default — otherwise
  /// moving straight up/down would flicker the character back and forth.
  void _applyFacing() {
    final dx = parent.facingDirection.x;
    if (dx.abs() < 0.05) {
      return;
    }
    scale.x = dx < 0 ? -scale.x.abs() : scale.x.abs();
  }
}
