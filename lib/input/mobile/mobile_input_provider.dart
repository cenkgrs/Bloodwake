import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart' show EdgeInsets;

import '../input_provider.dart';

/// Touch-driven [InputProvider] backed by a virtual joystick component.
///
/// The [joystick] must be added to the game's HUD/viewport layer by the
/// caller; this class only owns the translation from joystick state to
/// normalized movement intent.
class MobileInputProvider implements InputProvider {
  MobileInputProvider() : joystick = _buildJoystick();

  final JoystickComponent joystick;

  static JoystickComponent _buildJoystick() {
    return JoystickComponent(
      knob: CircleComponent(
        radius: 22,
        paint: Paint()..color = const Color(0xB3FFFFFF),
      ),
      background: CircleComponent(
        radius: 56,
        paint: Paint()..color = const Color(0x40FFFFFF),
      ),
      margin: const EdgeInsets.only(left: 36, bottom: 36),
    );
  }

  @override
  Vector2 get movementDirection => joystick.relativeDelta;
}
