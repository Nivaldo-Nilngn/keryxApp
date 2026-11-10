import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Design system smoke test - verifies theme and provider scope', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('KeryxApp Ready'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('KeryxApp Ready'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
