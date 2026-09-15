import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/widgets.dart' show EdgeInsets;

/// Touch button for manually aimed abilities: press and drag to aim, release
/// to fire in that direction. A plain tap (drag distance under threshold)
/// fires in whatever direction [fallbackDirection] currently returns — the
/// player's current facing — instead of requiring a deliberate aim every
/// time.
///
/// Deliberately ignorant of Player/PlayerAbilities; the caller supplies
/// both callbacks, so this stays a pure input widget like
/// MobileInputProvider's joystick.
class SkillButtonComponent extends PositionComponent
    with HasGameReference, ComponentViewportMargin, DragCallbacks {
  SkillButtonComponent({
    required this.onActivate,
    required this.fallbackDirection,
    double radius = 44,
    EdgeInsets? margin,
  }) : _radius = radius,
       super(size: Vector2.all(radius * 2), anchor: Anchor.center) {
    this.margin = margin ?? const EdgeInsets.only(right: 36, bottom: 36);
  }

  final void Function(Vector2 direction) onActivate;
  final Vector2 Function() fallbackDirection;
  final double _radius;

  static const double _minAimDistance = 10;

  late final CircleComponent _knob;
  final Vector2 _dragAccum = Vector2.zero();
  bool _dragging = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      CircleComponent(
        radius: _radius,
        anchor: Anchor.center,
        position: size / 2,
        paint: Paint()..color = const Color(0x40FFFFFF),
      ),
    );
    _knob = CircleComponent(
      radius: _radius * 0.45,
      anchor: Anchor.center,
      position: size / 2,
      paint: Paint()..color = const Color(0xCCFF9F43),
    );
    add(_knob);
  }

  @override
  bool onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragging = true;
    _dragAccum.setZero();
    return false;
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    if (!_dragging) {
      return false;
    }
    _dragAccum.add(event.localDelta);
    final clamped = _dragAccum.length > _radius
        ? _dragAccum.normalized() * _radius
        : _dragAccum;
    _knob.position = size / 2 + clamped;
    return false;
  }

  @override
  bool onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _fire();
    return false;
  }

  @override
  bool onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _fire();
    return false;
  }

  void _fire() {
    if (!_dragging) {
      return;
    }
    _dragging = false;
    final direction = _dragAccum.length >= _minAimDistance
        ? _dragAccum.normalized()
        : fallbackDirection();
    onActivate(direction);
    _dragAccum.setZero();
    _knob.position = size / 2;
  }
}
