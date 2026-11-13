import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_fonts.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 1. CONFIGURAÇÕES GLOBAIS DO SISTEMA (Aplicadas a todo o aplicativo)
// ══════════════════════════════════════════════════════════════════════════════

class SystemFontSettings {
  final String fontFamily;
  final double fontSize; // Base: 16.0 = escala 1.0x

  SystemFontSettings({
    this.fontFamily = 'Inter',
    this.fontSize = 16.0,
  });

  SystemFontSettings copyWith({
    String? fontFamily,
    double? fontSize,
  }) {
    return SystemFontSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

class SystemFontSettingsNotifier extends StateNotifier<SystemFontSettings> {
  final SharedPreferences prefs;

  SystemFontSettingsNotifier(this.prefs) : super(_loadInitial(prefs));

  static SystemFontSettings _loadInitial(SharedPreferences prefs) {
    final family = prefs.getString('system_font_family') ??
        prefs.getString('bible_font_family') ??
        'Inter';
    GoogleFonts.setGlobalFontFamilyOverride(family);
    final size = prefs.getDouble('system_font_size') ?? 16.0;
    return SystemFontSettings(
      fontFamily: family,
      fontSize: size,
    );
  }

  void setFontFamily(String family) async {
    GoogleFonts.setGlobalFontFamilyOverride(family);
    state = state.copyWith(fontFamily: family);
    await prefs.setString('system_font_family', family);
  }

  void setFontSize(double size) async {
    final clampedSize = size.clamp(12.0, 36.0);
    state = state.copyWith(fontSize: clampedSize);
    await prefs.setDouble('system_font_size', clampedSize);
  }

  void resetToDefault() async {
    GoogleFonts.setGlobalFontFamilyOverride('Inter');
    state = SystemFontSettings(fontFamily: 'Inter', fontSize: 16.0);
    await prefs.setString('system_font_family', 'Inter');
    await prefs.setDouble('system_font_size', 16.0);
  }
}

final systemFontSettingsProvider =
    StateNotifierProvider<SystemFontSettingsNotifier, SystemFontSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SystemFontSettingsNotifier(prefs);
});

// ══════════════════════════════════════════════════════════════════════════════
// 2. CONFIGURAÇÕES ESPECÍFICAS DA BÍBLIA (Isoladas: afetam somente a leitura bíblica)
// ══════════════════════════════════════════════════════════════════════════════

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
    // Configuração isolada: altera apenas a renderização da Bíblia sem interferir no app global
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

final bibleFontSettingsProvider =
    StateNotifierProvider<FontSettingsNotifier, FontSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FontSettingsNotifier(prefs);
});

/// Alias para manter compatibilidade com leitores bíblicos existentes
final fontSettingsProvider = bibleFontSettingsProvider;

// ══════════════════════════════════════════════════════════════════════════════
// 3. CONFIGURAÇÕES ESPECÍFICAS DO DEVOCIONAL (Isoladas: afetam somente o devocional)
// ══════════════════════════════════════════════════════════════════════════════

class DevocionalFontSettings {
  final String fontFamily;
  final double fontSize;
  final int? textColor; // Cor customizada do texto da reflexão/versículo
  final int? badgeColor; // Cor customizada de destaque, citação e bordas

  DevocionalFontSettings({
    this.fontFamily = 'Inter',
    this.fontSize = 16.0,
    this.textColor,
    this.badgeColor,
  });

  DevocionalFontSettings copyWith({
    String? fontFamily,
    double? fontSize,
    int? textColor,
    bool clearTextColor = false,
    int? badgeColor,
    bool clearBadgeColor = false,
  }) {
    return DevocionalFontSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      textColor: clearTextColor ? null : (textColor ?? this.textColor),
      badgeColor: clearBadgeColor ? null : (badgeColor ?? this.badgeColor),
    );
  }
}

class DevocionalFontSettingsNotifier extends StateNotifier<DevocionalFontSettings> {
  final SharedPreferences prefs;

  DevocionalFontSettingsNotifier(this.prefs) : super(_loadInitial(prefs));

  static DevocionalFontSettings _loadInitial(SharedPreferences prefs) {
    final family = prefs.getString('devocional_font_family') ?? 'Inter';
    final size = prefs.getDouble('devocional_font_size') ?? 16.0;
    final hasTextColor = prefs.containsKey('devocional_text_color');
    final textColorVal = hasTextColor ? prefs.getInt('devocional_text_color') : null;
    final hasBadgeColor = prefs.containsKey('devocional_badge_color');
    final badgeColorVal = hasBadgeColor ? prefs.getInt('devocional_badge_color') : null;
    return DevocionalFontSettings(
      fontFamily: family,
      fontSize: size,
      textColor: textColorVal,
      badgeColor: badgeColorVal,
    );
  }

  void setFontFamily(String family) async {
    state = state.copyWith(fontFamily: family);
    await prefs.setString('devocional_font_family', family);
  }

  void setFontSize(double size) async {
    final clampedSize = size.clamp(12.0, 36.0);
    state = state.copyWith(fontSize: clampedSize);
    await prefs.setDouble('devocional_font_size', clampedSize);
  }

  void setTextColor(int? colorVal) async {
    if (colorVal == null) {
      state = state.copyWith(clearTextColor: true);
      await prefs.remove('devocional_text_color');
    } else {
      state = state.copyWith(textColor: colorVal);
      await prefs.setInt('devocional_text_color', colorVal);
    }
  }

  void setBadgeColor(int? colorVal) async {
    if (colorVal == null) {
      state = state.copyWith(clearBadgeColor: true);
      await prefs.remove('devocional_badge_color');
    } else {
      state = state.copyWith(badgeColor: colorVal);
      await prefs.setInt('devocional_badge_color', colorVal);
    }
  }

  void resetToDefault() async {
    state = DevocionalFontSettings(fontFamily: 'Inter', fontSize: 16.0);
    await prefs.setString('devocional_font_family', 'Inter');
    await prefs.setDouble('devocional_font_size', 16.0);
    await prefs.remove('devocional_text_color');
    await prefs.remove('devocional_badge_color');
  }
}

final devocionalFontSettingsProvider =
    StateNotifierProvider<DevocionalFontSettingsNotifier, DevocionalFontSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DevocionalFontSettingsNotifier(prefs);
});
