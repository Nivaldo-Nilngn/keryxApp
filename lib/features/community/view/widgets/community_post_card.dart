import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/community/model/community_post.dart';
import 'package:keryx_app/features/community/view_model/community_feed_provider.dart';
import 'package:keryx_app/features/community/view/widgets/community_comments_bottom_sheet.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/core/state/navigation_state.dart';

class CommunityPostCard extends ConsumerWidget {
  final CommunityPost post;

  const CommunityPostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                  backgroundImage: post.userAvatar != null && post.userAvatar!.isNotEmpty
                      ? NetworkImage(post.userAvatar!)
                      : null,
                  child: (post.userAvatar == null || post.userAvatar!.isEmpty)
                      ? const Icon(Icons.person, color: AppTheme.kPrimaryGold, size: 20)
                      : null,
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

          // 2. Mídia / Cartão Bíblico Central
          if (post.bibleText != null && post.bibleText!.isNotEmpty)
            _buildBibleCard(context, ref, isDark)
          else if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty)
            _buildImageMedia(context),

          // 3. Barra de Ações (🙏 Orar, ❤️ Amém, 💬 Comentários, ↗️ Compartilhar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Botão Orar 🙏
                _buildActionButton(
                  context: context,
                  icon: Icons.volunteer_activism_rounded,
                  label: 'Orar',
                  count: post.prayingCount,
                  isActive: post.userPrayed,
                  activeColor: const Color(0xFF10B981), // Esmeralda / Oração
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
                  activeColor: const Color(0xFFEF4444), // Vermelho Amor
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

                const Spacer(),

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

          // 4. Legenda e Prévia de Comentários
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: '${post.userName}  ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: post.caption),
                  ],
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

  Widget _buildBibleCard(BuildContext context, WidgetRef ref, bool isDark) {
    LinearGradient cardGrad;
    Color accentColor;

    switch (post.cardTheme) {
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
              Icon(Icons.format_quote_rounded, color: accentColor, size: 24),
              const SizedBox(width: 8),
              if (post.bibleReference != null)
                Text(
                  '${post.bibleReference!} (${post.bibleVersion})',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 0.4,
                  ),
                ),
              const Spacer(),
              // Botão para abrir o versículo direto no leitor da Bíblia!
              InkWell(
                onTap: () {
                  final lastRead = ref.read(lastReadProvider);
                  if (lastRead != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReadingScreen(
                          book: lastRead.book,
                          initialChapter: lastRead.chapter,
                        ),
                      ),
                    );
                  } else {
                    Navigator.pop(context);
                    ref.read(navigationProvider.notifier).setIndex(1);
                  }
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
            '“${post.bibleText}”',
            style: GoogleFonts.merriweather(
              fontSize: 14.5,
              height: 1.55,
              color: isDark || post.cardTheme != 'gold'
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: NetworkImage(post.mediaUrl!),
          fit: BoxFit.cover,
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

    return InkWell(
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
    Share.share(text.toString());
  }
}
