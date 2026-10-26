import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/community/view_model/community_feed_provider.dart';

class CreatePostBottomSheet extends ConsumerStatefulWidget {
  const CreatePostBottomSheet({super.key});

  @override
  ConsumerState<CreatePostBottomSheet> createState() =>
      _CreatePostBottomSheetState();
}

class _CreatePostBottomSheetState extends ConsumerState<CreatePostBottomSheet> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _verseTextController = TextEditingController();

  String _selectedCategory = 'reflection'; // 'reflection', 'prayer', 'verse', 'testimony'
  String _selectedTheme = 'gold'; // 'gold', 'indigo', 'emerald', 'crimson'
  bool _includeVerse = true;
  bool _isPublishing = false;
  bool _showLivePreview = true;

  // Sugestões populares para preenchimento com 1 toque
  final List<Map<String, String>> _popularVerses = [
    {
      'ref': 'Salmos 23:1',
      'text': 'O SENHOR é o meu pastor, nada me faltará.',
      'tag': 'Provisão',
    },
    {
      'ref': 'Filipenses 4:13',
      'text': 'Posso todas as coisas em Cristo que me fortalece.',
      'tag': 'Fortaleza',
    },
    {
      'ref': 'Jeremias 29:11',
      'text': 'Porque eu bem sei os pensamentos que tenho a vosso respeito, diz o SENHOR; pensamentos de paz, e não de mal.',
      'tag': 'Esperança',
    },
    {
      'ref': 'Isaías 41:10',
      'text': 'Não temas, porque eu sou contigo; não te assombres, porque eu sou teu Deus; eu te fortaleço e te ajudo.',
      'tag': 'Coragem',
    },
    {
      'ref': 'Salmos 91:1-2',
      'text': 'Aquele que habita no esconderijo do Altíssimo, à sombra do Onipotente descansará. Ele é o meu refúgio e fortaleza.',
      'tag': 'Proteção',
    },
    {
      'ref': 'Romanos 8:28',
      'text': 'Sabemos que todas as coisas cooperam para o bem daqueles que amam a Deus, daqueles chamados segundo o Seu propósito.',
      'tag': 'Fé',
    },
    {
      'ref': 'João 3:16',
      'text': 'Porque Deus amou o mundo de tal maneira que deu o seu Filho unigênito, para que todo o que nele crer não pereça, mas tenha a vida eterna.',
      'tag': 'Salvação',
    },
  ];

  final List<String> _quickHashtags = [
    '#Oração',
    '#Gratidão',
    '#PalavraViva',
    '#FéInabalável',
    '#Milagre',
    '#DeusÉFiel',
  ];

  @override
  void initState() {
    super.initState();
    // Inicia com um versículo inspirador de exemplo
    _referenceController.text = 'Salmos 23:1';
    _verseTextController.text = 'O SENHOR é o meu pastor, nada me faltará.';
  }

  @override
  void dispose() {
    _captionController.dispose();
    _referenceController.dispose();
    _verseTextController.dispose();
    super.dispose();
  }

  void _applyQuickVerse(Map<String, String> item) {
    setState(() {
      _includeVerse = true;
      _referenceController.text = item['ref']!;
      _verseTextController.text = item['text']!;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📖 Versículo "${item['ref']}" inserido no cartão!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _insertHashtag(String tag) {
    final current = _captionController.text;
    final space = current.isEmpty || current.endsWith(' ') ? '' : ' ';
    _captionController.text = '$current$space$tag ';
    _captionController.selection = TextSelection.fromPosition(
      TextPosition(offset: _captionController.text.length),
    );
    setState(() {});
  }

  String _getCategoryHint() {
    switch (_selectedCategory) {
      case 'prayer':
        return 'Escreva seu pedido de oração para a comunidade se unir em clamor por você...';
      case 'verse':
        return 'Qual revelação ou ensinamento essa passagem bíblica trouxe hoje?';
      case 'testimony':
        return 'Compartilhe uma vitória, bênção ou testemunho do que Deus fez em sua vida!';
      case 'reflection':
      default:
        return 'O que Deus falou ao seu coração hoje? Deixe uma palavra de edificação...';
    }
  }

  String _getCategoryBadge() {
    switch (_selectedCategory) {
      case 'prayer':
        return '🙏 Pedido de Oração';
      case 'verse':
        return '📖 Versículo do Dia';
      case 'testimony':
        return '✨ Testemunho';
      case 'reflection':
      default:
        return '🕊️ Reflexão';
    }
  }

  Future<void> _publish() async {
    final caption = _captionController.text.trim();
    final refText = _referenceController.text.trim();
    final verse = _verseTextController.text.trim();

    if (caption.isEmpty && (!_includeVerse || verse.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, escreva uma mensagem ou insira um versículo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);

    // Se tiver categoria especial, prefixa uma tag sutil se necessário
    final finalCaption = caption;

    final service = ref.read(communityServiceProvider);
    final post = await service.createPost(
      caption: finalCaption,
      bibleReference: _includeVerse && refText.isNotEmpty ? refText : null,
      bibleText: _includeVerse && verse.isNotEmpty ? verse : null,
      cardTheme: _selectedTheme,
    );

    if (mounted) {
      if (post != null) {
        ref.read(communityFeedProvider.notifier).addLocalPost(post);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sua bênção foi compartilhada na Comunidade! 🎉🙏'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;
    final currentUser = FirebaseAuth.instance.currentUser;
    final userName = currentUser?.displayName ??
        currentUser?.email?.split('@').first ??
        'Você';
    final userPhoto = currentUser?.photoURL;

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

              // Barra de Título Superior
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Compartilhar Bênção',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
                            onTap: _publish,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7.5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD97706).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.send_rounded, size: 15, color: Colors.black),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Publicar',
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

              // Conteúdo com Rolagem
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    // 1. Identificação do Autor
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.kPrimaryGold.withValues(alpha: 0.2),
                          backgroundImage: userPhoto != null && userPhoto.isNotEmpty
                              ? NetworkImage(userPhoto)
                              : null,
                          child: (userPhoto == null || userPhoto.isEmpty)
                              ? Text(
                                  userName.substring(0, 1).toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.kPrimaryGold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  userName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Público',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Edificando a comunidade Keryx',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Botão para alternar Live Preview
                        TextButton.icon(
                          onPressed: () => setState(() => _showLivePreview = !_showLivePreview),
                          icon: Icon(
                            _showLivePreview ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 16,
                            color: AppTheme.kPrimaryGold,
                          ),
                          label: Text(
                            _showLivePreview ? 'Ocultar Prévia' : 'Ver Prévia',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.kPrimaryGold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 2. Seletor de Categoria/Propósito (Chips estilo TikTok/Instagram)
                    Text(
                      'TIPO DE PUBLICAÇÃO',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryButton(
                            id: 'reflection',
                            label: 'Reflexão',
                            icon: Icons.lightbulb_rounded,
                            color: const Color(0xFFF59E0B),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildCategoryButton(
                            id: 'prayer',
                            label: 'Pedido de Oração',
                            icon: Icons.volunteer_activism_rounded,
                            color: const Color(0xFF818CF8),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildCategoryButton(
                            id: 'verse',
                            label: 'Versículo',
                            icon: Icons.menu_book_rounded,
                            color: const Color(0xFF10B981),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildCategoryButton(
                            id: 'testimony',
                            label: 'Testemunho',
                            icon: Icons.celebration_rounded,
                            color: const Color(0xFFEC4899),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. Campo de Texto Principal (Reflexão / Pedido)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _captionController,
                            maxLines: 4,
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.45,
                            ),
                            decoration: InputDecoration(
                              hintText: _getCategoryHint(),
                              hintStyle: GoogleFonts.outfit(
                                fontSize: 13.5,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Barra de Hashtags Rápidas
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _quickHashtags.map((tag) {
                              return GestureDetector(
                                onTap: () => _insertHashtag(tag),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    tag,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.kPrimaryGold,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 4. Seção: Versículos Inspiradores de 1 Toque
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: AppTheme.kPrimaryGold, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'SUGESTÕES DE VERSÍCULOS RÁPIDOS',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _popularVerses.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final v = _popularVerses[index];
                          final isSelected = _referenceController.text == v['ref'] && _includeVerse;
                          return GestureDetector(
                            onTap: () => _applyQuickVerse(v),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.kPrimaryGold
                                    : (isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.kPrimaryGold
                                      : (isDark ? Colors.white12 : Colors.black12),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '📖 ${v['ref']}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected
                                          ? Colors.black
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '• ${v['tag']}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      color: isSelected
                                          ? Colors.black87
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 5. Bloco de Cartão de Versículo (Ativar / Desativar com Design Limpo)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A28) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _includeVerse
                              ? AppTheme.kPrimaryGold.withValues(alpha: 0.4)
                              : (isDark ? Colors.white10 : Colors.black12),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.format_quote_rounded,
                                  color: AppTheme.kPrimaryGold,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Destacar Cartão Bíblico',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Apresenta o versículo com tipografia e cores no feed',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _includeVerse,
                                activeThumbColor: AppTheme.kPrimaryGold,
                                onChanged: (val) => setState(() => _includeVerse = val),
                              ),
                            ],
                          ),

                          if (_includeVerse) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            // Campo da Referência
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF222234) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
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

                            // Campo do Texto do Versículo
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF222234) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
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
                                  hintText: 'Cole ou digite o texto bíblico aqui...',
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

                            const SizedBox(height: 14),

                            // Seletor de Tema do Cartão
                            Text(
                              'PALETA DE CORES DO CARTÃO',
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
                                _buildThemePill('Dourado', 'gold', const Color(0xFFD97706), const Color(0xFFF59E0B)),
                                const SizedBox(width: 8),
                                _buildThemePill('Índigo', 'indigo', const Color(0xFF312E81), const Color(0xFF818CF8)),
                                const SizedBox(width: 8),
                                _buildThemePill('Esmeralda', 'emerald', const Color(0xFF065F46), const Color(0xFF10B981)),
                                const SizedBox(width: 8),
                                _buildThemePill('Rubi', 'crimson', const Color(0xFF881337), const Color(0xFFE11D48)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // 6. Live Preview (Visualização ao Vivo Estilo Feed do Instagram)
                    if (_showLivePreview) ...[
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Icon(Icons.remove_red_eye_rounded, size: 16, color: AppTheme.kPrimaryGold),
                          const SizedBox(width: 6),
                          Text(
                            'PRÉVIA EM TEMPO REAL NO FEED',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildLivePreviewCard(context, isDark, userName, userPhoto),
                    ],

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Botão de Seleção de Categoria
  Widget _buildCategoryButton({
    required String id,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _selectedCategory == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : (isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pílula de Seleção de Tema do Cartão
  Widget _buildThemePill(String name, String value, Color darkColor, Color lightColor) {
    final isSelected = _selectedTheme == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTheme = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [darkColor, lightColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: lightColor.withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            name,
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

  // Card de Prévia em Tempo Real
  Widget _buildLivePreviewCard(BuildContext context, bool isDark, String userName, String? userPhoto) {
    LinearGradient previewGradient;
    Color accentColor;

    switch (_selectedTheme) {
      case 'indigo':
        previewGradient = const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
        );
        accentColor = const Color(0xFF818CF8);
        break;
      case 'emerald':
        previewGradient = const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF065F46)],
        );
        accentColor = const Color(0xFF34D399);
        break;
      case 'crimson':
        previewGradient = const LinearGradient(
          colors: [Color(0xFF4C0519), Color(0xFF881337)],
        );
        accentColor = const Color(0xFFFB7185);
        break;
      case 'gold':
      default:
        previewGradient = LinearGradient(
          colors: isDark
              ? [const Color(0xFF262117), const Color(0xFF3D321D)]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
        );
        accentColor = AppTheme.kPrimaryGold;
        break;
    }

    final captionText = _captionController.text.trim().isNotEmpty
        ? _captionController.text.trim()
        : 'Sua reflexão devocional ou pedido de oração aparecerá aqui...';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topo do Card
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.kPrimaryGold.withValues(alpha: 0.2),
                  backgroundImage: userPhoto != null && userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
                  child: (userPhoto == null || userPhoto.isEmpty)
                      ? Text(userName.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.kPrimaryGold))
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.kPrimaryGold.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getCategoryBadge(),
                              style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.kPrimaryGold),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Agora mesmo • Comunidade',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Texto da Mensagem
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Text(
              captionText,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.35,
              ),
            ),
          ),

          // Cartão Bíblico dentro da Prévia
          if (_includeVerse && _verseTextController.text.trim().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: previewGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_quote_rounded, color: accentColor, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '${_referenceController.text.trim()} (ACF)',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '« ${_verseTextController.text.trim()} »',
                    style: GoogleFonts.merriweather(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Barra de Reações Simuladas
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Row(
              children: [
                _buildReactionPill('🙏 Orar', '0'),
                const SizedBox(width: 8),
                _buildReactionPill('❤️ Amém', '0'),
                const Spacer(),
                Text(
                  '💬 0 comentários',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionPill(String label, String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label $count',
        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
