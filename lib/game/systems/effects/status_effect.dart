/// Slow reduces move speed; burn and bleed tick damage over time.
/// New types are a new case here plus a branch in Enemy's tick, not a new
/// per-effect class — that's what keeps this reusable across whichever
/// weapon or ability applies one next.
enum StatusEffectType { slow, burn, bleed }

/// A single active effect on an enemy.
///
/// [magnitude] means different things per [type]: for [StatusEffectType.slow]
/// it's the fraction of move speed removed (0.3 = -30%); for
/// [StatusEffectType.burn] and [StatusEffectType.bleed] it's damage per second.
class StatusEffectInstance {
  StatusEffectInstance({
    required this.type,
    required this.duration,
    required this.magnitude,
  });

  final StatusEffectType type;
  double duration;
  final double magnitude;
}
