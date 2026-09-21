import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roughlike/game/enemies/enemy.dart';
import 'package:roughlike/game/enemies/enemy_data.dart';

void main() {
  test('commander joins regular waves after wave six', () {
    expect(EnemyCatalog.commander.unlockWave, 6);
    expect(EnemyCatalog.commander.spawnWeight, greaterThan(0));
    expect(EnemyCatalog.all, contains(EnemyCatalog.commander));
    expect(EnemyCatalog.commander.aiType, AiType.commanderSupport);
  });

  test('command aura temporarily increases movement and damage', () {
    final enemy = Enemy(position: Vector2.zero(), data: EnemyCatalog.grunt);
    enemy.applyCommandAura(
      duration: 5,
      moveSpeedBonus: 0.22,
      damageBonus: 0.25,
    );
    expect(enemy.moveSpeedMultiplier, closeTo(1.22, 0.001));
    expect(enemy.damageMultiplier, closeTo(1.25, 0.001));

    enemy.update(5.1);
    expect(enemy.moveSpeedMultiplier, 1);
    expect(enemy.damageMultiplier, 1);
  });

  test('elite commander preserves its aura strength', () {
    final elite = EnemyCatalog.commander.scaled(
      statMultiplier: 1.4,
      elite: true,
    );
    expect(elite.auraMoveSpeedBonus, EnemyCatalog.commander.auraMoveSpeedBonus);
    expect(elite.auraDamageBonus, EnemyCatalog.commander.auraDamageBonus);
    expect(elite.auraDuration, EnemyCatalog.commander.auraDuration);
    expect(elite.isElite, true);
  });
}
