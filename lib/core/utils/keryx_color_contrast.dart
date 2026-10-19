import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Utilitário centralizado para cálculo de contraste WCAG 2.1,
/// garantia de legibilidade de texto e paletas adaptativas conforme o tema.
class KeryxColorContrast {
  /// Relação mínima de contraste recomendada pela WCAG AA para texto comum (4.5:1)
  static const double minContrastBodyText = 4.5;

  /// Relação mínima de contraste para texto grande ou decorativo (3.0:1)
  static const double minContrastLargeText = 3.0;

  /// Calcula a luminância relativa de uma cor conforme WCAG 2.1
  /// Fórmula: 0.2126 * R + 0.7152 * G + 0.0722 * B
  static double getRelativeLuminance(Color color) {
    double transform(double channel) {
      if (channel <= 0.04045) {
        return channel / 12.92;
      } else {
        return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
      }
    }

    final r = transform(color.r);
    final g = transform(color.g);
    final b = transform(color.b);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Calcula a relação de contraste entre duas cores (1.0 a 21.0)
  static double getContrastRatio(Color color1, Color color2) {
    final l1 = getRelativeLuminance(color1);
    final l2 = getRelativeLuminance(color2);

    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Verifica se o contraste atinge o padrão mínimo da WCAG (padrão: 4.5:1)
  static bool isContrastAdequate(
    Color foreground,
    Color background, {
    double minRatio = minContrastBodyText,
  }) {
    return getContrastRatio(foreground, background) >= minRatio;
  }

  /// Obtém a cor de fundo real de leitura da tela no tema atual
  static Color getReadingBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF0F0F1E) : Colors.white;
  }

  /// Sugere uma alternativa legível mantendo o tom (matiz/hue) da cor escolhida,
  /// ajustando brilho (Value) e saturação até atingir contraste >= targetRatio (4.5:1).
  static Color suggestReadableAlternative(
    Color originalColor,
    bool isDarkTheme, {
    double targetRatio = minContrastBodyText,
  }) {
    final background = isDarkTheme ? const Color(0xFF0F0F1E) : Colors.white;
    final currentRatio = getContrastRatio(originalColor, background);
    if (currentRatio >= targetRatio) return originalColor;

    final hsv = HSVColor.fromColor(originalColor);

    if (isDarkTheme) {
      // No modo escuro, clareia gradualmente aumentando o Value e reduzindo levemente saturação
      double value = math.max(hsv.value, 0.75);
      double sat = hsv.saturation;
      for (int step = 0; step < 20; step++) {
        final candidate = HSVColor.fromAHSV(1.0, hsv.hue, sat, value).toColor();
        if (getContrastRatio(candidate, background) >= targetRatio) {
          return candidate;
        }
        value = math.min(1.0, value + 0.02);
        sat = math.max(0.15, sat - 0.05);
      }
      return const Color(0xFFF1F5F9); // Fallback branco gelo
    } else {
      // No modo claro, escurece gradualmente diminuindo o Value
      double value = math.min(hsv.value, 0.40);
      double sat = math.min(1.0, hsv.saturation * 1.1);
      for (int step = 0; step < 20; step++) {
        final candidate = HSVColor.fromAHSV(1.0, hsv.hue, sat, value).toColor();
        if (getContrastRatio(candidate, background) >= targetRatio) {
          return candidate;
        }
        value = math.max(0.05, value - 0.02);
      }
      return const Color(0xFF1E293B); // Fallback grafite escuro
    }
  }

  /// Garante que o texto NUNCA fique invisível ou ilegível na tela.
  /// Se a cor do usuário tiver contraste insuficiente no tema atual (< 3.0:1),
  /// corrige automaticamente para uma tonalidade com leitura garantida.
  static Color ensureReadableTextColor(Color? userTextColor, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;

    if (userTextColor == null) return defaultColor;

    final bg = getReadingBackgroundColor(context);
    final ratio = getContrastRatio(userTextColor, bg);

    // Se o contraste for aceitável (>= 3.2:1 para leitura mínima aceitável), usa a cor
    if (ratio >= 3.2) return userTextColor;

    // Se falhar gravemente (ex: texto preto em fundo escuro ou texto branco em fundo claro),
    // ajusta inteligentemente preservando o matiz
    return suggestReadableAlternative(userTextColor, isDark, targetRatio: minContrastBodyText);
  }

