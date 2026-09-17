import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roughlike/game/player/character_class.dart';
import 'package:roughlike/game/player/player.dart';
import 'package:roughlike/game/upgrades/upgrade_catalog.dart';
import 'package:roughlike/game/upgrades/upgrade_roller.dart';
import 'package:roughlike/game/weapons/weapon_data.dart';
import 'package:roughlike/input/input_provider.dart';

class _IdleInput implements InputProvider {
  @override
  Vector2 get movementDirection => Vector2.zero();
}

void main() {
  test('each class starts with a distinct active skill', () {
    final skills = CharacterClassCatalog.all.map((c) => c.startingAbility.id).toSet();
    expect(skills.length, CharacterClassCatalog.all.length);
  });

  for (final characterClass in CharacterClassCatalog.all) {
    test('${characterClass.name} only receives its own weapon upgrades', () {
      final player = Player(
        position: Vector2.zero(),
        inputProvider: _IdleInput(),
        arenaSize: Vector2.all(1000),
        characterClass: characterClass,
        ability: characterClass.startingAbility,
      );
      final expected = switch (characterClass.id) {
        CharacterClass.warrior => {'greatsword', 'storm_blade', 'shockwave'},
        CharacterClass.gunslinger => {
          'rifle_tempo',
          'rifle_caliber',
          'rifle_range',
        },
        CharacterClass.mage => {'orb_pierce', 'orb_power', 'orb_range'},
        CharacterClass.assassin => {
          'dagger_tempo',
          'dagger_reach',
          'dagger_edge',
        },
      };
      final available = UpgradeCatalog.all
          .where((u) => u.isAvailable == null || u.isAvailable!(player))
          .map((u) => u.id)
          .toSet();
      expect(
        available.intersection({
          'greatsword',
          'storm_blade',
          'shockwave',
          'rifle_tempo',
          'rifle_caliber',
          'rifle_range',
          'orb_pierce',
          'orb_power',
          'orb_range',
          'dagger_tempo',
          'dagger_reach',
          'dagger_edge',
        }),
        expected,
      );
      expect(available.where((id) => id.startsWith('unlock_')), isEmpty);
      for (var i = 0; i < 30; i++) {
        expect(
          rollUpgradeChoices(player)
              .map((u) => u.id)
              .toSet()
              .difference(available),
          isEmpty,
        );
      }
    });
  }

  test('class upgrades change only their starting weapon slot', () {
    for (final characterClass in CharacterClassCatalog.all) {
      final player = Player(
        position: Vector2.zero(),
        inputProvider: _IdleInput(),
        arenaSize: Vector2.all(1000),
        characterClass: characterClass,
        ability: characterClass.startingAbility,
      );
      player.addWeapon(characterClass.startingWeapon);
      final slot = player.weaponSlot(characterClass.startingWeapon.id)!;
      final upgrade = switch (characterClass.id) {
        CharacterClass.warrior => UpgradeCatalog.greatsword,
        CharacterClass.gunslinger => UpgradeCatalog.rifleTempo,
        CharacterClass.mage => UpgradeCatalog.orbPierce,
        CharacterClass.assassin => UpgradeCatalog.daggerReach,
      };
      player.upgrades.apply(upgrade, player);
      expect(player.upgrades.levelOf(upgrade), 1);
      switch (characterClass.id) {
        case CharacterClass.warrior:
        case CharacterClass.assassin:
          expect(slot.bonusRangeMultiplier, greaterThan(1));
        case CharacterClass.gunslinger:
          expect(slot.bonusAttackSpeedMultiplier, greaterThan(1));
        case CharacterClass.mage:
          expect(slot.bonusPierceCount, 1);
      }
      expect(player.weaponSlotCount, 1);
      expect(player.ownsWeapon(WeaponCatalog.shotgun.id), false);
    }
  });
}
