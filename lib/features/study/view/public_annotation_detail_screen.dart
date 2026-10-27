import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/study/model/note_card.dart';
import 'package:keryx_app/features/study/model/comment.dart';
import 'package:keryx_app/features/study/view_model/comments_provider.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/features/study/view_model/note_cards_provider.dart';
import 'package:keryx_app/features/study/view_model/public_annotations_provider.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';

class PublicAnnotationDetailScreen extends ConsumerStatefulWidget {
  final NoteCard note;
  final String? focusCommentId;

  const PublicAnnotationDetailScreen({
    super.key,
    required this.note,
    this.focusCommentId,
  });

  @override
  ConsumerState<PublicAnnotationDetailScreen> createState() =>
      _PublicAnnotationDetailScreenState();
}

class _PublicAnnotationDetailScreenState
    extends ConsumerState<PublicAnnotationDetailScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _selectedKind = 'complemento';
  Comment? _replyTo;
  bool _isNoteExpanded = false;
  late bool _isLocked;

  static const _gold = AppTheme.kPrimaryGold;
  
  

  @override
  void initState() {
    super.initState();
    _isLocked = widget.note.isLocked;
  }

  Future<void> _toggleLock() async {
    final newVal = !_isLocked;
    setState(() => _isLocked = newVal);
    try {
      final updatedCard = widget.note.copyWith(isLocked: newVal);
      await ref.read(noteCardsProvider.notifier).save(updatedCard);
      ref.read(publicAnnotationsProvider.notifier).refresh();
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Row(
               children: [
                 Icon(newVal ? Icons.lock : Icons.lock_open, color: AppTheme.kPrimaryGold, size: 20),
                 const SizedBox(width: 8),
                 Text(newVal ? 'Tópico trancado.' : 'Tópico destrancado.', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
               ],
             ),
             backgroundColor: Theme.of(context).cardColor,
             behavior: SnackBarBehavior.floating,
             shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(12),
               side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
             ),
             margin: const EdgeInsets.all(16),
             duration: const Duration(seconds: 2),
           ),
         );
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLocked = !newVal);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text(
               'Erro ao alterar status do tópico.',
               style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
             ),
             backgroundColor: Colors.redAccent,
             behavior: SnackBarBehavior.floating,
             margin: const EdgeInsets.all(16),
           ),
         );
      }
    }
  }

  Future<void> _deleteTopic() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Excluir Tópico?', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Tem certeza que deseja apagar este tópico permanentemente?', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir', style: GoogleFonts.outfit(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(noteCardsProvider.notifier).delete(widget.note.id);
        ref.read(publicAnnotationsProvider.notifier).refresh();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.kPrimaryGold, size: 20),
                  const SizedBox(width: 8),
                  Text('Tópico excluído com sucesso.', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
              backgroundColor: Theme.of(context).cardColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erro ao excluir: você não tem permissão para remover este tópico.',
                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendComment() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    _textCtrl.clear();
    final replyTo = _replyTo;
    setState(() => _replyTo = null);

    final service = ref.read(commentsServiceProvider);
    await service.addComment(
      annotation: widget.note,
      text: text,
      kind: _selectedKind,
      replyTo: replyTo,
    );

    // Rola para baixo após enviar
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsStreamProvider(widget.note.id));
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.uid;
    final isAuthor = currentUserId == widget.note.authorId;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const MBibliaTopBar(
        title: 'KeryxApp',
        showLogo: true,
        showBackButton: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                SliverToBoxAdapter(
                  child: _buildOriginalNote(currentUserId),
                ),
                commentsAsync.when(
                  data: (comments) {
                    if (comments.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'Seja o primeiro a comentar.',
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final c = comments[i];
                            final isMe = c.authorId == currentUserId;
                            return _buildCommentItem(c, isMe, isAuthor);
                          },
                          childCount: comments.length,
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: _gold)),
                  ),
                  error: (err, _) {
                    final isDenied = err.toString().contains('permission-denied');
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isDenied ? Icons.lock_outline : Icons.error_outline,
                                color: isDenied ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38) : Colors.redAccent, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              isDenied
                                  ? 'Este tópico foi trancado\nou tornado privado pelo autor.'
                                  : 'Erro ao carregar comentários.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: isDenied ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54) : Colors.redAccent,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Input Area
          if (!commentsAsync.hasError) 
            _isLocked 
              ? Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  width: double.infinity,
                  color: Theme.of(context).cardColor,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), size: 18),
                      const SizedBox(width: 8),
                      Text('Este tópico foi trancado pelo autor.', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 14)),
                    ],
                  ),
                )
              : _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildOriginalNote(String? currentUserId) {
    return GestureDetector(
      onTap: () => setState(() => _isNoteExpanded = !_isNoteExpanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book, color: _gold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.note.title,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (currentUserId == widget.note.authorId) ...[
                  IconButton(
                    onPressed: _toggleLock,
                    icon: Icon(_isLocked ? Icons.lock : Icons.lock_open, size: 18),
                    color: _isLocked ? Colors.redAccent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                    tooltip: _isLocked ? 'Destrancar tópico' : 'Trancar tópico',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _deleteTopic,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: Colors.redAccent,
                    tooltip: 'Excluir tópico',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                ],
                Icon(
                  _isNoteExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                ),
              ],
            ),
            if (_isNoteExpanded) ...[
              const SizedBox(height: 12),
              Text(
                widget.note.plainTextBody.isNotEmpty ? widget.note.plainTextBody : '(sem conteúdo)',
                style: GoogleFonts.lora(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(Comment c, bool isMe, bool isNoteAuthor) {
    String? photoUrl = c.authorPhoto;
    if (photoUrl != null && photoUrl.contains('googleusercontent.com')) {
      photoUrl = photoUrl.replaceAll(RegExp(r'=s\d+(-c)?'), '=s256-c');
    }
    if (kIsWeb && photoUrl != null && photoUrl.startsWith('http') && !photoUrl.contains('wsrv.nl')) {
      photoUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(photoUrl)}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withValues(alpha: 0.2),
                ),
                child: photoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 14, color: _gold),
                      ),
                    )
                  : const Icon(Icons.person, size: 14, color: _gold),
              ),
              const SizedBox(width: 12),
              Text(
                c.authorName,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (c.authorId == widget.note.authorId) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('AUTOR',
                      style: GoogleFonts.outfit(
                          color: _gold,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ],
              const SizedBox(width: 8),
              _buildKindChip(c.kind),
              if (c.isAccepted) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: Colors.green, size: 14),
              ],
            ],
          ),
          if (c.replyToPreview != null)
            Container(
              margin: const EdgeInsets.only(top: 12, left: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
                border: Border(
                    left: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24), width: 3)),
              ),
              child: Text(
                c.replyToPreview!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 14, right: 14),
            child: Text(
              c.text,
              style: GoogleFonts.lora(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 6),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _replyTo = c),
                  icon: Icon(Icons.reply, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                  label: Text('Responder',
                      style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                if (isNoteAuthor && c.kind == 'resposta' && !c.isAccepted) ...[
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () => ref
                        .read(commentsServiceProvider)
                        .acceptAnswer(widget.note.id, c.id),
                    icon: const Icon(Icons.check_circle_outline,
                        size: 16, color: Colors.green),
                    label: Text('Marcar como Resposta',
                        style: GoogleFonts.outfit(
                            color: Colors.green, fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
                if (isMe) ...[
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () => ref
                        .read(commentsServiceProvider)
                        .deleteComment(widget.note.id, c.id),
                    icon: Icon(Icons.delete_outline,
                        size: 16, color: Colors.redAccent.withValues(alpha: 0.8)),
                    label: Text('Excluir',
                        style: GoogleFonts.outfit(
                            color: Colors.redAccent.withValues(alpha: 0.8), fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKindChip(String kind) {
    Color color;
    switch (kind) {
      case 'pergunta':
        color = Colors.orange;
        break;
      case 'resposta':
        color = Colors.green;
        break;
      default:
        color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        kind.toUpperCase(),
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05))),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_replyTo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(color: _gold, width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Respondendo a ${_replyTo!.authorName}: "${_replyTo!.text}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                      ),
                      onPressed: () => setState(() => _replyTo = null),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                _buildSelectableChip('Complemento', 'complemento', Colors.blue),
                const SizedBox(width: 8),
                _buildSelectableChip('Pergunta', 'pergunta', Colors.orange),
                const SizedBox(width: 8),
                _buildSelectableChip('Resposta', 'resposta', Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Escreva um comentário...',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendComment(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _gold,
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.black87),
                    onPressed: _sendComment,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectableChip(String label, String value, Color baseColor) {
    final isSelected = _selectedKind == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedKind = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? baseColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? baseColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? baseColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
