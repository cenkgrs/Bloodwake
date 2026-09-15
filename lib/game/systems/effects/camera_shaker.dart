import 'dart:math';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';

/// Add to `camera.viewfinder` *after* calling `camera.follow(...)` — Flame
/// updates a component's children in add order, so this nudges
/// `viewfinder.position` after FollowBehavior has already set it for the
/// frame, instead of the two fighting over the same field.
class CameraShaker extends Component {
  final Random _random = Random();
  double _timeRemaining = 0;
  double _intensity = 0;

  void shake({double intensity = 6, double duration = 0.2}) {
    if (intensity < _intensity) {
      return;
    }
    _intensity = intensity;
    _timeRemaining = duration;
  }

  @override
  void update(double dt) {
    if (_timeRemaining <= 0) {
      return;
    }
    _timeRemaining -= dt;
    final viewfinder = parent;
    if (viewfinder is! Viewfinder) {
      return;
    }
    final magnitude = _timeRemaining <= 0 ? 0.0 : _intensity;
    viewfinder.position += Vector2(
      (_random.nextDouble() * 2 - 1) * magnitude,
      (_random.nextDouble() * 2 - 1) * magnitude,
    );
    if (_timeRemaining <= 0) {
      _intensity = 0;
    }
  }
}
