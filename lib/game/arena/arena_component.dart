import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants/game_constants.dart';

/// Bounded playfield. Renders real floor art if it's available (see
/// assets/images/backgrounds/README.md) as a seamless repeating tile —
/// not one image stretched across the whole arena, which made individual
/// stones look person-sized next to the player. Falls back to the flat
/// grid floor if the asset is missing, the same "missing art never breaks
/// the screen" pattern used by the wave-end overlays. Carries no gameplay
/// logic of its own.
class ArenaComponent extends PositionComponent {
  ArenaComponent()
    : super(size: GameConstants.arenaSize, anchor: Anchor.topLeft);

  static const double _gridSpacing = 120;
  static const String _floorAsset = 'assets/images/backgrounds/map1.png';

  /// World-unit size of one repeat of the floor texture — tuned so a
  /// single paving stone reads at roughly human scale next to the
  /// player's ~96-unit sprite (see Player._spriteDisplaySize), not the
  /// oversized "giant flagstones" look the earlier single-stretch version
  /// had.
  static const double _tileWorldSize = 500;

  final Paint _fallbackFloorPaint = Paint()..color = const Color(0xFF14171F);
  final Paint _borderPaint = Paint()
    ..color = const Color(0xFF3A3F4B)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6;
  final Paint _gridPaint = Paint()
    ..color = const Color(0x1AFFFFFF)
    ..strokeWidth = 1;

  Paint? _tiledFloorPaint;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final bytes = await rootBundle.load(_floorAsset);
      final codec = await instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final scale = _tileWorldSize / image.width;
      final matrix = Float64List.fromList([
        scale, 0, 0, 0,
        0, scale, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      ]);
      _tiledFloorPaint = Paint()
        ..shader = ImageShader(image, TileMode.repeated, TileMode.repeated, matrix);
    } catch (_) {
      _tiledFloorPaint = null;
    }
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    final floorPaint = _tiledFloorPaint;
    if (floorPaint != null) {
      canvas.drawRect(rect, floorPaint);
    } else {
      canvas.drawRect(rect, _fallbackFloorPaint);
      for (double x = 0; x <= size.x; x += _gridSpacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.y), _gridPaint);
      }
      for (double y = 0; y <= size.y; y += _gridSpacing) {
        canvas.drawLine(Offset(0, y), Offset(size.x, y), _gridPaint);
      }
    }
    canvas.drawRect(rect, _borderPaint);
  }
}
