import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart'
    show EdgeInsets, FontWeight, TextPainter, TextSpan, TextStyle;

import '../../game/abilities/ability_data.dart';

/// Aimed skill button with a class icon and a live cooldown indicator.
class SkillButtonComponent extends PositionComponent
    with HasGameReference, ComponentViewportMargin, DragCallbacks {
  SkillButtonComponent({
    required this.onActivate,
    required this.fallbackDirection,
    required this.ability,
    required this.cooldownRemaining,
    double radius = 44,
    EdgeInsets? margin,
  }) : _radius = radius,
       super(size: Vector2.all(radius * 2), anchor: Anchor.center) {
    this.margin = margin ?? const EdgeInsets.only(right: 36, bottom: 36);
  }

  final void Function(Vector2 direction) onActivate;
  final Vector2 Function() fallbackDirection;
  final AbilityData ability;
  final double Function() cooldownRemaining;
  final double _radius;

  static const double _minAimDistance = 10;
  final Vector2 _dragAccum = Vector2.zero();
  bool _dragging = false;

  Color get _accent => switch (ability.icon) {
    AbilityIcon.sword => const Color(0xFFFFA24A),
    AbilityIcon.bullets => const Color(0xFFFFD27A),
    AbilityIcon.snowflake => const Color(0xFF8FDEFF),
    AbilityIcon.daggers => const Color(0xFFB897FF),
  };

  @override
  void render(Canvas canvas) {
    final center = Offset(_radius, _radius);
    final remaining = cooldownRemaining();
    final ready = remaining <= 0;
    canvas.drawCircle(
      center,
      _radius,
      Paint()..color = const Color(0xDD121A25),
    );
    canvas.drawCircle(
      center,
      _radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ready ? _accent : const Color(0xFF65707C),
    );
    final knob = center + Offset(_dragAccum.x * 0.35, _dragAccum.y * 0.35);
    canvas.drawCircle(
      knob,
      _radius * 0.67,
      Paint()..color = _accent.withValues(alpha: ready ? 0.24 : 0.11),
    );
    _drawIcon(canvas, knob, ready ? _accent : const Color(0xFF82909D));
    if (!ready) {
      canvas.drawCircle(
        center,
        _radius - 4,
        Paint()..color = const Color(0xAA080D15),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: _radius - 3),
        -math.pi / 2,
        math.pi * 2 * (1 - remaining / ability.cooldown),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = _accent,
      );
      final text = TextPainter(
        text: TextSpan(
          text: remaining.ceil().toString(),
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    }
  }

  void _drawIcon(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (ability.icon) {
      case AbilityIcon.sword:
        canvas.drawLine(
          center + const Offset(-12, 13),
          center + const Offset(13, -13),
          paint,
        );
        canvas.drawLine(
          center + const Offset(-10, -2),
          center + const Offset(2, 10),
          paint,
        );
        canvas.drawCircle(center + const Offset(-14, 15), 3, paint);
      case AbilityIcon.bullets:
        for (var i = -1; i <= 1; i++) {
          canvas.drawLine(
            center + Offset(-11, i * 10 - 3),
            center + Offset(10, i * 10 - 3),
            paint,
          );
          canvas.drawCircle(
            center + Offset(12, i * 10 - 3),
            2,
            Paint()..color = color,
          );
        }
      case AbilityIcon.snowflake:
        for (var i = 0; i < 3; i++) {
          final angle = i * math.pi / 3;
          final direction = Offset(math.cos(angle) * 15, math.sin(angle) * 15);
          canvas.drawLine(center - direction, center + direction, paint);
        }
      case AbilityIcon.daggers:
        canvas.drawLine(
          center + const Offset(-12, 12),
          center + const Offset(2, -14),
          paint,
        );
        canvas.drawLine(
          center + const Offset(2, 12),
          center + const Offset(16, -14),
          paint,
        );
        canvas.drawLine(
          center + const Offset(-16, 5),
          center + const Offset(-8, 9),
          paint,
        );
        canvas.drawLine(
          center + const Offset(-2, 5),
          center + const Offset(6, 9),
          paint,
        );
    }
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
    if (!_dragging) return false;
    _dragAccum.add(event.localDelta);
    if (_dragAccum.length > _radius) {
      _dragAccum.setFrom(_dragAccum.normalized() * _radius);
    }
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
    if (!_dragging) return;
    _dragging = false;
    final direction = _dragAccum.length >= _minAimDistance
        ? _dragAccum.normalized()
        : fallbackDirection();
    onActivate(direction);
    _dragAccum.setZero();
  }
}
