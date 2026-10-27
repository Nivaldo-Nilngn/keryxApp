import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/community/model/community_post.dart';
import 'package:keryx_app/features/community/view_model/community_feed_provider.dart';
import 'package:keryx_app/features/community/view/widgets/community_comments_bottom_sheet.dart';
import 'package:keryx_app/core/utils/bible_reference_helper.dart';
import 'package:keryx_app/features/community/view/widgets/community_user_avatar.dart';
import 'package:keryx_app/features/community/view_model/saved_posts_provider.dart';
import 'package:keryx_app/features/community/view/community_user_profile_screen.dart';

class CommunityPostCard extends ConsumerStatefulWidget {
  final CommunityPost post;

  const CommunityPostCard({super.key, required this.post});

  @override
  ConsumerState<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends ConsumerState<CommunityPostCard>
    with SingleTickerProviderStateMixin {
  bool _showHeartAnimation = false;
  bool _isCaptionExpanded = false;
  late AnimationController _heartAnimController;

  @override
  void initState() {
    super.initState();
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _heartAnimController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (!widget.post.userAmen) {
      ref.read(communityFeedProvider.notifier).toggleReaction(widget.post.id, 'amen');
    }
    setState(() => _showHeartAnimation = true);
    _heartAnimController.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _showHeartAnimation = false);
    });
  }

  void _sendQuickComment(String text) async {
    final service = ref.read(communityServiceProvider);
    final comm = await service.addComment(postId: widget.post.id, text: text);
    if (mounted && comm != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bênção enviada: "$text" ✨'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  void _openUserProfile(BuildContext context, String authorName, String? authorAvatar, String? authorFrame) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityUserProfileScreen(
          userId: widget.post.userId,
          userName: authorName,
          userAvatar: authorAvatar,
          userBadge: widget.post.userBadge,
          avatarFrame: authorFrame,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentAuthUser = FirebaseAuth.instance.currentUser;
    final userData = ref.watch(userDataProvider).valueOrNull;
    final currentUserName = (userData?['name'] as String?)?.trim() ??
        currentAuthUser?.displayName?.trim() ??
        '';
    final currentUserId = currentAuthUser?.uid;
    final isAuthor = (currentUserId != null && currentUserId == post.userId) ||
        (currentUserName.isNotEmpty && post.userName.trim().toLowerCase() == currentUserName.toLowerCase());
    final displayAuthorName = isAuthor && currentUserName.isNotEmpty ? currentUserName : post.userName;
    final displayAvatar = isAuthor ? (userData?['photoUrl'] ?? post.userAvatar) : post.userAvatar;
    final displayFrame = isAuthor ? (userData?['avatarFrame'] as String?) : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181824) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header do Post (Autor, Badge, Menu)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                CommunityUserAvatar(
                  photoUrl: displayAvatar,
                  name: displayAuthorName,
                  userId: post.userId,
                  radius: 20,
                  avatarFrame: displayFrame,
                  isOfficial: post.userName.toLowerCase().contains('keryx') || post.userBadge == 'Oficial',
                  onTap: () => _openUserProfile(context, displayAuthorName, displayAvatar, displayFrame),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: () => _openUserProfile(context, displayAuthorName, displayAvatar, displayFrame),
                          child: Text(
                            displayAuthorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '•',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatTime(post.createdAt),
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildBadge(post.userBadge),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  onSelected: (val) async {
                    if (val == 'delete') {
                      ref.read(communityFeedProvider.notifier).deletePost(post.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Publicação excluída.')),
                      );
                    } else if (val == 'share') {
                      _sharePost(post);
                    } else if (val == 'save') {
                      final isSaved = ref.read(savedPostsProvider).contains(post.id);
                      await ref.read(savedPostsProvider.notifier).toggleSave(post.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              !isSaved ? 'Publicação salva nos favoritos 🔖' : 'Publicação removida dos salvos',
                              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: !isSaved ? const Color(0xFF1E293B) : Colors.black87,
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (context) {
                    final isSaved = ref.watch(savedPostsProvider).contains(post.id);
                    return [
                      PopupMenuItem(
                        value: 'save',
                        child: Row(
                          children: [
                            Icon(
                              isSaved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined,
                              size: 18,
                              color: isSaved ? AppTheme.kPrimaryGold : null,
                            ),
                            const SizedBox(width: 10),
                            Text(isSaved ? 'Remover dos Salvos' : 'Salvar Publicação'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Compartilhar'),
                          ],
                        ),
                      ),
                      if (isAuthor)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                              SizedBox(width: 10),
                              Text('Excluir', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                    ];
                  },
                ),
              ],
            ),
          ),

          // 2. Mídia / Cartão Bíblico Central com Double-Tap Animado
          GestureDetector(
            onDoubleTap: _onDoubleTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (post.bibleText != null && post.bibleText!.isNotEmpty)
                  _buildBibleCard(context, isDark)
                else if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty)
                  _buildImageMedia(context)
                else
                  const SizedBox.shrink(),

                // Animação de Coração Pulsante no Double-Tap
                if (_showHeartAnimation)
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.4, end: 1.3).animate(
                      CurvedAnimation(
                        parent: _heartAnimController,
                        curve: Curves.elasticOut,
                      ),
                    ),
                    child: FadeTransition(
                      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                        CurvedAnimation(
                          parent: _heartAnimController,
                          curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
                        ),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 90,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 3. Barra de Ações Estilo Instagram (❤️ Amém, 💬 Comentar, 🙏 Orar, ↗️ Compartilhar ... 🔖 Salvar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                // Botão Amém ❤️
                IconButton(
                  icon: Icon(
                    post.userAmen ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: post.userAmen ? const Color(0xFFEF4444) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                    size: 26,
                  ),
                  tooltip: 'Amém',
                  onPressed: () {
                    ref.read(communityFeedProvider.notifier).toggleReaction(post.id, 'amen');
                  },
                ),
                // Botão Comentários 💬
                IconButton(
                  icon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                    size: 23,
                  ),
                  tooltip: 'Comentários',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => CommunityCommentsBottomSheet(post: post),
                    );
                  },
                ),
                // Botão Orar 🙏
                IconButton(
                  icon: Icon(
                    post.userPrayed ? Icons.volunteer_activism_rounded : Icons.volunteer_activism_outlined,
                    color: post.userPrayed ? const Color(0xFF10B981) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                    size: 24,
                  ),
                  tooltip: 'Em oração',
                  onPressed: () {
                    ref.read(communityFeedProvider.notifier).toggleReaction(post.id, 'pray');
                  },
                ),
                // Botão Compartilhar ↗️ (Aviãozinho Instagram)
                IconButton(
                  icon: Icon(
                    Icons.send_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                    size: 22,
                  ),
                  tooltip: 'Compartilhar',
                  onPressed: () => _sharePost(post),
                ),
                const Spacer(),
                // Botão Salvar 🔖 (Bookmark Instagram)
                Consumer(
                  builder: (context, ref, _) {
                    final isSaved = ref.watch(savedPostsProvider).contains(post.id);
                    return IconButton(
                      icon: Icon(
                        isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: isSaved ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                        size: 26,
                      ),
                      tooltip: isSaved ? 'Salvo' : 'Salvar',
                      onPressed: () async {
                        final willBeSaved = !isSaved;
                        await ref.read(savedPostsProvider.notifier).toggleSave(post.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                willBeSaved ? 'Publicação salva nos favoritos 🔖' : 'Publicação removida dos salvos',
                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: willBeSaved ? const Color(0xFF1E293B) : Colors.black87,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // 4. Resumo de Reações (ex: "14 amém • 7 em oração")
          if (post.amenCount > 0 || post.prayingCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Text(
                _buildReactionSummaryText(post),
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),

          // 5. Legenda Estilo Instagram (**username** texto... mais)
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 3),
              child: _buildInstagramCaption(context, displayAuthorName, post.caption),
            ),

          // 6. Prévia de Comentários
          if (post.commentsCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CommunityCommentsBottomSheet(post: post),
                  );
                },
                child: Text(
                  'Ver todos os ${post.commentsCount} ${post.commentsCount == 1 ? "comentário" : "comentários"}',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),

          // 7. Rodapé com Data Relativa
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
            child: Text(
              _formatTimeFooter(post.createdAt),
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),

          // 8. Pílulas de Bênçãos / Reações Rápidas
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildQuickPill('🙏 Em oração por você!'),
                  const SizedBox(width: 6),
                  _buildQuickPill('❤️ Amém, glória a Deus!'),
                  const SizedBox(width: 6),
                  _buildQuickPill('🙌 Palavra edificante!'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPill(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _sendQuickComment(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222234) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String badge) {
    Color bg;
    Color text;
    if (badge == 'Pastor' || badge == 'Oficial') {
      bg = const Color(0xFFD97706).withValues(alpha: 0.18);
      text = const Color(0xFFD97706);
    } else if (badge == 'Líder') {
      bg = const Color(0xFF3B82F6).withValues(alpha: 0.18);
      text = const Color(0xFF3B82F6);
    } else {
      bg = Colors.grey.withValues(alpha: 0.14);
      text = Colors.grey.shade400;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        badge,
        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Widget _buildBibleCard(BuildContext context, bool isDark) {
    LinearGradient cardGrad;
    Color accentColor;

    switch (widget.post.cardTheme) {
      case 'indigo':
        cardGrad = const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        accentColor = const Color(0xFF818CF8);
        break;
      case 'emerald':
        cardGrad = const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        accentColor = const Color(0xFF34D399);
        break;
      case 'crimson':
        cardGrad = const LinearGradient(
          colors: [Color(0xFF4C0519), Color(0xFF881337)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        accentColor = const Color(0xFFFB7185);
        break;
      case 'gold':
      default:
        cardGrad = LinearGradient(
          colors: isDark
              ? [const Color(0xFF262117), const Color(0xFF3D321D)]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        accentColor = AppTheme.kPrimaryGold;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: cardGrad,
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
              Icon(Icons.format_quote_rounded, color: accentColor, size: 22),
              const SizedBox(width: 8),
              if (widget.post.bibleReference != null)
                Expanded(
                  child: Text(
                    '${widget.post.bibleReference!} (${widget.post.bibleVersion})',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  BibleReferenceHelper.openReference(
                    context,
                    ref,
                    widget.post.bibleReference,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 13, color: accentColor),
                      const SizedBox(width: 4),
                      Text(
                        'Abrir na Bíblia',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '“${widget.post.bibleText}”',
            style: GoogleFonts.merriweather(
              fontSize: 14.5,
              height: 1.55,
              color: isDark || widget.post.cardTheme != 'gold'
                  ? Colors.white.withValues(alpha: 0.95)
                  : const Color(0xFF1E293B),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMedia(BuildContext context) {
    return Semantics(
      label: 'Imagem da postagem de ${widget.post.userName}',
      image: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: NetworkImage(widget.post.mediaUrl!),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }


  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    if (diff.inDays < 7) return 'há ${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  String _buildReactionSummaryText(CommunityPost post) {
    final parts = <String>[];
    if (post.amenCount > 0) {
      parts.add('${post.amenCount} ${post.amenCount == 1 ? "amém" : "améns"}');
    }
    if (post.prayingCount > 0) {
      parts.add('${post.prayingCount} em oração');
    }
    return parts.join(' • ');
  }

  Widget _buildInstagramCaption(BuildContext context, String author, String caption) {
    final isLong = caption.length > 115;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return RichText(
      text: TextSpan(
        style: GoogleFonts.outfit(
          fontSize: 13.5,
          color: onSurface,
          height: 1.38,
        ),
        children: [
          TextSpan(
            text: '$author ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: isLong && !_isCaptionExpanded
                ? '${caption.substring(0, 110).trim()}... '
                : caption,
          ),
          if (isLong)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () => setState(() => _isCaptionExpanded = !_isCaptionExpanded),
                child: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    _isCaptionExpanded ? 'menos' : 'mais',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimeFooter(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'AGORA';
    if (diff.inMinutes < 60) return 'HÁ ${diff.inMinutes} MINUTOS';
    if (diff.inHours < 24) return 'HÁ ${diff.inHours} ${diff.inHours == 1 ? "HORA" : "HORAS"}';
    if (diff.inDays < 7) return 'HÁ ${diff.inDays} ${diff.inDays == 1 ? "DIA" : "DIAS"}';
    return '${dt.day} DE ${_monthName(dt.month).toUpperCase()}';
  }

  String _monthName(int m) {
    const months = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
    ];
    if (m >= 1 && m <= 12) return months[m - 1];
    return '';
  }

  void _sharePost(CommunityPost post) {
    final text = StringBuffer();
    if (post.bibleText != null) {
      text.writeln('“${post.bibleText}”');
      text.writeln('— ${post.bibleReference} (${post.bibleVersion})\n');
    }
    if (post.caption.isNotEmpty) {
      text.writeln('${post.userName} na Comunidade Keryx:');
      text.writeln(post.caption);
    }
    text.writeln('\nLeia mais no KeryxApp: https://keryx.app');
    SharePlus.instance.share(ShareParams(text: text.toString()));
  }
}
