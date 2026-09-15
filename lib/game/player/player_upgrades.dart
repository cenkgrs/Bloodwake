import '../upgrades/upgrade_data.dart';
import 'player.dart';

/// Tracks how many times each upgrade has been picked this run and applies
/// new picks to the [Player]. Plain data holder, same pattern as
/// PlayerExperience — nothing here needs a per-frame update.
class PlayerUpgrades {
  final Map<String, int> _levels = {};

  int levelOf(UpgradeData upgrade) => _levels[upgrade.id] ?? 0;

  bool isMaxed(UpgradeData upgrade) => levelOf(upgrade) >= upgrade.maxLevel;

  void apply(UpgradeData upgrade, Player player) {
    upgrade.apply(player);
    _levels[upgrade.id] = levelOf(upgrade) + 1;
  }
}
