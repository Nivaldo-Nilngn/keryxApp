import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

enum WordTabletTab {
  home('Início'),
  insert('Inserir'),
  layout('Layout'),
  review('Revisão & Exibir');

  final String label;
  const WordTabletTab(this.label);
}

/// Faixa de Opções (Ribbon Toolbar) 100% nativa em Flutter para Tablets.
/// Inspirada no Microsoft Word com ergonomia para Touchscreen.
class WordTabletRibbonBar extends StatefulWidget {
  final quill.QuillController controller;
  final VoidCallback onInsertBibleVerse;
  final VoidCallback onOpenAiAssistant;
  final VoidCallback onInsertSermonOutline;
  final VoidCallback onInsertQuoteBox;
  final VoidCallback onInsertDivider;
  final VoidCallback onInsertDateTime;
  final VoidCallback onToggleViewMode;
  final bool isMobileView;
  final double currentZoom;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<Color> onChangePageColor;
  final VoidCallback onExportPdf;
  final VoidCallback onShare;
  final VoidCallback onQuickSave;
  final bool isSaving;

  const WordTabletRibbonBar({
    super.key,
    required this.controller,
    required this.onInsertBibleVerse,
    required this.onOpenAiAssistant,
    required this.onInsertSermonOutline,
    required this.onInsertQuoteBox,
    required this.onInsertDivider,
    required this.onInsertDateTime,
    required this.onToggleViewMode,
    required this.isMobileView,
    required this.currentZoom,
    required this.onZoomChanged,
    required this.onChangePageColor,
    required this.onExportPdf,
    required this.onShare,
    required this.onQuickSave,
    this.isSaving = false,
  });

  @override
  State<WordTabletRibbonBar> createState() => _WordTabletRibbonBarState();
}

class _WordTabletRibbonBarState extends State<WordTabletRibbonBar> {
  WordTabletTab _currentTab = WordTabletTab.home;
  bool _isCollapsed = false;

  String _currentFont = 'Calibri';
  int _currentFontSize = 12;

  final List<String> _fontFamilies = [
    'Calibri',
    'Roboto',
    'Merriweather',
    'Playfair Display',
    'Lora',
    'Inter',
    'Montserrat',
    'Outfit',
    'Caveat',
  ];

  final List<int> _fontSizes = [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48];

