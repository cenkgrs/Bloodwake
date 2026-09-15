import 'package:flutter/material.dart';

/// Fade+scale entrance for a child, optionally delayed — used to stagger a
/// list of cards (level-up choices, shop items) in one at a time instead of
/// all popping in simultaneously. Purely cosmetic; the child underneath is
/// fully interactive throughout.
class PopIn extends StatefulWidget {
  const PopIn({required this.child, this.delay = Duration.zero, super.key});

  final Widget child;
  final Duration delay;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: AnimatedScale(
        scale: _visible ? 1 : 0.85,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
