import 'dart:math';

import '../player/player.dart';
import 'upgrade_catalog.dart';
import 'upgrade_data.dart';

final _random = Random();

/// Picks up to [count] random upgrades the player hasn't maxed out and can
/// actually use right now (see [UpgradeData.isAvailable]). Returns fewer
/// than [count] (down to zero) once the pool runs dry rather than
/// repeating or crashing — a short prototype run won't hit that, but it
/// shouldn't misbehave if one does.
List<UpgradeData> rollUpgradeChoices(Player player, {int count = 3}) {
  final available =
      UpgradeCatalog.all
          .where(
            (u) =>
                !player.upgrades.isMaxed(u) &&
                (u.isAvailable == null || u.isAvailable!(player)),
          )
          .toList()
        ..shuffle(_random);
  return available.take(count).toList();
}
