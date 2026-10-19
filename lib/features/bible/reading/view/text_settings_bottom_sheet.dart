import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/utils/keryx_color_contrast.dart';
import 'package:keryx_app/core/widgets/keryx_color_picker_dialog.dart';

/// Modal bottom sheet para configurar tamanho de fonte, família tipográfica,
/// cores do texto, cores do balão numérico e destaque Strong.
/// O preview é fixo no topo e o conteúdo passa por baixo dele ao rolar.
void showTextSettingsBottomSheet(BuildContext context, {bool isStrongVersion = false}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    builder: (ctx) => TextSettingsBottomSheet(isStrongVersion: isStrongVersion),
  );
}

class TextSettingsBottomSheet extends ConsumerWidget {
  final bool isStrongVersion;

  const TextSettingsBottomSheet({
    super.key,
    this.isStrongVersion = false,
  });

  // Cores de balão numérico (círculos)
  static const List<Map<String, dynamic>> _badgeColorPresets = [
    {'value': null, 'color': Color(0xFF4F46E5), 'label': 'Índigo'},
    {'value': 0xFFD4AF37, 'color': Color(0xFFD4AF37), 'label': 'Dourado'},
    {'value': 0xFF10B981, 'color': Color(0xFF10B981), 'label': 'Esmeralda'},
    {'value': 0xFF0284C7, 'color': Color(0xFF0284C7), 'label': 'Celeste'},
    {'value': 0xFF8B5CF6, 'color': Color(0xFF8B5CF6), 'label': 'Roxo'},
    {'value': 0xFFBE123C, 'color': Color(0xFFBE123C), 'label': 'Carmim'},
    {'value': 0xFFEA580C, 'color': Color(0xFFEA580C), 'label': 'Laranja'},
    {'value': 0xFF475569, 'color': Color(0xFF475569), 'label': 'Grafite'},
    {'value': 0xFF18181B, 'color': Color(0xFF18181B), 'label': 'Preto'},
  ];

  static const List<String> _popularFonts = [
    'Outfit',
    'Inter',
    'Roboto',
    'Merriweather',
    'Lora',
    'Poppins',
    'Playfair Display',
    'Lato',
    'Open Sans',
  ];

  TextStyle _getFontStyle(String fontName, {double? fontSize, FontWeight? fontWeight, Color? color}) {
    if (CustomFontLoader.loadedFontFamilies.contains(fontName)) {
      return TextStyle(fontFamily: fontName, fontSize: fontSize, fontWeight: fontWeight, color: color);
    }
    try {
      return GoogleFonts.getFont(fontName, fontSize: fontSize, fontWeight: fontWeight, color: color);
    } catch (_) {
      return TextStyle(fontFamily: fontName, fontSize: fontSize, fontWeight: fontWeight, color: color);
    }
  }

