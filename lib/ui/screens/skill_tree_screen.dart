import 'package:flutter/material.dart';

import '../../game/progression/meta_progression.dart';
import '../../game/progression/skill_tree.dart';
import '../theme/bloodwake_theme.dart';
import '../theme/fantasy_text.dart';

class SkillTreeScreen extends StatelessWidget {
  const SkillTreeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progression = MetaProgression.instance;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/backgrounds/map1.png', fit: BoxFit.cover),
          const ColoredBox(color: Color(0xE80B1017)),
          SafeArea(
            child: AnimatedBuilder(
              animation: progression,
              builder: (context, _) => CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    sliver: SliverToBoxAdapter(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('BACK'),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'LEGACY TREE',
                              style: fantasyText(
                                fontSize: 31,
                                color: BloodwakeTheme.parchment,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Spend Essence earned from runs. Bonuses apply to every class at the start of the next run.',
                              style: TextStyle(
                                color: BloodwakeTheme.muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '${progression.essence} ESSENCE',
                              style: fantasyText(
                                fontSize: 19,
                                color: BloodwakeTheme.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  for (final branch in SkillBranch.values)
                    SliverMainAxisGroup(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          sliver: SliverToBoxAdapter(
                            child: Text(
                              branch.name.toUpperCase(),
                              style: fantasyText(
                                fontSize: 20,
                                color: _branchColor(branch),
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList.builder(
                            itemCount: SkillTree.nodes
                                .where((node) => node.branch == branch)
                                .length,
                            itemBuilder: (context, index) {
                              final node = SkillTree.nodes
                                  .where((node) => node.branch == branch)
                                  .elementAt(index);
                              return _SkillCard(
                                node: node,
                                progression: progression,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _branchColor(SkillBranch branch) => switch (branch) {
  SkillBranch.offense => const Color(0xFFE76A60),
  SkillBranch.defense => const Color(0xFF72A7D9),
  SkillBranch.mobility => const Color(0xFF79C99B),
};

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.node, required this.progression});
  final SkillNode node;
  final MetaProgression progression;

  @override
  Widget build(BuildContext context) {
    final level = progression.levelOf(node);
    final maxed = level == SkillNode.maxLevel;
    final prerequisite = node.requires;
    final locked =
        prerequisite != null &&
        progression.levelOf(SkillTree.byId(prerequisite)) == 0;
    final canBuy = progression.canBuy(node);
    final accent = _branchColor(node.branch);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: BloodwakeTheme.panel,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: canBuy
              ? () {
                  progression.buy(node);
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: level > 0 ? accent : BloodwakeTheme.line,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  locked ? Icons.lock_outline : Icons.auto_awesome,
                  color: locked ? BloodwakeTheme.muted : accent,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name.toUpperCase(),
                        style: fantasyText(
                          fontSize: 15,
                          color: BloodwakeTheme.parchment,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        node.description,
                        style: const TextStyle(
                          color: BloodwakeTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      if (locked)
                        Text(
                          'Requires ${SkillTree.byId(prerequisite).name}',
                          style: TextStyle(color: accent, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$level/${SkillNode.maxLevel}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      maxed ? 'MAX' : '${node.costForLevel(level)} ✦',
                      style: TextStyle(
                        color: canBuy
                            ? BloodwakeTheme.gold
                            : BloodwakeTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
