import 'package:flutter/material.dart';

/// Full-screen backdrop for a wave-end overlay: real art at [assetPath] if
/// it exists (see assets/images/backgrounds/README.md), a plain dark fill
/// otherwise — a missing background never breaks the screen, it's just
/// flatter until art is dropped in.
///
/// The scrim is deliberately light — just enough to keep the bottom
/// controls (REFRESH/CONTINUE, which sit directly on the image with no
/// card of their own) readable. Everything above that stays close to the
/// source art: the pills and cards already carry their own opaque
/// backgrounds for text contrast, so a second full-screen dark wash on
/// top would just bury the art for no reason.
class OverlayBackground extends StatelessWidget {
  const OverlayBackground({required this.assetPath, required this.child, super.key});

  final String assetPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0A0B10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Image.asset(
              assetPath,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x1A0A0B10), Color(0x330A0B10), Color(0xD90A0B10)],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
