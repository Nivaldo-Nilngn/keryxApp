import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/ai/model/chat_model.dart';
import 'package:keryx_app/features/ai/widgets/chat_bubble.dart';
import 'package:keryx_app/features/ai/widgets/chat_input.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/core/state/ai_token_state.dart';

/// Modos / Especialidades de Estudo Teológico da IATheos
enum TheologicalMode {
  general,
  exegesis,
  history,
  sermon,
  devotional,
}

extension TheologicalModeX on TheologicalMode {
  String get label {
    switch (this) {
      case TheologicalMode.general:
        return 'Geral';
      case TheologicalMode.exegesis:
        return 'Exegese';
      case TheologicalMode.history:
        return 'História';
      case TheologicalMode.sermon:
        return 'Esboços';
      case TheologicalMode.devotional:
        return 'Devocional';
    }
  }

  IconData get icon {
    switch (this) {
      case TheologicalMode.general:
        return Icons.auto_awesome_rounded;
      case TheologicalMode.exegesis:
        return Icons.translate_rounded;
      case TheologicalMode.history:
        return Icons.account_balance_rounded;
      case TheologicalMode.sermon:
        return Icons.menu_book_rounded;
      case TheologicalMode.devotional:
        return Icons.favorite_rounded;
    }
  }

  Color get color {
    switch (this) {
      case TheologicalMode.general:
        return AppTheme.kPrimaryGold;
      case TheologicalMode.exegesis:
        return const Color(0xFF6366F1); // Índigo
      case TheologicalMode.history:
        return const Color(0xFF10B981); // Esmeralda
      case TheologicalMode.sermon:
        return const Color(0xFFF59E0B); // Âmbar
      case TheologicalMode.devotional:
        return const Color(0xFFF43F5E); // Rosa/Rubi
    }
  }

  String get instruction {
    switch (this) {
      case TheologicalMode.general:
        return '';
      case TheologicalMode.exegesis:
        return 'Modo Exegese: Priorize raízes nas línguas originais (Grego e Hebraico), gramática e hermenêutica bíblica.';
      case TheologicalMode.history:
        return 'Modo História: Enfatize o contexto cultural, político, arqueológico e geográfico da época bíblica.';
      case TheologicalMode.sermon:
        return 'Modo Esboço de Sermão: Estruture a resposta com introdução, tópicos com referências e aplicação homilética prática.';
      case TheologicalMode.devotional:
        return 'Modo Devocional: Forneça uma reflexão calorosa, pastoral, com aplicação pessoal para a vida diária e encorajamento.';
    }
  }
}

class _SuggestionItem {
  final String category;
  final String title;
  final String prompt;
  final IconData icon;
  final Color color;

  const _SuggestionItem({
    required this.category,
    required this.title,
    required this.prompt,
    required this.icon,
    required this.color,
  });
}

class ChatAssistantScreen extends ConsumerStatefulWidget {
  final String? initialMessage;

  const ChatAssistantScreen({super.key, this.initialMessage});

  @override
  ConsumerState<ChatAssistantScreen> createState() => _ChatAssistantScreenState();
}

