/// Broad damage categories. Only [physical] is dealt in M01; the rest exist
/// so weapons/enemies can declare their damage type now without every call
/// site needing to change when elemental status effects (M05) land.
enum DamageType { physical, fire, lightning, poison }

/// A single instance of damage moving from a source to a target.
///
/// Every attack — melee, projectile, area, future DoT ticks — should produce
/// one of these rather than calling `target.hp -= x` directly. That keeps
/// damage math (crit rolls, armor, lifesteal, on-hit effects) in one place
/// and is the same shape that ports cleanly to an Unreal damage event later.
class DamageEvent {
  DamageEvent({
    required this.source,
    required this.baseDamage,
    this.damageType = DamageType.physical,
    this.isCritical = false,
  });

  final Object source;
  final double baseDamage;
  final DamageType damageType;
  final bool isCritical;
}
