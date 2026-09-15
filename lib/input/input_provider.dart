import 'package:flame/components.dart';

/// Abstract source of player movement intent.
///
/// Gameplay code (movement, combat, abilities) must depend only on this
/// interface, never on a concrete input source. That is what lets the same
/// systems run on a mobile joystick today and a keyboard or controller later
/// without any change to gameplay logic.
abstract class InputProvider {
  /// Movement intent as a vector whose components lie within `[-1, 1]`.
  /// A zero vector means no movement is requested.
  Vector2 get movementDirection;
}
