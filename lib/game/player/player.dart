import 'dart:ui';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../core/constants/game_constants.dart';
import '../../input/input_provider.dart';
import '../abilities/ability_data.dart';
import '../roughlike_game.dart';
import '../progression/meta_progression.dart';
import '../systems/audio/sfx_player.dart';
import '../systems/damage/damage_event.dart';
import '../systems/damage/damageable.dart';
import '../systems/effects/damage_number.dart';
import '../weapons/weapon_data.dart';
import 'character_class.dart';
import 'character_sprite_animator.dart';
import 'player_abilities.dart';
import 'player_currency.dart';
import 'player_experience.dart';
import 'player_items.dart';
import 'player_movement.dart';
import 'player_stats.dart';
import 'player_upgrades.dart';
import 'player_weapons.dart';

/// The player-controlled character.
///
/// Owns a [PlayerStats] data block and delegates behaviour to focused child
/// components ([PlayerMovement], [PlayerWeapons], [PlayerAbilities]; status
/// effects join in later milestones) instead of accumulating gameplay logic
/// directly on this class. Visual identity, starting weapon, and stat
/// flavor all come from [characterClass] (see CharacterClassCatalog) — the
/// collision hitbox stays a fixed size regardless of class, only the
/// animated sprite drawn on top of it changes.
class Player extends PositionComponent
    with CollisionCallbacks, HasGameReference<RoughlikeGame>
    implements Damageable {
  Player({
    required Vector2 position,
    required InputProvider inputProvider,
    required Vector2 arenaSize,
    required this.characterClass,
    required AbilityData ability,
  }) : stats = _startingStats(characterClass),
       experience = PlayerExperience(),
       upgrades = PlayerUpgrades(),
       currency = PlayerCurrency(),
       items = PlayerItems(),
       abilities = PlayerAbilities(ability: ability),
       _inputProvider = inputProvider,
       _arenaSize = arenaSize,
       super(
         position: position,
         size: Vector2.all(GameConstants.playerRadius * 2),
         anchor: Anchor.center,
       );

  final CharacterClassData characterClass;
  final PlayerStats stats;
  final PlayerExperience experience;
  final PlayerUpgrades upgrades;
  final PlayerCurrency currency;
  final PlayerItems items;
  final PlayerAbilities abilities;
  final InputProvider _inputProvider;
  final Vector2 _arenaSize;
  final Map<String, PlayerWeapons> _weaponSlots = {};
  final Random _dodgeRandom = Random();

  /// On-screen size of the animated sprite — independent of the collision
  /// hitbox (GameConstants.playerRadius), which stays fixed so swapping
  /// class art never touches movement/collision/balance.
  static const double _spriteDisplaySize = 96;

  late final CharacterSpriteAnimator _spriteAnimator;

  /// Last non-zero movement direction, normalized. Used as the aim fallback
  /// when a skill button is tapped rather than dragged. Defaults to "up"
  /// (away from camera) since the player hasn't moved yet at spawn.
  Vector2 facingDirection = Vector2(0, -1);

  double get radius => GameConstants.playerRadius;

  @override
  double get currentHp => stats.hp;

  @override
  double get maxHp => stats.maxHp;

  @override
  bool get isDead => stats.hp <= 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _spriteAnimator = CharacterSpriteAnimator(
      characterClass: characterClass,
      displaySize: _spriteDisplaySize,
    )..position = size / 2;
    add(
      CircleComponent(
        radius: 28,
        anchor: Anchor.center,
        position: size / 2 + Vector2(0, 30),
        scale: Vector2(1, 0.28),
        paint: Paint()..color = const Color(0x66000000),
      ),
    );
    add(_spriteAnimator);
    add(CircleHitbox(collisionType: CollisionType.active));
    add(
      PlayerMovement(
        inputProvider: _inputProvider,
        stats: stats,
        arenaSize: _arenaSize,
      ),
    );
    addWeapon(characterClass.startingWeapon);
    add(abilities);
  }

  bool ownsWeapon(String weaponId) => _weaponSlots.containsKey(weaponId);

  int get weaponSlotCount => _weaponSlots.length;

  PlayerWeapons? weaponSlot(String weaponId) => _weaponSlots[weaponId];

  /// Adds a new weapon slot, firing independently of every other one the
  /// player already owns. No-ops if already owned or if
  /// [GameConstants.maxWeaponSlots] is already full — the upgrade roller
  /// stops offering unlocks at that point too (see UpgradeCatalog), this is
  /// just the defensive backstop. Leveling an owned weapon happens through
  /// slot-specific upgrades (e.g. Chain Lightning), not by re-adding it.
  void addWeapon(WeaponData weapon) {
    if (ownsWeapon(weapon.id) ||
        weaponSlotCount >= GameConstants.maxWeaponSlots) {
      return;
    }
    final slot = PlayerWeapons(weapon: weapon);
    _weaponSlots[weapon.id] = slot;
    add(slot);
  }

  /// Called by PlayerWeapons/PlayerAbilities whenever an attack fires, so
  /// the character sprite plays its attack pose regardless of which
  /// weapon/ability triggered it.
  void triggerAttackAnim() => _spriteAnimator.triggerAttack();

  void gainXp(int amount) {
    final levelsGained = experience.addXp(
      (amount * stats.xpMultiplier).round(),
    );
    if (levelsGained > 0) {
      game.onLevelUp(levelsGained);
    }
  }

  void heal(double amount) {
    if (isDead || stats.hp >= stats.maxHp) return;
    final restored = (stats.maxHp - stats.hp).clamp(0, amount).toDouble();
    stats.hp += restored;
    game.world.add(
      DamageNumber(
        position: position + Vector2(0, -radius - 4),
        amount: restored,
        isHeal: true,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isDead && stats.regenPerSecond > 0) {
      stats.hp = (stats.hp + stats.regenPerSecond * dt).clamp(0, stats.maxHp);
    }
  }

  @override
  void applyDamage(DamageEvent event) {
    if (isDead) {
      return;
    }
    if (_dodgeRoll()) {
      return;
    }
    final mitigated = event.baseDamage * (1 - stats.armor).clamp(0, 1);
    var next = stats.hp - mitigated;
    if (next <= 0 && stats.hasSecondWind) {
      stats.hasSecondWind = false;
      next = 1;
    }
    stats.hp = next.clamp(0, stats.maxHp);
    game.world.add(
      DamageNumber(
        position: position + Vector2(0, -radius - 4),
        amount: mitigated,
      ),
    );
    game.shakeCamera(intensity: (mitigated / 4).clamp(3, 12), duration: 0.18);
    SfxPlayer.playerHit();
    _spriteAnimator.triggerHit();
    if (isDead) {
      game.onPlayerDeath();
    }
  }

  bool _dodgeRoll() =>
      stats.dodgeChance > 0 && _dodgeRandom.nextDouble() < stats.dodgeChance;
}

PlayerStats _startingStats(CharacterClassData characterClass) {
  final stats = characterClass.createStats();
  MetaProgression.instance.applyTo(stats);
  return stats;
}
