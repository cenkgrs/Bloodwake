import '../items/item_data.dart';
import 'player.dart';

/// Tracks which items this run has bought. Unlike upgrades, items are
/// one-time purchases (no levels/stacking) — owning one is a Set membership
/// check, not a level counter.
class PlayerItems {
  final Set<String> _ownedIds = {};

  bool owns(ItemData item) => _ownedIds.contains(item.id);

  int get count => _ownedIds.length;

  void apply(ItemData item, Player player) {
    if (owns(item)) {
      return;
    }
    item.apply(player);
    _ownedIds.add(item.id);
  }
}
