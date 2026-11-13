import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';
import 'package:keryx_app/features/study/widgets/word_mobile_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Font Settings Architectural Isolation Tests', () {
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'system_font_family': 'Ubuntu',
        'system_font_size': 18.0,
        'bible_font_family': 'Lora',
        'bible_font_size': 22.0,
        'bible_text_color': 0xFFFFFFFF,
        'devocional_font_family': 'Poppins',
        'devocional_font_size': 14.0,
      });
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Loads initial settings correctly and independently from SharedPreferences', () {
      final system = container.read(systemFontSettingsProvider);
      final bible = container.read(bibleFontSettingsProvider);
      final devocional = container.read(devocionalFontSettingsProvider);

      expect(system.fontFamily, 'Ubuntu');
      expect(system.fontSize, 18.0);

      expect(bible.fontFamily, 'Lora');
      expect(bible.fontSize, 22.0);
      expect(bible.textColor, 0xFFFFFFFF);

      expect(devocional.fontFamily, 'Poppins');
      expect(devocional.fontSize, 14.0);
    });

    test('2. Changing System Font Settings does NOT affect Bible or Devocional settings', () {
      container.read(systemFontSettingsProvider.notifier).setFontFamily('Raleway');
      container.read(systemFontSettingsProvider.notifier).setFontSize(20.0);

      final system = container.read(systemFontSettingsProvider);
      final bible = container.read(bibleFontSettingsProvider);
      final devocional = container.read(devocionalFontSettingsProvider);

      // System changed
      expect(system.fontFamily, 'Raleway');
      expect(system.fontSize, 20.0);

      // Bible remained unchanged
      expect(bible.fontFamily, 'Lora');
      expect(bible.fontSize, 22.0);

      // Devocional remained unchanged
      expect(devocional.fontFamily, 'Poppins');
      expect(devocional.fontSize, 14.0);
    });

    test('3. Changing Bible Font Settings does NOT affect System or Devocional settings', () {
      container.read(bibleFontSettingsProvider.notifier).setFontFamily('Merriweather');
      container.read(bibleFontSettingsProvider.notifier).setFontSize(26.0);
      container.read(bibleFontSettingsProvider.notifier).setTextColor(0xFF22C55E);

      final system = container.read(systemFontSettingsProvider);
      final bible = container.read(bibleFontSettingsProvider);
      final devocional = container.read(devocionalFontSettingsProvider);

      // Bible changed
      expect(bible.fontFamily, 'Merriweather');
      expect(bible.fontSize, 26.0);
      expect(bible.textColor, 0xFF22C55E);

      // System remained untouched
      expect(system.fontFamily, 'Ubuntu');
      expect(system.fontSize, 18.0);

      // Devocional remained untouched
      expect(devocional.fontFamily, 'Poppins');
      expect(devocional.fontSize, 14.0);
    });

    test('4. Changing Devocional Font Settings does NOT affect System or Bible settings', () {
      container.read(devocionalFontSettingsProvider.notifier).setFontFamily('Nunito');
      container.read(devocionalFontSettingsProvider.notifier).setFontSize(19.0);
      container.read(devocionalFontSettingsProvider.notifier).setBadgeColor(0xFFEAB308);

      final system = container.read(systemFontSettingsProvider);
      final bible = container.read(bibleFontSettingsProvider);
      final devocional = container.read(devocionalFontSettingsProvider);

      // Devocional changed
      expect(devocional.fontFamily, 'Nunito');
      expect(devocional.fontSize, 19.0);
      expect(devocional.badgeColor, 0xFFEAB308);

      // System remained untouched
      expect(system.fontFamily, 'Ubuntu');
      expect(system.fontSize, 18.0);

      // Bible remained untouched
      expect(bible.fontFamily, 'Lora');
      expect(bible.fontSize, 22.0);
    });

    test('5. Resetting Devocional does NOT reset Bible or System settings', () {
      container.read(devocionalFontSettingsProvider.notifier).resetToDefault();

      final system = container.read(systemFontSettingsProvider);
      final bible = container.read(bibleFontSettingsProvider);
      final devocional = container.read(devocionalFontSettingsProvider);

      // Devocional reset to defaults
      expect(devocional.fontFamily, 'Inter');
      expect(devocional.fontSize, 16.0);
      expect(devocional.textColor, isNull);
      expect(devocional.badgeColor, isNull);

      // System preserved
      expect(system.fontFamily, 'Ubuntu');
      expect(system.fontSize, 18.0);

      // Bible preserved
      expect(bible.fontFamily, 'Lora');
      expect(bible.fontSize, 22.0);
    });

    test('6. Resetting Bible does NOT reset Devocional or System settings', () {
      container.read(bibleFontSettingsProvider.notifier).resetToDefault();

      final system = container.read(systemFontSettingsProvider);
      final bible = container.read(bibleFontSettingsProvider);
      final devocional = container.read(devocionalFontSettingsProvider);

      // Bible reset to defaults
      expect(bible.fontFamily, 'Inter');
      expect(bible.fontSize, 16.0);
      expect(bible.textColor, isNull);

      // System preserved
      expect(system.fontFamily, 'Ubuntu');
      expect(system.fontSize, 18.0);

      // Devocional preserved
      expect(devocional.fontFamily, 'Poppins');
      expect(devocional.fontSize, 14.0);
    });

    test('7. Verifies 24 fonts available across all reading and document screens', () {
      expect(CustomFontLoader.googleFonts.length, 24);
      expect(CustomFontLoader.googleFonts, containsAll([
        'Outfit', 'Inter', 'Roboto', 'Playfair Display', 'Montserrat',
        'Lora', 'Merriweather', 'Nunito', 'Poppins', 'Raleway',
        'Ubuntu', 'Oswald', 'Lato', 'Open Sans', 'Caveat',
        'Dancing Script', 'Pacifico', 'Cinzel', 'Josefin Sans',
        'Quicksand', 'Bebas Neue', 'Anton', 'Satisfy', 'Lobster'
      ]));

      expect(WordMobileTheme.availableFonts, containsAll(CustomFontLoader.googleFonts));
    });
  });
}
