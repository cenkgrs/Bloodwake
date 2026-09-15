import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../../core/constants/game_constants.dart';

/// Simple bounded playfield. Renders a flat floor with a grid so player
/// movement is visually readable; carries no gameplay logic of its own.
class ArenaComponent extends PositionComponent {
  ArenaComponent()
    : super(size: GameConstants.arenaSize, anchor: Anchor.topLeft);

  static const double _gridSpacing = 120;

  final Paint _floorPaint = Paint()..color = const Color(0xFF14171F);
  final Paint _borderPaint = Paint()
    ..color = const Color(0xFF3A3F4B)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6;
  final Paint _gridPaint = Paint()
    ..color = const Color(0x1AFFFFFF)
    ..strokeWidth = 1;

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    canvas.drawRect(rect, _floorPaint);
    for (double x = 0; x <= size.x; x += _gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), _gridPaint);
    }
    for (double y = 0; y <= size.y; y += _gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), _gridPaint);
    }
    canvas.drawRect(rect, _borderPaint);
  }
}
