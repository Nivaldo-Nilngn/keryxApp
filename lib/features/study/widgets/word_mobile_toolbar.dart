import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'word_mobile_theme.dart';

enum WordRibbonTab {
  home('Início'),
  insert('Inserir'),
  layout('Layout'),
  review('Revisão');

  final String label;
  const WordRibbonTab(this.label);
}

/// Barra de Ferramentas Rápida do Microsoft Word Mobile (docked sobre o teclado)
class WordMobileQuickToolbar extends StatelessWidget {
  final quill.QuillController controller;
  final bool isRibbonOpen;
  final VoidCallback onToggleRibbon;
  final VoidCallback onInsertBibleVerse;
  final VoidCallback onOpenAiAssistant;
  final Function(Color) onSelectFontColor;
  final Function(Color?) onSelectHighlight;

  const WordMobileQuickToolbar({
    super.key,
    required this.controller,
    required this.isRibbonOpen,
    required this.onToggleRibbon,
    required this.onInsertBibleVerse,
    required this.onOpenAiAssistant,
    required this.onSelectFontColor,
    required this.onSelectHighlight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? WordMobileTheme.toolbarBgDark : WordMobileTheme.toolbarBgLight;
    final border = isDark ? WordMobileTheme.borderDark : WordMobileTheme.borderLight;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final attrs = controller.getSelectionStyle().attributes;
        final isBold = attrs.containsKey(quill.Attribute.bold.key);
        final isItalic = attrs.containsKey(quill.Attribute.italic.key);
        final isUnderline = attrs.containsKey(quill.Attribute.underline.key);
        final isStrike = attrs.containsKey(quill.Attribute.strikeThrough.key);
        final isBullet = attrs[quill.Attribute.list.key]?.value == quill.Attribute.ul.value;
        final isNumber = attrs[quill.Attribute.list.key]?.value == quill.Attribute.ol.value;

        // Cor da fonte atual
        Color currentFontColor = Colors.black;
        final fontAttr = attrs[quill.Attribute.color.key]?.value;
        if (fontAttr is String && fontAttr.startsWith('#')) {
          try {
            final hex = fontAttr.replaceAll('#', '');
            currentFontColor = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
          } catch (_) {}
        }

        // Cor do destaque atual
        Color? currentHighlightColor;
        final hlAttr = attrs[quill.Attribute.background.key]?.value;
        if (hlAttr is String && hlAttr.startsWith('#') && hlAttr != '#00000000') {
          try {
            final hex = hlAttr.replaceAll('#', '');
            currentHighlightColor = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
          } catch (_) {}
        }

        return Container(
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            border: Border(top: BorderSide(color: border, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      // Bold
                      _QuickActionBtn(
                        label: 'B',
                        isBoldText: true,
                        isActive: isBold,
                        onTap: () {
                          controller.formatSelection(
                            isBold ? quill.Attribute.clone(quill.Attribute.bold, null) : quill.Attribute.bold,
                          );
                        },
                      ),
                      // Italic
                      _QuickActionBtn(
                        label: 'I',
                        isItalicText: true,
                        isActive: isItalic,
                        onTap: () {
                          controller.formatSelection(
                            isItalic ? quill.Attribute.clone(quill.Attribute.italic, null) : quill.Attribute.italic,
                          );
                        },
                      ),
                      // Underline
                      _QuickActionBtn(
                        label: 'U',
                        isUnderlineText: true,
                        isActive: isUnderline,
                        onTap: () {
                          controller.formatSelection(
                            isUnderline ? quill.Attribute.clone(quill.Attribute.underline, null) : quill.Attribute.underline,
                          );
                        },
                      ),
                      // Strikethrough
                      _QuickActionBtn(
                        label: 'ab',
                        isStrikeText: true,
                        isActive: isStrike,
                        onTap: () {
                          controller.formatSelection(
                            isStrike ? quill.Attribute.clone(quill.Attribute.strikeThrough, null) : quill.Attribute.strikeThrough,
                          );
                        },
                      ),
                      // Realce (Highlighter)
                      _QuickHighlightBtn(
                        currentColor: currentHighlightColor,
                        onTap: () => _showHighlightPalette(context),
                      ),
                      // Cor da Fonte
                      _QuickColorBtn(
                        currentColor: currentFontColor,
                        onTap: () => _showFontColorPalette(context),
                      ),
                      // Marcadores (Bullet)
                      _QuickActionIconBtn(
                        icon: Icons.format_list_bulleted_rounded,
                        isActive: isBullet,
                        onTap: () {
                          controller.formatSelection(
                            isBullet ? quill.Attribute.clone(quill.Attribute.ul, null) : quill.Attribute.ul,
                          );
                        },
                      ),
                      // Numeração
                      _QuickActionIconBtn(
                        icon: Icons.format_list_numbered_rounded,
                        isActive: isNumber,
                        onTap: () {
                          controller.formatSelection(
                            isNumber ? quill.Attribute.clone(quill.Attribute.ol, null) : quill.Attribute.ol,
                          );
                        },
                      ),
                      // Diminuir Recuo
                      _QuickActionIconBtn(
                        icon: Icons.format_indent_decrease_rounded,
                        isActive: false,
                        onTap: () => controller.indentSelection(false),
                      ),
                      // Aumentar Recuo
                      _QuickActionIconBtn(
                        icon: Icons.format_indent_increase_rounded,
                        isActive: false,
                        onTap: () => controller.indentSelection(true),
                      ),
                      // Inserir Versículo Bíblico (1 toque!)
                      _QuickActionPillBtn(
                        icon: Icons.auto_stories_rounded,
                        label: 'Versículo',
                        onTap: onInsertBibleVerse,
                        color: WordMobileTheme.primaryBlue,
                      ),
                      // Assistente IA / Sermão
                      _QuickActionPillBtn(
                        icon: Icons.auto_awesome,
                        label: 'Copilot',
                        onTap: onOpenAiAssistant,
                        color: const Color(0xFF8E8CD8),
                      ),
                    ],
                  ),
                ),
              ),

              // Botão de expandir / recolher Lower Ribbon (estilo Word chevron)
              Container(
                height: 48,
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: border, width: 1)),
                ),
                child: InkWell(
                  onTap: onToggleRibbon,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Icon(
                        isRibbonOpen ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                        color: WordMobileTheme.primaryBlue,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHighlightPalette(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ColorGridSheet(
        title: 'Cores de Realce',
        options: WordMobileTheme.highlightColors.map((h) => h.color).toList(),
        isHighlight: true,
        onSelected: (color) {
          Navigator.pop(ctx);
          onSelectHighlight(color);
        },
      ),
    );
  }

  void _showFontColorPalette(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ColorGridSheet(
        title: 'Cor da Fonte',
        options: WordMobileTheme.fontColors,
        isHighlight: false,
        onSelected: (color) {
          if (color != null) {
            Navigator.pop(ctx);
            onSelectFontColor(color);
          }
        },
      ),
    );
  }
}

