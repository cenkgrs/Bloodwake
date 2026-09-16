import 'package:flutter/material.dart';

import '../../game/items/item_data.dart';
import '../../game/roughlike_game.dart';
import '../../game/systems/audio/sfx_player.dart';
import '../theme/fantasy_text.dart';
import '../theme/rarity_style.dart';
import '../widgets/catalog_icon.dart';
import '../widgets/overlay_background.dart';
import '../widgets/pop_in.dart';
import '../widgets/rarity_card_shell.dart';
import '../widgets/stat_pill.dart';

/// Shown once per wave-end breather, after any pending level-ups. Buying is
/// optional — items disappear from the offer list once bought (no
/// re-buying), gold updates live, a limited paid refresh rerolls the
/// offers, category chips filter them, and "Continue" ends the shop visit.
/// A full dedicated screen (background art, top stat bar, a 3-wide grid of
/// rarity-bordered cards) rather than a modal floating over the paused
/// arena.
class ShopOverlay extends StatefulWidget {
  const ShopOverlay({required this.game, super.key});

  final RoughlikeGame game;

  @override
  State<ShopOverlay> createState() => _ShopOverlayState();
}

class _ShopOverlayState extends State<ShopOverlay> {
  ItemCategory? _selectedCategory;

  void _buy(ItemData item) {
    final player = widget.game.player;
    if (!player.currency.spend(item.cost)) {
      return;
    }
    player.items.apply(item, player);
    SfxPlayer.purchase();
    setState(() => widget.game.currentShopOffers.remove(item));
  }

  void _refresh() {
    setState(widget.game.refreshShop);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final gold = game.player.currency.gold;
    final offers = game.currentShopOffers
        .where((i) => _selectedCategory == null || i.category == _selectedCategory)
        .toList();
    final refreshesLeft = RoughlikeGame.maxShopRefreshes - game.shopRefreshesUsed;
    final canRefresh = refreshesLeft > 0 && gold >= RoughlikeGame.shopRefreshCost;

    return OverlayBackground(
      assetPath: 'assets/images/backgrounds/shop_bg.png',
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatPill(
                    icon: Icons.monetization_on,
                    value: '$gold',
                    color: const Color(0xFFFFD23F),
                  ),
                  StatPill(
                    icon: Icons.flag,
                    value: '${game.waveManager.currentWave}',
                    color: const Color(0xFF64B5F6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 182),
            _CategoryTabs(
              selected: _selectedCategory,
              onSelect: (category) => setState(() => _selectedCategory = category),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: offers.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'Nothing to buy here',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        )
                      : _ItemGrid(offers: offers, refreshKey: game.shopRefreshesUsed, gold: gold, onBuy: _buy),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _RefreshButton(
                enabled: canRefresh,
                cost: RoughlikeGame.shopRefreshCost,
                refreshesLeft: refreshesLeft,
                onTap: _refresh,
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _ContinueButton(onTap: game.closeShop),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays [offers] out three-to-a-row (matching the reference design) instead
/// of one full-width card per line. Each row is wrapped in
/// [IntrinsicHeight] so all three cards in it share the tallest one's
/// height even though descriptions vary in length.
class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.offers, required this.refreshKey, required this.gold, required this.onBuy});

  final List<ItemData> offers;
  final int refreshKey;
  final int gold;
  final void Function(ItemData) onBuy;

  @override
  Widget build(BuildContext context) {
    const perRow = 3;
    final rows = <List<ItemData>>[];
    for (var i = 0; i < offers.length; i += perRow) {
      rows.add(offers.sublist(i, i + perRow > offers.length ? offers.length : i + perRow));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: PopIn(
                          key: ValueKey('${item.id}_$refreshKey'),
                          delay: Duration(milliseconds: offers.indexOf(item) * 70),
                          child: _ItemCard(
                            item: item,
                            affordable: gold >= item.cost,
                            onBuy: () => onBuy(item),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selected, required this.onSelect});

  final ItemCategory? selected;
  final void Function(ItemCategory?) onSelect;

  static const _tabs = <(String, ItemCategory?, IconData)>[
    ('ALL', null, Icons.apps),
    ('WEAPONS', ItemCategory.weapon, Icons.gavel),
    ('GEAR', ItemCategory.gear, Icons.shield),
    ('RELICS', ItemCategory.relic, Icons.diamond),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final (label, category, icon) in _tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                label: label,
                icon: icon,
                selected: selected == category,
                onTap: () => onSelect(category),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFFD23F) : Colors.white54;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0x33FFD23F) : const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? const Color(0xFFFFD23F) : Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({
    required this.enabled,
    required this.cost,
    required this.refreshesLeft,
    required this.onTap,
  });

  final bool enabled;
  final int cost;
  final int refreshesLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.white : Colors.white24;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onTap : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x26FFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: enabled ? Colors.white38 : Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(Icons.refresh, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REFRESH', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          'New items will appear',
                          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.monetization_on, size: 16, color: enabled ? const Color(0xFFFFD23F) : Colors.white24),
                  const SizedBox(width: 4),
                  Text('$cost', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Remaining refreshes: $refreshesLeft/${RoughlikeGame.maxShopRefreshes}',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}

/// Stretched-hexagon "CONTINUE" button, painted rather than a stock
/// rounded rect, to match the reference design's angular ribbon shape.
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.diamond, size: 10, color: Colors.white38),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 240,
            height: 54,
            child: CustomPaint(
              painter: _HexButtonPainter(),
              child: Center(
                child: Text(
                  'CONTINUE',
                  style: fantasyText(fontSize: 16, color: Colors.white, letterSpacing: 3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.diamond, size: 10, color: Colors.white38),
      ],
    );
  }
}

class _HexButtonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final notch = size.height * 0.45;
    final path = Path()
      ..moveTo(notch, 0)
      ..lineTo(size.width - notch, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - notch, size.height)
      ..lineTo(notch, size.height)
      ..lineTo(0, size.height / 2)
      ..close();

    canvas.drawShadow(path, const Color(0xFF4FC3F7), 14, false);

    final fill = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF4FC3F7), Color(0xFF3F51B5)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, fill);

    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.affordable, required this.onBuy});

  final ItemData item;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final style = RarityStyle.of(item.rarity);
    final iconColor = affordable ? style.color : Colors.white38;
    return RarityCardShell(
      rarity: item.rarity,
      dimmed: !affordable,
      onTap: affordable ? onBuy : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: iconColor.withValues(alpha: 0.15),
                border: Border.all(color: iconColor.withValues(alpha: 0.7), width: 1.5),
                boxShadow: [BoxShadow(color: iconColor.withValues(alpha: 0.35), blurRadius: 10)],
              ),
              child: CatalogIcon(
                assetPath: item.iconAsset,
                fallbackIcon: iconForItemCategory(item.category),
                color: iconColor,
                size: 68,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: fantasyText(
                fontSize: 13,
                color: affordable ? Colors.white : Colors.white38,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.description,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: affordable ? Colors.white70 : Colors.white30,
                fontSize: 10.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x1AFFD23F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: affordable ? const Color(0xFFFFD23F) : Colors.white24,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.monetization_on,
                    size: 12,
                    color: affordable ? const Color(0xFFFFD23F) : Colors.white30,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${item.cost}',
                    style: TextStyle(
                      color: affordable ? const Color(0xFFFFD23F) : Colors.white30,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
