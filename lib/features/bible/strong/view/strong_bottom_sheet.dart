import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:keryx_app/core/widgets/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/study/repository/strong_repository.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:keryx_app/core/services/tts/tts_service.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';
import 'package:keryx_app/features/bible/reading/view/text_settings_bottom_sheet.dart';

void showStrongBottomSheet(
  BuildContext context,
  String strongId,
  String wordClicked,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => StrongBottomSheet(
        strongId: strongId,
        wordClicked: wordClicked,
      ),
    ),
  );
}

class StrongBottomSheet extends ConsumerStatefulWidget {
  final String strongId;
  final String wordClicked;

  const StrongBottomSheet({
    super.key,
    required this.strongId,
    required this.wordClicked,
  });

  @override
  ConsumerState<StrongBottomSheet> createState() => _StrongBottomSheetState();
}

class _StrongBottomSheetState extends ConsumerState<StrongBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  bool _isSpeakingDef = false;

  Color get _surfaceBase => Theme.of(context).scaffoldBackgroundColor;
  Color get _surfaceElevated => Theme.of(context).cardColor;
  Color get _surfaceCard => Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
  Color get _secondaryColor => const Color(0xFFFFB95F);
  Color get _primaryContainer => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _flutterTts = FlutterTts();
    if (!kIsWeb) {
      try {
        _flutterTts.setEngine("com.google.android.tts");
      } catch (_) {}
    }
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speakDefinition(String text) async {
    final ttsService = ref.read(ttsServiceProvider);
    
    if (_isSpeakingDef) {
      await ttsService.stop();
      if (mounted) setState(() => _isSpeakingDef = false);
      return;
    }
    
    if (mounted) setState(() => _isSpeakingDef = true);
    
    final plainText = text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
    final selectedVoice = ref.read(ttsSelectedVoiceProvider);
    await ttsService.speak(plainText, voice: selectedVoice);
  }

  Future<void> _speak(String text, {bool isHebrew = false}) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    
    if (mounted) setState(() => _isSpeaking = true);
    
    // Para a palavra original com caracteres especiais, DEVEMOS usar a pronúncia nativa
    // (Hebraico ou Grego), ignorando a voz selecionada em português.
    await _flutterTts.setLanguage(isHebrew ? 'he-IL' : 'el-GR');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    
    // Remove os sinais massoréticos/niqqud (vogais do hebraico bíblico) 
    // porque os motores TTS modernos muitas vezes se confundem e soletram as letras!
    String cleanText = text;
    if (isHebrew) {
      cleanText = text.replaceAll(RegExp(r'[\u0591-\u05C7]'), '');
    }
    
    await _flutterTts.speak(cleanText);
  }

  Future<void> _speakTranslit(String translit) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    
    if (mounted) setState(() => _isSpeaking = true);
    
    // A transliteração do dicionário Strong é baseada na fonética do INGLÊS.
    // Se usarmos português, ele tentará soletrar a palavra!
    // Limpamos pontuações estranhas que possam fazer a TTS soletrar.
    String cleanTranslit = translit.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').toLowerCase();
    
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(cleanTranslit);
  }

  String _normalizeStrongId(String tag) {
    String normalized = tag
        .replaceAll(RegExp(r'<[^\>]+>'), '')
        .trim()
        .toUpperCase();
    if (normalized.startsWith('SGE')) {
      normalized = normalized.replaceFirst('SGE', 'G');
    } else if (normalized.startsWith('SHE')) {
      normalized = normalized.replaceFirst('SHE', 'H');
    } else if (normalized.startsWith('WG')) {
      normalized = normalized.replaceFirst('WG', 'G');
    } else if (normalized.startsWith('WH')) {
      normalized = normalized.replaceFirst('WH', 'H');
    } else if (normalized.startsWith('SG')) {
      normalized = normalized.replaceFirst('SG', 'G');
    } else if (normalized.startsWith('SH')) {
      normalized = normalized.replaceFirst('SH', 'H');
    }

    final baseMatch = RegExp(r'^([HG]\d+)').firstMatch(normalized);
    if (baseMatch != null) {
      return baseMatch.group(1)!;
    }
    return normalized;
  }

  String _cleanTags(String text) {
    return text
        .replaceAll(RegExp(r'<[HhGg]\d+>?'), '')
        .replaceAll(RegExp(r'<[^\>]+>'), '')
        .trim();
  }

  TextStyle _getLexiconTextStyle(
    FontSettings fontSettings, {
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? height,
  }) {
    final size = fontSize ?? fontSettings.fontSize;
    final family = fontSettings.fontFamily;
    if (CustomFontLoader.loadedFontFamilies.contains(family)) {
      return TextStyle(
        fontFamily: family,
        fontSize: size,
        color: color ?? _textPrimary.withValues(alpha: 0.88),
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        height: height ?? 1.6,
      );
    }
    try {
      return GoogleFonts.getFont(
        family,
        fontSize: size,
        color: color ?? _textPrimary.withValues(alpha: 0.88),
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        height: height ?? 1.6,
      );
    } catch (_) {
      return GoogleFonts.merriweather(
        fontSize: size,
        color: color ?? _textPrimary.withValues(alpha: 0.88),
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        height: height ?? 1.6,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final cleanId = _normalizeStrongId(widget.strongId);
    final dictionaryFallback = ref.watch(
      dictionaryProvider((dictId: 'STRONG (BR).dct.mybible', word: cleanId)),
    );
    final strongEntry = ref.watch(strongEntryProvider(cleanId));

    Widget buildTab1(ScrollController sc) {
      return strongEntry.when(
        data: (entryMap) {
          if (entryMap != null) {
            return _buildDictionaryTabMap(entryMap, cleanId, sc, fontSettings);
          } else {
            return dictionaryFallback.when(
              data: (def) => def != null && def.isNotEmpty
                  ? _buildDictionaryTabFallback(def, sc, fontSettings)
                  : _emptyState(),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _emptyState(),
            );
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _emptyState(),
      );
    }

    Widget buildTab2(ScrollController sc) {
      return strongEntry.when(
        data: (entryMap) {
          if (entryMap != null) {
            return _buildConcordanceTabMap(entryMap, sc, fontSettings);
          } else {
            return _emptyState();
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _emptyState(),
      );
    }

    final isExpanded = ResponsiveLayout.isExpanded(context);
    final sc1 = ScrollController();
    final sc2 = ScrollController();

    return Scaffold(
      backgroundColor: _surfaceBase,
      appBar: AppBar(
        backgroundColor: _surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _textPrimary, size: 24),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Voltar',
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.wordClicked,
              style: GoogleFonts.plusJakartaSans(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'LÉXICO E CONCORDÂNCIA • $cleanId',
              style: GoogleFonts.outfit(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.tune_rounded, color: _textSecondary, size: 22),
            tooltip: 'Configurações de Leitura & Strong',
            onPressed: () => showTextSettingsBottomSheet(context, isStrongVersion: true),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: _surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _textPrimary.withValues(alpha: 0.05)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: _textPrimary,
              unselectedLabelColor: _textSecondary,
              labelStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
              unselectedLabelStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'DICIONÁRIO'),
                Tab(text: 'CONCORDÂNCIA'),
              ],
            ),
          ),
        ),
      ),
      body: isExpanded
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'DICIONÁRIO',
                          style: GoogleFonts.outfit(
                            color: _textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: buildTab1(sc1)),
                    ],
                  ),
                ),
                Container(width: 1, color: _textPrimary.withValues(alpha: 0.1)),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'CONCORDÂNCIA',
                          style: GoogleFonts.outfit(
                            color: _textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: buildTab2(sc2)),
                    ],
                  ),
                ),
              ],
            )
          : TabBarView(
              controller: _tabController,
              children: [
                buildTab1(sc1),
                buildTab2(sc2),
              ],
            ),
    );
  }


  Widget _buildConcordanceTabMap(
    Map<String, dynamic> entry,
    ScrollController scrollController,
    FontSettings fontSettings,
  ) {
    // Agora buscaremos a concordância viva (pesquisa direta no banco)
    return Consumer(
      builder: (context, ref, _) {
        final asyncConcordance = ref.watch(strongConcordanceProvider(widget.strongId));
        
        return asyncConcordance.when(
          data: (verses) {
            if (verses.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Nenhuma conexão encontrada para esta palavra.',
                    style: GoogleFonts.outfit(color: _textSecondary),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      '${verses.length} CONEX${verses.length == 1 ? 'ÃO' : 'ÕES'} ENCONTRADA${verses.length == 1 ? '' : 'S'}',
                      style: GoogleFonts.outfit(
                        color: _textPrimary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: verses.length,
                      itemBuilder: (context, index) {
                        final v = verses[index];
                        final bookName = BibleMetadata.getBookName(v['book_id'] as int);
                        final refText = '$bookName ${v['chapter']}:${v['verse']}';
                        
                        // Limpar texto de outras tags Strong
                        var cleanText = v['text'].toString()
                            .replaceAll(RegExp(r'<[HhGg]\d+>?'), '')
                            .replaceAll(RegExp(r'<[^>]+>'), '');
                            
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              final bookNum = v['book_id'] as int;
                              final chapterNum = v['chapter'] as int;
                              
                              final bookDetails = BibleMetadata.bookDetails[bookNum]!;
                              final book = BibleBook(
                                id: bookNum,
                                abbrev: bookDetails['abbrev'],
                                name: BibleMetadata.bookNames[bookNum]!,
                                chapters: bookDetails['chapters'],
                                author: bookDetails['author'] ?? 'Desconhecido',
                                group: bookDetails['group'] ?? 'Antigo Testamento',
                              );
                              
                              Navigator.pop(context); // Fecha o bottom sheet do Strong
                              
                              // Navega para o versículo na Bíblia
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReadingScreen(
                                    book: book,
                                    initialChapter: chapterNum,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _surfaceElevated.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _textPrimary.withValues(alpha: 0.05)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.bookmark_outline_rounded, color: _secondaryColor, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        refText,
                                        style: GoogleFonts.outfit(
                                          color: _textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: (fontSettings.fontSize * 0.9).clamp(13.0, 18.0),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    cleanText,
                                    style: _getLexiconTextStyle(
                                      fontSettings,
                                      fontSize: fontSettings.fontSize,
                                      color: _textPrimary.withValues(alpha: 0.88),
                                      height: 1.6,
                                    ),
                                  ),
                                ],
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
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Center(
            child: Text(
              'Erro ao buscar conexões: $err',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        );
      },
    );
  }


  Widget _buildDictionaryTabMap(
    Map<String, dynamic> entry,
    String cleanId,
    ScrollController scrollController,
    FontSettings fontSettings,
  ) {
    final palavraOriginal = (entry['PALAVRA_ORIGINAL'] ?? '').toString();
    final pronuncia = (entry['PRONUNCIA'] ?? '').toString();
    final traducao = (entry['TRADUCAO'] ?? '').toString();
    final classe = (entry['CLASSE_GRAMATICAL'] ?? 'Não classificado')
        .toString();
    final definicao = _cleanTags((entry['DEFINICAO_STRONG'] ?? '').toString());
    final significado = _cleanTags((entry['SIGNIFICADO'] ?? '').toString());
    final anotacao = _cleanTags((entry['ANOTACAO'] ?? '').toString());
    final origem = _cleanTags((entry['ORIGEM_PALAVRA'] ?? '').toString());
    final isHebrew = cleanId.startsWith('H');

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Palavra original hebraica/grega grande + botão de áudio
          if (palavraOriginal.isNotEmpty) ...[
            Center(
              child: Column(
                children: [
                  Text(
                    palavraOriginal,
                    style: GoogleFonts.notoSerif(
                      color: _textPrimary,
                      fontSize: 48,
                      fontWeight: FontWeight.w400,
                    ).copyWith(
                      fontFamilyFallback: const [
                        'Noto Serif',
                        'Times New Roman',
                        'Georgia',
                        'serif',
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (pronuncia.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      pronuncia,
                      style: GoogleFonts.merriweather(
                        color: _textSecondary,
                        fontSize: (fontSettings.fontSize * 1.05).clamp(14.0, 24.0),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Botão de áudio
                  GestureDetector(
                    onTap: () {
                      if (pronuncia.isNotEmpty) {
                        _speakTranslit(pronuncia);
                      } else {
                        _speak(palavraOriginal, isHebrew: isHebrew);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSpeaking
                            ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
                            : _surfaceElevated,
                        border: Border.all(
                          color: _isSpeaking
                              ? const Color(0xFF4F46E5)
                              : _textPrimary.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _isSpeaking
                            ? Icons.stop_rounded
                            : Icons.volume_up_rounded,
                        color: _isSpeaking
                            ? const Color(0xFF4F46E5)
                            : _textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Cards: Transliteração + Classe Gramatical
          Row(
            children: [
              if (pronuncia.isNotEmpty)
                Expanded(
                  child: _buildInfoCard(
                    'TRANSLITERAÇÃO',
                    pronuncia,
                    isHighlight: false,
                    fontSize: (fontSettings.fontSize * 0.95).clamp(13.0, 20.0),
                  ),
                )
              else
                Expanded(
                  child: _buildInfoCard(
                    'CÓDIGO',
                    cleanId,
                    isHighlight: true,
                    fontSize: (fontSettings.fontSize * 0.95).clamp(13.0, 20.0),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'CLASSE',
                  classe,
                  fontSize: (fontSettings.fontSize * 0.95).clamp(13.0, 20.0),
                ),
              ),
            ],
          ),

          // Card: Tradução
          if (traducao.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoCard(
              'TRADUÇÃO',
              traducao,
              isHighlight: true,
              fullWidth: true,
              fontSize: (fontSettings.fontSize * 0.95).clamp(13.0, 20.0),
            ),
          ],

          const SizedBox(height: 20),

          // Definição Léxica
          if (significado.isNotEmpty || definicao.isNotEmpty)
            _buildDefinitionBox(
              'DEFINIÇÃO LÉXICA',
              Icons.info_outline_rounded,
              significado,
              definicao,
              fontSettings,
            ),

          // Origem
          if (origem.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSimpleBox(
              'ORIGEM DA PALAVRA',
              Icons.history_edu_rounded,
              origem,
              fontSettings,
            ),
          ],

          // Notas/Anotação
          if (anotacao.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSimpleBox(
              'NOTAS',
              Icons.auto_awesome_rounded,
              anotacao,
              fontSettings,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDictionaryTabFallback(
    String definition,
    ScrollController scrollController,
    FontSettings fontSettings,
  ) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'CÓDIGO',
                  widget.strongId,
                  isHighlight: true,
                  fontSize: (fontSettings.fontSize * 0.95).clamp(13.0, 20.0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'FONTE',
                  'Web / IA',
                  fontSize: (fontSettings.fontSize * 0.95).clamp(13.0, 20.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDefinitionBox(
            'DEFINIÇÃO LÉXICA',
            Icons.info_outline_rounded,
            '',
            definition,
            fontSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String label,
    String value, {
    bool isHighlight = false,
    bool fullWidth = false,
    double? fontSize,
  }) {
    final valueSize = fontSize ?? 15.0;
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isHighlight
            ? _primaryContainer.withValues(alpha: 0.15)
            : _surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: isHighlight
            ? Border.all(color: _primaryContainer.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: isHighlight
                  ? _primaryContainer.withValues(alpha: 0.8)
                  : _textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: _textPrimary,
              fontSize: valueSize,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDefinitionBox(
    String title,
    IconData icon,
    String significado,
    String definicao,
    FontSettings fontSettings,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _textPrimary.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Row(
            children: [
              Icon(icon, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _isSpeakingDef ? Icons.stop_circle : Icons.volume_up,
                  color: _isSpeakingDef ? Colors.redAccent : _textPrimary.withValues(alpha: 0.7),
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _speakDefinition('$significado. $definicao');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Significado (resumo curto em destaque)
          if (significado.isNotEmpty) ...[
            Text(
              significado,
              style: GoogleFonts.outfit(
                color: _textPrimary,
                fontSize: (fontSettings.fontSize + 2).clamp(16.0, 28.0),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            if (definicao.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(color: _textPrimary.withValues(alpha: 0.07)),
              const SizedBox(height: 14),
            ],
          ],

          // Definição completa - linha por linha
          if (definicao.isNotEmpty) ..._buildDefinitionLines(definicao, fontSettings),
        ],
      ),
    );
  }

  List<Widget> _buildDefinitionLines(String definicao, FontSettings fontSettings) {
    // Separa por ponto e vírgula ou ponto final para criar linhas distintas
    final lines = definicao
        .split(RegExp(r'(?<=[.;:])\s+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length <= 1) {
      // Texto sem pontuação estruturada — exibe direto
      return [
        Text(
          definicao,
          style: _getLexiconTextStyle(
            fontSettings,
            fontSize: fontSettings.fontSize,
            color: _textPrimary.withValues(alpha: 0.88),
            fontStyle: FontStyle.italic,
            height: 1.7,
          ),
        ),
      ];
    }

    return lines.asMap().entries.map((e) {
      final line = e.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 7, right: 10),
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                line,
                style: _getLexiconTextStyle(
                  fontSettings,
                  fontSize: fontSettings.fontSize,
                  color: _textPrimary.withValues(alpha: 0.88),
                  fontStyle: FontStyle.italic,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSimpleBox(
    String title,
    IconData icon,
    String content,
    FontSettings fontSettings,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _textPrimary.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _secondaryColor, size: 18),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: _textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            content,
            style: _getLexiconTextStyle(
              fontSettings,
              fontSize: fontSettings.fontSize,
              color: _textPrimary.withValues(alpha: 0.88),
              fontStyle: FontStyle.italic,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_rounded,
            color: _textSecondary.withValues(alpha: 0.3),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma definição encontrada.',
            style: GoogleFonts.outfit(color: _textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Use a versão ARA_S para acessar o léxico completo.',
            style: GoogleFonts.outfit(
              color: _textSecondary.withValues(alpha: 0.6),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