/// Painel do Lower Ribbon Expandido (estilo oficial Microsoft Word Mobile)
class WordMobileLowerRibbon extends StatefulWidget {
  final quill.QuillController controller;
  final VoidCallback onClose;
  final VoidCallback onInsertBibleVerse;
  final VoidCallback onOpenAiAssistant;
  final VoidCallback onInsertSermonOutline;
  final VoidCallback onInsertQuoteBox;
  final VoidCallback onToggleViewMode;
  final bool isMobileView;
  final double currentZoom;
  final Function(double) onZoomChanged;

  const WordMobileLowerRibbon({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onInsertBibleVerse,
    required this.onOpenAiAssistant,
    required this.onInsertSermonOutline,
    required this.onInsertQuoteBox,
    required this.onToggleViewMode,
    required this.isMobileView,
    required this.currentZoom,
    required this.onZoomChanged,
  });

  @override
  State<WordMobileLowerRibbon> createState() => _WordMobileLowerRibbonState();
}

class _WordMobileLowerRibbonState extends State<WordMobileLowerRibbon> {
  WordRibbonTab _currentTab = WordRibbonTab.home;
  String _currentFont = 'Calibri';
  int _currentFontSize = 11;

  @override
  void initState() {
    super.initState();
    _updateFontFromSelection();
    widget.controller.addListener(_updateFontFromSelection);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateFontFromSelection);
    super.dispose();
  }

  void _updateFontFromSelection() {
    if (!mounted) return;
    final attrs = widget.controller.getSelectionStyle().attributes;
    final sizeVal = attrs[quill.Attribute.size.key]?.value;
    int size = 11;
    if (sizeVal is String) {
      size = int.tryParse(sizeVal) ?? 11;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? WordMobileTheme.surfaceDark : WordMobileTheme.surfaceLight;
    final headerBg = isDark ? WordMobileTheme.toolbarBgDark : const Color(0xFFF8F9FA);
    final border = isDark ? WordMobileTheme.borderDark : WordMobileTheme.borderLight;

    return Container(
      height: 310,
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      child: Column(
        children: [
          // ── Ribbon Header (Tab Selector + Copilot + Undo/Redo + Minimize) ──
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: headerBg,
              border: Border(bottom: BorderSide(color: border, width: 1)),
            ),
            child: Row(
              children: [
                // Dropdown de seleção de Abas (Início, Inserir, Layout, Revisão)
                InkWell(
                  onTap: _showTabSelector,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentTab.label,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: WordMobileTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.unfold_more_rounded,
                          size: 18,
                          color: WordMobileTheme.primaryBlue,
                        ),
                      ],
                    ),
                  ),
                ),

                const VerticalDivider(width: 1, indent: 10, endIndent: 10),

                const Spacer(),

                // Copilot / Assistente
                IconButton(
                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 22),
                  color: WordMobileTheme.primaryBlue,
                  tooltip: 'Assistente Copilot',
                  onPressed: widget.onOpenAiAssistant,
                ),

                // Undo
                IconButton(
                  icon: const Icon(Icons.undo_rounded, size: 22),
                  color: widget.controller.hasUndo ? WordMobileTheme.primaryBlue : Colors.grey,
                  tooltip: 'Desfazer',
                  onPressed: () {
                    if (widget.controller.hasUndo) {
                      widget.controller.undo();
                    }
                  },
                ),

                // Redo
                IconButton(
                  icon: const Icon(Icons.redo_rounded, size: 22),
                  color: widget.controller.hasRedo ? WordMobileTheme.primaryBlue : Colors.grey,
                  tooltip: 'Refazer',
                  onPressed: () {
                    if (widget.controller.hasRedo) {
                      widget.controller.redo();
                    }
                  },
                ),

                // Minimize down chevron
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
                  color: Colors.grey.shade600,
                  tooltip: 'Recolher',
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // ── Ribbon Content Area ──
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  void _showTabSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Material(
          color: isDark ? WordMobileTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Selecione a Guia',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                ...WordRibbonTab.values.map((tab) {
                  final isSelected = tab == _currentTab;
                  return ListTile(
                    leading: Icon(
                      _getTabIcon(tab),
                      color: isSelected ? WordMobileTheme.primaryBlue : Colors.grey.shade600,
                    ),
                    title: Text(
                      tab.label,
                      style: GoogleFonts.outfit(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? WordMobileTheme.primaryBlue : null,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: WordMobileTheme.primaryBlue)
                        : null,
                    onTap: () {
                      setState(() => _currentTab = tab);
                      Navigator.pop(ctx);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getTabIcon(WordRibbonTab tab) {
    switch (tab) {
      case WordRibbonTab.home:
        return Icons.edit_note_rounded;
      case WordRibbonTab.insert:
        return Icons.add_circle_outline_rounded;
      case WordRibbonTab.layout:
        return Icons.view_quilt_rounded;
      case WordRibbonTab.review:
        return Icons.spellcheck_rounded;
    }
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case WordRibbonTab.home:
        return _buildHomeTab();
      case WordRibbonTab.insert:
        return _buildInsertTab();
      case WordRibbonTab.layout:
        return _buildLayoutTab();
      case WordRibbonTab.review:
        return _buildReviewTab();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GUIA 1: INÍCIO (Home)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHomeTab() {
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

        // Cor da fonte
        Color currentFontColor = Colors.black;
        final fontAttr = attrs[quill.Attribute.color.key]?.value;
        if (fontAttr is String && fontAttr.startsWith('#')) {
          try {
            final hex = fontAttr.replaceAll('#', '');
            currentFontColor = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
          } catch (_) {}
        }

        // Realce
        Color? currentHighlightColor;
        final hlAttr = attrs[quill.Attribute.background.key]?.value;
        if (hlAttr is String && hlAttr.startsWith('#') && hlAttr != '#00000000') {
          try {
            final hex = hlAttr.replaceAll('#', '');
            currentHighlightColor = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
          } catch (_) {}
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Linha 1: Seletor de Fonte + Tamanho da Fonte
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: _showFontPickerSheet,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _currentFont,
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: _showFontSizePickerSheet,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_currentFontSize',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Linha 2: Botões de Caractere (B, I, U, ab)
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RibbonCharBtn(
                    label: 'B',
                    isBold: true,
                    isActive: isBold,
                    onTap: () => widget.controller.formatSelection(
                      isBold ? quill.Attribute.clone(quill.Attribute.bold, null) : quill.Attribute.bold,
                    ),
                  ),
                  _RibbonCharBtn(
                    label: 'I',
                    isItalic: true,
                    isActive: isItalic,
                    onTap: () => widget.controller.formatSelection(
                      isItalic ? quill.Attribute.clone(quill.Attribute.italic, null) : quill.Attribute.italic,
                    ),
                  ),
                  _RibbonCharBtn(
                    label: 'U',
                    isUnderline: true,
                    isActive: isUnderline,
                    onTap: () => widget.controller.formatSelection(
                      isUnderline ? quill.Attribute.clone(quill.Attribute.underline, null) : quill.Attribute.underline,
                    ),
                  ),
                  _RibbonCharBtn(
                    label: 'ab',
                    isStrike: true,
                    isActive: isStrike,
                    onTap: () => widget.controller.formatSelection(
                      isStrike ? quill.Attribute.clone(quill.Attribute.strikeThrough, null) : quill.Attribute.strikeThrough,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Linha 3: Realce (Highlight) com indicador de cor e drilldown
            _RibbonActionRow(
              icon: Icons.border_color_rounded,
              label: 'Realce',
              trailingWidget: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: currentHighlightColor ?? Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade400, width: 1.5),
                ),
                child: currentHighlightColor == null
                    ? const Icon(Icons.do_not_disturb_alt_rounded, size: 14, color: Colors.grey)
                    : null,
              ),
              onTap: _showHighlightPicker,
            ),

            // Linha 4: Cor da Fonte
            _RibbonActionRow(
              icon: Icons.format_color_text_rounded,
              label: 'Cor da fonte',
              trailingWidget: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: currentFontColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade400, width: 1.5),
                ),
              ),
              onTap: _showFontColorPicker,
            ),

            // Linha 5: Limpar Formatação
            _RibbonActionRow(
              icon: Icons.format_clear_rounded,
              label: 'Limpar formatação',
              onTap: () {
                final curStyle = widget.controller.getSelectionStyle();
                for (final attr in curStyle.attributes.values) {
                  widget.controller.formatSelection(quill.Attribute.clone(attr, null));
                }
              },
            ),

            // Linha 6: Alinhamento de Parágrafo
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AlignBtn(
                    icon: Icons.format_align_left_rounded,
                    isActive: isLeft,
                    onTap: () => widget.controller.formatSelection(quill.Attribute.leftAlignment),
                  ),
                  _AlignBtn(
                    icon: Icons.format_align_center_rounded,
                    isActive: isCenter,
                    onTap: () => widget.controller.formatSelection(quill.Attribute.centerAlignment),
                  ),
                  _AlignBtn(
                    icon: Icons.format_align_right_rounded,
                    isActive: isRight,
                    onTap: () => widget.controller.formatSelection(quill.Attribute.rightAlignment),
                  ),
                  _AlignBtn(
                    icon: Icons.format_align_justify_rounded,
                    isActive: isJustify,
                    onTap: () => widget.controller.formatSelection(quill.Attribute.justifyAlignment),
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
  Widget _buildInsertTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _RibbonActionRow(
          icon: Icons.auto_stories_rounded,
          label: 'Versículo Bíblico',
          subtitle: 'Buscar na Bíblia e colar citação com referência',
          iconColor: WordMobileTheme.primaryBlue,
          onTap: widget.onInsertBibleVerse,
        ),
        _RibbonActionRow(
          icon: Icons.record_voice_over_outlined,
          label: 'Esboço de Sermão',
          subtitle: 'Inserir estrutura homilética completa',
          iconColor: const Color(0xFFD83B01),
          onTap: widget.onInsertSermonOutline,
        ),
        _RibbonActionRow(
          icon: Icons.format_quote_rounded,
          label: 'Caixa de Citação Teológica',
          subtitle: 'Bloco estilizado em destaque',
          iconColor: const Color(0xFFFFB900),
          onTap: widget.onInsertQuoteBox,
        ),
        _RibbonActionRow(
          icon: Icons.today_rounded,
          label: 'Data e Hora Atual',
          subtitle: 'Inserir timestamp de anotação',
          onTap: () {
            final now = DateTime.now();
            final formatted = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} às ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            final index = widget.controller.selection.baseOffset;
            widget.controller.replaceText(index, 0, '$formatted\n', null);
          },
        ),
        _RibbonActionRow(
          icon: Icons.auto_awesome,
          label: 'Copilot / Assistente Teológico',
          subtitle: 'Gerar comentários, estudos e explicações',
          iconColor: const Color(0xFF8E8CD8),
          onTap: widget.onOpenAiAssistant,
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GUIA 3: LAYOUT (Layout)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildLayoutTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        SwitchListTile.adaptive(
          title: Text(
            'Modo Móvel (Reflow)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            widget.isMobileView ? 'Texto ajustado à largura da tela' : 'Página A4 com margens e sombra',
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
          ),
          value: widget.isMobileView,
          activeColor: WordMobileTheme.primaryBlue,
          onChanged: (_) => widget.onToggleViewMode(),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Zoom do Documento',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                '${(widget.currentZoom * 100).toInt()}%',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: WordMobileTheme.primaryBlue),
              ),
            ],
          ),
        ),
        Slider(
          value: widget.currentZoom,
          min: 0.6,
          max: 1.8,
          divisions: 12,
          activeColor: WordMobileTheme.primaryBlue,
          onChanged: widget.onZoomChanged,
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GUIA 4: REVISÃO (Review)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildReviewTab() {
    final text = widget.controller.document.toPlainText();
    final words = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    final chars = text.replaceAll('\n', '').length;
    final lines = text.split('\n').length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Text(
          'Estatísticas do Documento',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(label: 'Palavras', value: '$words'),
            const SizedBox(width: 8),
            _StatCard(label: 'Caracteres', value: '$chars'),
            const SizedBox(width: 8),
            _StatCard(label: 'Linhas', value: '$lines'),
          ],
        ),
        const SizedBox(height: 16),
        _RibbonActionRow(
          icon: Icons.psychology_alt_rounded,
          label: 'Análise Homilética IA',
          subtitle: 'Verificar coerência bíblica e clareza da mensagem',
          iconColor: WordMobileTheme.primaryBlue,
          onTap: widget.onOpenAiAssistant,
        ),
      ],
    );
  }

  void _showFontPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Material(
          color: isDark ? WordMobileTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Fonte', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    children: WordMobileTheme.availableFonts.map((font) {
                      final isSelected = font == _currentFont;
                      return ListTile(
                        title: Text(font, style: TextStyle(fontFamily: font, fontSize: 16)),
                        trailing: isSelected ? const Icon(Icons.check, color: WordMobileTheme.primaryBlue) : null,
                        onTap: () {
                          setState(() => _currentFont = font);
                          widget.controller.formatSelection(quill.FontAttribute(font));
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFontSizePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Material(
          color: isDark ? WordMobileTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Tamanho da Fonte', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    children: WordMobileTheme.fontSizes.map((size) {
                      final isSelected = size == _currentFontSize;
                      return ListTile(
                        title: Text('$size pt', style: GoogleFonts.outfit(fontSize: 15)),
                        trailing: isSelected ? const Icon(Icons.check, color: WordMobileTheme.primaryBlue) : null,
                        onTap: () {
                          setState(() => _currentFontSize = size);
                          widget.controller.formatSelection(quill.SizeAttribute(size.toString()));
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHighlightPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ColorGridSheet(
        title: 'Cores de Realce',
        options: WordMobileTheme.highlightColors.map((h) => h.color).toList(),
        isHighlight: true,
        onSelected: (color) {
          Navigator.pop(ctx);
          if (color == null) {
            widget.controller.formatSelection(quill.BackgroundAttribute('#00000000'));
          } else {
            final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
            widget.controller.formatSelection(quill.BackgroundAttribute(hex));
          }
        },
      ),
    );
  }

  void _showFontColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ColorGridSheet(
        title: 'Cor da Fonte',
        options: WordMobileTheme.fontColors,
        isHighlight: false,
        onSelected: (color) {
          if (color != null) {
            Navigator.pop(ctx);
            final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
            widget.controller.formatSelection(quill.ColorAttribute(hex));
          }
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// COMPONENTES AUXILIARES
// ──────────────────────────────────────────────────────────────────────────────

class _QuickActionBtn extends StatelessWidget {
  final String label;
  final bool isBoldText;
  final bool isItalicText;
  final bool isUnderlineText;
  final bool isStrikeText;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.label,
    this.isBoldText = false,
    this.isItalicText = false,
    this.isUnderlineText = false,
    this.isStrikeText = false,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? WordMobileTheme.lightBlueBg : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBoldText ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalicText ? FontStyle.italic : FontStyle.normal,
            decoration: isUnderlineText
                ? TextDecoration.underline
                : (isStrikeText ? TextDecoration.lineThrough : null),
            color: isActive ? WordMobileTheme.primaryBlue : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _QuickActionIconBtn extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickActionIconBtn({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? WordMobileTheme.lightBlueBg : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: isActive ? WordMobileTheme.primaryBlue : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _QuickHighlightBtn extends StatelessWidget {
  final Color? currentColor;
  final VoidCallback onTap;

  const _QuickHighlightBtn({
    this.currentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.border_color_rounded, size: 18),
            const SizedBox(height: 2),
            Container(
              width: 18,
              height: 3,
              color: currentColor ?? Colors.yellow.shade700,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickColorBtn extends StatelessWidget {
  final Color currentColor;
  final VoidCallback onTap;

  const _QuickColorBtn({
    required this.currentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Container(
              width: 18,
              height: 3,
              color: currentColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionPillBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _QuickActionPillBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RibbonCharBtn extends StatelessWidget {
  final String label;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrike;
  final bool isActive;
  final VoidCallback onTap;

  const _RibbonCharBtn({
    required this.label,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrike = false,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? WordMobileTheme.lightBlueBg : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: isUnderline
                ? TextDecoration.underline
                : (isStrike ? TextDecoration.lineThrough : null),
            color: isActive ? WordMobileTheme.primaryBlue : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _RibbonActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailingWidget;
  final Color? iconColor;
  final VoidCallback onTap;

  const _RibbonActionRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailingWidget,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor ?? Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingWidget != null) ...[
              trailingWidget!,
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _AlignBtn extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _AlignBtn({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? WordMobileTheme.lightBlueBg : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? WordMobileTheme.primaryBlue : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: WordMobileTheme.primaryBlue)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _ColorGridSheet extends StatelessWidget {
  final String title;
  final List<Color?> options;
  final bool isHighlight;
  final Function(Color?) onSelected;

  const _ColorGridSheet({
    required this.title,
    required this.options,
    required this.isHighlight,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? WordMobileTheme.surfaceDark : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: options.map((c) {
                return InkWell(
                  onTap: () => onSelected(c),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c ?? Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == null ? Colors.red : Colors.grey.shade400,
                        width: 1.5,
                      ),
                    ),
                    child: c == null
                        ? const Icon(Icons.do_not_disturb_alt_rounded, size: 20, color: Colors.red)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }
}
