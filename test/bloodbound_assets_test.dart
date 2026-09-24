import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roughlike/game/player/character_class.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Bloodbound atlases load with valid frames and clip playback', () async {
    final folder = CharacterClassCatalog.gunslinger.spriteFolder;
    final metadata = jsonDecode(
      await rootBundle.loadString('$folder/animations.json'),
    ) as Map<String, dynamic>;
    expect(metadata.keys.toSet(), {'idle', 'run', 'attack', 'hit', 'death'});
    for (final entry in metadata.entries) {
      final clip = entry.value as Map<String, dynamic>;
      final data = await rootBundle.load('$folder/${entry.key}.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      final frameSize = clip['frameSize'] as int;
      final columns = clip['columns'] as int;
      final count = clip['frames'] as int;
      final duration = (clip['duration'] as num).toDouble();
      expect(image.width, columns * frameSize);
      expect(image.height, (count / columns).ceil() * frameSize);
      expect(image.width, lessThanOrEqualTo(2048));
      expect(image.height, lessThanOrEqualTo(2048));
      final loop = entry.key == 'idle' || entry.key == 'run';
      expect(clip['loop'], loop);
      final animation = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: count,
          amountPerRow: columns,
          stepTime: (clip['stepTime'] as num).toDouble(),
          textureSize: Vector2.all(frameSize.toDouble()),
          loop: loop,
        ),
      );
      for (final frame in animation.frames) {
        expect(
          frame.sprite.srcPosition.x + frameSize,
          lessThanOrEqualTo(image.width),
        );
        expect(
          frame.sprite.srcPosition.y + frameSize,
          lessThanOrEqualTo(image.height),
        );
      }
      final ticker = animation.createTicker()..update(duration + 0.001);
      expect(ticker.done(), !loop, reason: entry.key);
      if (!loop) expect(ticker.currentIndex, count - 1);
      image.dispose();
      codec.dispose();
    }
  });
}
