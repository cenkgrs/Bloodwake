import 'dart:math';

import '../../player/player_stats.dart';

class CritResult {
  const CritResult({required this.damage, required this.isCritical});

  final double damage;
  final bool isCritical;
}

final _random = Random();

/// Rolls a single attack's crit chance against [stats] and scales
/// [baseDamage] accordingly. Shared by every player attack source
/// (weapon, ability, future ones) so "critical hits" stays one system
/// instead of each attack re-implementing the roll.
CritResult rollDamage(PlayerStats stats, double baseDamage) {
  final isCritical = _random.nextDouble() < stats.criticalChance;
  final damage = baseDamage * (isCritical ? stats.criticalDamage : 1);
  return CritResult(damage: damage, isCritical: isCritical);
}
