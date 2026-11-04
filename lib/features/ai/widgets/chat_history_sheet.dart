import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/ai/model/chat_model.dart';
import 'package:keryx_app/features/ai/service/chat_history_service.dart';

class ChatHistorySheet extends ConsumerStatefulWidget {
  final String? currentSessionId;
  final ValueChanged<ChatSession> onSelectSession;
  final VoidCallback onNewChat;
  final VoidCallback onClearCurrent;
  final VoidCallback onClearAll;

  const ChatHistorySheet({
    super.key,
    required this.currentSessionId,
    required this.onSelectSession,
    required this.onNewChat,
    required this.onClearCurrent,
    required this.onClearAll,
  });

  @override
  ConsumerState<ChatHistorySheet> createState() => _ChatHistorySheetState();
}

class _ChatHistorySheetState extends ConsumerState<ChatHistorySheet> {
  List<ChatSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final service = ref.read(chatHistoryServiceProvider);
    final sessions = await service.loadSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  String _formatSessionDate(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (isToday) {
      return 'Hoje às $timeStr';
    } else if (isYesterday) {
      return 'Ontem às $timeStr';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} às $timeStr';
    }
  }

  Future<void> _deleteSession(ChatSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              'Excluir Conversa?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'Deseja excluir "${session.title}" permanentemente do histórico?',
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
            child: Text('Excluir', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final service = ref.read(chatHistoryServiceProvider);
    await service.deleteSession(session.id);

    final wasCurrent = session.id == widget.currentSessionId;
    setState(() {
      _sessions.removeWhere((s) => s.id == session.id);
    });

    if (wasCurrent) {
      widget.onClearCurrent();
    }
  }

  Future<void> _confirmClearAll() async {
    if (_sessions.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              'Limpar Todo o Histórico?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'Todas as conversas salvas com a IATheos serão permanentemente apagadas. Deseja continuar?',
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
            child: Text('Limpar Tudo', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final service = ref.read(chatHistoryServiceProvider);
    await service.clearAllSessions();

    if (mounted) {
      setState(() => _sessions.clear());
    }

    widget.onClearAll();
  }

  @override
  Widget build(BuildContext context) {
    const gold = AppTheme.kPrimaryGold;
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: mediaQuery.size.height * 0.78,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Cabeçalho da Aba
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: gold.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.history_rounded, color: gold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Histórico de Conversas',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Retome ou gerencie suas consultas',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Botão Nova Conversa
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: gold.withValues(alpha: 0.15),
                        foregroundColor: gold,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: gold.withValues(alpha: 0.35)),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        'Nova',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        widget.onNewChat();
                      },
                    ),
                    const SizedBox(width: 6),
                    // Botão Limpar Tudo
                    if (_sessions.isNotEmpty)
                      IconButton(
                        tooltip: 'Limpar todo o histórico',
                        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
                        onPressed: _confirmClearAll,
                      ),
                  ],
                ),
              ),

              const Divider(color: Colors.white12, height: 16),

              // Lista de Sessões
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(gold),
                        ),
                      )
                    : _sessions.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _sessions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final session = _sessions[index];
                              final isCurrent = session.id == widget.currentSessionId;

                              return _buildSessionCard(session, isCurrent, gold);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 32,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum histórico salvo',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Converse com a IATheos para que seus estudos e perguntas fiquem salvos aqui.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(ChatSession session, bool isCurrent, Color gold) {
    return Material(
      color: isCurrent
          ? gold.withValues(alpha: 0.08)
          : const Color(0xFF161A26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCurrent
              ? gold.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onSelectSession(session),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? gold.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 18,
                  color: isCurrent ? gold : Colors.white60,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                              color: isCurrent ? gold : Colors.white,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: gold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: gold.withValues(alpha: 0.4), width: 0.8),
                            ),
                            child: Text(
                              'Ativa',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: gold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.messages.length} ${session.messages.length == 1 ? 'mensagem' : 'mensagens'} • ${_formatSessionDate(session.updatedAt)}',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                tooltip: 'Excluir conversa',
                onPressed: () => _deleteSession(session),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

