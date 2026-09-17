import 'package:flutter/material.dart';

import '../../game/progression/equipment_catalog.dart';
import '../../game/progression/meta_progression.dart';
import '../theme/bloodwake_theme.dart';
import '../theme/fantasy_text.dart';

class BuildScreen extends StatelessWidget {
  const BuildScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progression = MetaProgression.instance;
    return Scaffold(
      backgroundColor: BloodwakeTheme.panel,
      appBar: AppBar(
        title: Text(
          'BUILDS',
          style: fantasyText(fontSize: 22, color: BloodwakeTheme.parchment),
        ),
      ),
      body: AnimatedBuilder(
        animation: progression,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Select a saved build. Its equipment applies when the next run starts.',
              style: TextStyle(color: BloodwakeTheme.muted),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                for (var index = 0; index < 3; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text('BUILD ${index + 1}'),
                        selected: progression.activeLoadout == index,
                        onSelected: (_) {
                          progression.selectLoadout(index);
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            for (final slot in EquipmentSlot.values)
              Card(
                color: const Color(0xFF1A2530),
                child: ListTile(
                  leading: Icon(_slotIcon(slot), color: BloodwakeTheme.gold),
                  title: Text(
                    slot.name.toUpperCase(),
                    style: fantasyText(
                      fontSize: 15,
                      color: BloodwakeTheme.parchment,
                    ),
                  ),
                  subtitle: Text(
                    progression.equipped(slot)?.name ?? 'Empty — tap to equip',
                    style: const TextStyle(color: BloodwakeTheme.muted),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: BloodwakeTheme.gold,
                  ),
                  onTap: () => _showEquipmentPicker(context, progression, slot),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              'Active: Build ${progression.activeLoadout + 1}',
              style: fantasyText(fontSize: 16, color: BloodwakeTheme.gold),
            ),
          ],
        ),
      ),
    );
  }

  void _showEquipmentPicker(
    BuildContext context,
    MetaProgression progression,
    EquipmentSlot slot,
  ) {
    final owned = progression.ownedFor(slot);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15202A),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                'CHOOSE ${slot.name.toUpperCase()}',
                style: fantasyText(
                  fontSize: 17,
                  color: BloodwakeTheme.parchment,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Empty slot'),
              onTap: () {
                progression.equip(slot, null);
                Navigator.pop(context);
              },
            ),
            if (owned.isEmpty)
              const ListTile(
                title: Text(
                  'No equipment owned in this slot yet. Visit the Armory.',
                ),
              ),
            for (final item in owned)
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: BloodwakeTheme.gold,
                ),
                title: Text(item.name),
                subtitle: Text(item.description),
                onTap: () {
                  progression.equip(slot, item.id);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

IconData _slotIcon(EquipmentSlot slot) => switch (slot) {
  EquipmentSlot.armor => Icons.shield_outlined,
  EquipmentSlot.boots => Icons.directions_run,
  EquipmentSlot.charm => Icons.auto_awesome,
};