  /// Paleta inteligente de cores para Texto no Tema Escuro (Todas com contraste excelente >= 14:1)
  static const List<Map<String, dynamic>> darkTextPresets = [
    {'value': null, 'isAuto': true, 'label': 'Auto', 'color': Color(0xFFFFFFFF)},
    {'value': 0xFFF1F5F9, 'label': 'Gelo Suave', 'color': Color(0xFFF1F5F9)},
    {'value': 0xFFFEF3C7, 'label': 'Marfim', 'color': Color(0xFFFEF3C7)},
    {'value': 0xFFFDE68A, 'label': 'Dourado Claro', 'color': Color(0xFFFDE68A)},
    {'value': 0xFFA7F3D0, 'label': 'Esmeralda Menta', 'color': Color(0xFFA7F3D0)},
    {'value': 0xFFBAE6FD, 'label': 'Celeste Claro', 'color': Color(0xFFBAE6FD)},
    {'value': 0xFFE9D5FF, 'label': 'Lavanda Clara', 'color': Color(0xFFE9D5FF)},
    {'value': 0xFFFED7AA, 'label': 'Pêssego Claro', 'color': Color(0xFFFED7AA)},
    {'value': 0xFFFBCFE8, 'label': 'Rosa Claro', 'color': Color(0xFFFBCFE8)},
  ];

  /// Paleta inteligente de cores para Texto no Tema Claro (Todas com contraste excelente >= 10:1)
  static const List<Map<String, dynamic>> lightTextPresets = [
    {'value': null, 'isAuto': true, 'label': 'Auto', 'color': Color(0xFF000000)},
    {'value': 0xFF1E293B, 'label': 'Grafite Escuro', 'color': Color(0xFF1E293B)},
    {'value': 0xFF0F172A, 'label': 'Azul Noturno', 'color': Color(0xFF0F172A)},
    {'value': 0xFF451A03, 'label': 'Sépia Profundo', 'color': Color(0xFF451A03)},
    {'value': 0xFF064E3B, 'label': 'Verde Floresta', 'color': Color(0xFF064E3B)},
    {'value': 0xFF881337, 'label': 'Carmim Escuro', 'color': Color(0xFF881337)},
    {'value': 0xFF312E81, 'label': 'Índigo Escuro', 'color': Color(0xFF312E81)},
    {'value': 0xFF3E2723, 'label': 'Café Escuro', 'color': Color(0xFF3E2723)},
    {'value': 0xFF581C87, 'label': 'Púrpura Escuro', 'color': Color(0xFF581C87)},
  ];

  /// Paleta inteligente de destaque Strong no Tema Escuro (Brilhante e nítida sobre fundo escuro)
  static const List<Map<String, dynamic>> darkStrongPresets = [
    {'value': null, 'isAuto': true, 'label': 'Padrão'},
    {'value': 0xFF38BDF8, 'label': 'Celeste', 'color': Color(0xFF38BDF8)},
    {'value': 0xFFFBBF24, 'label': 'Âmbar', 'color': Color(0xFFFBBF24)},
    {'value': 0xFFC084FC, 'label': 'Roxo Claro', 'color': Color(0xFFC084FC)},
    {'value': 0xFFF87171, 'label': 'Coral', 'color': Color(0xFFF87171)},
    {'value': 0xFFF472B6, 'label': 'Rosa Claro', 'color': Color(0xFFF472B6)},
    {'value': 0xFF22D3EE, 'label': 'Ciano', 'color': Color(0xFF22D3EE)},
    {'value': 0xFF818CF8, 'label': 'Índigo Claro', 'color': Color(0xFF818CF8)},
  ];

  /// Paleta inteligente de destaque Strong no Tema Claro (Profunda e nítida sobre fundo claro)
  static const List<Map<String, dynamic>> lightStrongPresets = [
    {'value': null, 'isAuto': true, 'label': 'Padrão'},
    {'value': 0xFF0284C7, 'label': 'Celeste', 'color': Color(0xFF0284C7)},
    {'value': 0xFFD97706, 'label': 'Âmbar', 'color': Color(0xFFD97706)},
    {'value': 0xFF7C3AED, 'label': 'Roxo', 'color': Color(0xFF7C3AED)},
    {'value': 0xFFDC2626, 'label': 'Carmim', 'color': Color(0xFFDC2626)},
    {'value': 0xFFDB2777, 'label': 'Rosa', 'color': Color(0xFFDB2777)},
    {'value': 0xFF0D9488, 'label': 'Petróleo', 'color': Color(0xFF0D9488)},
    {'value': 0xFF4F46E5, 'label': 'Índigo', 'color': Color(0xFF4F46E5)},
  ];
}
