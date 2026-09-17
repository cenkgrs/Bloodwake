import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roughlike/game/player/player_stats.dart';
import 'package:roughlike/game/progression/meta_progression.dart';
import 'package:roughlike/game/progression/equipment_catalog.dart';
import 'package:roughlike/game/progression/skill_tree.dart';

void main() {
  test('skill tree contains 15 unique nodes with valid prerequisites', () {
    expect(SkillTree.nodes.length, 15);
    final ids = SkillTree.nodes.map((node) => node.id).toSet();
    expect(ids.length, SkillTree.nodes.length);
    for (final node in SkillTree.nodes) {
      if (node.requires != null) expect(ids, contains(node.requires));
    }
  });

  test(
    'Essence purchases unlock dependent nodes and affect new runs',
    () async {
      final progress = MetaProgression.inMemory()..essence = 100;
      final might = SkillTree.byId('might');
      final precision = SkillTree.byId('precision');
      expect(progress.canBuy(precision), false);
      expect(await progress.buy(might), true);
      expect(progress.canBuy(precision), true);
      expect(await progress.buy(precision), true);
      final stats = PlayerStats();
      progress.applyTo(stats);
      expect(stats.damage, closeTo(1.02, 0.0001));
      expect(stats.criticalChance, closeTo(0.06, 0.0001));
      expect(progress.essence, 88);
    },
  );

  test('run rewards grow with wave and kills', () async {
    final progress = MetaProgression.inMemory();
    expect(await progress.awardRun(wave: 1, kills: 0), 2);
    expect(await progress.awardRun(wave: 10, kills: 50), 30);
    expect(progress.essence, 32);
  });

  test('Essence and node levels survive a reload', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bloodwake_progression_test',
    );
    final file = File('${directory.path}/save.json');
    try {
      final first = MetaProgression.forFile(file);
      await first.awardRun(wave: 10, kills: 50);
      await first.buy(SkillTree.byId('might'));
      final restored = MetaProgression.forFile(file);
      await restored.load();
      expect(restored.essence, 25);
      expect(restored.levelOf(SkillTree.byId('might')), 1);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'equipment purchases and distinct builds affect new run stats',
    () async {
      final progress = MetaProgression.inMemory()..essence = 100;
      final plate = EquipmentCatalog.byId('bloodplate')!;
      final cloak = EquipmentCatalog.byId('shadow_cloak')!;
      final sigil = EquipmentCatalog.byId('ember_sigil')!;

      expect(await progress.equip(EquipmentSlot.armor, plate.id), false);
      expect(await progress.buyEquipment(plate), true);
      expect(await progress.buyEquipment(plate), false);
      expect(await progress.buyEquipment(cloak), true);
      expect(await progress.buyEquipment(sigil), true);
      expect(await progress.equip(EquipmentSlot.boots, plate.id), false);
      expect(await progress.equip(EquipmentSlot.armor, plate.id), true);
      expect(await progress.equip(EquipmentSlot.charm, sigil.id), true);

      final first = PlayerStats();
      progress.applyTo(first);
      expect(first.maxHp, 122);
      expect(first.damage, closeTo(1.10, 0.0001));

      await progress.selectLoadout(1);
      expect(await progress.equip(EquipmentSlot.armor, cloak.id), true);
      final second = PlayerStats();
      progress.applyTo(second);
      expect(second.maxHp, 100);
      expect(second.moveSpeed, greaterThan(first.moveSpeed));
      expect(second.damage, 1);

      await progress.selectLoadout(0);
      expect(progress.equipped(EquipmentSlot.armor)?.id, plate.id);
      expect(progress.equipped(EquipmentSlot.charm)?.id, sigil.id);
    },
  );

  test('owned equipment and selected build survive a reload', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bloodwake_build_test',
    );
    final file = File('${directory.path}/save.json');
    try {
      final first = MetaProgression.forFile(file)..essence = 100;
      final plate = EquipmentCatalog.byId('bloodplate')!;
      await first.buyEquipment(plate);
      await first.selectLoadout(2);
      await first.equip(EquipmentSlot.armor, plate.id);

      final restored = MetaProgression.forFile(file);
      await restored.load();
      expect(restored.essence, 88);
      expect(restored.ownsEquipment(plate), true);
      expect(restored.activeLoadout, 2);
      expect(restored.equipped(EquipmentSlot.armor)?.id, plate.id);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
