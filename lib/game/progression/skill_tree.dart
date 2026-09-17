import '../player/player_stats.dart';

enum SkillBranch { offense, defense, mobility }

class SkillNode {
  const SkillNode({
    required this.id,
    required this.name,
    required this.description,
    required this.branch,
    required this.baseCost,
    required this.apply,
    this.requires,
  });

  final String id;
  final String name;
  final String description;
  final SkillBranch branch;
  final int baseCost;
  final String? requires;
  final void Function(PlayerStats stats, int level) apply;
  int costForLevel(int currentLevel) => baseCost * (currentLevel + 1);
  static const int maxLevel = 3;
}

void _damage(PlayerStats s, int level) => s.damage += level * 0.02;
void _crit(PlayerStats s, int level) => s.criticalChance += level * 0.01;
void _critDamage(PlayerStats s, int level) => s.criticalDamage += level * 0.03;
void _attackSpeed(PlayerStats s, int level) => s.attackSpeed += level * 0.02;
void _range(PlayerStats s, int level) => s.attackRange += level * 0.02;
void _health(PlayerStats s, int level) {
  s.maxHp += level * 4;
  s.hp += level * 4;
}

void _armor(PlayerStats s, int level) => s.armor += level * 0.005;
void _regen(PlayerStats s, int level) => s.regenPerSecond += level * 0.15;
void _lifesteal(PlayerStats s, int level) => s.lifesteal += level * 0.003;
void _secondWind(PlayerStats s, int level) {
  if (level >= 3) s.hasSecondWind = true;
}

void _speed(PlayerStats s, int level) => s.moveSpeed += level * 3;
void _dodge(PlayerStats s, int level) => s.dodgeChance += level * 0.005;
void _pickup(PlayerStats s, int level) => s.pickupRadius += level * 5;
void _xp(PlayerStats s, int level) => s.xpMultiplier += level * 0.02;
void _gold(PlayerStats s, int level) => s.bonusGoldPerKill += level;

class SkillTree {
  SkillTree._();
  static const nodes = <SkillNode>[
    SkillNode(
      id: 'might',
      name: 'Might',
      description: '+2% damage / level',
      branch: SkillBranch.offense,
      baseCost: 5,
      apply: _damage,
    ),
    SkillNode(
      id: 'precision',
      name: 'Precision',
      description: '+1% crit chance / level',
      branch: SkillBranch.offense,
      baseCost: 7,
      requires: 'might',
      apply: _crit,
    ),
    SkillNode(
      id: 'fury',
      name: 'Fury',
      description: '+2% attack speed / level',
      branch: SkillBranch.offense,
      baseCost: 8,
      requires: 'might',
      apply: _attackSpeed,
    ),
    SkillNode(
      id: 'execution',
      name: 'Execution',
      description: '+3% crit damage / level',
      branch: SkillBranch.offense,
      baseCost: 10,
      requires: 'precision',
      apply: _critDamage,
    ),
    SkillNode(
      id: 'reach',
      name: 'Reach',
      description: '+2% attack range / level',
      branch: SkillBranch.offense,
      baseCost: 10,
      requires: 'fury',
      apply: _range,
    ),
    SkillNode(
      id: 'vigor',
      name: 'Vigor',
      description: '+4 max HP / level',
      branch: SkillBranch.defense,
      baseCost: 5,
      apply: _health,
    ),
    SkillNode(
      id: 'plate',
      name: 'Plate',
      description: '+0.5% armor / level',
      branch: SkillBranch.defense,
      baseCost: 7,
      requires: 'vigor',
      apply: _armor,
    ),
    SkillNode(
      id: 'renewal',
      name: 'Renewal',
      description: '+0.15 HP/s / level',
      branch: SkillBranch.defense,
      baseCost: 8,
      requires: 'vigor',
      apply: _regen,
    ),
    SkillNode(
      id: 'drain',
      name: 'Drain',
      description: '+0.3% lifesteal / level',
      branch: SkillBranch.defense,
      baseCost: 10,
      requires: 'renewal',
      apply: _lifesteal,
    ),
    SkillNode(
      id: 'last_stand',
      name: 'Last Stand',
      description: 'Second Wind at level 3',
      branch: SkillBranch.defense,
      baseCost: 12,
      requires: 'plate',
      apply: _secondWind,
    ),
    SkillNode(
      id: 'stride',
      name: 'Stride',
      description: '+3 movement speed / level',
      branch: SkillBranch.mobility,
      baseCost: 5,
      apply: _speed,
    ),
    SkillNode(
      id: 'reflex',
      name: 'Reflex',
      description: '+0.5% dodge / level',
      branch: SkillBranch.mobility,
      baseCost: 7,
      requires: 'stride',
      apply: _dodge,
    ),
    SkillNode(
      id: 'magnet',
      name: 'Magnet',
      description: '+5 pickup radius / level',
      branch: SkillBranch.mobility,
      baseCost: 8,
      requires: 'stride',
      apply: _pickup,
    ),
    SkillNode(
      id: 'insight',
      name: 'Insight',
      description: '+2% XP / level',
      branch: SkillBranch.mobility,
      baseCost: 10,
      requires: 'magnet',
      apply: _xp,
    ),
    SkillNode(
      id: 'scavenger',
      name: 'Scavenger',
      description: '+1 gold per kill / level',
      branch: SkillBranch.mobility,
      baseCost: 10,
      requires: 'reflex',
      apply: _gold,
    ),
  ];

  static SkillNode byId(String id) => nodes.firstWhere((node) => node.id == id);
}
