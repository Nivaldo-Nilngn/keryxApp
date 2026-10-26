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
import 'package:keryx_app/features/study/widgets/word_mobile_theme.dart';
import 'package:keryx_app/features/study/widgets/word_mobile_toolbar.dart';
import 'package:keryx_app/features/study/widgets/word_tablet_ribbon.dart';

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
  final bool forceMobileView;
  const NoteDetailScreen({
    super.key,
    required this.note,
    this.isCommunity = false,
    this.forceMobileView = false,
  });

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
  bool _isEditing = true;
  bool _showBars = true;
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

  void _insertSermonOutline() {
    const sermonText = '\nESBOÇO DE SERMÃO\n\n'
        'Título: \n'
        'Texto Base: \n'
        'Tema: \n\n'
        'I. INTRODUÇÃO\n'
        '• Gancho e conexão com os ouvintes\n'
        '• Contexto histórico e literário da passagem\n\n'
        'II. PONTOS PRINCIPAIS\n'
        '1. Exposição Bíblica\n'
        '2. Ilustração Prática\n'
        '3. Desafio Pessoal e Aplicação\n\n'
        'III. CONCLUSÃO E APELO\n'
        '• Recapitulação do tema\n'
        '• Oração e compromisso de fé\n\n';

    final index = _quillController.selection.baseOffset;
    _quillController.replaceText(index, 0, sermonText, null);
    _quillController.formatText(index + 1, 'ESBOÇO DE SERMÃO'.length, quill.Attribute.bold);
    _quillController.formatText(index + 1, 'ESBOÇO DE SERMÃO'.length, quill.Attribute.h2);
    _quillController.updateSelection(
      TextSelection.collapsed(offset: index + sermonText.length),
      quill.ChangeSource.local,
    );
  }

  void _insertDivider() {
    final index = _quillController.selection.baseOffset;
    const dividerText = '\n────────────────────────────────────────\n\n';
    _quillController.replaceText(index, 0, dividerText, null);
    _quillController.updateSelection(
      TextSelection.collapsed(offset: index + dividerText.length),
      quill.ChangeSource.local,
    );
  }

  void _insertDateTime() {
    final index = _quillController.selection.baseOffset;
    final now = DateTime.now();
    final formatted = '📅 ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} às ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _quillController.replaceText(index, 0, '$formatted\n\n', null);
    _quillController.updateSelection(
      TextSelection.collapsed(offset: index + formatted.length + 2),
      quill.ChangeSource.local,
    );
  }

  Future<void> _changePageColor(Color color) async {
    final updated = _note.copyWith(pageColor: color.toARGB32());
    await ref.read(noteCardsProvider.notifier).save(updated);
    if (mounted) {
      setState(() {
        _note = updated;
      });
    }
  }

  Future<void> _quickSave() async {
    final title = _titleCtrl.text.trim();
    final finalTitle = (title.isEmpty || title == 'Nova Nota' || title == 'Novo Tópico') ? 'Sem título' : title;
    final jsonContent = jsonEncode(_quillController.document.toDelta().toJson());
    final updated = _note.copyWith(
      title: finalTitle,
      body: jsonContent,
      isPublic: _isPublic,
    );
    setState(() => _saving = true);
    await ref.read(noteCardsProvider.notifier).save(updated);
    if (mounted) {
      setState(() {
        _note = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Documento salvo!', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: const Color(0xFF107C41),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareNote() {
    final text = _quillController.getPlainText();
    final title = _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Estudo Bíblico';
    Share.share(text, subject: title);
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
          builder: (context) => BibleSelectorBottomSheet(
            initialStage: SelectorStage.books,
            fullSelection: true,
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
    final currentChapter = chapterData;

    // 2. Definir os Versículos (específico ou capítulo inteiro)
    List<BibleVerse>? selectedVerses;
    if (result.verse != null) {
      final v = currentChapter.verses.firstWhere(
        (verse) => verse.number == result.verse,
        orElse: () => currentChapter.verses.first,
      );
      selectedVerses = [v];
    } else {
      selectedVerses = currentChapter.verses;
    }

    if (selectedVerses.isNotEmpty) {
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



  Future<void> _insertDictionaryWord() async {
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
        quill.Attribute.clone(quill.Attribute.bold, null),
      );
      _quillController.updateSelection(
        TextSelection.collapsed(offset: index + fullText.length),
        quill.ChangeSource.local,
      );
    }
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
        appBar: AppBar(
          backgroundColor: WordMobileTheme.primaryBlue,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Voltar',
            onPressed: () => Navigator.maybePop(context),
          ),
          title: TextField(
            controller: _titleCtrl,
            focusNode: _titleFocus,
            textAlign: TextAlign.start,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Documento...',
              hintStyle: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          actions: [
            if (!ResponsiveLayout.isCompact(context)) ...[
              // Tablet / Desktop: Ações limpas da barra superior (estilo Office / Word)
              IconButton(
                icon: Icon(
                  _saving ? Icons.hourglass_top_rounded : Icons.save_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: 'Salvar Documento',
                onPressed: _quickSave,
              ),
              IconButton(
                icon: Icon(
                  Icons.undo_rounded,
                  color: _quillController.hasUndo ? Colors.white : Colors.white38,
                  size: 22,
                ),
                onPressed: () {
                  if (_quillController.hasUndo) {
                    _quillController.undo();
                  }
                },
                tooltip: 'Desfazer',
              ),
              IconButton(
                icon: Icon(
                  Icons.redo_rounded,
                  color: _quillController.hasRedo ? Colors.white : Colors.white38,
                  size: 22,
                ),
                onPressed: () {
                  if (_quillController.hasRedo) {
                    _quillController.redo();
                  }
                },
                tooltip: 'Refazer',
              ),
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Colors.white),
                tooltip: 'Pesquisar',
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
            ] else ...[
              // Celular (Compact): Controles móveis com suporte a alternar edição/leitura
              IconButton(
                icon: Icon(
                  _isEditing ? Icons.edit_note_rounded : Icons.edit_outlined,
                  color: Colors.white,
                ),
                tooltip: _isEditing ? 'Modo de Edição Ativo' : 'Habilitar Edição',
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                    _quillController.readOnly = !_isEditing;
                  });
                  if (_isEditing) _editorFocus.requestFocus();
                },
              ),
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Colors.white),
                tooltip: 'Pesquisar',
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
              IconButton(
                icon: Icon(
                  _isMobileView ? Icons.phone_android_rounded : Icons.description_outlined,
                  color: Colors.white,
                ),
                tooltip: _isMobileView ? 'Layout Móvel (Reflow)' : 'Layout de Impressão (A4)',
                onPressed: () {
                  setState(() {
                    _isMobileView = !_isMobileView;
                    ref.read(sharedPreferencesProvider).setBool('note_is_mobile_view', _isMobileView);
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.undo_rounded, color: Colors.white, size: 22),
                onPressed: () {
                  if (_quillController.hasUndo) {
                    _quillController.undo();
                  }
                },
                tooltip: 'Desfazer',
              ),
              IconButton(
                icon: const Icon(Icons.redo_rounded, color: Colors.white, size: 22),
                onPressed: () {
                  if (_quillController.hasRedo) {
                    _quillController.redo();
                  }
                },
                tooltip: 'Refazer',
              ),
            ],

            if (_saving || _isGeneratingPdf)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onSelected: (value) {
                  if (value == 'pdf') _generateAndSharePdf();
                  if (value == 'save') _save();
                  if (value == 'verse') _insertBibleVerse();
                  if (value == 'dictionary') _insertDictionaryWord();
                  if (value == 'ai') _showAiAssistant();
                  if (value == 'sermon') _insertSermonOutline();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'save',
                    child: Row(
                      children: [
                        const Icon(Icons.save_rounded, color: WordMobileTheme.primaryBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Salvar Documento',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: WordMobileTheme.primaryBlue),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Exportar como PDF', style: GoogleFonts.outfit(), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'verse',
                    child: Row(
                      children: [
                        const Icon(Icons.auto_stories_rounded, color: WordMobileTheme.primaryBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Inserir Versículo Bíblico', style: GoogleFonts.outfit(), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'dictionary',
                    child: Row(
                      children: [
                        const Icon(Icons.book_rounded, color: Color(0xFF0078D4)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Inserir Termo do Dicionário', style: GoogleFonts.outfit(), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sermon',
                    child: Row(
                      children: [
                        const Icon(Icons.record_voice_over_outlined, color: Color(0xFFD83B01)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Inserir Esboço de Sermão', style: GoogleFonts.outfit(), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'ai',
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFF8E8CD8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Assistente Copilot IA', style: GoogleFonts.outfit(), overflow: TextOverflow.ellipsis),
                        ),
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
              // ── Faixa de Opções (Ribbon Toolbar) Nativa para Tablets ──
              if (!ResponsiveLayout.isCompact(context))
                WordTabletRibbonBar(
                  controller: _quillController,
                  onInsertBibleVerse: _insertBibleVerse,
                  onOpenAiAssistant: _showAiAssistant,
                  onInsertSermonOutline: _insertSermonOutline,
                  onInsertQuoteBox: () => _insertCustomText('💬 CITAÇÃO', 'Insira seu texto em destaque aqui...', '', isQuote: true),
                  onInsertDivider: _insertDivider,
                  onInsertDateTime: _insertDateTime,
                  onToggleViewMode: () => setState(() {
                    _isMobileView = !_isMobileView;
                    ref.read(sharedPreferencesProvider).setBool('note_is_mobile_view', _isMobileView);
                  }),
                  isMobileView: _isMobileView,
                  currentZoom: _zoomLevel,
                  onZoomChanged: (z) => setState(() => _zoomLevel = z),
                  onChangePageColor: _changePageColor,
                  onExportPdf: _generateAndSharePdf,
                  onShare: _shareNote,
                  onQuickSave: _quickSave,
                  isSaving: _saving,
                ),

              // ── Documento (modo celular ou print) ─────────────────────────────
              Expanded(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: double.infinity,
                  child: _isMobileView ? _buildMobileView() : _buildPrintView(),
                ),
              ),

              // ── Modo Word Mobile: Lower Ribbon Expandido (replaces keyboard) ──
              if (ResponsiveLayout.isCompact(context) && _showFormattingBar)
                WordMobileLowerRibbon(
                  controller: _quillController,
                  onClose: () => setState(() => _showFormattingBar = false),
                  onInsertBibleVerse: _insertBibleVerse,
                  onOpenAiAssistant: _showAiAssistant,
                  onInsertSermonOutline: _insertSermonOutline,
                  onInsertQuoteBox: () => _insertCustomText('💬 CITAÇÃO', 'Insira seu texto em destaque aqui...', '', isQuote: true),
                  onToggleViewMode: () => setState(() {
                    _isMobileView = !_isMobileView;
                    ref.read(sharedPreferencesProvider).setBool('note_is_mobile_view', _isMobileView);
                  }),
                  isMobileView: _isMobileView,
                  currentZoom: _zoomLevel,
                  onZoomChanged: (z) => setState(() => _zoomLevel = z),
                ),

              // ── Modo Word Mobile: Barra de Ações Rápidas (docked sobre o teclado) ──
              if (ResponsiveLayout.isCompact(context) && _isEditing && !_showFormattingBar)
                WordMobileQuickToolbar(
                  controller: _quillController,
                  isRibbonOpen: _showFormattingBar,
                  onToggleRibbon: () {
                    setState(() {
                      _showFormattingBar = true;
                    });
                    SystemChannels.textInput.invokeMethod('TextInput.hide');
                    FocusScope.of(context).unfocus();
                  },
                  onInsertBibleVerse: _insertBibleVerse,
                  onOpenAiAssistant: _showAiAssistant,
                  onSelectFontColor: (c) {
                    final hex = '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                    _quillController.formatSelection(quill.ColorAttribute(hex));
                  },
                  onSelectHighlight: (c) {
                    if (c == null) {
                      _quillController.formatSelection(quill.BackgroundAttribute('#00000000'));
                    } else {
                      final hex = '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                      _quillController.formatSelection(quill.BackgroundAttribute(hex));
                    }
                  },
                ),

              // ── Modo Leitura (Reading mode footer bar) ──
              if (ResponsiveLayout.isCompact(context) && !_isEditing && !_showFormattingBar)
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            icon: const Icon(Icons.edit_note_rounded, color: WordMobileTheme.primaryBlue, size: 20),
                            label: Text('Editar', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: WordMobileTheme.primaryBlue, fontSize: 13)),
                            onPressed: () {
                              setState(() {
                                _isEditing = true;
                                _quillController.readOnly = false;
                              });
                              _editorFocus.requestFocus();
                            },
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            icon: Icon(_isMobileView ? Icons.description_outlined : Icons.phone_android_rounded, size: 20),
                            label: Text(_isMobileView ? 'A4' : 'Móvel', style: GoogleFonts.outfit(fontSize: 13)),
                            onPressed: () {
                              setState(() {
                                _isMobileView = !_isMobileView;
                                ref.read(sharedPreferencesProvider).setBool('note_is_mobile_view', _isMobileView);
                              });
                            },
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
                            label: Text('Exportar PDF', style: GoogleFonts.outfit(fontSize: 13)),
                            onPressed: _generateAndSharePdf,
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

