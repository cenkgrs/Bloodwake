import 'package:flame/components.dart';

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
class CharacterSpriteAnimator
    extends SpriteAnimationGroupComponent<_CharAnimState>
    with ParentIsA<Player> {
  CharacterSpriteAnimator({
    required this.characterClass,
    required double displaySize,
  }) : super(size: Vector2.all(displaySize), anchor: Anchor.center);

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
  static const double _hitHoldDuration = _hitStepTime * _frameCount;

  /// Ignore movement jitter under this squared distance per frame when
  /// deciding idle vs run — avoids flickering between the two from
  /// sub-pixel position noise while standing still.
  static const double _movementEpsilonSquared = 0.25;

  double _hitTimer = 0;
  double _attackTimer = 0;
  Vector2? _lastPosition;
  bool _deathTriggered = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (characterClass.id == CharacterClass.warrior) {
      const testFolder = 'assets/images/characters/warrior_rig_test';
      animations = {
        _CharAnimState.idle: await _loadRigAnimation(
          '$testFolder/idle',
          6,
          0.11,
        ),
        _CharAnimState.run: await _loadRigAnimation(
          '$testFolder/run',
          8,
          0.075,
        ),
        _CharAnimState.attack: await _loadRigAnimation(
          '$testFolder/sword_attack',
          8,
          0.075,
          loop: false,
        ),
        _CharAnimState.hit: await _loadRigAnimation(
          '$testFolder/recievehit',
          6,
          0.06,
          loop: false,
        ),
        _CharAnimState.death: await _loadRigAnimation(
          '$testFolder/death',
          8,
          0.12,
          loop: false,
        ),
      };
      current = _CharAnimState.idle;
      return;
    }
    final folder = characterClass.spriteFolder;
    animations = {
      _CharAnimState.idle: await _loadAnimation(
        '$folder/idle.png',
        _idleStepTime,
      ),
      _CharAnimState.run: await _loadAnimation('$folder/run.png', _runStepTime),
      _CharAnimState.attack: await _loadAnimation(
        '$folder/attack.png',
        _attackStepTime,
      ),
      _CharAnimState.hit: await _loadAnimation(
        '$folder/hit.png',
        _hitStepTime,
        loop: false,
      ),
      _CharAnimState.death: await _loadAnimation(
        '$folder/death.png',
        _deathStepTime,
        loop: false,
      ),
    };
    current = _CharAnimState.idle;
  }

  Future<SpriteAnimation> _loadRigAnimation(
    String folder,
    int frameCount,
    double stepTime, {
    bool loop = true,
  }) async {
    final sprites = await Future.wait(
      List.generate(frameCount, (index) async {
        final image = await parent.game.images.load(
          _imageKey('$folder/${index.toString().padLeft(2, '0')}.png'),
        );
        return Sprite(image);
      }),
    );
    return SpriteAnimation.spriteList(sprites, stepTime: stepTime, loop: loop);
  }

  Future<SpriteAnimation> _loadAnimation(
    String assetPath,
    double stepTime, {
    bool loop = true,
  }) async {
    final image = await parent.game.images.load(_imageKey(assetPath));
    // Generated strips include a grey border along their outside edge.
    const inset = 5.0;
    final count =
        assetPath.endsWith('/idle.png') || assetPath.endsWith('/run.png')
        ? 1
        : _frameCount;
    final sprites = List.generate(count, (index) {
      final frameIndex = count == 1 ? 2 : index;
      return Sprite(
        image,
        srcPosition: Vector2(frameIndex * 128.0 + inset, inset),
        srcSize: Vector2(128 - inset * 2, 94),
      );
    });
    return SpriteAnimation.spriteList(sprites, stepTime: stepTime, loop: loop);
  }

  String _imageKey(String assetPath) =>
      assetPath.replaceFirst('assets/images/', '');

  /// Called by PlayerWeapons/PlayerAbilities whenever an attack fires.
  // The generated attack frames change anatomy and camera angle between
  // frames. Automatic weapons can fire every few ticks, making the player
  // appear to thrash constantly. Keep the stable idle/run pose until a
  // properly aligned attack strip is available.
  void triggerAttack() {
    if (characterClass.id == CharacterClass.warrior && _attackTimer <= 0) {
      _attackTimer = 8 * 0.075;
    }
  }

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
    final moving =
        _lastPosition != null &&
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
