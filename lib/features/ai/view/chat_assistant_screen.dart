import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/ai/model/chat_model.dart';
import 'package:keryx_app/features/ai/widgets/chat_bubble.dart';
import 'package:keryx_app/features/ai/widgets/chat_input.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/core/state/ai_token_state.dart';

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

  static const _suggestions = <(IconData, String)>[
    (Icons.balance_rounded, 'Explique o conceito de Justificação'),
    (Icons.menu_book_rounded, 'Resumo do livro de Romanos'),
    (Icons.account_balance_rounded, 'Contexto histórico de Efésios'),
    (Icons.format_quote_rounded, 'O que significa João 3:16?'),
    (Icons.compare_arrows_rounded, 'Qual a diferença entre graça e misericórdia?'),
  ];

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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final hasTokens = await ref.read(aiTokenProvider.notifier).consumeToken();
    if (!hasTokens) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Limite de consultas atingido por hoje (${AiTokenNotifier.maxTokens}). Volte amanhã!'),
          backgroundColor: Colors.redAccent,
        )
      );
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    String reply;
    try {
      final aiService = ref.read(aiServiceProvider);
      reply = await aiService.askAssistant(text);
    } catch (e) {
      reply = 'Desculpe, ocorreu um erro ao processar sua pergunta: $e';
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
        title: const Text('Limpar conversa?'),
        content: const Text('Todas as mensagens desta conversa serão removidas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _messages.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;
    final tokens = ref.watch(aiTokenProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 4),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [gold, gold.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.auto_stories_rounded, size: 20, color: Colors.black87),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IATheos',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Pedidos restantes: $tokens / ${AiTokenNotifier.maxTokens}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Limpar conversa',
            onPressed: _messages.isEmpty ? null : _confirmClear,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState(theme, gold)
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
              onSend: _sendMessage,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, Color gold) {
    final onSurface = theme.colorScheme.onSurface;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gold.withValues(alpha: 0.10),
                border: Border.all(color: gold.withValues(alpha: 0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(color: gold.withValues(alpha: 0.18), blurRadius: 32, spreadRadius: 2),
                ],
              ),
              child: Icon(Icons.auto_stories_rounded, size: 38, color: gold),
            ),
            const SizedBox(height: 20),
            Text(
              'Como posso ajudar em\nseus estudos hoje?',
              textAlign: TextAlign.center,
              style: GoogleFonts.lora(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pergunte sobre passagens, doutrinas, contexto histórico e mais.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: onSurface.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 28),
            for (final s in _suggestions) _buildSuggestionCard(theme, gold, s.$1, s.$2),
            const SizedBox(height: 12),
            Text(
              'Respostas geradas por IA. Confira sempre com as Escrituras.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 11, color: onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(ThemeData theme, Color gold, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: gold.withValues(alpha: 0.18)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _controller.text = text;
            _sendMessage();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: gold),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.outfit(fontSize: 14.5, color: theme.colorScheme.onSurface),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}