import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:keryx_app/core/widgets/responsive_layout.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/bible/navigation/view/bible_selector_bottom_sheet.dart';
import 'package:keryx_app/features/study/model/note_card.dart';
import 'package:keryx_app/features/study/view_model/note_cards_provider.dart';
import 'package:keryx_app/core/services/ai_service.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_quill_to_pdf/flutter_quill_to_pdf.dart';
import 'package:keryx_app/core/utils/bible_text_parser.dart';

class ShapeEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'shape';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final type = embedContext.node.value.data as String;

    if (type == 'elipse') {
      return Container(
        width: 200,
        height: 100,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.blue, width: 2),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Elipse Customizada',
          style: TextStyle(color: Colors.black87),
        ),
      );
    } else if (type == 'caixa_texto') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade700, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: const Text(
          'Sua Caixa de Texto aqui...\n(Bloco visual inserido)',
          style: TextStyle(color: Colors.black87),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class NoteDetailScreen extends ConsumerStatefulWidget {
  final NoteCard note;
  final bool isCommunity;
  const NoteDetailScreen({super.key, required this.note, this.isCommunity = false});

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  late NoteCard _note;
  late TextEditingController _titleCtrl;
  late quill.QuillController _quillController;
  final FocusNode _editorFocus = FocusNode();
  final FocusNode _titleFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _saving = false;
  bool _isMobileView = true;
  double _zoomLevel = 1.0;
  bool _didInitView = false;
  bool _isGeneratingPdf = false;
  Color _quoteColor = const Color(0xFFF9A826); // Amarelo vibrante padrão
  bool _isPublic = false;
  bool _isEditing = false;
  bool _showBars = true;
  bool _isLandscapeMode = false;
  bool _ignoreFocusChange = false;

  static const _gold = AppTheme.kPrimaryGold;
  bool _showFormattingBar = false; // controla o painel expandido de formatação
  
  

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _titleCtrl = TextEditingController(text: _note.title);
    _isPublic = _note.isPublic;

    // Initialize Quill
    quill.Document doc;
    if (_note.body.isNotEmpty) {
      try {
        if (_note.body.startsWith('[') || _note.body.startsWith('{')) {
          doc = quill.Document.fromJson(jsonDecode(_note.body));
        } else {
          doc = quill.Document()..insert(0, _note.body);
        }
      } catch (_) {
        doc = quill.Document()..insert(0, _note.body);
      }
    } else {
      doc = quill.Document();
    }

    _quillController = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: !_isEditing,
    );

    _editorFocus.addListener(() {
      // The formatting bar should not automatically close when the editor gets focus.
      // It will temporarily hide due to viewInsets if the keyboard opens,
      // but its state remains true until explicitly closed by the user.
    });

    _scrollController.addListener(() {
      if (_isEditing) return; // Não esconde as barras se estiver editando
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (_showBars) setState(() => _showBars = false);
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_showBars) setState(() => _showBars = true);
      }
    });

    // View initialization is deferred to didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitView) {
      _didInitView = true;
      final prefs = ref.read(sharedPreferencesProvider);
      final savedView = prefs.getBool('note_is_mobile_view');
      if (savedView != null) {
        _isMobileView = savedView;
      } else {
        _isMobileView = !ResponsiveLayout.isExpanded(context);
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _titleCtrl.dispose();
    _quillController.dispose();
    _editorFocus.dispose();
    _titleFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<String?> _promptForTitle() async {
    final tc = TextEditingController(
      text: _titleCtrl.text == 'Nova Nota' ? '' : _titleCtrl.text,
    );
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            'Salvar Documento',
            style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: TextField(
            controller: tc,
            autofocus: true,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Digite o nome do documento...',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                final text = tc.text.trim();
                Navigator.pop(ctx, text.isEmpty ? 'Sem título' : text);
              },
              child: const Text('Salvar', style: TextStyle(color: _gold)),
            ),
          ],
        );
      },
    );
  }

  int get _currentFontSize {
    final attrs = _quillController.getSelectionStyle().attributes;
    if (attrs.containsKey('size')) {
      final val = attrs['size']?.value;
      if (val is String) {
        return int.tryParse(val) ?? 16;
      } else if (val is int) {
        return val;
      } else if (val is double) {
        return val.toInt();
      }
    }
    return 16;
  }

  void _updateFontSize(int delta) {
    _ignoreFocusChange = true;
    int current = _currentFontSize;
    int next = current + delta;
    if (next < 8) next = 8;
    if (next > 96) next = 96;
    _quillController.formatSelection(quill.SizeAttribute(next.toString()));
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    setState(() {});
    Future.microtask(() => _ignoreFocusChange = false);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _titleCtrl.text.trim() == 'Nova Nota' ||
        _titleCtrl.text.trim() == 'Sem título') {
      final newTitle = await _promptForTitle();
      if (newTitle == null) return; // cancelado
      _titleCtrl.text = newTitle;
    }

    setState(() => _saving = true);

    final jsonContent = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );

    final updated = _note.copyWith(
      title: _titleCtrl.text.trim().isEmpty
          ? 'Sem título'
          : _titleCtrl.text.trim(),
      body: jsonContent,
      isPublic: _isPublic,
    );

    await ref.read(noteCardsProvider.notifier).save(updated);
    setState(() {
      _note = updated;
      _saving = false;
    });

    if (mounted) {
      Navigator.pop(context, updated);
    }
  }

  void _saveQuietly() {
    final title = _titleCtrl.text.trim();
    final finalTitle = (title.isEmpty || title == 'Nova Nota') ? 'Sem título' : title;
    
    final jsonContent = jsonEncode(_quillController.document.toDelta().toJson());
    
    // Only save if there are actual changes
    if (_note.title == finalTitle && _note.body == jsonContent) {
      return;
    }

    final updated = _note.copyWith(
      title: finalTitle,
      body: jsonContent,
      isPublic: _isPublic,
    );
    
    ref.read(noteCardsProvider.notifier).save(updated);
  }

  Future<void> _generateAndSharePdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final delta = _quillController.document.toDelta();

      final converter = PDFConverter(
        backMatterDelta: null,
        frontMatterDelta: null,
        document: delta,
        fallbacks: [],
        pageFormat: PDFPageFormat.a4,
      );

      final pdfDocument = await converter.createDocument();
      if (pdfDocument == null) {
        throw Exception('Falha ao gerar o documento PDF.');
      }

      final dir = await getTemporaryDirectory();
      final title =
          _note.title.isNotEmpty &&
              _note.title != 'Sem título' &&
              _note.title != 'Nova Nota'
          ? _note.title
          : 'Estudo_Keryx';
      final file = File('${dir.path}/$title.pdf');
      await file.writeAsBytes(await pdfDocument.save());

      if (mounted) {
        Share.shareXFiles([
          XFile(file.path),
        ], text: 'Aqui está o meu estudo: $title');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _insertCustomText(
    String prefix,
    String text,
    String suffix, {
    bool isQuote = false,
  }) {
    final index = _quillController.selection.baseOffset;
    final length = _quillController.selection.extentOffset - index;
    // Insert text. If it's a quote, ensure we have a clean exit paragraph.
    final fullText = '\n$prefix\n$text\n$suffix\n\n';

    _quillController.replaceText(index, length, fullText, null);

    if (isQuote) {
      // Format the quote part (from first \n to the second-to-last \n)
      _quillController.formatText(
        index + 1,
        fullText.length - 3,
        quill.Attribute.blockQuote,
      );
      // Ensure the very last \n is NOT a blockquote (breaks the box)
      _quillController.formatText(
        index + fullText.length - 1,
        1,
        quill.Attribute.clone(quill.Attribute.blockQuote, null),
      );

      // Move cursor to the clean line outside the box
      _quillController.updateSelection(
        TextSelection.collapsed(offset: index + fullText.length - 1),
        quill.ChangeSource.local,
      );
    }
  }

  void _insertShape(String shapeType) {
    final index = _quillController.selection.baseOffset;
    final length = _quillController.selection.extentOffset - index;

    _quillController.replaceText(
      index,
      length,
      quill.BlockEmbed.custom(quill.CustomBlockEmbed('shape', shapeType)),
      null,
    );
    _quillController.replaceText(index + 1, 0, '\n', null);
    _quillController.updateSelection(
      TextSelection.collapsed(offset: index + 2),
      quill.ChangeSource.local,
    );
  }

  Future<void> _showAiAssistant() async {
    final tc = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: _gold),
              const SizedBox(width: 8),
              Text(
                'Assistente IA',
                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
          content: TextField(
            controller: tc,
            autofocus: true,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Ex: Gere uma introdução sobre João 3...',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                if (tc.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, tc.text.trim());
                }
              },
              child: const Text(
                'Gerar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (query != null && query.isNotEmpty) {
      setState(
        () => _saving = true,
      ); // Repurpose the save spinner as loading indicator
      try {
        final ai = AiService();
        final aiResponse = await ai.askAssistant(query);
        _insertCustomText('✨ IA:', aiResponse, '');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro na IA: $e')));
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Future<void> _insertBibleVerse() async {
    // 1. Escolher Livro e Capítulo
    final result =
        await showModalBottomSheet<
          ({BibleBook book, int chapter, int? verse, String version})
        >(
          context: context,
          isScrollControlled: true,
          constraints: const BoxConstraints(maxWidth: double.infinity),
          backgroundColor: Colors.transparent,
          builder: (context) => const BibleSelectorBottomSheet(
            initialStage: SelectorStage.versions,
          ),
        );

    if (result == null || !mounted) return;

    setState(() => _saving = true);
    BibleChapter? chapterData;
    try {
      final bibleService = ref.read(bibleServiceProvider);
      chapterData = await bibleService.getChapter(
        result.version,
        result.book.abbrev,
        result.chapter,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar versículos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (chapterData == null || !mounted) return;

    // 2. Escolher os Versículos
    final selectedVerses = await showModalBottomSheet<List<BibleVerse>>(
      context: context,
      isScrollControlled: true,
          constraints: const BoxConstraints(maxWidth: double.infinity),
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VerseSelectorSheet(chapter: chapterData!),
    );

    if (selectedVerses != null && selectedVerses.isNotEmpty) {
      // Ordena pelos números
      selectedVerses.sort((a, b) => a.number.compareTo(b.number));

      // Limpa as tags de Strong e formata
      final text = selectedVerses
          .map((v) => '[${v.number}] ${BibleTextParser.cleanToPlainText(v.text)}')
          .join('\n');

      // Monta a referência
      final versiculos = selectedVerses.length == 1
          ? '${selectedVerses.first.number}'
          : '${selectedVerses.first.number}-${selectedVerses.last.number}';

      final refText =
          '📖 ${result.book.name} ${result.chapter}:$versiculos (${result.version})';

      final index = _quillController.selection.baseOffset;
      final fullText = '\n$refText\n$text\n\n';
      
      _quillController.replaceText(index, 0, fullText, null);
      
      // Destaca a referência em negrito
      _quillController.formatText(index + 1, refText.length, quill.Attribute.bold);
      // Remove itálico/negrito do texto do versículo caso o usuário estivesse digitando com eles ativados
      _quillController.formatText(
        index + 1 + refText.length, 
        fullText.length - refText.length - 1, 
        quill.Attribute.clone(quill.Attribute.bold, null)
      );
      
      _quillController.updateSelection(
        TextSelection.collapsed(offset: index + fullText.length),
        quill.ChangeSource.local,
      );
    }
  }

  void _showCustomColorPicker({
    required bool isBackground,
    bool isPage = false,
    bool isQuoteBox = false,
  }) {
    SystemChannels.textInput.invokeMethod('TextInput.hide'); // Hide keyboard
    final List<Color> textColors = [
      Colors.black, Colors.white, Colors.grey, Colors.red, Colors.pink, Colors.orange,
      Colors.yellow, Colors.lightGreenAccent, Colors.green, Colors.cyan, Colors.blue, Colors.purple,
    ];
    final List<Color?> highlightColors = [
      null, // Transparent (Slash)
      const Color(0xFFF0E68C), const Color(0xFF90EE90), const Color(0xFFE0FFFF), const Color(0xFFFFB6C1), const Color(0xFF87CEFA),
      const Color(0xFFF08080), const Color(0xFF6A5ACD), const Color(0xFF48D1CC), const Color(0xFF3CB371), const Color(0xFFBA55D3), const Color(0xFFA0522D),
      const Color(0xFFBDB76B), Colors.grey.shade300, Colors.grey.shade400, Colors.grey.shade700,
    ];

    showDialog(
      context: context,
      barrierColor: Colors.transparent, // Floating feel
      builder: (ctx) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: Material(
              color: const Color(0xFF1E1E24), // Dark background matching the screenshot
              borderRadius: BorderRadius.circular(12),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: SizedBox(
                  width: 320, // Fixed width for the grid
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: (isBackground ? highlightColors : textColors).map((color) {
                      final isSelected = false; // Add state logic if needed
                      return GestureDetector(
                        onTap: () {
                          if (isPage) {
                            setState(() {
                              _note = _note.copyWith(pageColor: color?.value ?? 0xFFFFFFFF);
                            });
                            _save();
                          } else if (isQuoteBox) {
                            setState(() {
                              _quoteColor = color ?? Colors.grey.shade200;
                            });
                          } else if (isBackground) {
                            if (color == null) {
                              _quillController.formatSelection(quill.BackgroundAttribute('#00000000'));
                            } else {
                              final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                              _quillController.formatSelection(quill.BackgroundAttribute(hex));
                            }
                          } else {
                            if (color != null) {
                              final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                              _quillController.formatSelection(quill.ColorAttribute(hex));
                            }
                          }
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color ?? Colors.transparent,
                            shape: BoxShape.circle,
                            border: color == null ? Border.all(color: Colors.blue, width: 1.5) : null,
                          ),
                          child: color == null
                              ? const Icon(Icons.block, color: Colors.blue, size: 24)
                              : (isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : (isBackground ? Icon(Icons.grid_4x4, color: Colors.black.withValues(alpha: 0.1), size: 30) : null)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAlignmentMenu() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        Widget buildBtn(IconData icon, quill.Attribute attribute) {
          final isSelected = _quillController.getSelectionStyle().attributes[quill.Attribute.align.key]?.value == attribute.value;
          return IconButton(
            icon: Icon(icon, color: isSelected ? const Color(0xFF1E90FF) : Colors.white70),
            onPressed: () {
              _quillController.formatSelection(attribute);
              Navigator.pop(ctx);
            },
          );
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 85),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildBtn(Icons.format_align_left, quill.Attribute.leftAlignment),
                    buildBtn(Icons.format_align_center, quill.Attribute.centerAlignment),
                    buildBtn(Icons.format_align_right, quill.Attribute.rightAlignment),
                    buildBtn(Icons.format_align_justify, quill.Attribute.justifyAlignment),
                    IconButton(
                      icon: const Icon(Icons.format_indent_decrease, color: Colors.white70),
                      onPressed: () {
                        _quillController.indentSelection(false);
                        Navigator.pop(ctx);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_indent_increase, color: Colors.white70),
                      onPressed: () {
                        _quillController.indentSelection(true);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCustomFontSizePicker() {
    SystemChannels.textInput.invokeMethod('TextInput.hide'); // Hide keyboard
    final List<num> fontSizes = [5, 5.5, 6.5, 7.5, 8, 9, 10.5, 11, 12, 14, 16, 18, 20, 22, 24, 28, 32, 36, 48, 72];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24), // Dark background matching the screenshot
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _editorFocus.requestFocus();
                        SystemChannels.textInput.invokeMethod('TextInput.show');
                      },
                      child: Icon(Icons.keyboard_alt_outlined, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    const Text(
                      'Tamanho da fonte',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: fontSizes.length,
                  itemBuilder: (context, index) {
                    final size = fontSizes[index];
                    return InkWell(
                      onTap: () {
                        _quillController.formatSelection(
                          quill.SizeAttribute(size.toString()),
                        );
                        Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Text(
                            size.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomFontPicker() {
    SystemChannels.textInput.invokeMethod('TextInput.hide'); // Hide keyboard
    final fonts = [
      'Padrão',
      ...CustomFontLoader.googleFonts,
      ...CustomFontLoader.loadedFontFamilies.where((f) => !CustomFontLoader.googleFonts.contains(f)),
      '+ Importar Fonte',
    ];
    final currentFont = _quillController.getSelectionStyle().attributes[quill.Attribute.font.key]?.value ?? 'Padrão';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24), // Dark background matching the screenshot
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _editorFocus.requestFocus();
                        SystemChannels.textInput.invokeMethod('TextInput.show');
                      },
                      child: Icon(Icons.keyboard_alt_outlined, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    const Text(
                      'Fonte',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Fonte atual',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currentFont,
                    style: const TextStyle(color: Color(0xFF1E90FF), fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Todas as fontes',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: fonts.length,
                  itemBuilder: (context, index) {
                    final font = fonts[index];
                    return InkWell(
                      onTap: () async {
                        if (font == '+ Importar Fonte') {
                          final newFont = await CustomFontLoader.importCustomFont();
                          if (newFont != null) {
                            _quillController.formatSelection(
                              quill.FontAttribute(newFont),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                          return;
                        }
                        
                        if (font == 'Padrão') {
                          _quillController.formatSelection(
                            quill.Attribute.clone(
                              const quill.FontAttribute(''),
                              null,
                            ),
                          );
                        } else {
                          _quillController.formatSelection(
                            quill.FontAttribute(font),
                          );
                        }
                        Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              font,
                              style: font == '+ Importar Fonte' 
                                ? const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                                : (CustomFontLoader.loadedFontFamilies.contains(font) || font == 'Padrão'
                                  ? TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: font == 'Padrão' ? null : font,
                                    )
                                  : GoogleFonts.getFont(font, color: Colors.white, fontSize: 16)),
                            ),
                            ],
                          ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  void _showInsertMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isLight = Theme.of(context).brightness == Brightness.light;
        final primaryIconColor = isLight ? Theme.of(context).colorScheme.primary : _gold;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Inserir Elemento',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.auto_awesome, color: primaryIconColor),
                title: Text(
                  'Assistente IA',
                  style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAiAssistant();
                },
              ),
              ListTile(
                leading: Icon(Icons.menu_book, color: primaryIconColor),
                title: Text(
                  'Versículo Bíblico',
                  style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _insertBibleVerse();
                },
              ),
              ListTile(
                leading: const Icon(Icons.translate, color: Colors.blue),
                title: Text(
                  'Léxico / Dicionário',
                  style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await showModalBottomSheet<(String, String)>(
                    context: context,
                    isScrollControlled: true,
          constraints: const BoxConstraints(maxWidth: double.infinity),
                    backgroundColor: Colors.transparent,
                    builder: (context) => const _DictionarySearchSheet(),
                  );
                  if (result != null && mounted) {
                    final index = _quillController.selection.baseOffset;
                    final refText = '📚 Dicionário: ${result.$1}';
                    final text = result.$2;
                    final fullText = '\n$refText\n$text\n\n';
                    
                    _quillController.replaceText(index, 0, fullText, null);
                    _quillController.formatText(index + 1, refText.length, quill.Attribute.bold);
                    _quillController.formatText(
                      index + 1 + refText.length, 
                      fullText.length - refText.length - 1, 
                      quill.Attribute.clone(quill.Attribute.bold, null)
                    );
                    _quillController.updateSelection(
                      TextSelection.collapsed(offset: index + fullText.length),
                      quill.ChangeSource.local,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickColorBtn(Color color, bool isBackground) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: () {
          final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
          if (isBackground) {
            _quillController.formatSelection(quill.BackgroundAttribute(hex));
          } else {
            _quillController.formatSelection(quill.ColorAttribute(hex));
          }
        },
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: isBackground ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: isBackground ? BorderRadius.circular(8) : null,
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          ),
        ),
      ),
    );
  }

  Widget _buildPrintView() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 64 > 0 ? MediaQuery.of(context).size.width - 64 : 0,
            ),
            child: Center(
              child: Container(
                width: 794 * _zoomLevel,
                constraints: const BoxConstraints(minHeight: 1123),
                padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 80),
            decoration: BoxDecoration(
              color: Color(_note.pageColor),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
        child: Theme(
          data: ThemeData.light().copyWith(
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Colors.black,
              selectionColor: Color(0x40000000),
              selectionHandleColor: Colors.black,
            ),
          ),
          child: DefaultTextStyle(
            style: GoogleFonts.outfit(color: Colors.black87, fontSize: 16),
            child: quill.QuillEditor(
              controller: _quillController,
              focusNode: _editorFocus,
              scrollController: _scrollController,
              config: quill.QuillEditorConfig(
                padding: EdgeInsets.zero,
                scrollable: false,
                autoFocus: false,
                expands: false,
                embedBuilders: [ShapeEmbedBuilder()],
                customStyleBuilder: (attribute) {
                  if (attribute.key == 'font') {
                    final fontName = attribute.value as String?;
                    if (fontName != null && fontName.isNotEmpty && fontName != 'Padrão') {
                      if (CustomFontLoader.loadedFontFamilies.contains(fontName)) {
                        return TextStyle(fontFamily: fontName);
                      }
                      try {
                        return GoogleFonts.getFont(fontName);
                      } catch (_) {
                        return TextStyle(fontFamily: fontName);
                      }
                    }
                  }
                  return const TextStyle();
                },
                customStyles: quill.DefaultStyles(
                  quote: quill.DefaultTextBlockStyle(
                    GoogleFonts.outfit(
                      color: Colors.black87,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                    const quill.HorizontalSpacing(16, 0),
                    const quill.VerticalSpacing(16, 16),
                    const quill.VerticalSpacing(0, 0),
                    BoxDecoration(
                      color: _quoteColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
      ),
      ),
      ),
    );
  }

  Widget _buildMobileView() {
    final bgColor = Color(_note.pageColor);
    final isLightPage = ThemeData.estimateBrightnessForColor(bgColor) == Brightness.light;
    final textColor = isLightPage ? Colors.black87 : Colors.white;

    return Container(
      color: bgColor,
      child: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_zoomLevel)),
              child: Theme(
                data: isLightPage ? ThemeData.light().copyWith(
                  textSelectionTheme: const TextSelectionThemeData(
                    cursorColor: Colors.black,
                    selectionColor: Color(0x40000000),
                    selectionHandleColor: Colors.black,
                  ),
                ) : ThemeData.dark().copyWith(
                  textSelectionTheme: const TextSelectionThemeData(
                    cursorColor: Colors.white,
                    selectionColor: Color(0x40FFFFFF),
                    selectionHandleColor: Colors.white,
                  ),
                ),
                child: DefaultTextStyle(
                  style: GoogleFonts.outfit(color: textColor, fontSize: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      quill.QuillEditor(
                        controller: _quillController,
                        focusNode: _editorFocus,
                        scrollController: _scrollController,
                        config: quill.QuillEditorConfig(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          scrollable: false,
                          autoFocus: false,
                          expands: false,
                          embedBuilders: [ShapeEmbedBuilder()],
                          customStyleBuilder: (attribute) {
                            if (attribute.key == 'font') {
                              final fontName = attribute.value as String?;
                              if (fontName != null && fontName.isNotEmpty && fontName != 'Padrão') {
                                if (CustomFontLoader.loadedFontFamilies.contains(fontName)) {
                                  return TextStyle(fontFamily: fontName);
                                }
                                try {
                                  return GoogleFonts.getFont(fontName);
                                } catch (_) {
                                  return TextStyle(fontFamily: fontName);
                                }
                              }
                            }
                            return const TextStyle();
                          },
                          customStyles: quill.DefaultStyles(
                            quote: quill.DefaultTextBlockStyle(
                              GoogleFonts.outfit(
                                color: textColor,
                                fontSize: 18,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                              const quill.HorizontalSpacing(16, 0),
                              const quill.VerticalSpacing(16, 16),
                              const quill.VerticalSpacing(0, 0),
                              BoxDecoration(
                                color: _quoteColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isLightPage ? Colors.black : Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: isLightPage ? Colors.black : Colors.white,
                                    offset: const Offset(4, 4),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final title = _titleCtrl.text.trim();
        final finalTitle = (title.isEmpty || title == 'Nova Nota' || title == 'Novo Tópico') ? 'Sem título' : title;
        final jsonContent = jsonEncode(_quillController.document.toDelta().toJson());
        
        // Se não houve mudança, permite sair
        if (_note.title == finalTitle && _note.body == jsonContent) {
          Navigator.pop(context);
          return;
        }

        // Se houve mudança, pergunta
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Text('Atenção', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
            content: Text('Você tem alterações não salvas. O que deseja fazer?', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'discard'),
                child: const Text('Sair sem salvar', style: TextStyle(color: Colors.redAccent)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: const Text('Salvar'),
              ),
            ],
          ),
        );

        if (action == 'discard' && mounted) {
          Navigator.pop(context);
        } else if (action == 'save' && mounted) {
          await _save();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: (!_showBars && !_isEditing && !ResponsiveLayout.isExpanded(context)) ? null : AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
          title: TextField(
            controller: _titleCtrl,
            focusNode: _titleFocus,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Título da nota...',
              hintStyle: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          centerTitle: true,
          actions: [
            if (ResponsiveLayout.isExpanded(context))
              Row(
                children: [
                  Icon(Icons.zoom_out, size: 20, color: Theme.of(context).colorScheme.onSurface),
                  SizedBox(
                    width: 150,
                    child: Slider(
                      value: _zoomLevel,
                      min: 0.5,
                      max: 3.0,
                      activeColor: _gold,
                      inactiveColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      onChanged: (val) {
                        setState(() {
                          _zoomLevel = val;
                        });
                      },
                    ),
                  ),
                  Icon(Icons.zoom_in, size: 20, color: Theme.of(context).colorScheme.onSurface),
                  const SizedBox(width: 16),
                ],
              ),

            IconButton(
              icon: const Icon(Icons.undo, size: 22),
              onPressed: () {
                if (_quillController.hasUndo) {
                  _quillController.undo();
                }
              },
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              tooltip: 'Desfazer',
            ),
            IconButton(
              icon: const Icon(Icons.redo, size: 22),
              onPressed: () {
                if (_quillController.hasRedo) {
                  _quillController.redo();
                }
              },
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              tooltip: 'Refazer',
            ),
            if (_saving || _isGeneratingPdf)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _gold,
                    ),
                  ),
                ),
              )
            else
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface),
                onSelected: (value) {
                  if (value == 'pdf') _generateAndSharePdf();
                  if (value == 'save') _save();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.onSurface),
                        const SizedBox(width: 8),
                        const Text('Gerar PDF'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'save',
                    child: Row(
                      children: [
                        const Icon(Icons.save_rounded, color: _gold),
                        const SizedBox(width: 8),
                        Text('Salvar', style: GoogleFonts.outfit(color: _gold, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ── Modo Tablet/Expandido: toolbar completa no topo ──────────────
              if (ResponsiveLayout.isExpanded(context))
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: _gold),
                                    onPressed: _showInsertMenu,
                                    tooltip: 'Inserir...',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.format_size, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                    onPressed: _showCustomFontSizePicker,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.font_download, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                    onPressed: _showCustomFontPicker,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.format_color_text, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                    onPressed: () => _showCustomColorPicker(isBackground: false),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.format_color_fill, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                    onPressed: () => _showCustomColorPicker(isBackground: true),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.format_paint, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                    onPressed: () => _showCustomColorPicker(isBackground: false, isPage: true),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.format_quote, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                    onPressed: () => _showCustomColorPicker(isBackground: false, isQuoteBox: true),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                        child: SingleChildScrollView(
                          child: Theme(
                            data: Theme.of(context),
                            child: Listener(
                              onPointerUp: (_) {
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  if (mounted) {
                                    SystemChannels.textInput.invokeMethod('TextInput.hide');
                                    FocusScope.of(context).unfocus();
                                  }
                                });
                              },
                              child: quill.QuillSimpleToolbar(
                                controller: _quillController,
                                config: quill.QuillSimpleToolbarConfig(
                                  multiRowsDisplay: true,
                                  showFontFamily: false,
                                  showFontSize: false,
                                  showSearchButton: false,
                                  showInlineCode: false,
                                  showSubscript: false,
                                  showSuperscript: false,
                                  showColorButton: false,
                                  showBackgroundColorButton: false,
                                  showAlignmentButtons: true,
                                  showLeftAlignment: true,
                                  showCenterAlignment: true,
                                  showRightAlignment: true,
                                  showJustifyAlignment: true,
                                  showListNumbers: true,
                                  showListBullets: true,
                                  showListCheck: true,
                                  showCodeBlock: false,
                                  showQuote: true,
                                  showIndent: true,
                                  showLink: true,
                                  showUndo: true,
                                  showRedo: true,
                                  showDirection: false,
                                  showDividers: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Documento (modo celular ou print) ─────────────────────────────
              Expanded(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: double.infinity,
                  child: _isMobileView ? _buildMobileView() : _buildPrintView(),
                ),
              ),

              // ── Modo Celular: painel de formatação expandido (slide up) ────────
              if (!ResponsiveLayout.isExpanded(context) && _showFormattingBar && MediaQuery.of(context).viewInsets.bottom < 60)
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E24), // Dark background from screenshot
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Cabecalho (Teclado, Busca, Fechar)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.keyboard_alt_outlined, color: Colors.white70),
                                onPressed: () {
                                  setState(() {
                                    _showFormattingBar = false;
                                    _isEditing = true;
                                    _quillController.readOnly = false;
                                  });
                                  _editorFocus.requestFocus();
                                  SystemChannels.textInput.invokeMethod('TextInput.show');
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.search, color: Colors.white70),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => quill.QuillToolbarSearchDialog(
                                      controller: _quillController,
                                      dialogTheme: quill.QuillDialogTheme(
                                        dialogBackgroundColor: Theme.of(context).cardColor,
                                      ),
                                      searchBarAlignment: Alignment.topCenter,
                                    ),
                                  );
                                },
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white70),
                                onPressed: () => setState(() {
                                  _showFormattingBar = false;
                                  _quillController.readOnly = !_isEditing;
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Tamanho e Formato
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tamanho', style: TextStyle(fontSize: 12, color: Colors.white54)),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2A2A30),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          InkWell(
                                            onTap: () => _updateFontSize(-1),
                                            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.remove, size: 20, color: Colors.white)),
                                          ),
                                          InkWell(
                                            onTap: _showCustomFontSizePicker,
                                            child: Text('$_currentFontSize', style: const TextStyle(color: Colors.white, fontSize: 16)),
                                          ),
                                          InkWell(
                                            onTap: () => _updateFontSize(1),
                                            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.add, size: 20, color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Formato', style: TextStyle(fontSize: 12, color: Colors.white54)),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2A2A30),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _FormatToggleBtn(icon: Icons.format_bold, attribute: quill.Attribute.bold, controller: _quillController, iconSize: 22, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), onPressed: () { _ignoreFocusChange = true; Future.microtask(() => _ignoreFocusChange = false); }),
                                          _FormatToggleBtn(icon: Icons.format_italic, attribute: quill.Attribute.italic, controller: _quillController, iconSize: 22, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), onPressed: () { _ignoreFocusChange = true; Future.microtask(() => _ignoreFocusChange = false); }),
                                          _FormatToggleBtn(icon: Icons.format_strikethrough, attribute: quill.Attribute.strikeThrough, controller: _quillController, iconSize: 22, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), onPressed: () { _ignoreFocusChange = true; Future.microtask(() => _ignoreFocusChange = false); }),
                                          _FormatToggleBtn(icon: Icons.format_underline, attribute: quill.Attribute.underline, controller: _quillController, iconSize: 22, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), onPressed: () { _ignoreFocusChange = true; Future.microtask(() => _ignoreFocusChange = false); }),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Fonte
                          const Text('Fonte', style: TextStyle(fontSize: 12, color: Colors.white54)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _showCustomFontPicker,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text('Arial', style: TextStyle(color: Colors.white, fontSize: 14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Cor do texto
                          const Text('Cor do texto', style: TextStyle(fontSize: 12, color: Colors.white54)),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                               decoration: BoxDecoration(
                                 color: const Color(0xFF2A2A30),
                                 borderRadius: BorderRadius.circular(12),
                               ),
                               child: Row(
                                 children: [
                                   _buildQuickColorBtn(Colors.black, false),
                                   _buildQuickColorBtn(Colors.white, false),
                                   _buildQuickColorBtn(Colors.grey, false),
                                   _buildQuickColorBtn(Colors.red, false),
                                   _buildQuickColorBtn(Colors.pink, false),
                                   _buildQuickColorBtn(Colors.orange, false),
                                   _buildQuickColorBtn(Colors.yellow, false),
                                   _buildQuickColorBtn(Colors.green, false),
                                   _buildQuickColorBtn(Colors.blue, false),
                                   _buildQuickColorBtn(Colors.purple, false),
                                 ],
                               ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Destacar
                          const Text('Destacar', style: TextStyle(fontSize: 12, color: Colors.white54)),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                               decoration: BoxDecoration(
                                 color: const Color(0xFF2A2A30),
                                 borderRadius: BorderRadius.circular(12),
                               ),
                               child: Row(
                                 children: [
                                   Padding(
                                     padding: const EdgeInsets.symmetric(horizontal: 6),
                                     child: InkWell(
                                       onTap: () {
                                         _quillController.formatSelection(quill.BackgroundAttribute(''));
                                       },
                                       child: Container(
                                         width: 24,
                                         height: 24,
                                         decoration: BoxDecoration(
                                           color: Colors.transparent,
                                           shape: BoxShape.circle,
                                           border: Border.all(color: Colors.white54),
                                         ),
                                         child: const Icon(Icons.do_not_disturb_alt, size: 14, color: Colors.white54),
                                       ),
                                     ),
                                   ),
                                   _buildQuickColorBtn(Colors.yellow.withValues(alpha: 0.5), true),
                                   _buildQuickColorBtn(Colors.green.withValues(alpha: 0.5), true),
                                   _buildQuickColorBtn(Colors.cyan.withValues(alpha: 0.5), true),
                                   _buildQuickColorBtn(Colors.pink.withValues(alpha: 0.5), true),
                                   _buildQuickColorBtn(Colors.indigo.withValues(alpha: 0.5), true),
                                   _buildQuickColorBtn(Colors.red.withValues(alpha: 0.5), true),
                                   _buildQuickColorBtn(Colors.grey.withValues(alpha: 0.5), true),
                                 ],
                               ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Parágrafo
                          const Text('Parágrafo', style: TextStyle(fontSize: 12, color: Colors.white54)),
                          const SizedBox(height: 6),
                          Container(
                             height: 44,
                             decoration: BoxDecoration(
                               color: const Color(0xFF2A2A30),
                               borderRadius: BorderRadius.circular(12),
                             ),
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                               children: [
                                 _FormatToggleBtn(icon: Icons.format_align_left, attribute: quill.Attribute.leftAlignment, controller: _quillController, isAlign: true, iconSize: 22, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), onPressed: () { _ignoreFocusChange = true; Future.microtask(() => _ignoreFocusChange = false); }),
                                 _FormatToggleBtn(icon: Icons.format_align_center, attribute: quill.Attribute.centerAlignment, controller: _quillController, isAlign: true, iconSize: 22, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), onPressed: () { _ignoreFocusChange = true; Future.microtask(() => _ignoreFocusChange = false); }),
                                 _FormatToggleBtn(icon: Icons.format_align_right, attribute: quill.Attribute.rightAlignment, controller: _quillController, isAlign: true, iconSize: 22, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), onPressed: () { _ignoreFocusChange = true; Future.microtask(() => _ignoreFocusChange = false); }),
                                 _FormatToggleBtn(icon: Icons.format_align_justify, attribute: quill.Attribute.justifyAlignment, controller: _quillController, isAlign: true, iconSize: 22, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), onPressed: () { _ignoreFocusChange = true; Future.microtask(() => _ignoreFocusChange = false); }),
                                 IconButton(
                                   icon: const Icon(Icons.format_indent_decrease),
                                   color: Colors.white,
                                   onPressed: () { _ignoreFocusChange = true; _quillController.indentSelection(false); Future.microtask(() => _ignoreFocusChange = false); },
                                 ),
                                 IconButton(
                                   icon: const Icon(Icons.format_indent_increase),
                                   color: Colors.white,
                                   onPressed: () { _ignoreFocusChange = true; _quillController.indentSelection(true); Future.microtask(() => _ignoreFocusChange = false); },
                                 ),
                               ],
                             ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Barra inferior compacta (estilo doc editor) ────────────────────
              if (!ResponsiveLayout.isExpanded(context) && (_showBars || _isEditing) && !(_showFormattingBar && MediaQuery.of(context).viewInsets.bottom < 60))
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E24), // Dark background matching the screenshot
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Taller bar
                      child: _isEditing
                          ? Row(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        const SizedBox(width: 8),
                                        _FormatBtn(
                                          onTap: () {
                                            final isPanelVisible = _showFormattingBar;
                                            setState(() {
                                              _showFormattingBar = !isPanelVisible;
                                              _quillController.readOnly = !_isEditing || !isPanelVisible;
                                            });
                                            if (!isPanelVisible) { // If it was hidden, we are trying to show it
                                              SystemChannels.textInput.invokeMethod('TextInput.hide');
                                              FocusScope.of(context).unfocus();
                                            }
                                          },
                                          child: Icon(_showFormattingBar ? Icons.keyboard_arrow_down : Icons.window, color: Colors.white70, size: 26),
                                        ),
                                        const SizedBox(width: 8),
                                        _FormatBtn(
                                          onTap: () => _showCustomColorPicker(isBackground: false),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.format_color_text, color: Color(0xFFFF1493), size: 26),
                                              Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _FormatBtn(
                                          onTap: () => _showCustomColorPicker(isBackground: true),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.format_color_fill, color: Color(0xFF32CD32), size: 26),
                                              Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _FormatToggleBtn(
                                          icon: Icons.format_bold,
                                          attribute: quill.Attribute.bold,
                                          controller: _quillController,
                                          iconSize: 26,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                        ),
                                        const SizedBox(width: 8),
                                        _FormatBtn(
                                          onTap: _showCustomFontSizePicker,
                                          child: const Text('Aa', style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.w400)),
                                        ),
                                        const SizedBox(width: 8),
                                        _FormatBtn(
                                          onTap: _showCustomFontPicker,
                                          child: const Text('T', style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.w400)),
                                        ),
                                        const SizedBox(width: 8),
                                        _FormatBtn(
                                          onTap: _showAlignmentMenu,
                                          child: const Icon(Icons.format_align_left, color: Colors.white70, size: 26),
                                        ),
                                        const SizedBox(width: 8),
                                        _FormatToggleBtn(
                                          icon: Icons.format_italic,
                                          attribute: quill.Attribute.italic,
                                          controller: _quillController,
                                          iconSize: 26,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                        ),
                                        const SizedBox(width: 8),
                                        _FormatToggleBtn(
                                          icon: Icons.format_underline,
                                          attribute: quill.Attribute.underline,
                                          controller: _quillController,
                                          iconSize: 26,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                        ),
                                        const SizedBox(width: 8),
                                        _FormatToggleBtn(
                                          icon: Icons.format_strikethrough,
                                          attribute: quill.Attribute.strikeThrough,
                                          controller: _quillController,
                                          iconSize: 26,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                        ),
                                        const SizedBox(width: 16),
                                      ],
                                    ),
                                  ),
                                ),
                                Builder(
                                  builder: (ctx) {
                                    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 60;
                                    return IconButton(
                                      icon: Icon(
                                        isKeyboardOpen ? Icons.keyboard_hide : Icons.arrow_back,
                                        color: Colors.white70,
                                        size: 26,
                                      ),
                                      onPressed: () {
                                        if (isKeyboardOpen) {
                                          // Teclado aberto (keyboard_hide): Minimiza o teclado, mas continua no modo de edição (barra rápida visível)
                                          SystemChannels.textInput.invokeMethod('TextInput.hide');
                                          FocusScope.of(context).unfocus();
                                        } else {
                                          // Teclado fechado (arrow_back): Sai do modo de edição e volta para a barra principal
                                          SystemChannels.textInput.invokeMethod('TextInput.hide');
                                          FocusScope.of(context).unfocus();
                                          setState(() {
                                            _showFormattingBar = false;
                                            _isEditing = false;
                                            _quillController.readOnly = true;
                                          });
                                        }
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _BottomBarBtn(
                                  icon: _isMobileView ? Icons.fullscreen : Icons.description_outlined,
                                  label: _isMobileView ? 'Tela Inteira' : 'Página',
                                  context: context,
                                  onTap: () {
                                    setState(() {
                                      _isMobileView = !_isMobileView;
                                      ref.read(sharedPreferencesProvider).setBool('note_is_mobile_view', _isMobileView);
                                    });
                                  },
                                ),
                                _BottomBarBtn(
                                  icon: Icons.edit_document,
                                  label: 'Editar',
                                  context: context,
                                  onTap: () {
                                    setState(() {
                                      _isEditing = true;
                                      _quillController.readOnly = false;
                                    });
                                    Future.delayed(const Duration(milliseconds: 200), () {
                                      if (mounted) _editorFocus.requestFocus();
                                    });
                                  },
                                ),
                                _BottomBarBtn(
                                  icon: Icons.screen_rotation,
                                  label: 'Paisagem',
                                  context: context,
                                  onTap: () {
                                    setState(() {
                                      _isLandscapeMode = !_isLandscapeMode;
                                    });
                                    if (_isLandscapeMode) {
                                      SystemChrome.setPreferredOrientations([
                                        DeviceOrientation.landscapeLeft,
                                        DeviceOrientation.landscapeRight,
                                      ]);
                                    } else {
                                      SystemChrome.setPreferredOrientations([
                                        DeviceOrientation.portraitUp,
                                        DeviceOrientation.portraitDown,
                                      ]);
                                    }
                                  },
                                ),
                                _BottomBarBtn(
                                  icon: Icons.search,
                                  label: 'Pesquisar',
                                  context: context,
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => quill.QuillToolbarSearchDialog(
                                        controller: _quillController,
                                        dialogTheme: quill.QuillDialogTheme(
                                          dialogBackgroundColor: Theme.of(context).cardColor,
                                        ),
                                        searchBarAlignment: Alignment.topCenter,
                                      ),
                                    );
                                  },
                                ),
                                _BottomBarBtn(
                                  icon: Icons.ios_share,
                                  label: 'Compartilhar',
                                  context: context,
                                  onTap: _generateAndSharePdf,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers de botão ─────────────────────────────────────────────────────────
class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final BuildContext? context;

  const _ToolbarBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    final iconColor = color ?? (context != null ? Theme.of(context!).colorScheme.onSurface.withValues(alpha: 0.7) : Colors.white70);
    return IconButton(
      icon: Icon(icon, color: iconColor, size: 22),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}

class _BottomBarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isActive;
  final BuildContext context;

  const _BottomBarBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.context,
    this.color,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext ctx) {
    final baseColor = color ?? Theme.of(context).colorScheme.onSurface;
    final activeColor = isActive ? Theme.of(context).colorScheme.primary : baseColor.withValues(alpha: 0.75);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: activeColor, size: 22),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormatBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _FormatBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      canRequestFocus: false,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: child,
      ),
    );
  }
}

class _FormatToggleBtn extends StatefulWidget {
  final IconData icon;
  final quill.Attribute attribute;
  final quill.QuillController controller;
  final bool isAlign;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? customColor;
  final VoidCallback? onPressed;
  final bool hideKeyboardOnTap;
  final double iconSize;
  final EdgeInsetsGeometry? padding;

  const _FormatToggleBtn({
    required this.icon,
    required this.attribute,
    required this.controller,
    this.isAlign = false,
    this.activeColor,
    this.inactiveColor,
    this.customColor,
    this.onPressed,
    this.hideKeyboardOnTap = false,
    this.iconSize = 24,
    this.padding,
    super.key,
  });

  @override
  State<_FormatToggleBtn> createState() => _FormatToggleBtnState();
}

class _FormatToggleBtnState extends State<_FormatToggleBtn> {
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _isActive = _isToggled();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      final toggled = _isToggled();
      if (_isActive != toggled) {
        setState(() => _isActive = toggled);
      }
    }
  }

  bool _isToggled() {
    final attrs = widget.controller.getSelectionStyle().attributes;
    if (widget.isAlign) {
      final alignAttr = attrs[quill.Attribute.align.key];
      if (widget.attribute.value == 'left' || widget.attribute == quill.Attribute.leftAlignment) {
        return alignAttr == null || alignAttr.value == 'left';
      }
      return alignAttr?.value == widget.attribute.value;
    }
    return attrs.containsKey(widget.attribute.key);
  }

  void _handleTap() {
    widget.onPressed?.call();
    if (widget.isAlign) {
      widget.controller.formatSelection(widget.attribute);
    } else {
      final toggled = _isToggled();
      widget.controller.formatSelection(
        toggled ? quill.Attribute.clone(widget.attribute, null) : widget.attribute,
      );
    }
    if (widget.hideKeyboardOnTap) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeColor ?? const Color(0xFF1E90FF);
    final inactive = widget.inactiveColor ?? widget.customColor ?? Colors.white70;
    final color = _isActive ? active : inactive;

    return InkWell(
      canRequestFocus: false,
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: _isActive
            ? BoxDecoration(
                color: active.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Icon(widget.icon, color: color, size: widget.iconSize),
      ),
    );
  }
}

class _VerseSelectorSheet extends StatefulWidget {
  final BibleChapter chapter;

  const _VerseSelectorSheet({required this.chapter});

  @override
  State<_VerseSelectorSheet> createState() => _VerseSelectorSheetState();
}

class _VerseSelectorSheetState extends State<_VerseSelectorSheet> {
  final Set<BibleVerse> _selected = {};

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final accentColor = isLight ? Theme.of(context).colorScheme.primary : const Color(0xFFD4AF37);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.chapter.book.name} ${widget.chapter.chapterNumber}',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected.toList()),
                  child: Text(
                    'Inserir (${_selected.length})',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.chapter.verses.length,
              itemBuilder: (context, index) {
                final verse = widget.chapter.verses[index];
                final isSelected = _selected.contains(verse);
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selected.remove(verse);
                        } else {
                          _selected.add(verse);
                        }
                      });
                    },
                    leading: isSelected 
                        ? Icon(Icons.check_circle, color: accentColor)
                        : Icon(Icons.circle_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                    title: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${verse.number}. ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? accentColor : Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            BibleTextParser.cleanToPlainText(verse.text),
                            style: TextStyle(
                              color: isSelected 
                                  ? Theme.of(context).colorScheme.onSurface 
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DictionarySearchSheet extends ConsumerStatefulWidget {
  const _DictionarySearchSheet();
  @override
  ConsumerState<_DictionarySearchSheet> createState() => _DictionarySearchSheetState();
}

class _DictionarySearchSheetState extends ConsumerState<_DictionarySearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedLetter;

  @override
  Widget build(BuildContext context) {
    final dictsMap = ref.watch(availableDictionariesListProvider);
    final dicts = dictsMap.entries.toList();
    final selectedFilename = ref.watch(selectedDictionaryProvider);
    
    final isValidSelection = dicts.any((e) => e.value == selectedFilename);
    final effectiveSelection = isValidSelection
        ? selectedFilename
        : (dicts.isNotEmpty ? dicts.first.value : null);

    final isLight = Theme.of(context).brightness == Brightness.light;
    final accentColor = isLight ? Theme.of(context).colorScheme.primary : const Color(0xFFD4AF37);
    final alphabet = List.generate(26, (i) => String.fromCharCode(65 + i));

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Seletor de Dicionário
          if (dicts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: effectiveSelection,
                    icon: Icon(Icons.expand_more, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    items: dicts.map((e) {
                      return DropdownMenuItem<String>(
                        value: e.value,
                        child: Text(e.key, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(selectedDictionaryProvider.notifier).state = val;
                      }
                    },
                  ),
                ),
              ),
            ),
            
          // Campo de Busca
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              autofocus: false, // Don't autofocus so they can see letters
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Buscar termo...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.search, color: accentColor),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                    });
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _query = val.trim();
                  if (_query.isNotEmpty) _selectedLetter = null; // Clear letter selection
                });
              },
            ),
          ),
          
          // Letras (Alfabeto)
          if (_query.isEmpty)
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: alphabet.length,
                itemBuilder: (context, index) {
                  final letter = alphabet[index];
                  final isSelected = _selectedLetter == letter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedLetter = letter;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? accentColor : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? accentColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected 
                                ? (isLight ? Colors.white : Colors.black) 
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          const SizedBox(height: 8),

          // Lista de Resultados
          Expanded(
            child: effectiveSelection == null
                ? Center(child: Text('Nenhum dicionário selecionado.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))))
                : (_query.isEmpty && _selectedLetter == null)
                    ? Center(
                        child: Text(
                          'Selecione uma letra ou digite para buscar.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      )
                    : (_query.isNotEmpty
                        ? ref.watch(dictionarySearchWordsProvider((dictId: effectiveSelection, query: _query)))
                        : ref.watch(dictionaryLetterWordsProvider((dictId: effectiveSelection, letter: _selectedLetter!))))
                      .when(
                        data: (words) {
                          if (words.isEmpty) {
                            return Center(
                              child: Text(
                                'Nenhum termo encontrado.',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                              ),
                            );
                          }
                          return ListView.builder(
                            itemCount: words.length,
                            itemBuilder: (context, index) {
                              final item = words[index];
                              final word = item['word']?.toString() ?? 'Sem termo';
                              final rawData = item['data']?.toString() ?? '';
                              final previewText = rawData.replaceAll(RegExp(r'<[^>]+>'), '').trim();

                              return Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  title: Text(
                                    word, 
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  subtitle: Text(
                                    previewText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context, (word, rawData));
                                  },
                                ),
                              );
                            },
                          );
                        },
                        loading: () => Center(child: CircularProgressIndicator(color: accentColor)),
                        error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.red))),
                      ),
          ),
        ],
      ),
    );
  }
}

