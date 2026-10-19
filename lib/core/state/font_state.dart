import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontSettings {
  final String fontFamily;
  final double fontSize;
  final int? textColor; // null = automático (tema); outro int = cor customizada do versículo
  final int? badgeColor; // null = padrão Keryx (0xFF4F46E5); outro int = cor customizada do balão numérico
  final int? strongHighlightColor; // null = padrão verde/azul; 0 = mesma cor do texto; outro int = cor customizada
  final bool strongUnderline;
  final bool strongBold;
  final bool splitPage; // true = dividir página em dois (2 colunas)

  FontSettings({
    this.fontFamily = 'Inter',
    this.fontSize = 16.0,
    this.textColor,
    this.badgeColor,
    this.strongHighlightColor,
    this.strongUnderline = true,
    this.strongBold = true,
    this.splitPage = false,
  });

  FontSettings copyWith({
    String? fontFamily,
    double? fontSize,
    int? textColor,
    bool clearTextColor = false,
    int? badgeColor,
    bool clearBadgeColor = false,
    int? strongHighlightColor,
    bool clearStrongHighlightColor = false,
    bool? strongUnderline,
    bool? strongBold,
    bool? splitPage,
  }) {
    return FontSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      textColor: clearTextColor ? null : (textColor ?? this.textColor),
      badgeColor: clearBadgeColor ? null : (badgeColor ?? this.badgeColor),
      strongHighlightColor: clearStrongHighlightColor
          ? null
          : (strongHighlightColor ?? this.strongHighlightColor),
      strongUnderline: strongUnderline ?? this.strongUnderline,
      strongBold: strongBold ?? this.strongBold,
      splitPage: splitPage ?? this.splitPage,
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main');
});

class FontSettingsNotifier extends StateNotifier<FontSettings> {
  final SharedPreferences prefs;

  FontSettingsNotifier(this.prefs) : super(_loadInitial(prefs));

  static FontSettings _loadInitial(SharedPreferences prefs) {
    final family = prefs.getString('bible_font_family') ?? 'Inter';
    final size = prefs.getDouble('bible_font_size') ?? 16.0;
    final hasTextColor = prefs.containsKey('bible_text_color');
    final textColorVal = hasTextColor ? prefs.getInt('bible_text_color') : null;
    final hasBadgeColor = prefs.containsKey('bible_badge_color');
    final badgeColorVal = hasBadgeColor ? prefs.getInt('bible_badge_color') : null;
    final hasColor = prefs.containsKey('bible_strong_color');
    final colorVal = hasColor ? prefs.getInt('bible_strong_color') : null;
    final underline = prefs.getBool('bible_strong_underline') ?? true;
    final bold = prefs.getBool('bible_strong_bold') ?? true;
    final split = prefs.getBool('bible_split_page') ?? false;
    return FontSettings(
      fontFamily: family,
      fontSize: size,
      textColor: textColorVal,
      badgeColor: badgeColorVal,
      strongHighlightColor: colorVal,
      strongUnderline: underline,
      strongBold: bold,
      splitPage: split,
    );
  }

  void setFontFamily(String family) async {
    state = state.copyWith(fontFamily: family);
    await prefs.setString('bible_font_family', family);
  }

  void setFontSize(double size) async {
    final clampedSize = size.clamp(12.0, 40.0);
    state = state.copyWith(fontSize: clampedSize);
    await prefs.setDouble('bible_font_size', clampedSize);
  }

  void setTextColor(int? colorVal) async {
    if (colorVal == null) {
      state = state.copyWith(clearTextColor: true);
      await prefs.remove('bible_text_color');
    } else {
      state = state.copyWith(textColor: colorVal);
      await prefs.setInt('bible_text_color', colorVal);
    }
  }

  void setBadgeColor(int? colorVal) async {
    if (colorVal == null) {
      state = state.copyWith(clearBadgeColor: true);
      await prefs.remove('bible_badge_color');
    } else {
      state = state.copyWith(badgeColor: colorVal);
      await prefs.setInt('bible_badge_color', colorVal);
    }
  }

  void setStrongHighlightColor(int? colorVal) async {
    if (colorVal == null) {
      state = state.copyWith(clearStrongHighlightColor: true);
      await prefs.remove('bible_strong_color');
    } else {
      state = state.copyWith(strongHighlightColor: colorVal);
      await prefs.setInt('bible_strong_color', colorVal);
    }
  }

  void setStrongUnderline(bool value) async {
    state = state.copyWith(strongUnderline: value);
    await prefs.setBool('bible_strong_underline', value);
  }

  void setStrongBold(bool value) async {
    state = state.copyWith(strongBold: value);
    await prefs.setBool('bible_strong_bold', value);
  }

  void setSplitPage(bool value) async {
    state = state.copyWith(splitPage: value);
    await prefs.setBool('bible_split_page', value);
  }

  void resetToDefault() async {
    state = FontSettings(fontFamily: 'Inter', fontSize: 16.0);
    await prefs.setString('bible_font_family', 'Inter');
    await prefs.setDouble('bible_font_size', 16.0);
    await prefs.remove('bible_text_color');
    await prefs.remove('bible_badge_color');
    await prefs.remove('bible_strong_color');
    await prefs.remove('bible_strong_underline');
    await prefs.remove('bible_strong_bold');
    await prefs.remove('bible_split_page');
  }
}

final fontSettingsProvider = StateNotifierProvider<FontSettingsNotifier, FontSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FontSettingsNotifier(prefs);
});
