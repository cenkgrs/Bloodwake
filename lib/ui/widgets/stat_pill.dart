import 'package:flutter/material.dart';

/// Small rounded chip used in the top bar of wave-end overlays (gold
/// amount, wave/kill counter) — an icon plus a value, styled once and
/// reused everywhere instead of each overlay hand-rolling its own.
class StatPill extends StatelessWidget {
  const StatPill({required this.icon, required this.value, required this.color, super.key});

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x99161822),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
