// This is a basic Flutter widget test.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SubTrackerApp()));
    // Just verify it builds without crashing.
    expect(find.byType(SubTrackerApp), findsOneWidget);
  });
}
