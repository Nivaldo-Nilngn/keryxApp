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
///
/// Implementado seguindo as 10 Heurísticas de Usabilidade de Nielsen:
/// 1. Visibilidade do status (Pill com cor ativa mesmo recolhido + live preview)
/// 2. Correspondência com o mundo real (Metáforas claras de balão, texto e tipografia)
/// 3. Controle e liberdade do usuário (Cards minimizáveis / expansíveis + Restaurar padrões)
/// 4. Consistência e padrões (Cards com design unificado e tema Dark/Light)
/// 5. Prevenção de erros (Validação automática de contraste WCAG 2.1)
/// 6. Reconhecimento em vez de memorização (Amostras visuais de cores e fontes reais)
/// 7. Flexibilidade e eficiência (Atalhos de tamanho rápido 14/16/19/24/28px + Minimizar listas)
/// 8. Design estético e minimalista (Cores perfeitamente centralizadas, sem sobras na lateral)
/// 9. Auxílio no reconhecimento e recuperação de erros (Confirmação ao restaurar padrões)
/// 10. Ajuda e documentação (Legendas e tooltips explicativos em cada controle)
void showTextSettingsBottomSheet(BuildContext context, {bool isStrongVersion = false}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    builder: (ctx) => TextSettingsBottomSheet(isStrongVersion: isStrongVersion),
  );
}

class TextSettingsBottomSheet extends ConsumerStatefulWidget {
  final bool isStrongVersion;

  const TextSettingsBottomSheet({
    super.key,
    this.isStrongVersion = false,
  });

  @override
  ConsumerState<TextSettingsBottomSheet> createState() => _TextSettingsBottomSheetState();
}

class _TextSettingsBottomSheetState extends ConsumerState<TextSettingsBottomSheet> {
  // Controle de expansão/recolhimento das paletas de cores (todas minimizadas por padrão)
  bool _isBadgeColorsExpanded = false;
  bool _isTextColorsExpanded = false;
  bool _isStrongColorsExpanded = false;

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

  // Presets rápidos de tamanho de fonte para eficiência de uso
  static const List<Map<String, dynamic>> _fontSizePresets = [
    {'label': 'Pequeno', 'size': 14.0},
    {'label': 'Padrão', 'size': 16.0},
    {'label': 'Médio', 'size': 19.0},
    {'label': 'Grande', 'size': 24.0},
    {'label': 'Extra', 'size': 28.0},
  ];

  String _getBadgeColorLabel(int? value) {
    if (value == null) return 'Índigo';
    final match = _badgeColorPresets.firstWhere(
      (p) => p['value'] == value,
      orElse: () => {'label': 'Personalizada'},
    );
    return match['label'] as String;
  }

  String _getTextColorLabel(int? value, List<Map<String, dynamic>> presets) {
    if (value == null) return 'Auto';
    final match = presets.firstWhere(
      (p) => p['value'] == value,
      orElse: () => {'label': 'Personalizada'},
    );
    return match['label'] as String;
  }

