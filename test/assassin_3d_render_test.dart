import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roughlike/game/player/character_class.dart';
import 'package:roughlike/ui/screens/game_screen.dart';

void main() {
  testWidgets('Assassin 3D model loads and renders in a run', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(characterClass: CharacterClassCatalog.assassin)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
