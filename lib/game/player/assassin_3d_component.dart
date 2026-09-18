import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'player.dart';

/// Draws the Assassin's textured 3D mesh directly in the Flame scene.
///
/// Geometry is projected whenever facing changes, so turning rotates the actual
/// model rather than swapping a set of pre-rendered pictures. The source GLB
/// with its armature lives beside this compact runtime mesh. The current source
/// has no animation actions, so only whole-body turning and a small run bob
/// are used until animations are authored.
class Assassin3DComponent extends PositionComponent with ParentIsA<Player> {
  Assassin3DComponent() : super(anchor: Anchor.center);

  static const _assetRoot = 'assets/models/characters/assassin';
  static const _stride = 5;
  static const _scale = 51.0;

  Float32List? _mesh;
  ui.Image? _texture;
  ui.Vertices? _vertices;
  double? _renderedYaw;
  double _yaw = 0;
  double _time = 0;
  Vector2? _lastPosition;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final bytes = await rootBundle.load('$_assetRoot/assassin_mesh.bin');
    _mesh = bytes.buffer.asFloat32List(
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 4,
    );
    final texture = await rootBundle.load('$_assetRoot/assassin_texture.png');
    final codec = await ui.instantiateImageCodec(texture.buffer.asUint8List());
    _texture = (await codec.getNextFrame()).image;
    codec.dispose();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final currentPosition = parent.position;
    final lastPosition = _lastPosition;
    if (lastPosition != null &&
        currentPosition.distanceToSquared(lastPosition) > 0.25) {
      _time += dt;
      final direction = parent.facingDirection;
      if (direction.length2 > 0.001) {
        // The model's front faces negative Y in its Blender rest pose.
        _yaw = math.atan2(-direction.x, -direction.y);
      }
    } else {
      _time = 0;
    }
    _lastPosition = currentPosition.clone();
  }

  @override
  void render(ui.Canvas canvas) {
    final mesh = _mesh;
    final texture = _texture;
    if (mesh == null || texture == null) return;

    if (_vertices == null || _renderedYaw != _yaw) {
      _vertices?.dispose();
      _vertices = _projectMesh(mesh, texture);
      _renderedYaw = _yaw;
    }
    final bob = _time == 0 ? 0.0 : math.sin(_time * 13) * 1.7;
    canvas.save();
    canvas.translate(0, bob);
    final paint = ui.Paint()
      ..shader = ui.ImageShader(
        texture,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      );
    canvas.drawVertices(_vertices!, ui.BlendMode.modulate, paint);
    canvas.restore();
  }

  ui.Vertices _projectMesh(Float32List mesh, ui.Image texture) {
    final faceCount = mesh.length ~/ (_stride * 3);
    final order = List<int>.generate(faceCount, (i) => i);
    final sinYaw = math.sin(_yaw);
    final cosYaw = math.cos(_yaw);
    // Back faces are submitted first for depth without a separate 3D engine.
    double depth(int face) {
      var sum = 0.0;
      for (var corner = 0; corner < 3; corner++) {
        final i = (face * 3 + corner) * _stride;
        sum += mesh[i] * sinYaw + mesh[i + 1] * cosYaw;
      }
      return sum;
    }

    order.sort((a, b) => depth(b).compareTo(depth(a)));

    final positions = Float32List(faceCount * 6);
    final texCoords = Float32List(faceCount * 6);
    for (var faceIndex = 0; faceIndex < faceCount; faceIndex++) {
      final face = order[faceIndex];
      for (var corner = 0; corner < 3; corner++) {
        final source = (face * 3 + corner) * _stride;
        final target = (faceIndex * 3 + corner) * 2;
        final x = mesh[source];
        final y = mesh[source + 1];
        final z = mesh[source + 2];
        final rotatedX = x * cosYaw - y * sinYaw;
        final rotatedY = x * sinYaw + y * cosYaw;
        positions[target] = rotatedX * _scale;
        positions[target + 1] = -z * _scale * 0.88 + rotatedY * _scale * 0.28;
        texCoords[target] = mesh[source + 3] * texture.width;
        texCoords[target + 1] = mesh[source + 4] * texture.height;
      }
    }

    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
    );
  }

  @override
  void onRemove() {
    _vertices?.dispose();
    _texture?.dispose();
    super.onRemove();
  }
}