  String _getStrongColorLabel(FontSettings settings, List<Map<String, dynamic>> presets) {
    if (settings.strongHighlightColor == 0) return 'Mesma cor';
    if (settings.strongHighlightColor == null) return 'Padrão';
    final match = presets.firstWhere(
      (p) => p['value'] == settings.strongHighlightColor,
      orElse: () => {'label': 'Personalizada'},
    );
    return match['label'] as String;
  }

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

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF222234)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.restart_alt_rounded, color: Color(0xFF4F46E5), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Restaurar Padrões?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Todas as fontes, cores e tamanhos voltarão para as configurações padrão originais.',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ref.read(fontSettingsProvider.notifier).resetToDefault();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Configurações originais restauradas!'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(
              'Restaurar',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
    final horizontalPadding = isTablet ? 32.0 : 18.0;

    // Itens de cores do Balão Numérico
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
          tooltip: preset['label'] as String?,
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
        tooltip: 'Outra cor de balão...',
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

    // Itens de cores do Texto da Bíblia
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
          tooltip: preset['label'] as String?,
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
        tooltip: 'Outra cor de texto...',
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
            const SizedBox(height: 8),

            // Cabeçalho da modal com Botão Restaurar e Fechar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isStrongVersion ? 'Configurações de Leitura & Strong' : 'Configurações de Leitura',
                          style: GoogleFonts.outfit(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          widget.isStrongVersion ? 'Ajuste fontes, cores e destaque Strong' : 'Ajuste fontes, cores de texto e balões',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Botão rápido para restaurar padrões no topo (Heurística #3 e #9)
                  IconButton(
                    icon: const Icon(Icons.restart_alt_rounded, size: 21),
                    tooltip: 'Restaurar padrões originais',
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    onPressed: () => _confirmReset(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: 'Fechar',
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ==========================================
            // PREVIEW FIXO NO TOPO (NÃO ROLA!)
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
              padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 12),
              child: Container(
                padding: const EdgeInsets.all(13),
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
                          widget.isStrongVersion ? Icons.auto_awesome : Icons.remove_red_eye_outlined,
                          size: 13,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isStrongVersion ? 'PRÉVIA • BÍBLIA STRONG' : 'PRÉVIA • TEXTO NORMAL',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                        if (isTablet && fontSettings.splitPage) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                const Icon(Icons.vertical_split_rounded, size: 9, color: Color(0xFF10B981)),
                                const SizedBox(width: 3),
                                Text(
                                  '2 Colunas',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
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
                    const SizedBox(height: 8),
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
                          if (widget.isStrongVersion) ...[
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
                            const TextSpan(text: 'No princípio, criou Deus os céus e a terra.'),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==========================================
            // CONTEÚDO SCROLLÁVEL
            // ==========================================
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 14, horizontalPadding, 24),
                physics: const BouncingScrollPhysics(),
                children: [
                  // Barra de Controle de Cores com Botão Minimizar / Expandir Todas
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'CORES E CONTRASTE',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            setState(() {
                              final anyExpanded = _isBadgeColorsExpanded ||
                                  _isTextColorsExpanded ||
                                  (widget.isStrongVersion && _isStrongColorsExpanded);
                              final target = !anyExpanded;
                              _isBadgeColorsExpanded = target;
                              _isTextColorsExpanded = target;
                              _isStrongColorsExpanded = target;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  (_isBadgeColorsExpanded || _isTextColorsExpanded)
                                      ? Icons.unfold_less_rounded
                                      : Icons.unfold_more_rounded,
                                  size: 13,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  (_isBadgeColorsExpanded || _isTextColorsExpanded)
                                      ? 'Recolher Cores'
                                      : 'Expandir Cores',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Cards de Cores (No tablet lado a lado, no celular empilhados)
                  if (isTablet) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildCollapsibleSectionCard(
                            context: context,
                            icon: Icons.tag_rounded,
                            title: 'COR DO BALÃO NUMÉRICO',
                            subtitle: 'Marcador do número do versículo',
                            isExpanded: _isBadgeColorsExpanded,
                            onToggle: () => setState(() => _isBadgeColorsExpanded = !_isBadgeColorsExpanded),
                            activeStatusWidget: _buildColorStatusPill(
                              context: context,
                              color: badgeColor,
                              label: _getBadgeColorLabel(fontSettings.badgeColor),
                            ),
                            expandedContent: _buildCenteredSwatchGrid(badgeSwatches, isTablet: true),
                            isDark: isDark,
                            cardBg: cardBg,
                            borderColor: borderColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildCollapsibleSectionCard(
                            context: context,
                            icon: Icons.format_color_text_rounded,
                            title: 'COR DO TEXTO DA BÍBLIA',
                            subtitle: isDark ? 'Modo Escuro (alto contraste)' : 'Modo Claro (alto contraste)',
                            isExpanded: _isTextColorsExpanded,
                            onToggle: () => setState(() => _isTextColorsExpanded = !_isTextColorsExpanded),
                            activeStatusWidget: _buildColorStatusPill(
                              context: context,
                              color: verseTextColor,
                              label: _getTextColorLabel(fontSettings.textColor, textColorPresets),
                              border: Border.all(color: isDark ? Colors.white30 : Colors.black26),
                            ),
                            expandedContent: _buildCenteredSwatchGrid(textSwatches, isTablet: true),
                            isDark: isDark,
                            cardBg: cardBg,
                            borderColor: borderColor,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Celular: Card do Balão Numérico
                    _buildCollapsibleSectionCard(
                      context: context,
                      icon: Icons.tag_rounded,
                      title: 'COR DO BALÃO NUMÉRICO',
                      subtitle: 'Marcador do número do versículo',
                      isExpanded: _isBadgeColorsExpanded,
                      onToggle: () => setState(() => _isBadgeColorsExpanded = !_isBadgeColorsExpanded),
                      activeStatusWidget: _buildColorStatusPill(
                        context: context,
                        color: badgeColor,
                        label: _getBadgeColorLabel(fontSettings.badgeColor),
                      ),
                      expandedContent: _buildCenteredSwatchGrid(badgeSwatches, isTablet: false),
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),

                    // Celular: Card da Cor do Texto
                    _buildCollapsibleSectionCard(
                      context: context,
                      icon: Icons.format_color_text_rounded,
                      title: 'COR DO TEXTO DA BÍBLIA',
                      subtitle: isDark ? 'Modo Escuro (alto contraste)' : 'Modo Claro (alto contraste)',
                      isExpanded: _isTextColorsExpanded,
                      onToggle: () => setState(() => _isTextColorsExpanded = !_isTextColorsExpanded),
                      activeStatusWidget: _buildColorStatusPill(
                        context: context,
                        color: verseTextColor,
                        label: _getTextColorLabel(fontSettings.textColor, textColorPresets),
                        border: Border.all(color: isDark ? Colors.white30 : Colors.black26),
                      ),
                      expandedContent: _buildCenteredSwatchGrid(textSwatches, isTablet: false),
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
                  ],

                  // Seção Bíblia Strong (Se ativa)
                  if (widget.isStrongVersion) ...[
                    ...(() {
                      final strongSwatches = <Widget>[
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

                      final strongActiveColor = isSameColorAsText
                          ? verseTextColor
                          : (fontSettings.strongHighlightColor != null
                              ? Color(fontSettings.strongHighlightColor!)
                              : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)));

                      return [
                        _buildCollapsibleSectionCard(
                          context: context,
                          icon: Icons.auto_awesome_rounded,
                          title: 'PALAVRAS COM DICIONÁRIO STRONG',
                          subtitle: isSameColorAsText
                              ? 'Texto uniforme (toque no Strong ativo)'
                              : 'Destaque visual ativo para hebraico/grego',
                          isExpanded: _isStrongColorsExpanded,
                          onToggle: () => setState(() => _isStrongColorsExpanded = !_isStrongColorsExpanded),
                          activeStatusWidget: _buildColorStatusPill(
                            context: context,
                            color: strongActiveColor,
                            label: _getStrongColorLabel(fontSettings, strongColorPresets),
                          ),
                          expandedContent: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCenteredSwatchGrid(strongSwatches, isTablet: isTablet),
                              const SizedBox(height: 12),
                              // Opções de sublinhado e negrito
                              Material(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: borderColor),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    SwitchListTile(
                                      dense: true,
                                      title: Text(
                                        'Sublinhar termos com Strong',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Exibe linha sutil para indicar termo clicável',
                                        style: GoogleFonts.outfit(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
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
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Aumenta o peso tipográfico das palavras com Strong',
                                        style: GoogleFonts.outfit(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
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
                          ),
                          isDark: isDark,
                          cardBg: cardBg,
                          borderColor: borderColor,
                        ),
                      ];
                    })(),
                  ],

                  const SizedBox(height: 4),

                  // Card de Tamanho do Texto (Com Slider e Presets Rápidos)
                  _buildFontSizeCard(
                    context: context,
                    fontSettings: fontSettings,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                  ),

                  // Card de Família da Fonte
                  _buildFontFamilyCard(
                    context: context,
                    fontSettings: fontSettings,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                  ),

                  // Card de Layout de Leitura (Dividir em 2 Colunas) - Ocultado no modo celular
                  if (isTablet) ...[
                    _buildLayoutCard(
                      context: context,
                      fontSettings: fontSettings,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Botão de Restaurar Padrões no Rodapé
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _confirmReset(context),
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
                  SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card expansível/minimizável para categorias de cores
  Widget _buildCollapsibleSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget activeStatusWidget,
    required Widget expandedContent,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? primaryColor.withValues(alpha: 0.35) : borderColor,
          width: isExpanded ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: isExpanded ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header clicável para expandir/minimizar
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: primaryColor, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  activeStatusWidget,
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(
                    height: 12,
                    thickness: 1,
                    color: borderColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  expandedContent,
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  /// Chip compacto exibindo a cor ativa atual mesmo com o card minimizado
  Widget _buildColorStatusPill({
    required BuildContext context,
    required Color color,
    required String label,
    Border? border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: border,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 85),
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Grid de swatches perfeitamente centralizado em telas de qualquer largura
  Widget _buildCenteredSwatchGrid(List<Widget> items, {bool isTablet = false}) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: isTablet ? 12.0 : 9.0,
        runSpacing: isTablet ? 12.0 : 9.0,
        children: items,
      ),
    );
  }

  /// Swatch circular individual sem padding unilateral (evita desalinhamento)
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
    final ringColor = isDark && color.computeLuminance() < 0.1 ? Colors.white : color;
    final circleSize = isTablet ? 44.0 : 40.0;

    final swatch = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(circleSize / 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: circleSize,
        height: circleSize,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? ringColor : Colors.transparent,
            width: isSelected ? 2.4 : 0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: ringColor.withValues(alpha: 0.45),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: innerBorder,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: child ??
              (isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: isTablet ? 18 : 16,
                      color: color.computeLuminance() > 0.55 ? Colors.black : Colors.white,
                    )
                  : null),
        ),
      ),
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 200),
        child: swatch,
      );
    }
    return swatch;
  }

  /// Botão circular de paleta (+ Outra cor personalizada)
  Widget _buildCustomPickerCircle({
    required BuildContext context,
    required bool isCustomSelected,
    required VoidCallback onTap,
    Color? activeCustomColor,
    bool isTablet = false,
    String? tooltip,
  }) {
    final circleSize = isTablet ? 44.0 : 40.0;
    final primary = Theme.of(context).colorScheme.primary;
    final borderColor = isCustomSelected
        ? (activeCustomColor ?? primary)
        : primary.withValues(alpha: 0.6);

    final picker = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(circleSize / 2),
      child: Container(
        width: circleSize,
        height: circleSize,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor,
            width: isCustomSelected ? 2.4 : 1.2,
          ),
          boxShadow: isCustomSelected && activeCustomColor != null
              ? [
                  BoxShadow(
                    color: activeCustomColor.withValues(alpha: 0.45),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
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
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.colorize_rounded,
            size: isTablet ? 17 : 15,
            color: isCustomSelected && activeCustomColor != null
                ? (activeCustomColor.computeLuminance() > 0.55 ? Colors.black : Colors.white)
                : Colors.white,
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 200),
        child: picker,
      );
    }
    return picker;
  }

  /// Card de Tamanho do Texto com Slider e Botões de Preset Rápido (14, 16, 19, 24, 28)
  Widget _buildFontSizeCard({
    required BuildContext context,
    required FontSettings fontSettings,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.format_size_rounded, color: primaryColor, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TAMANHO DO TEXTO',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Escala dos versículos e Léxico Strong',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${fontSettings.fontSize.toInt()} px',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                tooltip: 'Diminuir fonte',
                onPressed: fontSettings.fontSize > 12
                    ? () => ref.read(fontSettingsProvider.notifier).setFontSize(fontSettings.fontSize - 1)
                    : null,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: primaryColor,
                    inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                    thumbColor: primaryColor,
                    overlayColor: primaryColor.withValues(alpha: 0.15),
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
                icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                tooltip: 'Aumentar fonte',
                onPressed: fontSettings.fontSize < 36
                    ? () => ref.read(fontSettingsProvider.notifier).setFontSize(fontSettings.fontSize + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Presets rápidos em botões (Heurística #7)
          Row(
            children: _fontSizePresets.map((preset) {
              final size = preset['size'] as double;
              final label = preset['label'] as String;
              final isCurrent = (fontSettings.fontSize - size).abs() < 0.5;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: InkWell(
                    onTap: () => ref.read(fontSettingsProvider.notifier).setFontSize(size),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? primaryColor.withValues(alpha: 0.16)
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCurrent ? primaryColor : borderColor,
                          width: isCurrent ? 1.2 : 0.8,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${size.toInt()}px',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                              color: isCurrent ? primaryColor : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            label,
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              color: isCurrent
                                  ? primaryColor
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Card de Família da Fonte
  Widget _buildFontFamilyCard({
    required BuildContext context,
    required FontSettings fontSettings,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.font_download_rounded, color: primaryColor, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FAMÍLIA DA FONTE',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Selecione ou importe tipografias personalizadas',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fontSettings.fontFamily,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, size: 16, color: primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              'Importar',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? primaryColor : borderColor,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        family,
                        style: _getFontStyle(
                          family,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Card de Layout de Leitura (2 Colunas)
  Widget _buildLayoutCard({
    required BuildContext context,
    required FontSettings fontSettings,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile(
          dense: true,
          secondary: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.vertical_split_rounded,
              color: primaryColor,
              size: 18,
            ),
          ),
          title: Text(
            'Dividir página em dois (2 colunas)',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            'Exibe o texto bíblico lado a lado, estilo Bíblia impressa',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          activeThumbColor: primaryColor,
          value: fontSettings.splitPage,
          onChanged: (val) {
            ref.read(fontSettingsProvider.notifier).setSplitPage(val);
          },
        ),
      ),
    );
  }

  Widget _buildPreviewBadge(Color badgeColor, String number) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 25,
      height: 25,
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
