import 'package:flutter_test/flutter_test.dart';
import 'package:roughlike/game/enemies/enemy_data.dart';

void main() {
  test(
    'health drops are optional for regular enemies and guaranteed for bosses',
    () {
      final elite = EnemyCatalog.grunt.scaled(elite: true);
      expect(EnemyCatalog.grunt.healthDropChance, greaterThan(0));
      expect(EnemyCatalog.grunt.healthDropChance, lessThan(1));
      expect(
        elite.healthDropChance,
        greaterThan(EnemyCatalog.grunt.healthDropChance),
      );
      expect(
        elite.healthDropAmount,
        greaterThan(EnemyCatalog.grunt.healthDropAmount),
      );
      expect(EnemyCatalog.boss.healthDropChance, 1);
    },
  );
}
