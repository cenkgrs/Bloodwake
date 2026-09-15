import 'dart:math';

import '../../core/constants/game_constants.dart';
import '../player/player.dart';
import 'item_catalog.dart';
import 'item_data.dart';

final _random = Random();

/// Picks up to [count] random items the player doesn't already own. Empty
/// once GameConstants.maxItemSlots is reached — the shop overlay is
/// expected to show "nothing left to buy" rather than force a screen with
/// no cards.
List<ItemData> rollShopOffers(Player player, {int count = 3}) {
  if (player.items.count >= GameConstants.maxItemSlots) {
    return const [];
  }
  final available =
      ItemCatalog.all
          .where(
            (i) =>
                !player.items.owns(i) &&
                (i.isAvailable == null || i.isAvailable!(player)),
          )
          .toList()
        ..shuffle(_random);
  return available.take(count).toList();
}