  TextStyle _getStrongPreviewStyle(BuildContext context, FontSettings settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTextColor = KeryxColorContrast.ensureReadableTextColor(
      settings.textColor != null ? Color(settings.textColor!) : null,
      context,
    );
    Color? color;
    Color? decColor;

    if (settings.strongHighlightColor == 0) {
      color = effectiveTextColor;
      decColor = effectiveTextColor.withValues(alpha: 0.35);
    } else if (settings.strongHighlightColor != null) {
      color = Color(settings.strongHighlightColor!);
      decColor = color.withValues(alpha: 0.4);
    } else {
      color = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
      decColor = color.withValues(alpha: 0.4);
    }

    final base = _getFontStyle(
      settings.fontFamily,
      fontSize: settings.fontSize,
      fontWeight: settings.strongBold ? FontWeight.bold : FontWeight.normal,
      color: color,
    );

    return base.copyWith(
      decoration: settings.strongUnderline ? TextDecoration.underline : TextDecoration.none,
      decorationColor: decColor,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF181824) : Colors.white;
    final cardBg = isDark ? const Color(0xFF222234) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    final textColorPresets = isDark ? KeryxColorContrast.darkTextPresets : KeryxColorContrast.lightTextPresets;
    final strongColorPresets = isDark ? KeryxColorContrast.darkStrongPresets : KeryxColorContrast.lightStrongPresets;

    final isSameColorAsText = fontSettings.strongHighlightColor == 0;
    final badgeColor = fontSettings.badgeColor != null ? Color(fontSettings.badgeColor!) : const Color(0xFF4F46E5);
    final verseTextColor = KeryxColorContrast.ensureReadableTextColor(
      fontSettings.textColor != null ? Color(fontSettings.textColor!) : null,
      context,
    );

    final isBadgeCustom = fontSettings.badgeColor != null &&
        !_badgeColorPresets.any((p) => p['value'] == fontSettings.badgeColor);

    final isTextCustom = fontSettings.textColor != null &&
        !textColorPresets.any((p) => p['value'] == fontSettings.textColor);

    final isStrongCustom = !isSameColorAsText &&
        fontSettings.strongHighlightColor != null &&
        !strongColorPresets.any((p) => p['value'] == fontSettings.strongHighlightColor);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth >= 600;
    final horizontalPadding = isTablet ? 32.0 : 20.0;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: screenHeight * (isTablet ? 0.86 : 0.90),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Puxador / Handle
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: isTablet ? 64 : 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Cabeçalho da modal
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isStrongVersion ? 'Configurações de Leitura & Strong' : 'Configurações de Leitura',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          isStrongVersion ? 'Ajuste fontes, cores e destaque Strong' : 'Ajuste fontes, cores de texto e balões',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ==========================================
            // PREVIEW FIXO NO TOPO (NÃO ROLA!)
            // O conteúdo abaixo rola por baixo dele
            // ==========================================
            Container(
              decoration: BoxDecoration(
                color: bg,
                border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isStrongVersion ? Icons.auto_awesome : Icons.remove_red_eye_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isStrongVersion ? 'PRÉVIA • BÍBLIA STRONG' : 'PRÉVIA • TEXTO NORMAL',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${fontSettings.fontSize.toInt()} px • ${fontSettings.fontFamily}',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        if (fontSettings.splitPage) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.vertical_split_rounded, size: 10, color: Color(0xFF10B981)),
                                const SizedBox(width: 3),
                                Text(
                                  '2 Colunas',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        style: _getFontStyle(
                          fontSettings.fontFamily,
                          fontSize: fontSettings.fontSize,
                          fontWeight: FontWeight.normal,
                          color: verseTextColor,
                        ),
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: _buildPreviewBadge(badgeColor, '1'),
                          ),
                          if (isStrongVersion) ...[
                            // Preview com termos Strong destacados
                            const TextSpan(text: 'No '),
                            TextSpan(
                              text: 'princípio',
                              style: _getStrongPreviewStyle(context, fontSettings),
                            ),
                            const TextSpan(text: ', '),
                            TextSpan(
                              text: 'criou',
                              style: _getStrongPreviewStyle(context, fontSettings),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: 'Deus',
                              style: _getStrongPreviewStyle(context, fontSettings),
                            ),
                            const TextSpan(text: ' os '),
                            TextSpan(
                              text: 'céus',
                              style: _getStrongPreviewStyle(context, fontSettings),
                            ),
                            const TextSpan(text: ' e a '),
                            TextSpan(
                              text: 'terra',
                              style: _getStrongPreviewStyle(context, fontSettings),
                            ),
                            const TextSpan(text: '.'),
                          ] else ...[
                            // Preview para Bíblia Comum (sem Strong - Texto limpo e uniforme)
                            const TextSpan(text: 'No princípio, criou Deus os céus e a terra.'),
                          ],
                        ],
                      ),
                    ),
                    if (isStrongVersion) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSameColorAsText
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                  : const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isSameColorAsText
                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
                                    : const Color(0xFF10B981).withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSameColorAsText ? Icons.format_color_text_rounded : Icons.palette_outlined,
                                  size: 11,
                                  color: isSameColorAsText
                                      ? Theme.of(context).colorScheme.primary
                                      : const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isSameColorAsText ? 'Texto Uniforme (Mesma cor)' : 'Destaque Colorido Ativo',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSameColorAsText
                                        ? Theme.of(context).colorScheme.primary
                                        : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ==========================================
            // CONTEÚDO SCROLLÁVEL QUE PASSA POR BAIXO
            // ==========================================
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 24),
                physics: const BouncingScrollPhysics(),
                children: [
                  // 1 & 2: Cor do Balão Numérico & Cor do Texto (No tablet em 2 colunas, no mobile empilhado)
                  // Cada um com 10 opções divididas em 2 linhas de 5 e 5
                  ...(() {
                    final badgeSwatches = <Widget>[
                      ..._badgeColorPresets.map((preset) {
                        final val = preset['value'] as int?;
                        final isSelected = fontSettings.badgeColor == val;
                        final color = preset['color'] as Color;

                        return _buildCircleSwatch(
                          context: context,
                          color: color,
                          isSelected: isSelected,
                          isTablet: isTablet,
                          onTap: () => ref.read(fontSettingsProvider.notifier).setBadgeColor(val),
                          child: Text(
                            '1',
                            style: GoogleFonts.outfit(
                              fontSize: isTablet ? 14 : 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }),
                      _buildCustomPickerCircle(
                        context: context,
                        isCustomSelected: isBadgeCustom,
                        activeCustomColor: isBadgeCustom ? badgeColor : null,
                        isTablet: isTablet,
                        onTap: () async {
                          final picked = await showKeryxColorPicker(
                            context: context,
                            initialColor: badgeColor,
                            title: 'Cor do Balão Numérico',
                          );
                          if (picked != null) {
                            ref.read(fontSettingsProvider.notifier).setBadgeColor(picked.toARGB32());
                          }
                        },
                      ),
                    ];

                    final textSwatches = <Widget>[
                      ...textColorPresets.map((preset) {
                        final val = preset['value'] as int?;
                        final isAuto = preset['isAuto'] == true;
                        final isSelected = fontSettings.textColor == val;
                        final color = isAuto
                            ? (isDark ? Colors.white : Colors.black87)
                            : (preset['color'] as Color);

                        return _buildCircleSwatch(
                          context: context,
                          color: color,
                          isSelected: isSelected,
                          isTablet: isTablet,
                          innerBorder: isAuto || color == Colors.white || color == const Color(0xFFF1F5F9) || color == const Color(0xFFFEF3C7)
                              ? Border.all(color: isDark ? Colors.white24 : Colors.black26, width: 1)
                              : null,
                          onTap: () => ref.read(fontSettingsProvider.notifier).setTextColor(val),
                          child: isAuto
                              ? Icon(
                                  Icons.brightness_auto_rounded,
                                  size: isTablet ? 18 : 16,
                                  color: isDark ? Colors.black : Colors.white,
                                )
                              : null,
                        );
                      }),
                      _buildCustomPickerCircle(
                        context: context,
                        isCustomSelected: isTextCustom,
                        activeCustomColor: isTextCustom ? verseTextColor : null,
                        isTablet: isTablet,
                        onTap: () async {
                          final picked = await showKeryxColorPicker(
                            context: context,
                            initialColor: verseTextColor,
                            title: 'Cor do Texto da Bíblia',
                            isTextColor: true,
                            referenceBackgroundColor: isDark ? const Color(0xFF0F0F1E) : Colors.white,
                          );
                          if (picked != null) {
                            ref.read(fontSettingsProvider.notifier).setTextColor(picked.toARGB32());
                          }
                        },
                      ),
                    ];

                    if (isTablet) {
                      return [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(
                                    context,
                                    title: 'COR DO BALÃO NUMÉRICO',
                                    subtitle: 'Círculo indicador do versículo',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSwatchGrid5x2(badgeSwatches, isTablet: true),
                                ],
                              ),
                            ),
                            const SizedBox(width: 28),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(
                                    context,
                                    title: 'COR DO TEXTO DA BÍBLIA (GERAL)',
                                    subtitle: isDark
                                        ? 'Cores claras de alto contraste para o modo escuro'
                                        : 'Cores escuras de alto contraste para o modo claro',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSwatchGrid5x2(textSwatches, isTablet: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ];
                    } else {
                      return [
                        _buildSectionHeader(
                          context,
                          title: 'COR DO BALÃO NUMÉRICO',
                          subtitle: 'Círculo indicador do versículo',
                        ),
                        const SizedBox(height: 10),
                        _buildSwatchGrid5x2(badgeSwatches, isTablet: false),
                        const SizedBox(height: 22),
                        _buildSectionHeader(
                          context,
                          title: 'COR DO TEXTO DA BÍBLIA (GERAL)',
                          subtitle: isDark
                              ? 'Cores claras de alto contraste para o modo escuro'
                              : 'Cores escuras de alto contraste para o modo claro',
                        ),
                        const SizedBox(height: 10),
                        _buildSwatchGrid5x2(textSwatches, isTablet: false),
                      ];
                    }
                  })(),

                  // 3. SE FOR BÍBLIA STRONG: Exibe a seção Strong. SE NÃO FOR, FICA OCULTO!
                  if (isStrongVersion) ...[
                    const SizedBox(height: 22),
                    _buildSectionHeader(
                      context,
                      title: 'PALAVRAS COM DICIONÁRIO STRONG',
                      subtitle: isSameColorAsText
                          ? 'Texto uniforme (sem destaque colorido), mantendo o toque no Strong'
                          : 'Destaque visual ativo para termos com chave hebraica/grega',
                    ),
                    const SizedBox(height: 12),

                    // Linha única com todas as opções de cores Strong (incluindo Mesma cor do texto e sem cores repetidas)
                    ...(() {
                      final strongSwatches = <Widget>[
                        // 1. Mesma cor do texto (Sem destaque colorido)
                        _buildCircleSwatch(
                          context: context,
                          color: isDark ? const Color(0xFF222234) : const Color(0xFFE2E8F0),
                          isSelected: isSameColorAsText,
                          isTablet: isTablet,
                          tooltip: 'Mesma cor do texto (Sem destaque)',
                          innerBorder: Border.all(
                            color: isSameColorAsText
                                ? Theme.of(context).colorScheme.primary
                                : (isDark ? Colors.white24 : Colors.black26),
                            width: isSameColorAsText ? 1.8 : 1.2,
                          ),
                          onTap: () => ref.read(fontSettingsProvider.notifier).setStrongHighlightColor(0),
                          child: Icon(
                            isSameColorAsText ? Icons.check_rounded : Icons.format_color_text_rounded,
                            size: isTablet ? 18 : 16,
                            color: isSameColorAsText
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                        // 2. Presets Strong (Padrão e cores sem repetição)
                        ...strongColorPresets.map((preset) {
                          final val = preset['value'] as int?;
                          final isAuto = preset['isAuto'] == true;
                          final isSelected = !isSameColorAsText && fontSettings.strongHighlightColor == val;
                          final color = isAuto
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                              : (preset['color'] as Color);

                          return _buildCircleSwatch(
                            context: context,
                            color: color,
                            isSelected: isSelected,
                            isTablet: isTablet,
                            tooltip: preset['label'] as String?,
                            onTap: () => ref.read(fontSettingsProvider.notifier).setStrongHighlightColor(val),
                            child: isAuto
                                ? (isSelected
                                    ? const Icon(Icons.check, size: 17, color: Colors.white)
                                    : const Icon(Icons.auto_awesome, size: 17, color: Colors.white))
                                : null,
                          );
                        }),
                        // 3. Custom color picker
                        _buildCustomPickerCircle(
                          context: context,
                          isCustomSelected: isStrongCustom,
                          activeCustomColor: isStrongCustom && fontSettings.strongHighlightColor != null
                              ? Color(fontSettings.strongHighlightColor!)
                              : null,
                          isTablet: isTablet,
                          tooltip: 'Outra cor de destaque...',
                          onTap: () async {
                            final picked = await showKeryxColorPicker(
                              context: context,
                              initialColor: fontSettings.strongHighlightColor != null && fontSettings.strongHighlightColor != 0
                                  ? Color(fontSettings.strongHighlightColor!)
                                  : (isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED)),
                              title: 'Cor de Destaque Strong',
                              isTextColor: false,
                            );
                            if (picked != null) {
                              ref.read(fontSettingsProvider.notifier).setStrongHighlightColor(picked.toARGB32());
                            }
                          },
                        ),
                      ];

                      return [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: strongSwatches,
                          ),
                        ),
                      ];
                    })(),

                    const SizedBox(height: 16),

                    // Switches de Sublinhado e Negrito para Strong
                    Material(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: borderColor),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: isTablet
                            ? Row(
                                children: [
                                  Expanded(
                                    child: SwitchListTile(
                                      dense: true,
                                      title: Text(
                                        'Sublinhar termos com Strong',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Exibe linha sutil para indicar termo clicável',
                                        style: GoogleFonts.outfit(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                      ),
                                      activeThumbColor: Theme.of(context).colorScheme.primary,
                                      value: fontSettings.strongUnderline,
                                      onChanged: (val) {
                                        ref.read(fontSettingsProvider.notifier).setStrongUnderline(val);
                                      },
                                    ),
                                  ),
                                  Container(width: 1, height: 48, color: borderColor),
                                  Expanded(
                                    child: SwitchListTile(
                                      dense: true,
                                      title: Text(
                                        'Negrito nos termos com Strong',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Aumenta o peso tipográfico das palavras Strong',
                                        style: GoogleFonts.outfit(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                      ),
                                      activeThumbColor: Theme.of(context).colorScheme.primary,
                                      value: fontSettings.strongBold,
                                      onChanged: (val) {
                                        ref.read(fontSettingsProvider.notifier).setStrongBold(val);
                                      },
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  SwitchListTile(
                                    dense: true,
                                    title: Text(
                                      'Sublinhar termos com Strong',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Exibe linha sutil para indicar termo clicável',
                                      style: GoogleFonts.outfit(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                    ),
                                    activeThumbColor: Theme.of(context).colorScheme.primary,
                                    value: fontSettings.strongUnderline,
                                    onChanged: (val) {
                                      ref.read(fontSettingsProvider.notifier).setStrongUnderline(val);
                                    },
                                  ),
                                  Divider(height: 1, color: borderColor),
                                  SwitchListTile(
                                    dense: true,
                                    title: Text(
                                      'Negrito nos termos com Strong',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Aumenta o peso tipográfico das palavras Strong',
                                      style: GoogleFonts.outfit(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                    ),
                                    activeThumbColor: Theme.of(context).colorScheme.primary,
                                    value: fontSettings.strongBold,
                                    onChanged: (val) {
                                      ref.read(fontSettingsProvider.notifier).setStrongBold(val);
                                    },
                                  ),
                                ],
                              ),
                      ),
                  ],

                  const SizedBox(height: 22),

                  // 4. Tamanho do Texto
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(
                        context,
                        title: 'TAMANHO DO TEXTO',
                        subtitle: 'Escala de leitura dos versículos',
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${fontSettings.fontSize.toInt()} px',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_rounded, size: 20),
                          onPressed: fontSettings.fontSize > 12
                              ? () => ref.read(fontSettingsProvider.notifier).setFontSize(fontSettings.fontSize - 1)
                              : null,
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              activeTrackColor: Theme.of(context).colorScheme.primary,
                              inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                              thumbColor: Theme.of(context).colorScheme.primary,
                              overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            ),
                            child: Slider(
                              value: fontSettings.fontSize,
                              min: 12,
                              max: 36,
                              divisions: 24,
                              onChanged: (val) {
                                ref.read(fontSettingsProvider.notifier).setFontSize(val);
                              },
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, size: 20),
                          onPressed: fontSettings.fontSize < 36
                              ? () => ref.read(fontSettingsProvider.notifier).setFontSize(fontSettings.fontSize + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 5. Família da Fonte
                  _buildSectionHeader(
                    context,
                    title: 'FAMÍLIA DA FONTE',
                    subtitle: 'Selecione ou importe tipografias personalizadas',
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        ..._popularFonts,
                        ...CustomFontLoader.loadedFontFamilies.where((f) => !_popularFonts.contains(f)),
                        '+ Importar',
                      ].map((family) {
                        if (family == '+ Importar') {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () async {
                                final newFont = await CustomFontLoader.importCustomFont();
                                if (newFont != null) {
                                  ref.read(fontSettingsProvider.notifier).setFontFamily(newFont);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.add_circle_outline_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Importar',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        final isSelected = fontSettings.fontFamily == family;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              ref.read(fontSettingsProvider.notifier).setFontFamily(family);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : borderColor,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                family,
                                style: _getFontStyle(
                                  family,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 6. Layout de Leitura (Dividir página em dois)
                  _buildSectionHeader(
                    context,
                    title: 'LAYOUT DE LEITURA',
                    subtitle: 'Organização das colunas na tela',
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: borderColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile(
                        dense: true,
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.vertical_split_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Dividir página em dois',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Exibe o texto bíblico em duas colunas lado a lado',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        value: fontSettings.splitPage,
                        onChanged: (val) {
                          ref.read(fontSettingsProvider.notifier).setSplitPage(val);
                        },
                      ),
                    ),

                  const SizedBox(height: 28),

                  // 7. Botão de Restaurar Padrões
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        ref.read(fontSettingsProvider.notifier).resetToDefault();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        'Restaurar configurações originais',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  SizedBox(height: 28 + MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Grid de swatches 5 e 5 (total 10)
  Widget _buildSwatchGrid5x2(List<Widget> items, {bool isTablet = false}) {
    final row1 = items.take(5).toList();
    final row2 = items.skip(5).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: row1,
        ),
        SizedBox(height: isTablet ? 12 : 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: row2,
        ),
      ],
    );
  }

  // Swatch circular ultra-limpo
  Widget _buildCircleSwatch({
    required BuildContext context,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? child,
    Border? innerBorder,
    bool isTablet = false,
    String? tooltip,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ringColor = isDark && color.computeLuminance() < 0.1
        ? Colors.white
        : color;
    final circleSize = isTablet ? 46.0 : 42.0;

    final swatch = Padding(
      padding: EdgeInsets.only(right: isTablet ? 12 : 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(circleSize / 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: circleSize,
          height: circleSize,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? ringColor : Colors.transparent,
              width: 2.2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: innerBorder,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: child ?? (isSelected
                ? Icon(
                    Icons.check,
                    size: isTablet ? 18 : 16,
                    color: color.computeLuminance() > 0.55 ? Colors.black : Colors.white,
                  )
                : null),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 250),
        child: swatch,
      );
    }
    return swatch;
  }

  // Botão circular de paleta (+ Outra cor)
  Widget _buildCustomPickerCircle({
    required BuildContext context,
    required bool isCustomSelected,
    required VoidCallback onTap,
    Color? activeCustomColor,
    bool isTablet = false,
    String? tooltip,
  }) {
    final circleSize = isTablet ? 46.0 : 42.0;
    final borderColor = isCustomSelected
        ? (activeCustomColor ?? Theme.of(context).colorScheme.primary)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.5);

    final picker = Padding(
      padding: EdgeInsets.only(right: isTablet ? 12 : 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(circleSize / 2),
        child: Container(
          width: circleSize,
          height: circleSize,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: isCustomSelected ? 2.2 : 1.2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isCustomSelected ? activeCustomColor : null,
              gradient: isCustomSelected
                  ? null
                  : const SweepGradient(
                      colors: [
                        Color(0xFFEF4444),
                        Color(0xFFF59E0B),
                        Color(0xFF10B981),
                        Color(0xFF0284C7),
                        Color(0xFF8B5CF6),
                        Color(0xFFEC4899),
                        Color(0xFFEF4444),
                      ],
                    ),
              shape: BoxShape.circle,
              boxShadow: [
                if (isCustomSelected && activeCustomColor != null)
                  BoxShadow(
                    color: activeCustomColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.colorize_rounded,
              size: isTablet ? 18 : 16,
              color: isCustomSelected && activeCustomColor != null
                  ? (activeCustomColor.computeLuminance() > 0.55 ? Colors.black : Colors.white)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 250),
        child: picker,
      );
    }
    return picker;
  }

  Widget _buildSectionHeader(BuildContext context, {required String title, String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewBadge(Color badgeColor, String number) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        number,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}
