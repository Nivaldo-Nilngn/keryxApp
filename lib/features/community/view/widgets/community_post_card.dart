import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/community/model/community_post.dart';
import 'package:keryx_app/features/community/view_model/community_feed_provider.dart';
import 'package:keryx_app/features/community/view/widgets/community_comments_bottom_sheet.dart';
import 'package:keryx_app/core/utils/bible_reference_helper.dart';
import 'package:keryx_app/features/community/view/widgets/community_user_avatar.dart';

class CommunityPostCard extends ConsumerStatefulWidget {
  final CommunityPost post;

  const CommunityPostCard({super.key, required this.post});

  @override
  ConsumerState<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends ConsumerState<CommunityPostCard>
    with SingleTickerProviderStateMixin {
  bool _showHeartAnimation = false;
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

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isAuthor = currentUserId != null && currentUserId == post.userId;

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
                  photoUrl: post.userAvatar,
                  name: post.userName,
                  userId: post.userId,
                  radius: 20,
                  isOfficial: post.userName.toLowerCase().contains('keryx') || post.userBadge == 'Oficial',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildBadge(post.userBadge),
                        ],
                      ),
                      Text(
                        _formatTime(post.createdAt),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  onSelected: (val) {
                    if (val == 'delete') {
                      ref.read(communityFeedProvider.notifier).deletePost(post.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Publicação excluída.')),
                      );
                    } else if (val == 'share') {
                      _sharePost(post);
                    }
                  },
                  itemBuilder: (context) => [
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
                  ],
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

          // 3. Barra de Ações (🙏 Orar, ❤️ Amém, 💬 Comentários, ↗️ Compartilhar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botão Orar 🙏
                        _buildActionButton(
                          context: context,
                          icon: Icons.volunteer_activism_rounded,
                          label: 'Orar',
                          count: post.prayingCount,
                          isActive: post.userPrayed,
                          activeColor: const Color(0xFF10B981),
                          onTap: () {
                            ref.read(communityFeedProvider.notifier).toggleReaction(post.id, 'pray');
                          },
                        ),
                        const SizedBox(width: 6),

                        // Botão Amém ❤️
                        _buildActionButton(
                          context: context,
                          icon: post.userAmen ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          label: 'Amém',
                          count: post.amenCount,
                          isActive: post.userAmen,
                          activeColor: const Color(0xFFEF4444),
                          onTap: () {
                            ref.read(communityFeedProvider.notifier).toggleReaction(post.id, 'amen');
                          },
                        ),
                        const SizedBox(width: 6),

                        // Botão Comentários 💬
                        _buildActionButton(
                          context: context,
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Comentar',
                          count: post.commentsCount,
                          isActive: false,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => CommunityCommentsBottomSheet(post: post),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Botão Compartilhar ↗️
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  tooltip: 'Compartilhar',
                  onPressed: () => _sharePost(post),
                ),
              ],
            ),
          ),

          // 4. Pílulas de Bênçãos / Reações Rápidas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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

          // 5. Legenda e Prévia de Comentários
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
              child: Text(
                post.caption,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),

          if (post.commentsCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
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
                  'Ver todos os ${post.commentsCount} comentários...',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 10),
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

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int count,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final color = isActive
        ? activeColor
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);

    return Semantics(
      label: '$label: $count',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 5),
              Text(
                count > 0 ? '$count' : label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
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
