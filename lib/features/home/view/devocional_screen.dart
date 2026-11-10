import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/theme/app_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';
import 'package:keryx_app/core/services/tts/web_tts_helper.dart';
import 'package:keryx_app/features/home/service/devocional_service.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/features/bible/reading/view/text_settings_bottom_sheet.dart';
import 'package:keryx_app/features/bible/view/tts_settings_sheet.dart';

class DevocionalScreen extends ConsumerStatefulWidget {
  final DevocionalData devocional;

  const DevocionalScreen({super.key, required this.devocional});

  @override
  ConsumerState<DevocionalScreen> createState() => _DevocionalScreenState();
}

class _DevocionalScreenState extends ConsumerState<DevocionalScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  int _currentPartIndex = 0;
  List<String> _speechParts = [];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    if (kIsWeb) return;

    try {
      final langResult = await _flutterTts.setLanguage("pt-BR");
      if (langResult == 0) {
        await _flutterTts.setLanguage("pt");
      }
    } catch (_) {}

    try {
      await _flutterTts.setVolume(1.0);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final rate = prefs.getDouble('tts_speech_rate') ?? 0.48;
      final pitch = prefs.getDouble('tts_pitch') ?? 1.0;
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.setPitch(pitch);

      final voiceName = prefs.getString('tts_voice_name');
      final voiceLocale = prefs.getString('tts_voice_locale');
      if (voiceName != null && voiceLocale != null && voiceName.isNotEmpty) {
        await _flutterTts.setVoice({"name": voiceName, "locale": voiceLocale});
      }
    } catch (_) {}

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isPlaying = true);
    });

    _flutterTts.setCompletionHandler(() {
      if (!mounted) return;
      if (_isPlaying && _currentPartIndex + 1 < _speechParts.length) {
        _currentPartIndex++;
        Future.delayed(const Duration(milliseconds: 260), () {
          if (mounted && _isPlaying) {
            _speakCurrentPart();
          }
        });
      } else {
        if (mounted) setState(() => _isPlaying = false);
      }
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint("🗣️ TTS Erro DevocionalScreen: $msg");
      if (mounted) {
        setState(() => _isPlaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voz em português não disponível ou sintetizador desativado.'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  List<String> _buildSpeechParts() {
    final List<String> parts = [];

    if (widget.devocional.title.trim().isNotEmpty) {
      parts.add(widget.devocional.title.trim());
    }

    if (widget.devocional.verse.trim().isNotEmpty) {
      parts.add(widget.devocional.verse.trim());
    }

    if (widget.devocional.verseReference.trim().isNotEmpty) {
      final cleanRef = widget.devocional.verseReference
          .replaceAll('—', '')
          .replaceAll('(', '')
          .replaceAll(')', '')
          .trim();
      if (cleanRef.isNotEmpty) parts.add(cleanRef);
    }

    final rawParagraphs = widget.devocional.content.split(RegExp(r'\n+'));
    for (final p in rawParagraphs) {
      final clean = p
          .replaceAll('*', '')
          .replaceAll('_', '')
          .replaceAll('“', '"')
          .replaceAll('”', '"')
          .trim();
      if (clean.isNotEmpty) {
        parts.add(clean);
      }
    }

    return parts;
  }

  Future<void> _speakCurrentPart() async {
    if (_currentPartIndex < 0 || _currentPartIndex >= _speechParts.length) {
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    final text = _speechParts[_currentPartIndex].trim();
    if (text.isEmpty) {
      if (_currentPartIndex + 1 < _speechParts.length) {
        _currentPartIndex++;
        _speakCurrentPart();
      } else {
        if (mounted) setState(() => _isPlaying = false);
      }
      return;
    }

    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.speak(text, focus: true);
    } catch (e) {
      debugPrint("Erro ao falar parte $_currentPartIndex: $e");
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  // ── TTS: Leitura em voz alta controlada por handlers nativos ─────────────────
  Future<void> _toggleTts() async {
    if (_isPlaying) {
      if (mounted) setState(() => _isPlaying = false);
      if (kIsWeb) {
        WebTtsHelper.stop();
      } else {
        await _flutterTts.stop();
      }
      return;
    }

    _speechParts = _buildSpeechParts();
    if (_speechParts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum texto disponível para leitura.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (kIsWeb) {
      if (mounted) setState(() => _isPlaying = true);
      WebTtsHelper.speakQueue(
        texts: _speechParts,
        onStart: () {
          if (mounted) setState(() => _isPlaying = true);
        },
        onFinished: () {
          if (mounted) setState(() => _isPlaying = false);
        },
        onError: () {
          if (mounted) setState(() => _isPlaying = false);
        },
      );
      return;
    }

    _currentPartIndex = 0;
    if (mounted) setState(() => _isPlaying = true);
    await _speakCurrentPart();
  }

  void _shareDevocional() {
    final text = '''
✨ *${widget.devocional.title}*
📖 Devocional Diário • KeryxApp

"${widget.devocional.verse}"
— ${widget.devocional.verseReference}

${widget.devocional.content}
''';
    try {
      SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: 'Devocional: ${widget.devocional.title}',
        ),
      );
    } catch (e) {
      debugPrint('Erro ao compartilhar devocional: $e');
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WebTtsHelper.stop();
    } else {
      _flutterTts.stop();
    }
    super.dispose();
  }

  TextStyle _getDevocionalTextStyle(
    String fontName, {
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
    FontStyle? fontStyle,
    double? height,
  }) {
    if (CustomFontLoader.loadedFontFamilies.contains(fontName)) {
      return TextStyle(
        fontFamily: fontName,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontStyle: fontStyle,
        height: height,
      );
    }
    try {
      return GoogleFonts.getFont(
        fontName,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontStyle: fontStyle,
        height: height,
      );
    } catch (_) {
      return TextStyle(
        fontFamily: fontName,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontStyle: fontStyle,
        height: height,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuta as configurações de leitura (fontSettingsProvider)
    final fontSettings = ref.watch(fontSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Cores dinâmicas de acordo com as configurações de leitura
    final textColor = fontSettings.textColor != null
        ? Color(fontSettings.textColor!)
        : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B));

    final accentColor = fontSettings.badgeColor != null
        ? Color(fontSettings.badgeColor!)
        : (isDark ? AppTheme.kPrimaryGold : const Color(0xFF4F46E5));

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomPadding = bottomInset + 40.0;

    return SelectionArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leadingWidth: 44,
        leading: IconButton(
          tooltip: 'Voltar',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _isPlaying ? 'LENDO DEVOCIONAL' : 'DEVOCIONAL DO DIA',
                    style: GoogleFonts.outfit(
                      color: _isPlaying ? Colors.redAccent : accentColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isPlaying) ...[
                  const SizedBox(width: 6),
                  const SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 1),
            Text(
              widget.devocional.title,
              style: _getDevocionalTextStyle(
                fontSettings.fontFamily,
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Compartilhar Devocional
          IconButton(
            tooltip: 'Compartilhar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 38, height: 40),
            icon: Icon(
              Icons.share_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
            onPressed: _shareDevocional,
          ),
          // Ouvir em voz alta (TTS)
          GestureDetector(
            onLongPress: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const TtsSettingsSheet(),
              );
            },
            child: IconButton(
              tooltip: _isPlaying ? 'Parar leitura' : 'Ouvir devocional (segure para vozes)',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 38, height: 40),
              icon: Icon(
                _isPlaying ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                color: _isPlaying ? Colors.redAccent : accentColor,
                size: 23,
              ),
              onPressed: _toggleTts,
            ),
          ),
          // Configurações com layout modelado para o Devocional
          IconButton(
            tooltip: 'Aparência e Leitura',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 38, height: 40),
            icon: Icon(
              Icons.tune_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 21,
            ),
            onPressed: () => showTextSettingsBottomSheet(
              context,
              isDevocional: true,
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Tag de Categoria com Linha Divisória Sutil
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'REFLEXÃO ESPIRITUAL',
                          style: GoogleFonts.outfit(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2. Título da Reflexão
                  Text(
                    widget.devocional.title,
                    style: _getDevocionalTextStyle(
                      fontSettings.fontFamily,
                      fontSize: (fontSettings.fontSize + 4).clamp(18.0, 28.0),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Citação do Versículo Base (Card Único, Compacto e Elegante)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
                          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                          color: accentColor,
                          width: 3.5,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.devocional.verse.startsWith('“') || widget.devocional.verse.startsWith('"')
                              ? widget.devocional.verse
                              : '“${widget.devocional.verse}”',
                          style: _getDevocionalTextStyle(
                            fontSettings.fontFamily,
                            fontSize: (fontSettings.fontSize - 1).clamp(13.0, 24.0),
                            fontStyle: FontStyle.italic,
                            color: textColor,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '— ${widget.devocional.verseReference}',
                            style: GoogleFonts.outfit(
                              color: accentColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Texto do Devocional diagramado por parágrafos com links bíblicos
                  _buildContentWithLinks(
                    context,
                    ref,
                    widget.devocional.content,
                    fontSettings,
                    textColor,
                    accentColor,
                  ),
                  const SizedBox(height: 36),

                  // 5. Botão para ler o capítulo na Bíblia
                  InkWell(
                    onTap: () {
                      final books = ref.read(booksProvider).value ?? [];
                      if (books.isNotEmpty) {
                        String refParts = widget.devocional.verseReference.replaceAll('—', '').trim();
                        final bookNameOrAbbrev = refParts.split(RegExp(r'\s+')).first.toLowerCase();

                        final book = books.firstWhere(
                          (b) =>
                              b.name.toLowerCase() == bookNameOrAbbrev ||
                              b.abbrev.toLowerCase() == bookNameOrAbbrev ||
                              refParts.toLowerCase().startsWith(b.name.toLowerCase()) ||
                              refParts.toLowerCase().startsWith('${b.name.toLowerCase()} '),
                          orElse: () => books.firstWhere(
                            (b) => b.name == 'Salmos' || b.abbrev.toLowerCase() == 'sl',
                            orElse: () => books.first,
                          ),
                        );

                        int chapter = 1;
                        final match = RegExp(r'(\d+):').firstMatch(refParts);
                        if (match != null) {
                          chapter = int.tryParse(match.group(1) ?? '1') ?? 1;
                        }

                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => Container(
                            height: MediaQuery.of(context).size.height * 0.9,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                            ),
                            child: ReadingScreen(
                              book: book,
                              initialChapter: chapter,
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.auto_stories,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Ler Capítulo Completo',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 6. Botão secundário: Compartilhar
                  OutlinedButton.icon(
                    onPressed: _shareDevocional,
                    icon: Icon(Icons.share_rounded, size: 20, color: accentColor),
                    label: Text(
                      'Compartilhar Devocional',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      side: BorderSide(color: accentColor.withValues(alpha: 0.4), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildContentWithLinks(
    BuildContext context,
    WidgetRef ref,
    String content,
    FontSettings fontSettings,
    Color contentTextColor,
    Color linkColor,
  ) {
    // Separa os parágrafos do devocional para diagramação elegante
    final paragraphs = content
        .split(RegExp(r'\n{2,}|\r\n\r\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      return _buildParagraphWithLinks(
        context,
        ref,
        content,
        fontSettings,
        contentTextColor,
        linkColor,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 18.0),
          child: _buildParagraphWithLinks(
            context,
            ref,
            paragraph,
            fontSettings,
            contentTextColor,
            linkColor,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildParagraphWithLinks(
    BuildContext context,
    WidgetRef ref,
    String paragraph,
    FontSettings fontSettings,
    Color contentTextColor,
    Color linkColor,
  ) {
    // Regex para encontrar referências bíblicas como "Atos 1:8", "Mateus 5:13-16", "1 João 3:1"
    final refRegex = RegExp(r'([1-3]?\s?[A-ZÇÃ][a-záãçéíóú]+\s+\d+:\d+(?:-\d+)?)');
    final matches = refRegex.allMatches(paragraph);

    final baseStyle = _getDevocionalTextStyle(
      fontSettings.fontFamily,
      fontSize: fontSettings.fontSize,
      color: contentTextColor,
      height: 1.7,
    );

    if (matches.isEmpty) {
      return Text(
        paragraph,
        style: baseStyle,
      );
    }

    List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: paragraph.substring(lastMatchEnd, match.start)));
      }

      final verseRef = match.group(0)!;
      spans.add(TextSpan(
        text: verseRef,
        style: _getDevocionalTextStyle(
          fontSettings.fontFamily,
          fontSize: fontSettings.fontSize,
          fontWeight: FontWeight.bold,
          color: linkColor,
        ).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: linkColor.withValues(alpha: 0.6),
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            _showVerseModal(context, ref, verseRef, fontSettings, accentColor: linkColor);
          },
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < paragraph.length) {
      spans.add(TextSpan(text: paragraph.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: spans,
      ),
    );
  }

  void _showVerseModal(
    BuildContext context,
    WidgetRef ref,
    String reference,
    FontSettings fontSettings, {
    required Color accentColor,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.auto_stories, color: accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reference,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: FutureBuilder<String>(
          future: _fetchVerseText(ref, reference),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(color: accentColor),
                ),
              );
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Text(
                'Não foi possível carregar os versículos.',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              );
            }
            return SingleChildScrollView(
              child: Text(
                snapshot.data!,
                style: _getDevocionalTextStyle(
                  fontSettings.fontFamily,
                  fontSize: fontSettings.fontSize,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.6,
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'FECHAR',
              style: GoogleFonts.outfit(
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _fetchVerseText(WidgetRef ref, String reference) async {
    final books = ref.read(booksProvider).value ?? [];
    if (books.isEmpty) return '';

    final bookNameOrAbbrev =
        reference.split(RegExp(r'\s+\d')).first.trim().toLowerCase();

    final book = books.firstWhere(
      (b) =>
          b.name.toLowerCase() == bookNameOrAbbrev ||
          b.abbrev.toLowerCase() == bookNameOrAbbrev ||
          reference.toLowerCase().startsWith(b.name.toLowerCase()) ||
          reference.toLowerCase().startsWith('${b.name.toLowerCase()} '),
      orElse: () => books.first,
    );

    final match = RegExp(r'(\d+):(\d+)(?:-(\d+))?').firstMatch(reference);
    if (match == null) return '';

    int chapter = int.parse(match.group(1)!);
    int startVerse = int.parse(match.group(2)!);
    int endVerse =
        match.group(3) != null ? int.parse(match.group(3)!) : startVerse;

    try {
      final bibleService = ref.read(bibleServiceProvider);
      final version = ref.read(selectedVersionProvider);
      final chapterData =
          await bibleService.getChapter(version, book.abbrev, chapter);

      String text = '';
      for (final v in chapterData.verses) {
        if (v.number >= startVerse && v.number <= endVerse) {
          text += '${v.number}. ${v.text} ';
        }
      }
      return text.trim();
    } catch (e) {
      return '';
    }
  }
}
