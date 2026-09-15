import 'package:flutter/material.dart';

import '../../game/items/item_data.dart';
import '../../game/roughlike_game.dart';

/// Shown once per wave-end breather, after any pending level-ups. Buying is
/// optional — items disappear from the offer list once bought (no
/// re-buying), gold updates live, "Continue" ends the shop visit and
/// resumes the run. Stateful (unlike LevelUpOverlay) because a purchase
/// needs to update this same screen without closing it.
class ShopOverlay extends StatefulWidget {
  const ShopOverlay({required this.game, super.key});

  final RoughlikeGame game;

  @override
  State<ShopOverlay> createState() => _ShopOverlayState();
}

class _ShopOverlayState extends State<ShopOverlay> {
  void _buy(ItemData item) {
    final player = widget.game.player;
    if (!player.currency.spend(item.cost)) {
      return;
    }
    player.items.apply(item, player);
    setState(() => widget.game.currentShopOffers.remove(item));
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final gold = game.player.currency.gold;
    final offers = game.currentShopOffers;

    return ColoredBox(
      color: const Color(0xD0000000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SHOP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gold: $gold',
              style: const TextStyle(color: Color(0xFFFFD23F), fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (offers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nothing left to buy',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            ...offers.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _ItemCard(
                  item: item,
                  affordable: gold >= item.cost,
                  onBuy: () => _buy(item),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: game.closeShop,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Text('CONTINUE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.affordable, required this.onBuy});

  final ItemData item;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: OutlinedButton(
        onPressed: affordable ? onBuy : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1D26),
          disabledBackgroundColor: const Color(0xFF15171F),
          side: BorderSide(color: affordable ? const Color(0xFF3A3F4B) : const Color(0xFF262A33)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color: affordable ? Colors.white : Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(
                      color: affordable ? Colors.white70 : Colors.white30,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${item.cost}g',
              style: TextStyle(
                color: affordable ? const Color(0xFFFFD23F) : Colors.white30,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
