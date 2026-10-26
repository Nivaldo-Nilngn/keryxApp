import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/community/model/community_story.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/core/state/navigation_state.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  final CommunityStory story;

  const StoryViewerScreen({super.key, required this.story});

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) Navigator.pop(context);
        }
      });
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;

    LinearGradient gradient;
    switch (story.backgroundStyle) {
      case 'indigo_gradient':
        gradient = const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        break;
      case 'emerald_gradient':
        gradient = const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF047857)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        break;
      case 'crimson_gradient':
        gradient = const LinearGradient(
          colors: [Color(0xFF4C0519), Color(0xFF881337), Color(0xFF9F1239)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        break;
      case 'gold_gradient':
      default:
        gradient = const LinearGradient(
          colors: [Color(0xFF1C1917), Color(0xFF292524), Color(0xFF44403C), Color(0xFF78350F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        break;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _progressController.stop(),
        onTapUp: (_) => _progressController.forward(),
        onTapCancel: () => _progressController.forward(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: gradient),
          child: SafeArea(
            child: Column(
              children: [
                // Barra de Progresso no Topo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _progressController.value,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.kPrimaryGold),
                          minHeight: 3,
                        ),
                      );
                    },
                  ),
                ),

                // Header do Story (Autor + Fechar)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.kPrimaryGold.withValues(alpha: 0.2),
                        backgroundImage: story.authorAvatar != null && story.authorAvatar!.isNotEmpty
                            ? NetworkImage(story.authorAvatar!)
                            : null,
                        child: (story.authorAvatar == null || story.authorAvatar!.isEmpty)
                            ? const Icon(Icons.auto_stories, color: AppTheme.kPrimaryGold, size: 18)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              story.authorName,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              story.title,
                              style: GoogleFonts.outfit(
                                color: AppTheme.kPrimaryGold,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Conteúdo Principal do Story
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ícone de Citação Dourado
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                              border: Border.all(
                                color: AppTheme.kPrimaryGold.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.format_quote_rounded,
                              size: 32,
                              color: AppTheme.kPrimaryGold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (story.verseText != null && story.verseText!.isNotEmpty)
                            Text(
                              '“${story.verseText}”',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.merriweather(
                                color: Colors.white,
                                fontSize: 19,
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 16),

                          if (story.bibleReference != null && story.bibleReference!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                story.bibleReference!,
                                style: GoogleFonts.outfit(
                                  color: AppTheme.kPrimaryGold,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Botão de Ação: Ler na Bíblia
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final lastRead = ref.read(lastReadProvider);
                      Navigator.pop(context);
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
                        ref.read(navigationProvider.notifier).setIndex(1);
                      }
                    },
                    icon: const Icon(Icons.menu_book_rounded, size: 18, color: Colors.black),
                    label: Text(
                      'ABRIR NA BÍBLIA',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.kPrimaryGold,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
