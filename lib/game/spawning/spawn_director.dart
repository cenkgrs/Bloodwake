import 'dart:math';

import 'package:flame/components.dart';

import '../enemies/enemy.dart';
import '../enemies/enemy_data.dart';
import '../roughlike_game.dart';
import '../waves/wave_manager.dart';

/// Turns WaveManager's numbers into actual spawns. Each wave has a fixed
/// total; this trickles that total in — paced by [WaveManager.spawnInterval],
/// bounded by [WaveManager.maxAliveAtOnce] — and reports back once every
/// spawn is both used up and dead, so WaveManager knows to start the
/// breather. Does nothing while WaveManager is resting.
///
/// Composition is a weighted pick among every [EnemyCatalog] entry whose
/// [EnemyData.unlockWave] has been reached — new archetypes join the mix
/// just by existing in the catalog, no per-wave spawn tables to maintain.
class SpawnDirector extends Component with HasGameReference<RoughlikeGame> {
  SpawnDirector({required this.waveManager, required Vector2 arenaSize})
    : _arenaSize = arenaSize;

  final WaveManager waveManager;
  final Vector2 _arenaSize;
  final Random _random = Random();

  static const double _spawnRadius = 520;

  double _spawnTimer = 0;

  @override
  void update(double dt) {
    if (waveManager.state == WaveState.resting) {
      return;
    }

    final aliveCount = game.world.children.query<Enemy>().length;

    if (waveManager.quotaFullySpawned) {
      if (aliveCount == 0) {
        waveManager.startResting();
      }
      return;
    }

    _spawnTimer -= dt;
    if (_spawnTimer > 0 || aliveCount >= waveManager.maxAliveAtOnce) {
      return;
    }
    _spawnTimer = waveManager.spawnInterval;

    // Boss waves bypass composition/wave-scaling entirely — the boss spawns
    // with its own raw stats, not diluted by the elite roll or the flat
    // per-wave multiplier meant for regular fodder.
    final data = waveManager.isBossWave ? EnemyCatalog.boss : _rollEnemyData();
    game.world.add(Enemy(position: _spawnPosition(data.radius), data: data));
    waveManager.registerSpawn();
  }

  EnemyData _rollEnemyData() {
    final unlocked = EnemyCatalog.all
        .where((e) => waveManager.currentWave >= e.unlockWave)
        .toList();
    final totalWeight = unlocked.fold<int>(0, (sum, e) => sum + e.spawnWeight);
    var roll = _random.nextInt(totalWeight);
    var chosen = unlocked.first;
    for (final candidate in unlocked) {
      if (roll < candidate.spawnWeight) {
        chosen = candidate;
        break;
      }
      roll -= candidate.spawnWeight;
    }

    final isElite = _random.nextDouble() < waveManager.eliteChance;
    return chosen.scaled(
      statMultiplier: waveManager.enemyStatMultiplier,
      elite: isElite,
    );
  }

  Vector2 _spawnPosition(double enemyRadius) {
    final angle = _random.nextDouble() * 2 * pi;
    final offset = Vector2(cos(angle), sin(angle)) * _spawnRadius;
    final position = game.player.position + offset;
    position.x = position.x.clamp(enemyRadius, _arenaSize.x - enemyRadius);
    position.y = position.y.clamp(enemyRadius, _arenaSize.y - enemyRadius);
    return position;
  }
}
