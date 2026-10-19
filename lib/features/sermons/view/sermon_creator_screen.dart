import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/features/sermons/model/sermon_model.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/core/services/ai_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:keryx_app/features/sermons/view_model/sermon_view_model.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class SermonCreatorScreen extends ConsumerStatefulWidget {
  final Sermon? sermon;
  const SermonCreatorScreen({super.key, this.sermon});

  @override
  ConsumerState<SermonCreatorScreen> createState() => _SermonCreatorScreenState();
}

class _SermonCreatorScreenState extends ConsumerState<SermonCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers and FocusNodes map to handle dynamic fields efficiently
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, quill.QuillController> _quillControllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, ScrollController> _scrollControllers = {};

  // Layer link for floating toolbar
  final LayerLink _toolbarLayerLink = LayerLink();
  OverlayEntry? _toolbarEntry;

  // Track focused field to show toolbar
  String? _currentlyFocusedKey;

  // Sermon State
  String _title = "";
  String? _editingSermonId;
  String? _introduction;
  String? _conclusion;
  List<SermonPoint> _points = [];

  // Intro Formatting State
  final String _introAlign = 'left';
  final double _introSize = 14;
  String? _introFont;
  int? _introColor;

  // Conclusion Formatting State
  final String _concAlign = 'left';
  final double _concSize = 14;
  String? _concFont;
  int? _concColor;

  final AiService _aiService = AiService();
  bool _isGenerating = false;
  bool _showPreview = false;

  TextEditingController _getController(String key, {String initialText = ""}) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initialText);
    }
    return _controllers[key]!;
  }

  ScrollController _getScrollController(String key) {
    return _scrollControllers.putIfAbsent(key, () => ScrollController());
  }

  quill.QuillController _getQuillController(String key, {String? initialContent}) {
    if (!_quillControllers.containsKey(key)) {
      quill.Document doc;
      if (initialContent != null && initialContent.isNotEmpty) {
        try {
          if (initialContent.startsWith('[') || initialContent.startsWith('{')) {
            doc = quill.Document.fromJson(jsonDecode(initialContent));
          } else {
            doc = quill.Document()..insert(0, initialContent);
          }
        } catch (e) {
          doc = quill.Document()..insert(0, initialContent);
        }
      } else {
        doc = quill.Document();
      }
      
      final controller = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      
      // Clear toolbar when selection changes or hides
      controller.addListener(() {
        if (controller.selection.isCollapsed) {
          _hideFloatingToolbar();
        }
      });
      
      _quillControllers[key] = controller;
    }
    return _quillControllers[key]!;
  }

  FocusNode _getFocusNode(String key) {
    if (!_focusNodes.containsKey(key)) {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          setState(() => _currentlyFocusedKey = key);
          Future.delayed(const Duration(milliseconds: 150), () {
            if (node.context != null && mounted) {
              Scrollable.ensureVisible(
                node.context!,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: 0.1, // Align near the top
              );
            }
          });
        } else {
          // Check if any other field got focus, otherwise clear
          Future.delayed(const Duration(milliseconds: 100), () {
             if (mounted && !_focusNodes.values.any((n) => n.hasFocus)) {
               setState(() => _currentlyFocusedKey = null);
             }
          });
        }
      });
      _focusNodes[key] = node;
    }
    return _focusNodes[key]!;
  }

  @override
  void initState() {
    super.initState();
  }


  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var controller in _quillControllers.values) {
      controller.dispose();
    }
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    _hideFloatingToolbar();
    super.dispose();
  }

  void _addPoint() {
    setState(() {
      final newPoint = SermonPoint(title: "Novo Ponto Principal", subdivisions: [], keyVerses: []);
      newPoint.subdivisions.add(SermonSubdivision(text: "", supportingVerses: []));
      _points.add(newPoint);
    });
  }

  void _addSubdivision(int pointIndex) {
    setState(() {
      _points[pointIndex].subdivisions.add(SermonSubdivision(text: "", supportingVerses: []));
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: MBibliaTopBar(
        title: _editingSermonId != null ? "Editar Sermão" : "Criar Sermão",
        showLogo: false,
        onBack: () => Navigator.pop(context),
        additionalActions: [
          _buildActionIcon(
            icon: _showPreview ? Icons.edit_note_rounded : Icons.visibility_outlined,
            tooltip: _showPreview ? "Editar" : "Visualizar",
            onPressed: () => setState(() => _showPreview = !_showPreview),
            color: _showPreview ? const Color(0xFF4B45D8) : null,
          ),
          _buildActionIcon(
            icon: Icons.copy_all_rounded,
            tooltip: "Copiar Esboço",
            onPressed: _exportOutline,
          ),
          _buildActionIcon(
            icon: Icons.refresh_rounded,
            tooltip: "Limpar Tudo",
            onPressed: _resetEditor,
            color: Colors.redAccent,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: isDark ? null : BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.05),
          ),
          child: Column(
            children: [
              Expanded(
                child: _buildEditor(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _currentlyFocusedKey != null ? SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
            border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: quill.QuillSimpleToolbar(
                  controller: _quillControllers[_currentlyFocusedKey]!,
                  config: const quill.QuillSimpleToolbarConfig(
                    multiRowsDisplay: false,
                    showFontFamily: false,
                    showFontSize: true,
                    showBoldButton: true,
                    showItalicButton: true,
                    showUnderLineButton: true,
                    showStrikeThrough: true,
                    showColorButton: true,
                    showBackgroundColorButton: false,
                    showListBullets: true,
                    showListNumbers: true,
                    showAlignmentButtons: true,
                    showLink: false,
                    showSearchButton: false,
                    showQuote: false,
                    showUndo: false,
                    showRedo: false,
                    showIndent: false,
                    toolbarSize: 32, 
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4B45D8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.keyboard_hide_rounded, size: 20, color: Color(0xFF4B45D8)),
                  onPressed: () => FocusScope.of(context).unfocus(),
                  tooltip: "Minimizar editor",
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ) : null,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: const Color(0xFF4B45D8).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _saveSermon,
          backgroundColor: const Color(0xFF4B45D8),
          elevation: 0,
          icon: Icon(_editingSermonId != null ? Icons.update_rounded : Icons.save_outlined, color: Colors.white),
          label: Text(_editingSermonId != null ? "ATUALIZAR SERMÃO" : "SALVAR SERMÃO", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // Lista de blocos para o ListView
    final List<Widget> editorBlocks = [
      const SizedBox(height: 8),
      const Divider(),
      
      _buildCategoryHeader("DADOS GERAIS", Icons.settings_outlined),
      _buildTextField("Título do Sermão", (v) => _title = v, controller: _getController("title"), icon: Icons.title_rounded),
      const SizedBox(height: 32),

      _buildCategoryHeader(
        "ABERTURA", 
        Icons.chat_bubble_outline_rounded,
        trailing: IconButton(
          onPressed: () => _generateSermonWithWorker(),
          icon: const Icon(Icons.flash_on, size: 16, color: Colors.blueAccent),
          tooltip: "Estudo IA",
          visualDensity: VisualDensity.compact,
        ),
      ),
      _showPreview 
        ? Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50], borderRadius: BorderRadius.circular(16)),
            child: _buildRichPreview(_introduction),
          )
        : _buildRichTextField(
            "Digite a introdução do sermão...", 
            quillController: _getQuillController("intro", initialContent: _introduction),
            fieldKey: "intro",
            onChanged: (json) => setState(() => _introduction = json),
          ),
      const SizedBox(height: 32),

      _buildCategoryHeader("MENSAGEM", Icons.format_list_bulleted_rounded),
      
      // Pontos do sermão (serão adicionados dinamicamente à lista final)
      ..._points.asMap().entries.map((entry) => _buildPointCard(entry.key, entry.value)),
      
      const SizedBox(height: 16),
      Center(
        child: InkWell(
          onTap: _addPoint,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4B45D8), Color(0xFF6A64F1)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: const Color(0xFF4B45D8).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text("ADICIONAR PONTO NOVO", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
      ),
      
      const SizedBox(height: 48),
      _buildCategoryHeader("FINALIZAÇÃO", Icons.flag_outlined),
      _showPreview 
        ? Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50], borderRadius: BorderRadius.circular(16)),
            child: _buildRichPreview(_conclusion),
          )
        : _buildRichTextField(
            "Digite a conclusão...", 
            quillController: _getQuillController("conclusion", initialContent: _conclusion),
            fieldKey: "conclusion",
            onChanged: (json) => setState(() => _conclusion = json),
          ),
      const SizedBox(height: 120), // Espaço para o FAB
    ];

    return Form(
      key: _formKey,
      child: ListView.builder(
        physics: _currentlyFocusedKey != null 
            ? const NeverScrollableScrollPhysics() 
            : const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        itemCount: editorBlocks.length,
        itemBuilder: (context, index) => editorBlocks[index],
      ),
    );
  }


  void _generateSermonWithWorker() async {
    final String theme = _getController("title").text;
    if (theme.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, digite um título ou tema primeiro.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    
    try {
      final draft = await _aiService.generateSermonDraftFromWorker(theme);
      
      if (!mounted) return;
      
      // Abre o resultado num bottom sheet para o usuário decidir o que fazer
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on, color: Colors.cyanAccent),
                    const SizedBox(width: 12),
                    const Text('Rascunho do Worker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    MarkdownBody(data: draft),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _introduction = jsonEncode([{"insert": "$draft\n"}]);
                          final controller = _getQuillController("intro");
                          controller.clear();
                          controller.document.insert(0, draft);
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rascunho inserido na Introdução.')),
                        );
                      },
                      child: const Text('USAR COMO INTRODUÇÃO'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }


  Widget _buildCategoryHeader(String title, IconData icon, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF4B45D8).withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 2,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildTextField(String label, Function(String) onChanged, {TextEditingController? controller, IconData? icon}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.orange) : null,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildRichTextField(String hint, {
    required quill.QuillController quillController, 
    String? fieldKey, 
    required Function(String) onChanged,
  }) {
    final bool isFocused = fieldKey != null && _currentlyFocusedKey == fieldKey;
    final FocusNode focusNode = fieldKey != null ? _getFocusNode(fieldKey) : FocusNode();
    
    // Listen to changes to handle local state update
    quillController.addListener(() {
      final json = jsonEncode(quillController.document.toDelta().toJson());
      onChanged(json);
    });

    return Column(
      key: fieldKey != null ? ValueKey("rich_col_$fieldKey") : null,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused 
                ? const Color(0xFF4B45D8) 
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              width: isFocused ? 2 : 1,
            ),
            boxShadow: isFocused ? [
              BoxShadow(color: const Color(0xFF4B45D8).withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 8)),
            ] : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: isFocused ? MediaQuery.of(context).size.height * 0.45 : null,
                constraints: BoxConstraints(minHeight: 180, maxHeight: isFocused ? MediaQuery.of(context).size.height * 0.45 : double.infinity),
                child: quill.QuillEditor(
                  controller: quillController,
                  focusNode: focusNode,
                  scrollController: _getScrollController(fieldKey!),
                  config: quill.QuillEditorConfig(
                    placeholder: hint,
                    padding: const EdgeInsets.all(20),
                    autoFocus: fieldKey == _currentlyFocusedKey,
                    scrollable: isFocused,
                    expands: isFocused,
                    enableSelectionToolbar: false, 
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

  }

  void _hideFloatingToolbar() {
    _toolbarEntry?.remove();
    _toolbarEntry = null;
  }

  TextStyle _getStyle(String? fontFamily, double? fontSize, int? colorValue) {
    Color? color = colorValue != null && colorValue != Colors.transparent.toARGB32() ? Color(colorValue) : null;
    double size = fontSize ?? 14;
    
    if (CustomFontLoader.loadedFontFamilies.contains(fontFamily)) {
      return TextStyle(fontFamily: fontFamily, fontSize: size, color: color);
    }
    
    switch (fontFamily) {
      case 'Inter': return GoogleFonts.inter(fontSize: size, color: color);
      case 'Roboto': return GoogleFonts.roboto(fontSize: size, color: color);
      case 'Playfair Display': return GoogleFonts.playfairDisplay(fontSize: size, color: color);
      case 'Montserrat': return GoogleFonts.montserrat(fontSize: size, color: color);
      default: return GoogleFonts.outfit(fontSize: size, color: color);
    }
  }

  Widget _buildWordPadContextMenu(
    BuildContext context, 
    EditableTextState editableTextState,
    TextEditingController controller, {
    required String textAlign,
    required double fontSize,
    required String fontFamily,
    required int colorValue,
    Function(String)? onAlignChanged, 
    Function(double)? onSizeChanged,
    Function(String)? onFontChanged,
    Function(int)? onColorChanged,
    required Function(String) onChanged,
  }) {
    final List<ContextMenuButtonItem> buttonItems = editableTextState.contextMenuButtonItems;

    // Add WordPad Custom Actions
    buttonItems.insert(0, ContextMenuButtonItem(
      label: 'Negrito',
      onPressed: () {
        _wrapSelection(controller, "**", "**");
        onChanged(controller.text);
        editableTextState.hideToolbar();
      },
    ));
    buttonItems.insert(1, ContextMenuButtonItem(
      label: 'Itálico',
      onPressed: () {
        _wrapSelection(controller, "*", "*");
        onChanged(controller.text);
        editableTextState.hideToolbar();
      },
    ));
    buttonItems.insert(2, ContextMenuButtonItem(
      label: 'Lista',
      onPressed: () {
        _prefixLine(controller, "* ");
        onChanged(controller.text);
        editableTextState.hideToolbar();
      },
    ));
    buttonItems.insert(3, ContextMenuButtonItem(
      label: 'Estilos ✨',
      onPressed: () {
        editableTextState.hideToolbar();
        _showFormattingSheet(
          context,
          align: textAlign,
          size: fontSize,
          font: fontFamily,
          color: colorValue,
          onAlignChanged: onAlignChanged,
          onSizeChanged: onSizeChanged,
          onFontChanged: onFontChanged,
          onColorChanged: onColorChanged,
          onChanged: () => onChanged(controller.text),
        );
      },
    ));

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  Widget _buildRichPreview(String? content) {
    if (content == null || content.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.auto_awesome_outlined, color: Colors.grey.withValues(alpha: 0.3), size: 48),
              const SizedBox(height: 16),
              Text("Nenhum conteúdo para visualizar.", style: GoogleFonts.outfit(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    try {
      if (content.startsWith('[') || content.startsWith('{')) {
        final doc = quill.Document.fromJson(jsonDecode(content));
        final previewController = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
        return quill.QuillEditor(
          controller: previewController,
          focusNode: FocusNode(),
          scrollController: ScrollController(),
          config: const quill.QuillEditorConfig(
            scrollable: false,
            expands: false,
            padding: EdgeInsets.all(12),
            showCursor: false,
          ),
        );
      } else {
        // Se for texto plano (IA Sketch), vamos estilizar com Cards Profissionais
        return _buildStructuredAiSketch(content);
      }
    } catch (e) {
      return MarkdownBody(
        data: content,
        styleSheet: MarkdownStyleSheet(
          p: GoogleFonts.outfit(fontSize: 15, height: 1.6),
          h1: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
          h2: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      );
    }
  }

  Widget _buildStructuredAiSketch(String text) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Simples motor de busca de seções
    String findSection(String start, String end) {
      final startIndex = text.indexOf(start);
      if (startIndex == -1) return "";
      final actualStart = startIndex + start.length;
      final endIndex = text.indexOf(end, actualStart);
      return (endIndex == -1) ? text.substring(actualStart).trim() : text.substring(actualStart, endIndex).trim();
    }

    final title = findSection("[TÍTULO]", "[") ?? "Esboço de Sermão";
    final contextText = findSection("[CONTEXTO HISTÓRICO]", "[");
    final application = findSection("[APLICAÇÃO PRÁTICA]", "EndSectionNotExists"); // Pega até o fim

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card de Título
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFF4B45D8), const Color(0xFF4B45D8).withValues(alpha: 0.7)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("TEMA DO SERMÃO", style: GoogleFonts.outfit(fontSize: 10, color: Colors.white70, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: GoogleFonts.playfairDisplay(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (contextText.isNotEmpty) ...[
          _buildInfoSection("Contexto Exegético", contextText, Icons.history_edu, Colors.orangeAccent),
          const SizedBox(height: 16),
        ],

        // Corpo do Esboço como Markdown estilizado
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: MarkdownBody(
            data: text.replaceAll(title, "").replaceAll("[TÍTULO]", "").replaceAll("[CONTEXTO HISTÓRICO]", "### Contexto").replaceAll("[APLICAÇÃO PRÁTICA]", "### Aplicação"),
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.outfit(fontSize: 15, height: 1.6, color: isDark ? Colors.white70 : Colors.black87),
              h3: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF4B45D8)),
            ),
          ),
        ),

        const SizedBox(height: 16),
        if (application.isNotEmpty)
          _buildInfoSection("Aplicação Diária", application, Icons.lightbulb_outline, Colors.greenAccent),
      ],
    );
  }

  Widget _buildInfoSection(String title, String content, IconData icon, Color color) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(content, style: GoogleFonts.outfit(fontSize: 14, height: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  void _showFormattingSheet(
    BuildContext context, {
    required String align, 
    required double size, 
    required String font,
    required int color,
    Function(String)? onAlignChanged, 
    Function(double)? onSizeChanged,
    Function(String)? onFontChanged,
    Function(int)? onColorChanged,
    required VoidCallback onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF4B45D8)),
                   const SizedBox(width: 12),
                   Text("Estilo do Bloco", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                   const Spacer(),
                   IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 24),
              Text("ALINHAMENTO", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSheetIcon(Icons.format_align_left, align == 'left', () {
                    onAlignChanged?.call('left');
                    onChanged();
                    setSheetState(() => align = 'left');
                  }),
                  _buildSheetIcon(Icons.format_align_center, align == 'center', () {
                    onAlignChanged?.call('center');
                    onChanged();
                    setSheetState(() => align = 'center');
                  }),
                  _buildSheetIcon(Icons.format_align_right, align == 'right', () {
                    onAlignChanged?.call('right');
                    onChanged();
                    setSheetState(() => align = 'right');
                  }),
                  _buildSheetIcon(Icons.format_align_justify, align == 'justify', () {
                    onAlignChanged?.call('justify');
                    onChanged();
                    setSheetState(() => align = 'justify');
                  }),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("TAMANHO FONTE", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildSheetIcon(Icons.remove, false, () {
                              if (size > 8) {
                                onSizeChanged?.call(size - 1);
                                onChanged();
                                setSheetState(() => size--);
                              }
                            }),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text("${size.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            _buildSheetIcon(Icons.add, false, () {
                              onSizeChanged?.call(size + 1);
                              onChanged();
                              setSheetState(() => size++);
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("FONTE", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        _buildFontButton(font, (f) {
                          onFontChanged?.call(f);
                          onChanged();
                          setSheetState(() => font = f);
                        }),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text("COR DO TEXTO", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              _buildColorButton(color, (c) {
                onColorChanged?.call(c);
                onChanged();
                setSheetState(() => color = c);
              }),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetIcon(IconData icon, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4B45D8) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: active ? Colors.white : Colors.grey[700], size: 20),
      ),
    );
  }

  Widget _buildFormattingToolbar(
    String currentAlign, 
    double currentSize, 
    String currentFont,
    int currentColor,
    TextEditingController controller,
    Function(String)? onAlignChanged, 
    Function(double)? onSizeChanged,
    Function(String)? onFontChanged,
    Function(int)? onColorChanged,
  ) {
    // This is now legacy/unused but kept for internal builders maybe
    return const SizedBox.shrink();
  }

  void _wrapSelection(TextEditingController controller, String prefix, String suffix) {
    final text = controller.text;
    final selection = controller.selection;
    if (selection.start == -1) return;

    final selectedText = selection.textInside(text);
    final newText = text.replaceRange(selection.start, selection.end, "$prefix$selectedText$suffix");
    
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.end + prefix.length,
      ),
    );
  }

  void _prefixLine(TextEditingController controller, String prefix) {
    final text = controller.text;
    final selection = controller.selection;
    if (selection.start == -1) return;

    // Find the start of the current line
    int start = selection.start;
    while (start > 0 && text[start - 1] != '\n') {
      start--;
    }

    final newText = text.replaceRange(start, start, prefix);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + prefix.length),
    );
  }

  Widget _buildFontButton(String currentFont, Function(String)? onFontChanged) {
    return PopupMenuButton<String>(
      tooltip: "Fonte",
      onSelected: (val) async {
        if (val == '+ Importar Fonte') {
          final newFont = await CustomFontLoader.importCustomFont();
          if (newFont != null && onFontChanged != null) {
            onFontChanged(newFont);
          }
        } else {
          if (onFontChanged != null) {
            onFontChanged(val);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentFont, style: TextStyle(fontSize: 12, fontFamily: currentFont)),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => [
        ...CustomFontLoader.googleFonts,
        ...CustomFontLoader.loadedFontFamilies.where((f) => !CustomFontLoader.googleFonts.contains(f)),
        '+ Importar Fonte'
      ].map((f) => PopupMenuItem(
        value: f, 
        child: f == '+ Importar Fonte'
          ? const Text('+ Importar Fonte', style: TextStyle(fontWeight: FontWeight.bold))
          : Text(f, style: CustomFontLoader.loadedFontFamilies.contains(f) 
            ? TextStyle(fontFamily: f, fontSize: 14) 
            : GoogleFonts.getFont(f, fontSize: 14))
      )).toList(),
    );
  }

  Widget _buildColorButton(int currentColor, Function(int)? onColorChanged) {
    final Color actualColor = currentColor == Colors.transparent.toARGB32() ? Colors.grey : Color(currentColor);
    return PopupMenuButton<int>(
      tooltip: "Cor do Texto",
      onSelected: onColorChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16, 
              height: 16, 
              decoration: BoxDecoration(color: actualColor, shape: BoxShape.circle),
              child: currentColor == Colors.transparent.toARGB32() ? const Icon(Icons.close, size: 10, color: Colors.white) : null,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => [
        Colors.transparent.toARGB32(),
        const Color(0xFF1A1A1A).toARGB32(),
        const Color(0xFF4B45D8).toARGB32(),
        const Color(0xFFE91E63).toARGB32(),
        const Color(0xFF4CAF50).toARGB32(),
        const Color(0xFFFF9800).toARGB32(),
        const Color(0xFF00BCD4).toARGB32(),
        const Color(0xFF9C27B0).toARGB32(),
      ].map((c) => PopupMenuItem(
        value: c, 
        child: Row(
          children: [
            Container(
              width: 24, 
              height: 24, 
              decoration: BoxDecoration(
                color: c == Colors.transparent.toARGB32() ? Colors.grey[200] : Color(c), 
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: c == Colors.transparent.toARGB32() ? const Icon(Icons.close, size: 14, color: Colors.black) : null,
            ),
            const SizedBox(width: 12),
            Text(c == Colors.transparent.toARGB32() ? "Padrão" : "Cor"),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildToolbarIcon(IconData icon, bool active, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: IconButton(
        icon: Icon(icon, size: 20, color: active ? const Color(0xFF4B45D8) : Colors.grey[600]),
        onPressed: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        tooltip: _getTooltip(icon),
      ),
    );
  }

  String _getTooltip(IconData icon) {
    if (icon == Icons.format_bold) return "Negrito";
    if (icon == Icons.format_italic) return "Itálico";
    if (icon == Icons.format_list_bulleted) return "Lista";
    if (icon == Icons.format_list_numbered) return "Numeração";
    if (icon == Icons.format_align_left) return "Esquerda";
    if (icon == Icons.format_align_center) return "Centralizar";
    if (icon == Icons.format_align_right) return "Direita";
    if (icon == Icons.format_align_justify) return "Justificar";
    return "";
  }


  Future<void> _pickBiblePassage({required Function(String passage) onSelected}) async {
    // Agora pedimos apenas o nome da passagem manualmente por enquanto ou simplificamos
    String passage = "";
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Inserir Referência"),
        content: TextField(
          onChanged: (v) => passage = v,
          decoration: const InputDecoration(hintText: "Ex: João 3:16"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          TextButton(onPressed: () {
            onSelected(passage);
            Navigator.pop(context);
          }, child: const Text("OK")),
        ],
      ),
    );
  }

  Widget _buildPointCard(int index, SermonPoint point) {
    return Container(
      key: ValueKey("point_card_$index"),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4B45D8).withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFF4B45D8), shape: BoxShape.circle),
                      child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Text("Ponto Principal", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF4B45D8))),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, color: Color(0xFF4B45D8), size: 20), 
                      onPressed: () => _duplicatePoint(index)
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), 
                      onPressed: () => setState(() => _points.removeAt(index))
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _showPreview 
                  ? _buildRichPreview(point.title)
                  : _buildRichTextField(
                      "Título do Ponto", 
                      quillController: _getQuillController("point_${index}_title", initialContent: point.title),
                      fieldKey: "point_${index}_title",
                      onChanged: (json) => setState(() => point.title = json),
                    ),
                const SizedBox(height: 24),
                
                // Versículos chave do ponto
                Row(
                  children: [
                    const Icon(Icons.bookmark_added_outlined, size: 18, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text("Versículos Chave", style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _pickBiblePassage(onSelected: (p) => setState(() => point.keyVerses.add(p))),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Adicionar", style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                ...point.keyVerses.asMap().entries.map((vEntry) => Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book, size: 14, color: Colors.purple),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(vEntry.value, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      ),
                      IconButton(icon: const Icon(Icons.close, size: 14, color: Colors.grey), onPressed: () => setState(() => point.keyVerses.removeAt(vEntry.key))),
                    ],
                  ),
                )),
                
                const SizedBox(height: 24),
                ...point.subdivisions.asMap().entries.map((subEntry) => _buildSubdivisionBlock(index, subEntry.key, subEntry.value)),
                const SizedBox(height: 16),
                Center(
                  child: InkWell(
                    onTap: () => _addSubdivision(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4B45D8).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF4B45D8).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF4B45D8)),
                          const SizedBox(width: 8),
                          Text("ADICIONAR SUBDIVISÃO", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4B45D8), letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubdivisionBlock(int pointIndex, int subIndex, SermonSubdivision sub) {
    return Container(
      key: ValueKey("sub_block_${pointIndex}_$subIndex"),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.green),
                   const SizedBox(width: 8),
                   Text("Subdivisão ${subIndex + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.grey), onPressed: () => setState(() => _points[pointIndex].subdivisions.removeAt(subIndex))),
            ],
          ),
          const SizedBox(height: 8),
          _showPreview 
            ? _buildRichPreview(sub.text)
            : _buildRichTextField(
                "Digite a subdivisão ou aplicação...", 
                quillController: _getQuillController("pt_${pointIndex}_sub_$subIndex", initialContent: sub.text),
                fieldKey: "pt_${pointIndex}_sub_$subIndex",
                onChanged: (json) => setState(() => sub.text = json),
              ),
          const SizedBox(height: 16),
          _buildCategoryHeader("ILUSTRAÇÃO / EXEMPLO", Icons.auto_awesome_mosaic_outlined),
          _showPreview 
            ? _buildRichPreview(sub.illustration)
            : _buildRichTextField(
                "Descreva uma ilustração...", 
                quillController: _getQuillController("pt_${pointIndex}_illus_$subIndex", initialContent: sub.illustration),
                fieldKey: "pt_${pointIndex}_illus_$subIndex",
                onChanged: (json) => setState(() => sub.illustration = json),
              ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.menu_book_outlined, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text("Versos de Apoio", style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
              const Spacer(),
              InkWell(
                onTap: () => _pickBiblePassage(onSelected: (p) => setState(() => sub.supportingVerses.add(p))),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text("ADICIONAR", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ...sub.supportingVerses.asMap().entries.map((vEntry) => Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.bookmark_outline, size: 14, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(vEntry.value, style: const TextStyle(fontSize: 12)),
                ),
                IconButton(icon: const Icon(Icons.close, size: 14, color: Colors.grey), onPressed: () => setState(() => sub.supportingVerses.removeAt(vEntry.key))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Future<void> _saveSermon() async {
    if (_title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("O título é obrigatório.")));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Faça login para salvar seus sermões.")));
       return;
    }

    final sermon = Sermon(
      id: _editingSermonId ?? "", 
      title: _title,
      referenceText: "Manual",
      introduction: _introduction,
      conclusion: _conclusion,
      points: _points,
      createdAt: DateTime.now(),
      useTimer: false,
      introAlign: _introAlign,
      introSize: _introSize,
      introFont: _introFont,
      introColor: _introColor,
      concAlign: _concAlign,
      concSize: _concSize,
      concFont: _concFont,
      concColor: _concColor,
    );

    try {
      final notifier = ref.read(sermonListProvider.notifier);
      
      if (_editingSermonId != null) {
        await notifier.updateSermon(sermon);
      } else {
        await notifier.addSermon(sermon);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sermão salvo com sucesso!")));
        Navigator.pop(context); // Geralmente queremos voltar após salvar
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _duplicatePoint(int index) {
    setState(() {
      final originalPoint = _points[index];
      final newPoint = SermonPoint(
        title: originalPoint.title,
        keyVerses: List.from(originalPoint.keyVerses),
        subdivisions: originalPoint.subdivisions.map((s) => SermonSubdivision(
          text: s.text,
          illustration: s.illustration,
          supportingVerses: List.from(s.supportingVerses),
        )).toList(),
      );
      _points.insert(index + 1, newPoint);
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ponto duplicado!"), duration: Duration(seconds: 1)));
  }

  String _getPlainTextFromRich(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return "";
    try {
      final dynamic data = jsonDecode(jsonString);
      if (data is List) {
        String text = "";
        for (final op in data) {
          if (op is Map && op.containsKey('insert')) {
            text += op['insert'].toString();
          }
        }
        return text.trim();
      }
    } catch (e) {
      return jsonString;
    }
    return jsonString;
  }

  void _exportOutline() {
    String outline = "TÍTULO: ${_title.toUpperCase()}\n\n";
    
    if (_introduction != null) {
      outline += "INTRODUÇÃO:\n${_getPlainTextFromRich(_introduction)}\n\n";
    }

    for (int i = 0; i < _points.length; i++) {
      final point = _points[i];
      outline += "PONTO ${i + 1}: ${_getPlainTextFromRich(point.title)}\n";
      
      if (point.keyVerses.isNotEmpty) {
        outline += "Versículos: ${point.keyVerses.join(", ")}\n";
      }
      
      for (int j = 0; j < point.subdivisions.length; j++) {
        final sub = point.subdivisions[j];
        outline += "  ${j + 1}. ${_getPlainTextFromRich(sub.text)}\n";
        if (sub.illustration != null && sub.illustration!.isNotEmpty) {
          outline += "     Ilustração: ${_getPlainTextFromRich(sub.illustration)}\n";
        }
        if (sub.supportingVerses.isNotEmpty) {
          outline += "     Versos: ${sub.supportingVerses.join(", ")}\n";
        }
      }
      outline += "\n";
    }

    if (_conclusion != null) {
      outline += "CONCLUSÃO:\n${_getPlainTextFromRich(_conclusion)}\n";
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Esboço do Sermão"),
        content: SingleChildScrollView(
          child: SelectableText(outline, style: GoogleFonts.robotoMono(fontSize: 13)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: outline));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copiado para a área de transferência!")));
              Navigator.pop(context);
            }, 
            child: const Text("COPIAR")
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("FECHAR")),
        ],
      ),
    );
  }

  Widget _buildActionIcon({required IconData icon, required String tooltip, required VoidCallback onPressed, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color?.withValues(alpha: 0.1) ?? Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color ?? Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }

  void _resetEditor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Text("Limpar Tudo?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("Deseja apagar todo o conteúdo atual? Esta ação não pode ser desfeita."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCELAR", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _editingSermonId = null;
                _title = "";
                _introduction = null;
                _conclusion = null;
                _points = [];
                _controllers.clear();
                _quillControllers.clear();
                _focusNodes.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Editor limpo com sucesso"),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: const Color(0xFF4B45D8),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("LIMPAR"),
          ),
        ],
      ),
    );
  }
}