class _ChatAssistantScreenState extends ConsumerState<ChatAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  TheologicalMode _selectedMode = TheologicalMode.general;

  List<_SuggestionItem> _getSuggestionsForMode(TheologicalMode mode) {
    switch (mode) {
      case TheologicalMode.exegesis:
        return const [
          _SuggestionItem(
            category: 'GREGO BÍBLICO',
            title: 'Significado de Ágape',
            prompt: 'Explique o significado e as nuances da palavra grega Ágape em 1 Coríntios 13.',
            icon: Icons.translate_rounded,
            color: Color(0xFF6366F1),
          ),
          _SuggestionItem(
            category: 'HEBRAICO',
            title: 'O Termo Hesed',
            prompt: 'Qual a profundidade do conceito hebraico Hesed (misericórdia fiel) no Antigo Testamento?',
            icon: Icons.auto_stories_rounded,
            color: Color(0xFF3B82F6),
          ),
          _SuggestionItem(
            category: 'CRUZ DE CRISTO',
            title: 'Tetélestai em João',
            prompt: 'O que significa a expressão grega Tetélestai ("Está consumado") dita por Jesus na cruz?',
            icon: Icons.check_circle_outline_rounded,
            color: Color(0xFF8B5CF6),
          ),
          _SuggestionItem(
            category: 'HERMENÊUTICA',
            title: 'O Logos em João 1:1',
            prompt: 'Analise o conceito teológico e filosófico de Logos no prólogo do Evangelho de João.',
            icon: Icons.menu_book_rounded,
            color: Color(0xFF06B6D4),
          ),
        ];

      case TheologicalMode.history:
        return const [
          _SuggestionItem(
            category: 'SOCIEDADE BÍBLICA',
            title: 'Fariseus e Saduceus',
            prompt: 'Quem eram os Fariseus, Saduceus e Zelotes e quais eram suas diferenças nos Evangelhos?',
            icon: Icons.groups_rounded,
            color: Color(0xFF10B981),
          ),
          _SuggestionItem(
            category: 'CULTURA GRECO-ROMANA',
            title: 'Cenário de Éfeso',
            prompt: 'Como era o cenário religioso e cultural da cidade de Éfeso quando Paulo escreveu sua epístola?',
            icon: Icons.account_balance_rounded,
            color: Color(0xFF059669),
          ),
          _SuggestionItem(
            category: 'ARQUEOLOGIA',
            title: 'Templo de Herodes',
            prompt: 'Como era a estrutura do Templo de Jerusalém na época de Jesus e o significado do véu?',
            icon: Icons.temple_buddhist_rounded,
            color: Color(0xFF14B8A6),
          ),
          _SuggestionItem(
            category: 'GEOGRAFIA BÍBLICA',
            title: 'Viagens de Paulo',
            prompt: 'Resuma as principais rotas das viagens missionárias de Paulo e o impacto no Império Romano.',
            icon: Icons.explore_rounded,
            color: Color(0xFF84CC16),
          ),
        ];

      case TheologicalMode.sermon:
        return const [
          _SuggestionItem(
            category: 'EXPOSITIVO',
            title: 'Esboço de Salmos 23',
            prompt: 'Crie um esboço expositivo de Salmos 23 em 3 pontos com introdução e conclusão.',
            icon: Icons.format_list_numbered_rounded,
            color: Color(0xFFF59E0B),
          ),
          _SuggestionItem(
            category: 'TEMÁTICO',
            title: 'Vencendo a Ansiedade',
            prompt: 'Monte um sermão temático bíblico sobre Vencendo a Ansiedade com base em Filipenses 4:6-7.',
            icon: Icons.psychology_rounded,
            color: Color(0xFFD97706),
          ),
          _SuggestionItem(
            category: 'PARÁBOLA',
            title: 'O Filho Pródigo',
            prompt: 'Elabore um esboço homilético sobre o Amor do Pai na Parábola do Filho Pródigo (Lucas 15).',
            icon: Icons.volunteer_activism_rounded,
            color: Color(0xFFB45309),
          ),
          _SuggestionItem(
            category: 'EVANGELÍSTICO',
            title: 'Mensagem em João 3:16',
            prompt: 'Estruture uma mensagem evangelística clara e impactante baseada em João 3:16.',
            icon: Icons.campaign_rounded,
            color: Color(0xFFEA580C),
          ),
        ];

      case TheologicalMode.devotional:
        return const [
          _SuggestionItem(
            category: 'PAZ INTERIOR',
            title: 'A Paz que Excede Entendimento',
            prompt: 'Compartilhe uma meditação bíblica sobre como cultivar a paz de Deus em momentos difíceis.',
            icon: Icons.spa_rounded,
            color: Color(0xFFF43F5E),
          ),
          _SuggestionItem(
            category: 'ORAÇÃO',
            title: 'Oração do Pai Nosso',
            prompt: 'O que a oração do Pai Nosso nos ensina sobre confiança e dependência diária de Deus?',
            icon: Icons.favorite_rounded,
            color: Color(0xFFE11D48),
          ),
          _SuggestionItem(
            category: 'FÉ & CORAGEM',
            title: 'Esperança em Jeremias 29:11',
            prompt: 'Traga uma palavra de ânimo e aplicação prática sobre os planos de Deus em Jeremias 29:11.',
            icon: Icons.light_mode_rounded,
            color: Color(0xFFBE123C),
          ),
          _SuggestionItem(
            category: 'VIDA CRISTÃ',
            title: 'Fruto do Espírito',
            prompt: 'Como podemos evidenciar os aspectos do Fruto do Espírito nas decisões do dia a dia?',
            icon: Icons.eco_rounded,
            color: Color(0xFFFDA4AF),
          ),
        ];

      case TheologicalMode.general:
        return const [
          _SuggestionItem(
            category: 'DOUTRINA',
            title: 'Justificação pela Fé',
            prompt: 'Explique o conceito de Justificação pela Fé segundo o Apóstolo Paulo.',
            icon: Icons.balance_rounded,
            color: Color(0xFF6366F1),
          ),
          _SuggestionItem(
            category: 'PANORAMA',
            title: 'Propósito de Romanos',
            prompt: 'Qual o contexto histórico, propósito e mensagem central da Epístola aos Romanos?',
            icon: Icons.menu_book_rounded,
            color: Color(0xFFF59E0B),
          ),
          _SuggestionItem(
            category: 'HISTÓRIA',
            title: 'Cenário de Efésios',
            prompt: 'Como era o contexto cultural, político e espiritual de Éfeso na época bíblica?',
            icon: Icons.account_balance_rounded,
            color: Color(0xFF10B981),
          ),
          _SuggestionItem(
            category: 'TEOLOGIA',
            title: 'Graça e Misericórdia',
            prompt: 'Qual a diferença bíblica e teológica entre a graça de Deus e a misericórdia?',
            icon: Icons.compare_arrows_rounded,
            color: Color(0xFFF43F5E),
          ),
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      _controller.text = widget.initialMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendMessage());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage([String? directText]) async {
    final text = (directText ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

    final hasTokens = await ref.read(aiTokenProvider.notifier).consumeToken();
    if (!hasTokens) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Limite de consultas diárias atingido. Volte amanhã para novas perguntas!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      if (directText == null) _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    // Contextualiza a IA com o modo selecionado se for específico
    String promptWithContext = text;
    if (_selectedMode != TheologicalMode.general && _selectedMode.instruction.isNotEmpty) {
      promptWithContext = '${_selectedMode.instruction}\n\nPergunta do usuário: $text';
    }

    String reply;
    try {
      final aiService = ref.read(aiServiceProvider);
      reply = await aiService.askAssistant(promptWithContext);
    } catch (e) {
      reply = 'Desculpe, ocorreu uma instabilidade ao conectar com o serviço teológico: $e';
    }

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: reply, isUser: false));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _confirmClear() async {
    if (_messages.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              'Limpar Conversa?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'Todas as mensagens desta conversa serão removidas da tela.',
          style: GoogleFonts.manrope(fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.outfit(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Limpar', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _messages.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gold = AppTheme.kPrimaryGold;
    final tokens = ref.watch(aiTokenProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Row(
          children: [
            const SizedBox(width: 4),
            // Avatar Celestial da IATheos
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD56B), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: Color(0xFF1E1B18),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'IATheos',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Assistente Teológico',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Pílula Elegante com Contador de Consultas
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: gold.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, size: 14, color: gold),
                const SizedBox(width: 4),
                Text(
                  '$tokens/${AiTokenNotifier.maxTokens}',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: gold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white60),
            tooltip: 'Limpar conversa',
            onPressed: _messages.isEmpty ? null : _confirmClear,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _buildModernEmptyState(theme, gold)
                  : ListView.builder(
                      controller: _scrollController,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(top: 12, bottom: 16),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _messages.length) return const TypingBubble();
                        return ChatBubble(message: _messages[index]);
                      },
                    ),
            ),
            ChatInput(
              controller: _controller,
              onSend: () => _sendMessage(),
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  /// Estado Vazio Moderno estilo ChatGPT / Perplexity com Avatar Celestial,
  /// Seletor de Modos e Mosaico 2x2 com Cores Temáticas
  Widget _buildModernEmptyState(ThemeData theme, Color gold) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 600;
    final suggestions = _getSuggestionsForMode(_selectedMode);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 18 : 32,
        vertical: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),

          // ── Avatar Celestial Grande com Halo Iluminado ─────────────
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD56B), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_stories_rounded,
                size: 36,
                color: Color(0xFF1E1B18),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Título Nobre e Convidativo ─────────────────────────────
          Text(
            'Como posso ajudar em seus estudos hoje?',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: isCompact ? 20 : 23,
              fontWeight: FontWeight.bold,
              height: 1.25,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Explore exegese, teologia histórica, esboços e mensagens práticas.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: Colors.white60,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),

          // ── Seletor Horizontal de Modos de Estudo ───────────────────
          _buildModeSelector(),

          const SizedBox(height: 20),

          // ── Mosaico 2x2 com Cards Modernos ──────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: suggestions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isCompact ? 1 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: isCompact ? 84 : 100,
            ),
            itemBuilder: (context, index) {
              return _buildModernSuggestionCard(suggestions[index]);
            },
          ),

          const SizedBox(height: 16),

          // ── Aviso de Rodapé Ético e Teológico ───────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_rounded, size: 13, color: Colors.white38),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Respostas geradas por IA. Examine tudo à luz das Escrituras.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(fontSize: 11, color: Colors.white38),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Seletor de Especialidade Teológica (Geral, Exegese, História, Esboços, Devocional)
  Widget _buildModeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: TheologicalMode.values.map((mode) {
          final isSelected = _selectedMode == mode;
          final modeColor = mode.color;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedMode = mode),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? modeColor.withValues(alpha: 0.22) : const Color(0xFF1B1F2D),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? modeColor : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: modeColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mode.icon,
                        size: 15,
                        color: isSelected ? modeColor : Colors.white60,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        mode.label,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Card de Sugestão Estilo ChatGPT/Perplexity
  Widget _buildModernSuggestionCard(_SuggestionItem item) {
    return Material(
      color: const Color(0xFF161A26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _controller.text = item.prompt;
          _sendMessage(item.prompt);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ícone com Container Squircle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.color.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Icon(item.icon, size: 20, color: item.color),
              ),
              const SizedBox(width: 12),

              // Textos e Pergunta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.category,
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: item.color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.title,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.prompt,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: Colors.white60,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: item.color.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}