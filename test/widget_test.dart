// This is a basic Flutter widget test.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiper/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KiperApp()));
    // Just verify it builds without crashing.
    expect(find.byType(KiperApp), findsOneWidget);
  });
}
