import 'package:flame/components.dart';

enum WaveState { spawning, resting }

/// Owns wave progression and every difficulty knob that scales with it.
///
/// Each wave has a fixed enemy quota. SpawnDirector trickles that quota in
/// and, once every one of them has been spawned and killed, calls
/// [startResting] — the player gets a breather for [restDuration] seconds
/// before the next wave starts. This class only owns the numbers and the
/// state machine; it never queries enemies itself (SpawnDirector does,
/// since it already needs to for spawn positions).
///
/// Nothing here is wave-number-specific ("if wave == 5 then...") —
/// everything is a formula of [currentWave], so adding wave 50 costs
/// nothing. Boss waves (M07) hook in here later the same way.
class WaveManager extends Component {
  WaveManager({this.restDuration = 4, this.onWaveCleared});

  final double restDuration;

  /// Fired once, right as the wave transitions into resting — RoughlikeGame
  /// uses this to pause and show the level-up/shop screens before the
  /// breather timer starts counting down.
  final void Function()? onWaveCleared;

  int currentWave = 1;
  WaveState state = WaveState.spawning;
  int enemiesSpawnedThisWave = 0;

  double _restTimer = 0;

  /// Total enemies this wave will ever spawn.
  int get waveEnemyQuota => 6 + currentWave * 4;

  /// How many can be alive at once — bounds worst-case enemies on screen
  /// without changing how many the wave totals.
  int get maxAliveAtOnce => (5 + currentWave).clamp(5, 20);

  /// Seconds between spawn attempts — gets faster, but not without floor.
  double get spawnInterval => (1.2 - currentWave * 0.04).clamp(0.35, 1.2);

  /// Chance a spawned enemy rolls as an elite variant instead of normal.
  double get eliteChance => (0.03 * (currentWave - 1)).clamp(0, 0.35);

  /// Flat stat multiplier applied to non-elite enemies as waves progress.
  /// Deliberately modest — difficulty should come from more enemies and
  /// elites, not from inflating one enemy's numbers.
  double get enemyStatMultiplier => 1 + (currentWave - 1) * 0.08;

  bool get quotaFullySpawned => enemiesSpawnedThisWave >= waveEnemyQuota;

  double get restTimeRemaining =>
      (restDuration - _restTimer).clamp(0, restDuration);

  void registerSpawn() => enemiesSpawnedThisWave++;

  void startResting() {
    if (state == WaveState.resting) {
      return;
    }
    state = WaveState.resting;
    _restTimer = 0;
    onWaveCleared?.call();
  }

  @override
  void update(double dt) {
    if (state != WaveState.resting) {
      return;
    }
    _restTimer += dt;
    if (_restTimer >= restDuration) {
      currentWave++;
      enemiesSpawnedThisWave = 0;
      state = WaveState.spawning;
    }
  }
}
