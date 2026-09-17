import 'package:flutter_test/flutter_test.dart';

import 'package:roughlike/main.dart';

void main() {
  testWidgets('main menu shows the start run button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RoughlikeApp());

    expect(find.text('BEGIN RUN'), findsOneWidget);
  });
}
