import 'package:flutter_test/flutter_test.dart';
import 'package:roughlike/game/waves/wave_manager.dart';

void main() {
  test('debug wave jump resets active wave state', () {
    final manager = WaveManager();
    manager.registerSpawn();
    manager.startResting();

    manager.startWaveForDebug(10);

    expect(manager.currentWave, 10);
    expect(manager.isBossWave, true);
    expect(manager.enemiesSpawnedThisWave, 0);
    expect(manager.state, WaveState.spawning);
  });

  test('debug wave jump clamps invalid wave numbers', () {
    final manager = WaveManager();
    manager.startWaveForDebug(0);
    expect(manager.currentWave, 1);
    manager.startWaveForDebug(5000);
    expect(manager.currentWave, 999);
  });
}
