import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/glass_card.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/core/services/tts/tts_service.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';

class DictionaryDetailScreen extends ConsumerStatefulWidget {
  final String word;
  final String? definition;
  final String letter;

  const DictionaryDetailScreen({
    super.key,
    required this.word,
    this.definition,
    required this.letter,
  });

  @override
  ConsumerState<DictionaryDetailScreen> createState() => _DictionaryDetailScreenState();
}

class _DictionaryDetailScreenState extends ConsumerState<DictionaryDetailScreen> {
  bool _isSpeaking = false;

  Future<void> _toggleSpeech(String htmlText) async {
    final ttsService = ref.read(ttsServiceProvider);
    
    if (_isSpeaking) {
      await ttsService.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    
    if (mounted) setState(() => _isSpeaking = true);
    
    // Strip HTML tags for clean reading
    final plainText = htmlText.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
    
    final selectedVoice = ref.read(ttsSelectedVoiceProvider);
    await ttsService.speak(plainText, voice: selectedVoice);
    
    // Optional: we can't reliably know when it finishes without a listener, 
    // but the user can click again to stop it.
  }

  @override
  void dispose() {
    ref.read(ttsServiceProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const MBibliaTopBar(
        title: 'KeryxApp',
        showLogo: true,
      ),

      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context),
              _buildDefinitionSection(context, ref),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Voltar',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.letter.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.word,
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.label_outline, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Letra ${widget.letter}',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: Icon(
                    _isSpeaking ? Icons.stop_circle : Icons.volume_up,
                    color: _isSpeaking ? Colors.redAccent : Theme.of(context).colorScheme.onSurface,
                    size: 28,
                  ),
                  onPressed: () {
                    if (widget.definition != null) {
                      _toggleSpeech(widget.definition!);
                    } else {
                      final dictId = ref.read(selectedDictionaryProvider);
                      final asyncDef = ref.read(dictionaryProvider((dictId: dictId, word: widget.word)));
                      asyncDef.whenData((text) {
                        if (text != null && text.isNotEmpty) {
                          _toggleSpeech(text);
                        }
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefinitionSection(BuildContext context, WidgetRef ref) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, Icons.book_outlined, 'Definição'),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.definition != null)
                  Html(
                    data: widget.definition,
                    style: {
                      "body": Style(
                        fontSize: FontSize(fontSettings.fontSize),
                        color: onSurface,
                        fontFamily: CustomFontLoader.loadedFontFamilies.contains(fontSettings.fontFamily)
                            ? fontSettings.fontFamily
                            : GoogleFonts.getFont(fontSettings.fontFamily).fontFamily ?? 'Outfit',
                        lineHeight: LineHeight.em(1.7),
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                      ),
                    },
                  )
                else
                  _buildAsyncDefinition(context, ref),
                const SizedBox(height: 20),
                _buildDisclaimerBox(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAsyncDefinition(BuildContext context, WidgetRef ref) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final dictId = ref.watch(selectedDictionaryProvider);
    final asyncDef = ref.watch(dictionaryProvider((dictId: dictId, word: widget.word)));
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return asyncDef.when(
      data: (text) => text != null && text.isNotEmpty
          ? Html(data: text, style: _getHtmlStyle(context, fontSettings))
          : Text('Nenhuma definição encontrada.', style: GoogleFonts.outfit(color: onSurface.withValues(alpha: 0.54))),
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.kPrimaryGold)),
      error: (e, _) => Text('Erro ao carregar: $e', style: const TextStyle(color: Colors.redAccent)),
    );
  }


  Widget _buildDisclaimerBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Esta definição pode variar conforme fontes e edições. Para aprofundar e confirmar o contexto, use a análise da IATheos.',
              style: GoogleFonts.outfit(
                color: Colors.orangeAccent.withValues(alpha: 0.8),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, IconData icon, String title, {bool small = false}) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, color: small ? AppTheme.kPrimaryGold : const Color(0xFF8B5CF6), size: small ? 20 : 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: small ? 16 : 20,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
      ],
    );
  }

  Map<String, Style> _getHtmlStyle(BuildContext context, FontSettings fontSettings) => {
    "body": Style(
      fontSize: FontSize(fontSettings.fontSize),
      color: Theme.of(context).colorScheme.onSurface,
      fontFamily: CustomFontLoader.loadedFontFamilies.contains(fontSettings.fontFamily)
          ? fontSettings.fontFamily
          : GoogleFonts.getFont(fontSettings.fontFamily).fontFamily ?? 'Outfit',
      lineHeight: LineHeight.em(1.6),
      margin: Margins.zero,
    ),
  };
}
