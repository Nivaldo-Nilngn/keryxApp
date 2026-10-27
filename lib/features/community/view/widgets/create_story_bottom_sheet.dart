import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/community/view_model/community_feed_provider.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/navigation/view/bible_selector_bottom_sheet.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/features/community/view/widgets/community_user_avatar.dart';

class CreateStoryBottomSheet extends ConsumerStatefulWidget {
  const CreateStoryBottomSheet({super.key});

  @override
  ConsumerState<CreateStoryBottomSheet> createState() =>
      _CreateStoryBottomSheetState();
}

class _CreateStoryBottomSheetState extends ConsumerState<CreateStoryBottomSheet> {
  final TextEditingController _titleController = TextEditingController(text: 'Versículo do Dia');
  final TextEditingController _referenceController = TextEditingController(text: 'Salmos 23:1');
  final TextEditingController _verseTextController = TextEditingController(
    text: 'O SENHOR é o meu pastor, nada me faltará.',
  );
  final TextEditingController _reflectionController = TextEditingController();

  String _selectedBackgroundStyle = 'gold_gradient'; // 'gold_gradient', 'indigo_gradient', 'emerald_gradient', 'crimson_gradient'
  bool _isPublishing = false;

  final List<Map<String, String>> _popularVerses = [
    {
      'ref': 'Salmos 23:1',
      'text': 'O SENHOR é o meu pastor, nada me faltará.',
      'title': 'Provisão e Descanso',
    },
    {
      'ref': 'Filipenses 4:13',
      'text': 'Posso todas as coisas em Cristo que me fortalece.',
      'title': 'Fortaleza Diária',
    },
    {
      'ref': 'Jeremias 29:11',
      'text': 'Porque eu bem sei os pensamentos que tenho a vosso respeito, diz o SENHOR; pensamentos de paz, e não de mal.',
      'title': 'Esperança e Futuro',
    },
    {
      'ref': 'Isaías 41:10',
      'text': 'Não temas, porque eu sou contigo; não te assombres, porque eu sou teu Deus; eu te fortaleço e te ajudo.',
      'title': 'Coragem & Presença',
    },
    {
      'ref': 'Salmos 91:1-2',
      'text': 'Aquele que habita no esconderijo do Altíssimo, à sombra do Onipotente descansará. Ele é o meu refúgio e fortaleza.',
      'title': 'Proteção Divina',
    },
    {
      'ref': 'Romanos 8:28',
      'text': 'Sabemos que todas as coisas cooperam para o bem daqueles que amam a Deus, daqueles chamados segundo o Seu propósito.',
      'title': 'Fé Inabalável',
    },
    {
      'ref': 'João 3:16',
      'text': 'Porque Deus amou o mundo de tal maneira que deu o seu Filho unigênito, para que todo o que nele crer não pereça, mas tenha a vida eterna.',
      'title': 'Amor Eterno',
    },
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _referenceController.dispose();
    _verseTextController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  void _applyQuickVerse(Map<String, String> item) {
    setState(() {
      _referenceController.text = item['ref']!;
      _verseTextController.text = item['text']!;
      if (_titleController.text.trim().isEmpty || _titleController.text == 'Versículo do Dia') {
        _titleController.text = item['title'] ?? item['ref']!;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📖 Versículo "${item['ref']}" inserido no seu Story!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openBibleSelector() async {
    final result = await showModalBottomSheet<
      ({BibleBook book, int chapter, int? verse, String version})
    >(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      backgroundColor: Colors.transparent,
      builder: (context) => const BibleSelectorBottomSheet(
        initialStage: SelectorStage.books,
        fullSelection: true,
      ),
    );

    if (result == null || !mounted) return;

    final bookName = result.book.name;
    final chapter = result.chapter;
    final verse = result.verse ?? 1;
    final version = result.version;

    final refString = '$bookName $chapter:$verse';
    _referenceController.text = refString;
    _titleController.text = refString;

    try {
      final bibleService = ref.read(bibleServiceProvider);
      String? verseText = await bibleService.getVerseText(
        version: version,
        bookId: result.book.id ?? 1,
        chapter: chapter,
        verse: verse,
      );

      if (verseText == null || verseText.trim().isEmpty) {
        final chapterData = await bibleService.getChapter(
          version,
          result.book.abbrev,
          chapter,
        );
        if (chapterData.verses.isNotEmpty) {
          final found = chapterData.verses.firstWhere(
            (v) => v.number == verse,
            orElse: () => chapterData.verses.first,
          );
          verseText = found.text;
        }
      }

      if (verseText != null && verseText.trim().isNotEmpty) {
        _verseTextController.text = verseText.trim();
      }

      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📖 $refString selecionado da Bíblia! ✨'),
            backgroundColor: AppTheme.kPrimaryGold,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar versículo da Bíblia para Story: $e');
      setState(() {});
    }
  }

  Future<void> _publishStory() async {
    final verseText = _verseTextController.text.trim();
    final reference = _referenceController.text.trim();
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (reference.isNotEmpty ? reference : 'Versículo do Dia');
    final reflection = _reflectionController.text.trim();

    if (verseText.isEmpty && reflection.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe ao menos um versículo ou mensagem para o Story.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final service = ref.read(communityServiceProvider);
      final currentUser = FirebaseAuth.instance.currentUser;
      final userData = ref.read(userDataProvider).valueOrNull;

      final resolvedPhoto = (userData?['photoUrl'] as String?)?.trim() ??
          currentUser?.photoURL?.trim() ??
          (currentUser?.providerData.isNotEmpty == true
              ? currentUser!.providerData.first.photoURL?.trim()
              : null);
      final resolvedName = (userData?['name'] as String?)?.trim() ??
          currentUser?.displayName ??
          currentUser?.email?.split('@').first ??
          'Você';

      final story = await service.createStory(
        title: title,
        bibleReference: reference.isNotEmpty ? reference : null,
        verseText: verseText.isNotEmpty ? verseText : null,
        reflection: reflection.isNotEmpty ? reflection : null,
        backgroundStyle: _selectedBackgroundStyle,
        authorAvatar: resolvedPhoto,
        authorName: resolvedName,
      );

      if (mounted) {
        if (story != null) {
          ref.read(communityFeedProvider.notifier).addLocalStory(story);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seu Story bíblico foi publicado com sucesso por 24h! 🌟📖'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() => _isPublishing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível salvar o story. Verifique a conexão e tente novamente.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao publicar story: $e');
      if (mounted) {
        setState(() => _isPublishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao publicar story: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;
    final currentUser = FirebaseAuth.instance.currentUser;
    final userData = ref.watch(userDataProvider).valueOrNull;
    final userName = (userData?['name'] as String?)?.trim() ??
        currentUser?.displayName ??
        currentUser?.email?.split('@').first ??
        'Você';
    final userPhoto = (userData?['photoUrl'] as String?)?.trim() ??
        currentUser?.photoURL?.trim() ??
        (currentUser?.providerData.isNotEmpty == true
            ? currentUser!.providerData.first.photoURL?.trim()
            : null);

    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
            children: [
              // Puxador Superior
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Barra de Cabeçalho Superior
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Criar Story Bíblico',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Disponível no topo por 24 horas',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _isPublishing
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppTheme.kPrimaryGold,
                            ),
                          )
                        : GestureDetector(
                            onTap: _publishStory,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7.5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.black),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Publicar Story',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: Colors.black,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),

              // Conteúdo Rolável
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    // Autor do Story
                    Row(
                      children: [
                        CommunityUserAvatar(
                          photoUrl: userPhoto,
                          name: userName,
                          radius: 20,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Story temporário de 24 horas',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: AppTheme.kPrimaryGold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Bloco do Versículo com Botão de Escolha na Bíblia
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'VERSÍCULO EM DESTAQUE',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                        GestureDetector(
                          onTap: _openBibleSelector,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.kPrimaryGold.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.kPrimaryGold.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.menu_book_rounded, color: AppTheme.kPrimaryGold, size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  'Escolher da Bíblia',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.kPrimaryGold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Carrossel de Versículos Rápidos
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _popularVerses.map((v) {
                          final isSelected = _referenceController.text == v['ref'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => _applyQuickVerse(v),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.kPrimaryGold
                                      : (isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.kPrimaryGold
                                        : (isDark ? Colors.white12 : Colors.black12),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '📖 ${v['ref']}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? Colors.black : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Campo de Referência
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: TextField(
                        controller: _referenceController,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.kPrimaryGold,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Referência (ex: Salmos 23:1)',
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                          ),
                          prefixIcon: const Icon(Icons.bookmark_border_rounded, color: AppTheme.kPrimaryGold, size: 18),
                          prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 0),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Campo de Texto Bíblico
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: TextField(
                        controller: _verseTextController,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.merriweather(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Texto do versículo bíblico...',
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Reflexão Curta Devocional
                    Text(
                      'REFLEXÃO OU PALAVRA DO CORAÇÃO (OPCIONAL)',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: TextField(
                        controller: _reflectionController,
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Deixe uma curta meditação ou pensamento de encorajamento para quem ler...',
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Seletor de Fundo Visual do Story
                    Text(
                      'ESTILO VISUAL DO STORY',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStyleButton('Dourado', 'gold_gradient', const Color(0xFFD97706), const Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        _buildStyleButton('Noturno', 'indigo_gradient', const Color(0xFF1E1B4B), const Color(0xFF4338CA)),
                        const SizedBox(width: 8),
                        _buildStyleButton('Esmeralda', 'emerald_gradient', const Color(0xFF022C22), const Color(0xFF059669)),
                        const SizedBox(width: 8),
                        _buildStyleButton('Rubi', 'crimson_gradient', const Color(0xFF4C0519), const Color(0xFFBE123C)),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // PRÉVIA EM TEMPO REAL DO STORY
                    Text(
                      'PRÉVIA DO SEU STORY (24H)',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStoryPreviewCard(userName, userPhoto),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyleButton(String label, String styleKey, Color c1, Color c2) {
    final isSelected = _selectedBackgroundStyle == styleKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedBackgroundStyle = styleKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: isSelected ? 2.2 : 0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: c2.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryPreviewCard(String userName, String? userPhoto) {
    LinearGradient previewGradient;
    switch (_selectedBackgroundStyle) {
      case 'indigo_gradient':
        previewGradient = const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        break;
      case 'emerald_gradient':
        previewGradient = const LinearGradient(
          colors: [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF065F46)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        break;
      case 'crimson_gradient':
        previewGradient = const LinearGradient(
          colors: [Color(0xFF4C0519), Color(0xFF881337), Color(0xFF9F1239)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        break;
      case 'gold_gradient':
      default:
        previewGradient = const LinearGradient(
          colors: [Color(0xFF1C1917), Color(0xFF292524), Color(0xFF78350F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        break;
    }

    final verseText = _verseTextController.text.trim();
    final ref = _referenceController.text.trim();
    final reflection = _reflectionController.text.trim();

    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: previewGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.kPrimaryGold.withValues(alpha: 0.4), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              CommunityUserAvatar(photoUrl: userPhoto, name: userName, radius: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  userName,
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Story (24h)',
                  style: GoogleFonts.outfit(color: AppTheme.kPrimaryGold, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (verseText.isNotEmpty)
            Text(
              '“$verseText”',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.merriweather(
                color: Colors.white,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          if (ref.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              ref,
              style: GoogleFonts.outfit(
                color: AppTheme.kPrimaryGold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (reflection.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reflection,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10.5,
              ),
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}