  @override
  void initState() {
    super.initState();
    _updateStateFromSelection();
    widget.controller.addListener(_updateStateFromSelection);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateStateFromSelection);
    super.dispose();
  }

  void _updateStateFromSelection() {
    if (!mounted) return;
    final attrs = widget.controller.getSelectionStyle().attributes;
    final sizeVal = attrs[quill.Attribute.size.key]?.value;
    int size = 12;
    if (sizeVal is String) {
      size = int.tryParse(sizeVal) ?? 12;
    } else if (sizeVal is int) {
      size = sizeVal;
    }

    final fontVal = attrs[quill.Attribute.font.key]?.value;
    String font = 'Calibri';
    if (fontVal is String && fontVal.isNotEmpty) {
      font = fontVal;
    }

    if (size != _currentFontSize || font != _currentFont) {
      setState(() {
        _currentFontSize = size;
        _currentFont = font;
      });
    }
  }

  void _applyFont(String font) {
    setState(() => _currentFont = font);
    widget.controller.formatSelection(quill.FontAttribute(font));
  }

  void _applyFontSize(int size) {
    final clamped = size.clamp(6, 72);
    setState(() => _currentFontSize = clamped);
    widget.controller.formatSelection(quill.SizeAttribute('$clamped'));
  }

  void _applyTextColor(Color color) {
    final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    widget.controller.formatSelection(quill.ColorAttribute(hex));
  }

  void _applyHighlightColor(Color? color) {
    if (color == null) {
      widget.controller.formatSelection(quill.BackgroundAttribute('#00000000'));
    } else {
      final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      widget.controller.formatSelection(quill.BackgroundAttribute(hex));
    }
  }

  void _clearFormatting() {
    widget.controller.formatSelection(quill.Attribute.clone(quill.Attribute.bold, null));
    widget.controller.formatSelection(quill.Attribute.clone(quill.Attribute.italic, null));
    widget.controller.formatSelection(quill.Attribute.clone(quill.Attribute.underline, null));
    widget.controller.formatSelection(quill.Attribute.clone(quill.Attribute.strikeThrough, null));
    widget.controller.formatSelection(quill.Attribute.clone(quill.Attribute.color, null));
    widget.controller.formatSelection(quill.Attribute.clone(quill.Attribute.background, null));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ribbonBg = isDark ? const Color(0xFF1E1E2D) : const Color(0xFFF3F5F9);
    final headerBg = isDark ? const Color(0xFF181824) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ribbonBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Tab Strip (Abas no topo) ──────────────────────────────────
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: headerBg,
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                // Botões de cada Guia
                ...WordTabletTab.values.map((tab) {
                  final isSelected = tab == _currentTab;
                  return _RibbonTabButton(
                    label: tab.label,
                    isSelected: isSelected,
                    onTap: () {
                      if (_isCollapsed) {
                        setState(() {
                          _currentTab = tab;
                          _isCollapsed = false;
                        });
                      } else {
                        setState(() => _currentTab = tab);
                      }
                    },
                  );
                }),

                const Spacer(),

                // Botão de Recolher / Expandir Ribbon
                IconButton(
                  icon: Icon(
                    _isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    size: 20,
                  ),
                  tooltip: _isCollapsed ? 'Expandir Faixa de Opções' : 'Recolher Faixa de Opções',
                  color: isDark ? Colors.white70 : Colors.black54,
                  onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),

          // ── 2. Ribbon Body (Painel de Ferramentas) ─────────────────────────
          if (!_isCollapsed)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 104,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildActiveTabContent(context, borderColor),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(BuildContext context, Color borderColor) {
    switch (_currentTab) {
      case WordTabletTab.home:
        return _buildHomeTab(context, borderColor);
      case WordTabletTab.insert:
        return _buildInsertTab(context, borderColor);
      case WordTabletTab.layout:
        return _buildLayoutTab(context, borderColor);
      case WordTabletTab.review:
        return _buildReviewTab(context, borderColor);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GUIA 1: INÍCIO (Home)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHomeTab(BuildContext context, Color borderColor) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final attrs = widget.controller.getSelectionStyle().attributes;
        final isBold = attrs.containsKey(quill.Attribute.bold.key);
        final isItalic = attrs.containsKey(quill.Attribute.italic.key);
        final isUnderline = attrs.containsKey(quill.Attribute.underline.key);
        final isStrike = attrs.containsKey(quill.Attribute.strikeThrough.key);

        final alignAttr = attrs[quill.Attribute.align.key]?.value;
        final isLeft = alignAttr == null || alignAttr == 'left';
        final isCenter = alignAttr == 'center';
        final isRight = alignAttr == 'right';
        final isJustify = alignAttr == 'justify';

        final listAttr = attrs[quill.Attribute.list.key]?.value;
        final isBullet = listAttr == quill.Attribute.ul.value;
        final isNumber = listAttr == quill.Attribute.ol.value;
        final isQuote = attrs.containsKey(quill.Attribute.blockQuote.key);

        final headerAttr = attrs[quill.Attribute.header.key]?.value;
        final isH1 = headerAttr == 1;
        final isH2 = headerAttr == 2;
        final isNormal = headerAttr == null;

        // Cor de texto ativa
        Color activeTextColor = Colors.black87;
        final colorVal = attrs[quill.Attribute.color.key]?.value;
        if (colorVal is String && colorVal.startsWith('#')) {
          try {
            final hex = colorVal.replaceAll('#', '');
            activeTextColor = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
          } catch (_) {}
        }

        // Cor de realce ativa
        Color? activeHighlightColor;
        final bgVal = attrs[quill.Attribute.background.key]?.value;
        if (bgVal is String && bgVal.startsWith('#') && bgVal != '#00000000') {
          try {
            final hex = bgVal.replaceAll('#', '');
            activeHighlightColor = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
          } catch (_) {}
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Grupo: Área de Transferência ──
            _RibbonGroup(
              label: 'Área de transferência',
              borderColor: borderColor,
              child: Row(
                children: [
                  _BigToolButton(
                    icon: Icons.content_paste_rounded,
                    label: 'Colar',
                    onTap: () {
                      // Simula colagem ou abre caixa de diálogo de cola
                      _pasteClipboard();
                    },
                  ),
                  const SizedBox(width: 4),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SmallToolButton(
                        icon: Icons.copy_rounded,
                        tooltip: 'Copiar Texto',
                        onTap: () {
                          final text = widget.controller.getPlainText();
                          if (text.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Texto copiado para a área de transferência!'), duration: Duration(seconds: 1)),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                      _SmallToolButton(
                        icon: Icons.format_paint_rounded,
                        tooltip: 'Limpar Formatação',
                        onTap: _clearFormatting,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Grupo: Fonte ──
            _RibbonGroup(
              label: 'Fonte',
              borderColor: borderColor,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha superior: Seletor de Família + Seletor de Tamanho + A+ / A-
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Seletor de Família
                      _FontDropdown(
                        currentFont: _currentFont,
                        fonts: _fontFamilies,
                        onChanged: _applyFont,
                      ),
                      const SizedBox(width: 6),
                      // Seletor de Tamanho
                      _FontSizeDropdown(
                        currentSize: _currentFontSize,
                        sizes: _fontSizes,
                        onChanged: _applyFontSize,
                      ),
                      const SizedBox(width: 4),
                      _SmallToolButton(
                        label: 'A+',
                        tooltip: 'Aumentar Tamanho da Fonte',
                        onTap: () => _applyFontSize(_currentFontSize + 2),
                      ),
                      const SizedBox(width: 2),
                      _SmallToolButton(
                        label: 'A-',
                        tooltip: 'Diminuir Tamanho da Fonte',
                        onTap: () => _applyFontSize(_currentFontSize - 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Linha inferior: B, I, U, S, Cor do Texto, Realce
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ToggleToolButton(
                        label: 'N',
                        isBoldText: true,
                        tooltip: 'Negrito (Ctrl+B)',
                        isActive: isBold,
                        onTap: () {
                          widget.controller.formatSelection(
                            isBold ? quill.Attribute.clone(quill.Attribute.bold, null) : quill.Attribute.bold,
                          );
                        },
                      ),
                      const SizedBox(width: 3),
                      _ToggleToolButton(
                        label: 'I',
                        isItalicText: true,
                        tooltip: 'Itálico (Ctrl+I)',
                        isActive: isItalic,
                        onTap: () {
                          widget.controller.formatSelection(
                            isItalic ? quill.Attribute.clone(quill.Attribute.italic, null) : quill.Attribute.italic,
                          );
                        },
                      ),
                      const SizedBox(width: 3),
                      _ToggleToolButton(
                        label: 'S',
                        isUnderlineText: true,
                        tooltip: 'Sublinhado (Ctrl+U)',
                        isActive: isUnderline,
                        onTap: () {
                          widget.controller.formatSelection(
                            isUnderline ? quill.Attribute.clone(quill.Attribute.underline, null) : quill.Attribute.underline,
                          );
                        },
                      ),
                      const SizedBox(width: 3),
                      _ToggleToolButton(
                        label: 'abc',
                        isStrikeText: true,
                        tooltip: 'Tachado',
                        isActive: isStrike,
                        onTap: () {
                          widget.controller.formatSelection(
                            isStrike ? quill.Attribute.clone(quill.Attribute.strikeThrough, null) : quill.Attribute.strikeThrough,
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      // Cor do Texto
                      _ColorPickerButton(
                        icon: Icons.format_color_text_rounded,
                        tooltip: 'Cor da Fonte',
                        indicatorColor: activeTextColor,
                        onColorSelected: _applyTextColor,
                      ),
                      const SizedBox(width: 3),
                      // Marca-texto
                      _HighlightPickerButton(
                        icon: Icons.border_color_rounded,
                        tooltip: 'Cor do Realce do Texto',
                        indicatorColor: activeHighlightColor,
                        onColorSelected: _applyHighlightColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Grupo: Parágrafo ──
            _RibbonGroup(
              label: 'Parágrafo',
              borderColor: borderColor,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alinhamentos
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ToggleToolButton(
                        icon: Icons.format_align_left_rounded,
                        tooltip: 'Alinhar à Esquerda',
                        isActive: isLeft,
                        onTap: () => widget.controller.formatSelection(quill.Attribute.leftAlignment),
                      ),
                      const SizedBox(width: 3),
                      _ToggleToolButton(
                        icon: Icons.format_align_center_rounded,
                        tooltip: 'Centralizar',
                        isActive: isCenter,
                        onTap: () => widget.controller.formatSelection(quill.Attribute.centerAlignment),
                      ),
                      const SizedBox(width: 3),
                      _ToggleToolButton(
                        icon: Icons.format_align_right_rounded,
                        tooltip: 'Alinhar à Direita',
                        isActive: isRight,
                        onTap: () => widget.controller.formatSelection(quill.Attribute.rightAlignment),
                      ),
                      const SizedBox(width: 3),
                      _ToggleToolButton(
                        icon: Icons.format_align_justify_rounded,
                        tooltip: 'Justificar',
                        isActive: isJustify,
                        onTap: () => widget.controller.formatSelection(quill.Attribute.justifyAlignment),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Listas e Citação
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ToggleToolButton(
                        icon: Icons.format_list_bulleted_rounded,
                        tooltip: 'Marcadores',
                        isActive: isBullet,
                        onTap: () {
                          widget.controller.formatSelection(
                            isBullet ? quill.Attribute.clone(quill.Attribute.ul, null) : quill.Attribute.ul,
                          );
                        },
                      ),
                      const SizedBox(width: 3),
                      _ToggleToolButton(
                        icon: Icons.format_list_numbered_rounded,
                        tooltip: 'Numeração',
                        isActive: isNumber,
                        onTap: () {
                          widget.controller.formatSelection(
                            isNumber ? quill.Attribute.clone(quill.Attribute.ol, null) : quill.Attribute.ol,
                          );
                        },
                      ),
                      const SizedBox(width: 3),
                      _ToggleToolButton(
                        icon: Icons.format_quote_rounded,
                        tooltip: 'Citação / Destaque',
                        isActive: isQuote,
                        onTap: () {
                          widget.controller.formatSelection(
                            isQuote ? quill.Attribute.clone(quill.Attribute.blockQuote, null) : quill.Attribute.blockQuote,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Grupo: Estilos Rápidos ──
            _RibbonGroup(
              label: 'Estilos',
              borderColor: borderColor,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StylePill(
                    label: 'Normal',
                    sampleStyle: const TextStyle(fontSize: 12),
                    isSelected: isNormal,
                    onTap: () {
                      widget.controller.formatSelection(quill.Attribute.clone(quill.Attribute.header, null));
                    },
                  ),
                  const SizedBox(width: 6),
                  _StylePill(
                    label: 'Título 1',
                    sampleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2B47B5)),
                    isSelected: isH1,
                    onTap: () {
                      widget.controller.formatSelection(quill.Attribute.h1);
                    },
                  ),
                  const SizedBox(width: 6),
                  _StylePill(
                    label: 'Título 2',
                    sampleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2B47B5)),
                    isSelected: isH2,
                    onTap: () {
                      widget.controller.formatSelection(quill.Attribute.h2);
                    },
                  ),
                ],
              ),
            ),

            // ── Grupo: Recursos Especiais ──
            _RibbonGroup(
              label: 'Ferramentas',
              borderColor: borderColor,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BigToolButton(
                    icon: Icons.auto_stories_rounded,
                    label: 'Versículo',
                    highlightColor: const Color(0xFF107C41),
                    onTap: widget.onInsertBibleVerse,
                  ),
                  const SizedBox(width: 6),
                  _BigToolButton(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Copilot IA',
                    highlightColor: const Color(0xFF8E8CD8),
                    onTap: widget.onOpenAiAssistant,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GUIA 2: INSERIR (Insert)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildInsertTab(BuildContext context, Color borderColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RibbonGroup(
          label: 'Bíblia & Estudos',
          borderColor: borderColor,
          child: Row(
            children: [
              _BigToolButton(
                icon: Icons.auto_stories_rounded,
                label: 'Versículo Bíblico',
                highlightColor: const Color(0xFF107C41),
                onTap: widget.onInsertBibleVerse,
              ),
              const SizedBox(width: 8),
              _BigToolButton(
                icon: Icons.edit_note_rounded,
                label: 'Esboço de Sermão',
                highlightColor: const Color(0xFF2B47B5),
                onTap: widget.onInsertSermonOutline,
              ),
              const SizedBox(width: 8),
              _BigToolButton(
                icon: Icons.auto_awesome_rounded,
                label: 'Assistente IA',
                highlightColor: const Color(0xFF8E8CD8),
                onTap: widget.onOpenAiAssistant,
              ),
            ],
          ),
        ),

        _RibbonGroup(
          label: 'Elementos do Documento',
          borderColor: borderColor,
          child: Row(
            children: [
              _BigToolButton(
                icon: Icons.format_quote_rounded,
                label: 'Caixa Citação',
                onTap: widget.onInsertQuoteBox,
              ),
              const SizedBox(width: 8),
              _BigToolButton(
                icon: Icons.horizontal_rule_rounded,
                label: 'Linha Divisória',
                onTap: widget.onInsertDivider,
              ),
              const SizedBox(width: 8),
              _BigToolButton(
                icon: Icons.access_time_rounded,
                label: 'Data e Hora',
                onTap: widget.onInsertDateTime,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GUIA 3: LAYOUT (Page Setup)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildLayoutTab(BuildContext context, Color borderColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RibbonGroup(
          label: 'Modo de Visualização',
          borderColor: borderColor,
          child: Row(
            children: [
              _BigToolButton(
                icon: widget.isMobileView ? Icons.menu_book_rounded : Icons.description_rounded,
                label: widget.isMobileView ? 'Modo Fluxo' : 'Folha A4 Contínua',
                isActive: !widget.isMobileView,
                onTap: widget.onToggleViewMode,
              ),
            ],
          ),
        ),

        _RibbonGroup(
          label: 'Cor do Papel',
          borderColor: borderColor,
          child: Row(
            children: [
              _PaperColorSample(
                name: 'Branco A4',
                color: Colors.white,
                borderColor: Colors.black26,
                onTap: () => widget.onChangePageColor(Colors.white),
              ),
              const SizedBox(width: 8),
              _PaperColorSample(
                name: 'Creme',
                color: const Color(0xFFFBF8EE),
                borderColor: Colors.black26,
                onTap: () => widget.onChangePageColor(const Color(0xFFFBF8EE)),
              ),
              const SizedBox(width: 8),
              _PaperColorSample(
                name: 'Sépia',
                color: const Color(0xFFF4ECD8),
                borderColor: Colors.black26,
                onTap: () => widget.onChangePageColor(const Color(0xFFF4ECD8)),
              ),
              const SizedBox(width: 8),
              _PaperColorSample(
                name: 'Noturno',
                color: const Color(0xFF1E1E28),
                borderColor: Colors.white30,
                onTap: () => widget.onChangePageColor(const Color(0xFF1E1E28)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GUIA 4: REVISÃO & EXIBIR (Review & View)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildReviewTab(BuildContext context, Color borderColor) {
    final text = widget.controller.getPlainText();
    final wordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    final charCount = text.replaceAll('\n', '').length;
    final readTimeMin = (wordCount / 180).ceil();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RibbonGroup(
          label: 'Zoom da Página',
          borderColor: borderColor,
          child: Row(
            children: [
              _SmallToolButton(
                icon: Icons.zoom_out_rounded,
                tooltip: 'Diminuir Zoom',
                onTap: () => widget.onZoomChanged((widget.currentZoom - 0.1).clamp(0.6, 2.0)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '${(widget.currentZoom * 100).round()}%',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              _SmallToolButton(
                icon: Icons.zoom_in_rounded,
                tooltip: 'Aumentar Zoom',
                onTap: () => widget.onZoomChanged((widget.currentZoom + 0.1).clamp(0.6, 2.0)),
              ),
              const SizedBox(width: 6),
              _SmallToolButton(
                label: '100%',
                tooltip: 'Zoom Padrão',
                onTap: () => widget.onZoomChanged(1.0),
              ),
            ],
          ),
        ),

        _RibbonGroup(
          label: 'Estatísticas',
          borderColor: borderColor,
          child: Row(
            children: [
              _StatItem(label: 'Palavras', value: '$wordCount'),
              const SizedBox(width: 12),
              _StatItem(label: 'Caracteres', value: '$charCount'),
              const SizedBox(width: 12),
              _StatItem(label: 'Leitura', value: '~$readTimeMin min'),
            ],
          ),
        ),

        _RibbonGroup(
          label: 'Exportar & Compartilhar',
          borderColor: borderColor,
          child: Row(
            children: [
              _BigToolButton(
                icon: Icons.picture_as_pdf_rounded,
                label: 'Exportar PDF',
                highlightColor: Colors.redAccent,
                onTap: widget.onExportPdf,
              ),
              const SizedBox(width: 8),
              _BigToolButton(
                icon: Icons.share_rounded,
                label: 'Compartilhar',
                highlightColor: const Color(0xFF2B47B5),
                onTap: widget.onShare,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _pasteClipboard() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pressione na folha e toque em Colar (ou use Ctrl+V / Cmd+V)'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES DA BARRA RIBBON
// ─────────────────────────────────────────────────────────────────────────────

class _RibbonTabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RibbonTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF1E1E2D) : const Color(0xFFF3F5F9)) : Colors.transparent,
          border: isSelected
              ? Border(
                  top: const BorderSide(color: Color(0xFF2B47B5), width: 3),
                  left: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1),
                  right: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1),
                )
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF2B47B5)
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}

class _RibbonGroup extends StatelessWidget {
  final String label;
  final Widget child;
  final Color borderColor;

  const _RibbonGroup({
    required this.label,
    required this.child,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Center(child: child)),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 9,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? highlightColor;
  final bool isActive;

  const _BigToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlightColor,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = highlightColor ?? (isActive ? const Color(0xFF2B47B5) : (isDark ? Colors.white70 : Colors.black87));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2B47B5).withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive ? Border.all(color: const Color(0xFF2B47B5).withValues(alpha: 0.3)) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallToolButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;

  const _SmallToolButton({
    this.icon,
    this.label,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(4),
          ),
          child: icon != null
              ? Icon(icon, size: 16, color: isDark ? Colors.white70 : Colors.black87)
              : Text(
                  label ?? '',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ToggleToolButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final bool isBoldText;
  final bool isItalicText;
  final bool isUnderlineText;
  final bool isStrikeText;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleToolButton({
    this.icon,
    this.label,
    this.isBoldText = false,
    this.isItalicText = false,
    this.isUnderlineText = false,
    this.isStrikeText = false,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = const Color(0xFF2B47B5).withValues(alpha: 0.18);
    final activeBorder = const Color(0xFF2B47B5);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive ? activeBorder : (isDark ? Colors.white12 : Colors.black12),
              width: 1,
            ),
          ),
          child: icon != null
              ? Icon(
                  icon,
                  size: 16,
                  color: isActive ? const Color(0xFF2B47B5) : (isDark ? Colors.white70 : Colors.black87),
                )
              : Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isBoldText ? FontWeight.bold : FontWeight.normal,
                    fontStyle: isItalicText ? FontStyle.italic : FontStyle.normal,
                    decoration: isUnderlineText
                        ? TextDecoration.underline
                        : (isStrikeText ? TextDecoration.lineThrough : null),
                    color: isActive ? const Color(0xFF2B47B5) : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
        ),
      ),
    );
  }
}

class _FontDropdown extends StatelessWidget {
  final String currentFont;
  final List<String> fonts;
  final ValueChanged<String> onChanged;

  const _FontDropdown({
    required this.currentFont,
    required this.fonts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: fonts.contains(currentFont) ? currentFont : fonts.first,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
          items: fonts.map((f) {
            return DropdownMenuItem<String>(
              value: f,
              child: Text(
                f,
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

class _FontSizeDropdown extends StatelessWidget {
  final int currentSize;
  final List<int> sizes;
  final ValueChanged<int> onChanged;

  const _FontSizeDropdown({
    required this.currentSize,
    required this.sizes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: sizes.contains(currentSize) ? currentSize : 12,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 16),
          items: sizes.map((s) {
            return DropdownMenuItem<int>(
              value: s,
              child: Text(
                '$s',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

class _ColorPickerButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color indicatorColor;
  final ValueChanged<Color> onColorSelected;

  const _ColorPickerButton({
    required this.icon,
    required this.tooltip,
    required this.indicatorColor,
    required this.onColorSelected,
  });

  static const List<Color> _palette = [
    Colors.black,
    Color(0xFF2B47B5),
    Color(0xFF107C41),
    Color(0xFFD83B01),
    Color(0xFF8E8CD8),
    Color(0xFFD4AF37),
    Color(0xFF5C2D91),
    Colors.grey,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<Color>(
      tooltip: tooltip,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (ctx) {
        return [
          PopupMenuItem<Color>(
            enabled: false,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _palette.map((c) {
                return InkWell(
                  onTap: () {
                    onColorSelected(c);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ];
      },
      child: Container(
        width: 32,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.white70 : Colors.black87),
            const SizedBox(height: 1),
            Container(
              width: 16,
              height: 3,
              color: indicatorColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightPickerButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? indicatorColor;
  final ValueChanged<Color?> onColorSelected;

  const _HighlightPickerButton({
    required this.icon,
    required this.tooltip,
    required this.indicatorColor,
    required this.onColorSelected,
  });

  static const List<Color> _highlightPalette = [
    Color(0xFFFFF176), // Amarelo
    Color(0xFFAED581), // Verde claro
    Color(0xFF81D4FA), // Azul claro
    Color(0xFFFF8A80), // Rosa / Vermelho
    Color(0xFFFFB74D), // Laranja
    Color(0xFFCE93D8), // Roxo
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<Color?>(
      tooltip: tooltip,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (ctx) {
        return [
          PopupMenuItem<Color?>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _highlightPalette.map((c) {
                    return InkWell(
                      onTap: () {
                        onColorSelected(c);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.black26),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    onColorSelected(null);
                    Navigator.pop(ctx);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.format_color_reset_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Sem Cores', style: GoogleFonts.outfit(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      },
      child: Container(
        width: 32,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.white70 : Colors.black87),
            const SizedBox(height: 1),
            Container(
              width: 16,
              height: 3,
              color: indicatorColor ?? Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class _StylePill extends StatelessWidget {
  final String label;
  final TextStyle sampleStyle;
  final bool isSelected;
  final VoidCallback onTap;

  const _StylePill({
    required this.label,
    required this.sampleStyle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2B47B5).withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF2B47B5) : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(label, style: sampleStyle),
      ),
    );
  }
}

class _PaperColorSample extends StatelessWidget {
  final String name;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;

  const _PaperColorSample({
    required this.name,
    required this.color,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              name,
              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2B47B5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }
}
