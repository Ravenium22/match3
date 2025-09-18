// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:match3/main.dart';

void main() {
  testWidgets('Match3 app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const Match3Game());

    // Verify that the home screen renders with title text.
    expect(find.text('MATCH 3 BATTLE'), findsOneWidget);

    // Verify that primary buttons exist.
    expect(find.text('Single Player'), findsOneWidget);
    expect(find.text('Practice vs AI'), findsOneWidget);
    expect(find.text('Online Multiplayer'), findsOneWidget);
    expect(find.text('Local PvP'), findsOneWidget);
  });
}
