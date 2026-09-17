import 'dart:ui';

enum EnemyType { grunt, archer, tank, assassin, healer, commander, boss }

enum AiType {
  chaseAndMelee,
  archerKite,
  assassinDashStrike,
  healerSupport,
  bossPhased,
}

/// Data-driven enemy archetype. New enemy types are new [EnemyData]
/// constants, not new Dart classes — [Enemy] stays generic and reads
/// behaviour numbers from here. Only the fields an [aiType] actually uses
/// matter for it; the rest sit at harmless defaults (0) for archetypes that
/// don't need them (e.g. a melee Grunt never reads [projectileSpeed]).
class EnemyData {
  const EnemyData({
    required this.type,
    required this.aiType,
    required this.maxHp,
    required this.moveSpeed,
    required this.damage,
    required this.attackRange,
    required this.attackCooldown,
    required this.xpReward,
    required this.goldReward,
    required this.radius,
    required this.color,
    this.unlockWave = 1,
    this.spawnWeight = 1,
    this.preferredRange = 0,
    this.projectileSpeed = 0,
    this.supportRadius = 0,
    this.healAmount = 0,
    this.isElite = false,
  });

  final EnemyType type;
  final AiType aiType;
  final double maxHp;
  final double moveSpeed;
  final double damage;
  final double attackRange;
  final double attackCooldown;
  final int xpReward;
  final int goldReward;
  final double radius;
  final Color color;

  /// First wave SpawnDirector is allowed to spawn this archetype in.
  final int unlockWave;

  /// Relative weight in the random composition pick among unlocked types.
  final int spawnWeight;

  /// Distance a kiting archetype (Archer, Healer) tries to keep from the
  /// player.
  final double preferredRange;

  /// Archer's shot speed.
  final double projectileSpeed;

  /// Healer's ally-search radius.
  final double supportRadius;

  /// Healer's heal amount per activation.
  final double healAmount;
  final bool isElite;

  double get healthDropChance => type == EnemyType.boss
      ? 1
      : isElite
      ? 0.22
      : 0.08;
  double get healthDropAmount => type == EnemyType.boss
      ? 70
      : isElite
      ? 35
      : 18;

  static const Color eliteColor = Color(0xFFFF8A00);

  /// Applies wave-based difficulty scaling and, optionally, the elite
  /// modifier (bigger, tougher, better rewards, orange per the placeholder
  /// palette) without needing a separate Elite enemy class.
  EnemyData scaled({double statMultiplier = 1, bool elite = false}) {
    if (statMultiplier == 1 && !elite) {
      return this;
    }
    const eliteStatMultiplier = 2.5;
    const eliteRewardMultiplier = 4;
    return EnemyData(
      type: type,
      aiType: aiType,
      maxHp: maxHp * statMultiplier * (elite ? eliteStatMultiplier : 1),
      moveSpeed: moveSpeed * (elite ? 1.15 : 1),
      damage: damage * statMultiplier * (elite ? 1.4 : 1),
      attackRange: attackRange,
      attackCooldown: attackCooldown,
      xpReward: elite ? xpReward * eliteRewardMultiplier : xpReward,
      goldReward: elite ? goldReward * eliteRewardMultiplier : goldReward,
      radius: elite ? radius * 1.35 : radius,
      color: elite ? eliteColor : color,
      unlockWave: unlockWave,
      spawnWeight: spawnWeight,
      preferredRange: preferredRange,
      projectileSpeed: projectileSpeed,
      supportRadius: supportRadius,
      healAmount: elite ? healAmount * eliteStatMultiplier : healAmount,
      isElite: elite,
    );
  }
}

class EnemyCatalog {
  EnemyCatalog._();

  static const grunt = EnemyData(
    type: EnemyType.grunt,
    aiType: AiType.chaseAndMelee,
    maxHp: 30,
    moveSpeed: 90,
    damage: 8,
    attackRange: 28,
    attackCooldown: 1.0,
    xpReward: 5,
    goldReward: 1,
    radius: 16,
    color: Color(0xFFE0463F),
    unlockWave: 1,
    spawnWeight: 5,
  );

  static const archer = EnemyData(
    type: EnemyType.archer,
    aiType: AiType.archerKite,
    maxHp: 20,
    moveSpeed: 80,
    damage: 7,
    attackRange: 220,
    attackCooldown: 1.3,
    xpReward: 8,
    goldReward: 2,
    radius: 14,
    color: Color(0xFF9B59B6),
    unlockWave: 2,
    spawnWeight: 3,
    preferredRange: 220,
    projectileSpeed: 300,
  );

  static const tank = EnemyData(
    type: EnemyType.tank,
    aiType: AiType.chaseAndMelee,
    maxHp: 90,
    moveSpeed: 55,
    damage: 16,
    attackRange: 34,
    attackCooldown: 1.6,
    xpReward: 12,
    goldReward: 3,
    radius: 22,
    color: Color(0xFF8B3A2B),
    unlockWave: 3,
    spawnWeight: 2,
  );

  static const assassin = EnemyData(
    type: EnemyType.assassin,
    aiType: AiType.assassinDashStrike,
    maxHp: 22,
    moveSpeed: 130,
    damage: 14,
    attackRange: 30,
    attackCooldown: 1.0,
    xpReward: 10,
    goldReward: 2,
    radius: 14,
    color: Color(0xFF4A4E69),
    unlockWave: 4,
    spawnWeight: 2,
  );

  static const healer = EnemyData(
    type: EnemyType.healer,
    aiType: AiType.healerSupport,
    maxHp: 25,
    moveSpeed: 85,
    damage: 0,
    attackRange: 0,
    attackCooldown: 2.0,
    xpReward: 10,
    goldReward: 3,
    radius: 15,
    color: Color(0xFF2ECC71),
    unlockWave: 5,
    spawnWeight: 1,
    preferredRange: 180,
    supportRadius: 260,
    healAmount: 10,
  );

  /// Not in [all] — bosses never come out of the regular weighted roll.
  /// SpawnDirector spawns this directly on boss waves (see
  /// WaveManager.isBossWave), bypassing composition and wave-scaling
  /// entirely; BossAi owns its own phase/attack tuning as constants rather
  /// than more EnemyData fields, since there's only one boss so far.
  static const boss = EnemyData(
    type: EnemyType.boss,
    aiType: AiType.bossPhased,
    maxHp: 900,
    moveSpeed: 70,
    damage: 22,
    attackRange: 70,
    attackCooldown: 2.0,
    xpReward: 150,
    goldReward: 80,
    radius: 52,
    color: Color(0xFF6B0F1A),
  );

  static const List<EnemyData> all = [grunt, archer, tank, assassin, healer];
}
