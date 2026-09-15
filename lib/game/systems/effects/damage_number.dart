import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';

/// Floating combat text: rises and disappears. The only way the player can
/// currently see crit rolls, armor mitigation, or heals landing — without
/// this, several stats (armor, dodge, regen) would be invisible even when
/// working correctly.
class DamageNumber extends TextComponent {
  DamageNumber({
    required Vector2 position,
    required double amount,
    this.isCritical = false,
    this.isHeal = false,
  }) : super(
         text: '${isHeal ? '+' : ''}${amount.round()}',
         position: position.clone(),
         anchor: Anchor.center,
         textRenderer: TextPaint(
           style: TextStyle(
             color: isHeal
                 ? const Color(0xFF6FFFB0)
                 : (isCritical ? const Color(0xFFFFD23F) : const Color(0xFFFFFFFF)),
             fontSize: isCritical ? 20 : 14,
             fontWeight: isCritical ? FontWeight.bold : FontWeight.normal,
           ),
         ),
         priority: 20,
       );

  final bool isCritical;
  final bool isHeal;

  double _age = 0;
  static const double lifetime = 0.6;
  static const double riseSpeed = 42;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position.y -= riseSpeed * dt;
    if (_age >= lifetime) {
      removeFromParent();
    }
  }
}
