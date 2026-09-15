import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../roughlike_game.dart';
import '../systems/damage/damage_event.dart';
import '../systems/damage/damageable.dart';
import '../systems/effects/damage_number.dart';
import '../systems/effects/status_effect.dart';
import '../systems/experience/xp_gem.dart';
import 'ai/archer_ai.dart';
import 'ai/assassin_ai.dart';
import 'ai/boss_ai.dart';
import 'ai/chase_attack_ai.dart';
import 'ai/healer_ai.dart';
import 'enemy_data.dart';

/// Generic enemy shell driven entirely by [EnemyData]. New archetypes are
/// new data + a matching AI component, not a subclass of this.
class Enemy extends PositionComponent
    with CollisionCallbacks, HasGameReference<RoughlikeGame>
    implements Damageable {
  Enemy({required Vector2 position, required this.data})
    : _hp = data.maxHp,
      super(
        position: position,
        size: Vector2.all(data.radius * 2),
        anchor: Anchor.center,
      );

  final EnemyData data;
  double _hp;
  late final CircleComponent _visual;
  final List<StatusEffectInstance> _statusEffects = [];

  @override
  double get currentHp => _hp;

  @override
  double get maxHp => data.maxHp;

  @override
  bool get isDead => _hp <= 0;

  /// 1.0 = full speed. Reduced while a slow effect is active; the
  /// strongest active slow wins rather than stacking multiplicatively, so
  /// two weak slows can't accidentally freeze an enemy in place.
  double get moveSpeedMultiplier {
    var strongestSlow = 0.0;
    for (final effect in _statusEffects) {
      if (effect.type == StatusEffectType.slow && effect.magnitude > strongestSlow) {
        strongestSlow = effect.magnitude;
      }
    }
    return 1 - strongestSlow;
  }

  void applyStatusEffect(StatusEffectInstance effect) {
    final existingIndex = _statusEffects.indexWhere((e) => e.type == effect.type);
    if (existingIndex >= 0) {
      _statusEffects[existingIndex] = effect;
    } else {
      _statusEffects.add(effect);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _visual = CircleComponent(
      radius: data.radius,
      anchor: Anchor.center,
      position: size / 2,
      paint: Paint()..color = data.color,
    );
    add(_visual);
    add(CircleHitbox(collisionType: CollisionType.active));
    switch (data.aiType) {
      case AiType.chaseAndMelee:
        add(ChaseAttackAi(data: data));
      case AiType.archerKite:
        add(ArcherAi(data: data));
      case AiType.assassinDashStrike:
        add(AssassinAi(data: data));
      case AiType.healerSupport:
        add(HealerAi(data: data));
      case AiType.bossPhased:
        add(BossAi(data: data));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDead || _statusEffects.isEmpty) {
      return;
    }
    for (final effect in List.of(_statusEffects)) {
      if (effect.type == StatusEffectType.burn) {
        applyDamage(DamageEvent(source: this, baseDamage: effect.magnitude * dt));
        if (isDead) {
          return;
        }
      }
      effect.duration -= dt;
      if (effect.duration <= 0) {
        _statusEffects.remove(effect);
      }
    }
  }

  @override
  void applyDamage(DamageEvent event) {
    if (isDead) {
      return;
    }
    _hp = (_hp - event.baseDamage).clamp(0, data.maxHp);
    // Self-inflicted ticks (burn) fire every frame — a floating number per
    // tick would just be spam, so only real hits get one.
    if (!identical(event.source, this)) {
      game.world.add(
        DamageNumber(
          position: position + Vector2(0, -data.radius - 4),
          amount: event.baseDamage,
          isCritical: event.isCritical,
        ),
      );
    }
    if (isDead) {
      _die();
    }
  }

  void heal(double amount) {
    if (isDead) {
      return;
    }
    _hp = (_hp + amount).clamp(0, data.maxHp);
    game.world.add(
      DamageNumber(position: position + Vector2(0, -data.radius - 4), amount: amount, isHeal: true),
    );
  }

  /// Toggles the Assassin's brief "vanish" while it repositions. A dim
  /// tint rather than true invisibility — simple placeholder shapes only,
  /// per the prototype's art rules.
  void setHidden(bool hidden) {
    _visual.paint.color = hidden ? data.color.withAlpha(50) : data.color;
  }

  void _die() {
    game.world.add(XpGem(position: position.clone(), value: data.xpReward));
    game.player.currency.add(data.goldReward + game.player.stats.bonusGoldPerKill);
    game.registerKill();
    removeFromParent();
  }
}
