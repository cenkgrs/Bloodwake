import 'package:flutter/material.dart';

import '../../game/progression/equipment_catalog.dart';
import '../../game/progression/meta_progression.dart';
import '../theme/bloodwake_theme.dart';
import '../theme/fantasy_text.dart';

class ArmoryShopScreen extends StatelessWidget {
  const ArmoryShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progression = MetaProgression.instance;
    return Scaffold(
      backgroundColor: BloodwakeTheme.panel,
      appBar: AppBar(
        title: Text(
          'ARMORY',
          style: fantasyText(fontSize: 22, color: BloodwakeTheme.parchment),
        ),
      ),
      body: AnimatedBuilder(
        animation: progression,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${progression.essence} ESSENCE',
              style: fantasyText(fontSize: 22, color: BloodwakeTheme.gold),
            ),
            const SizedBox(height: 5),
            const Text(
              'Permanent equipment. Buy it here, then equip it in Builds before a run.',
              style: TextStyle(color: BloodwakeTheme.muted),
            ),
            for (final slot in EquipmentSlot.values) ...[
              const SizedBox(height: 24),
              Text(
                slot.name.toUpperCase(),
                style: fantasyText(fontSize: 18, color: BloodwakeTheme.gold),
              ),
              const SizedBox(height: 10),
              for (final item in EquipmentCatalog.all.where(
                (item) => item.slot == slot,
              ))
                Card(
                  color: const Color(0xFF1A2530),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          _slotIcon(slot),
                          color: BloodwakeTheme.gold,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name.toUpperCase(),
                                style: fantasyText(
                                  fontSize: 15,
                                  color: BloodwakeTheme.parchment,
                                ),
                              ),
                              Text(
                                item.description,
                                style: const TextStyle(
                                  color: BloodwakeTheme.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        progression.ownsEquipment(item)
                            ? const Text(
                                'OWNED',
                                style: TextStyle(
                                  color: BloodwakeTheme.gold,
                                  fontSize: 11,
                                ),
                              )
                            : FilledButton(
                                onPressed: progression.essence >= item.cost
                                    ? () {
                                        progression.buyEquipment(item);
                                      }
                                    : null,
                                child: Text('${item.cost} ✦'),
                              ),
                      ],
                    ),
                  ),
                ),
            ],
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
