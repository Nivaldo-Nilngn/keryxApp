import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: KeryxApp(),
      ),
    );

    // Verify that the app starts.
    // Since it's a complex app with Firebase and SQLite, it might take a few frames or show a loading state.
    expect(find.byType(KeryxApp), findsOneWidget);
  });
}
