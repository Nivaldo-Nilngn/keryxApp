import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keryx_app/core/utils/navigation_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adaptive Back Button Visibility Tests', () {
    testWidgets('1. Hides back arrow on Android tablets with 3-button navigation in Safe Area', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 1280), // Android Tablet
              viewPadding: EdgeInsets.only(bottom: 48), // Safe Area com 3 botões (Voltar ◀, Início ●, Recentes ◼)
            ),
            child: Builder(
              builder: (context) {
                final hasButtons = hasDeviceNavigationButtons(context);
                expect(hasButtons, isTrue);

                final hide = shouldHideBackButton(context);
                expect(hide, isTrue);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('2. Shows back arrow on Desktop / Web platforms', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(1440, 900), // Desktop
              viewPadding: EdgeInsets.zero,
            ),
            child: Builder(
              builder: (context) {
                final hide = shouldHideBackButton(context);
                expect(hide, isFalse);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('3. Hides back arrow on Android root screen with 3-button navigation (bottom padding >= 24px)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844), // Mobile phone root
              viewPadding: EdgeInsets.only(bottom: 48), // Android 3-button system nav bar
            ),
            child: Builder(
              builder: (context) {
                final hide = shouldHideBackButton(context);
                expect(hide, isTrue);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('4. Shows back arrow on Mobile without device nav buttons (e.g. gesture bar / iOS)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844), // Mobile phone
              viewPadding: EdgeInsets.only(bottom: 16), // Thin gesture indicator
            ),
            child: Builder(
              builder: (context) {
                final hide = shouldHideBackButton(context);
                expect(hide, isFalse);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
  });
}
