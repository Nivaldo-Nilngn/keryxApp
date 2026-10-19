import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/utils/keryx_color_contrast.dart';

/// Abre um seletor de cores visual completo, moderno e inteligente conforme o tema
Future<Color?> showKeryxColorPicker({
  required BuildContext context,
  required Color initialColor,
  String title = 'Selecionar Cor',
  bool isTextColor = false,
  Color? referenceBackgroundColor,
}) async {
  return showDialog<Color>(
    context: context,
    builder: (ctx) => _KeryxColorPickerDialog(
      initialColor: initialColor,
      title: title,
      isTextColor: isTextColor,
      referenceBackgroundColor: referenceBackgroundColor,
    ),
  );
}

class _KeryxColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String title;
  final bool isTextColor;
  final Color? referenceBackgroundColor;

  const _KeryxColorPickerDialog({
    required this.initialColor,
    required this.title,
    this.isTextColor = false,
    this.referenceBackgroundColor,
  });

  @override
  State<_KeryxColorPickerDialog> createState() => _KeryxColorPickerDialogState();
}

class _KeryxColorPickerDialogState extends State<_KeryxColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  late TextEditingController _hexController;

  static const List<Color> _generalQuickPalette = [
    Color(0xFF4F46E5), // Indigo Keryx
    Color(0xFF2563EB), // Azul Real
    Color(0xFF0284C7), // Azul Celeste
    Color(0xFF0D9488), // Verde Petróleo
    Color(0xFF10B981), // Esmeralda
    Color(0xFF84CC16), // Verde Lima
    Color(0xFFEAB308), // Ouro / Âmbar
    Color(0xFFF97316), // Laranja
    Color(0xFFEF4444), // Vermelho
    Color(0xFFE11D48), // Rosa Carmim
    Color(0xFF9333EA), // Roxo
    Color(0xFF7C3AED), // Violeta
    Color(0xFFD4AF37), // Dourado Bíblico
    Color(0xFF475569), // Grafite
  ];

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _hexController = TextEditingController(text: _colorToHex(_currentColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _currentColor {
    return HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
  }

  String _colorToHex(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  }

  void _updateFromHex(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) {
        final c = Color(val);
        final hsv = HSVColor.fromColor(c);
        setState(() {
          _hue = hsv.hue;
          _saturation = hsv.saturation;
          _value = hsv.value;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final cardBg = isDark ? const Color(0xFF28283E) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);
    final curColor = _currentColor;

    // Fundo de referência e avaliação de contraste (WCAG 2.1)
    final refBg = widget.referenceBackgroundColor ?? (isDark ? const Color(0xFF0F0F1E) : Colors.white);
    final contrastRatio = KeryxColorContrast.getContrastRatio(curColor, refBg);
    final isContrastOk = contrastRatio >= KeryxColorContrast.minContrastBodyText;

    // Paleta rápida adaptada ao tema se for para texto
    final quickColors = widget.isTextColor
        ? (isDark
            ? KeryxColorContrast.darkTextPresets.where((p) => p['color'] != null).map((p) => p['color'] as Color).toList()
            : KeryxColorContrast.lightTextPresets.where((p) => p['color'] != null).map((p) => p['color'] as Color).toList())
        : _generalQuickPalette;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: curColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: curColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          widget.isTextColor
                              ? (isDark ? 'Cores adaptadas para modo escuro' : 'Cores adaptadas para modo claro')
                              : 'Toque ou arraste para escolher o tom',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ==========================================
              // BADGE INTELIGENTE DE CONTRASTE WCAG 2.1
              // ==========================================
              if (widget.isTextColor) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isContrastOk
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isContrastOk
                          ? const Color(0xFF10B981).withValues(alpha: 0.35)
                          : const Color(0xFFEF4444).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isContrastOk ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                        size: 16,
                        color: isContrastOk ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isContrastOk
                              ? 'Contraste excelente (${contrastRatio.toStringAsFixed(1)}:1 - WCAG AA)'
                              : 'Contraste baixo (${contrastRatio.toStringAsFixed(1)}:1) • Ilegível no tema ${isDark ? "escuro" : "claro"}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isContrastOk ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                      if (!isContrastOk) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            final better = KeryxColorContrast.suggestReadableAlternative(curColor, isDark);
                            final hsv = HSVColor.fromColor(better);
                            setState(() {
                              _hue = hsv.hue;
                              _saturation = hsv.saturation;
                              _value = hsv.value;
                              _hexController.text = _colorToHex(better);
                            });
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Ajustar',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 1. Área 2D: Saturação x Brilho (Value)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 170,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;

                      void handleTouch(Offset localPosition) {
                        final dx = localPosition.dx.clamp(0.0, width);
                        final dy = localPosition.dy.clamp(0.0, height);
                        setState(() {
                          _saturation = dx / width;
                          _value = 1.0 - (dy / height);
                          _hexController.text = _colorToHex(_currentColor);
                        });
                      }

                      final thumbX = (_saturation * width).clamp(8.0, width - 8.0);
                      final thumbY = ((1.0 - _value) * height).clamp(8.0, height - 8.0);

                      return GestureDetector(
                        onPanDown: (details) => handleTouch(details.localPosition),
                        onPanUpdate: (details) => handleTouch(details.localPosition),
                        child: Stack(
                          children: [
                            // Fundo da Matiz (Hue)
                            Container(
                              color: HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor(),
                            ),
                            // Gradiente Branco -> Transparente (Saturação horizontal)
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [Colors.white, Colors.transparent],
                                ),
                              ),
                            ),
                            // Gradiente Transparente -> Preto (Brilho vertical)
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black],
                                ),
                              ),
                            ),
                            // Cursor indicador
                            Positioned(
                              left: thumbX - 10,
                              top: thumbY - 10,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: curColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Barra de Matiz (Rainbow Hue Slider)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 26,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      void handleHueTouch(Offset localPosition) {
                        final dx = localPosition.dx.clamp(0.0, width);
                        setState(() {
                          _hue = (dx / width) * 360.0;
                          _hexController.text = _colorToHex(_currentColor);
                        });
                      }

                      final thumbX = ((_hue / 360.0) * width).clamp(7.0, width - 7.0);

                      return GestureDetector(
                        onPanDown: (details) => handleHueTouch(details.localPosition),
                        onPanUpdate: (details) => handleHueTouch(details.localPosition),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFF0000),
                                    Color(0xFFFFFF00),
                                    Color(0xFF00FF00),
                                    Color(0xFF00FFFF),
                                    Color(0xFF0000FF),
                                    Color(0xFFFF00FF),
                                    Color(0xFFFF0000),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: thumbX - 8,
                              child: Container(
                                width: 16,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Campo HEX + Valores RGB
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Text(
                      'HEX',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _hexController,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: _updateFromHex,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: curColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'R:${(curColor.r * 255).round()} G:${(curColor.g * 255).round()} B:${(curColor.b * 255).round()}',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Paleta rápida de sugestões adaptada
              Text(
                widget.isTextColor ? 'CORES LEGÍVEIS SUGERIDAS' : 'CORES SUGERIDAS',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quickColors.map((c) {
                  final isSelected = c.toARGB32() == curColor.toARGB32();
                  return InkWell(
                    onTap: () {
                      final hsv = HSVColor.fromColor(c);
                      setState(() {
                        _hue = hsv.hue;
                        _saturation = hsv.saturation;
                        _value = hsv.value;
                        _hexController.text = _colorToHex(c);
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.black.withValues(alpha: 0.15),
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Botões Cancelar e Confirmar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: borderColor),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isTextColor && !isContrastOk
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        // Se o contraste for insuficiente para texto, auto-ajusta para garantir legibilidade
                        if (widget.isTextColor && !isContrastOk) {
                          final safeColor = KeryxColorContrast.suggestReadableAlternative(curColor, isDark);
                          Navigator.pop(context, safeColor);
                        } else {
                          Navigator.pop(context, curColor);
                        }
                      },
                      child: Text(
                        widget.isTextColor && !isContrastOk ? 'Aplicar Ajustado' : 'Confirmar',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
