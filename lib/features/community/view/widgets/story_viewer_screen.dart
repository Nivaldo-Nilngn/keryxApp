import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/community/model/community_story.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/core/state/navigation_state.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  final List<CommunityStory> stories;
  final int initialIndex;

  StoryViewerScreen({
    super.key,
    List<CommunityStory>? stories,
    CommunityStory? story,
    this.initialIndex = 0,
  }) : stories = stories ?? (story != null ? [story] : []);

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late int _currentIndex;
  bool _isPaused = false;
  static const int _storyDurationSeconds = 15; // 15s para leitura meditativa

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.isEmpty ? 0 : widget.stories.length - 1);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _storyDurationSeconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _goToNextStory();
        }
      });
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _goToNextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _progressController.reset();
      _progressController.forward();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _goToPreviousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _progressController.reset();
      _progressController.forward();
    } else {
      _progressController.reset();
      _progressController.forward();
    }
  }

  void _pause() {
    setState(() => _isPaused = true);
    _progressController.stop();
  }

  void _resume() {
    setState(() => _isPaused = false);
    _progressController.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final story = widget.stories[_currentIndex];

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

    final totalStories = widget.stories.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) {
            Navigator.pop(context);
          }
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: gradient),
          child: SafeArea(
            child: Stack(
              children: [
                // 1. Áreas de Toque para avançar / retroceder e segurar para pausar
                Positioned.fill(
                  child: Row(
                    children: [
                      // Toque à esquerda (Voltar)
                      Expanded(
                        flex: 1,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _goToPreviousStory,
                          onLongPressStart: (_) => _pause(),
                          onLongPressEnd: (_) => _resume(),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      // Centro / Direita (Avançar)
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _goToNextStory,
                          onLongPressStart: (_) => _pause(),
                          onLongPressEnd: (_) => _resume(),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Conteúdo visual
                Column(
                  children: [
                    // Barras de Progresso Segmentadas no Topo
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: List.generate(totalStories, (index) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: AnimatedBuilder(
                                animation: _progressController,
                                builder: (context, _) {
                                  double val = 0.0;
                                  if (index < _currentIndex) {
                                    val = 1.0;
                                  } else if (index == _currentIndex) {
                                    val = _progressController.value;
                                  }
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: val,
                                      backgroundColor: Colors.white24,
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.kPrimaryGold),
                                      minHeight: 2.8,
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Header do Story (Autor, Titulo, Indicador de Pausa, Fechar)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 19,
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
                                Row(
                                  children: [
                                    Text(
                                      story.authorName,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (_isPaused) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Pausado',
                                          style: GoogleFonts.outfit(fontSize: 10, color: Colors.white70),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  story.title,
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.kPrimaryGold,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.5,
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

                    // Cartão Central de Leitura do Versículo
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.45),
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
                                    fontSize: 20,
                                    height: 1.65,
                                    fontStyle: FontStyle.italic,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 10,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 18),

                              if (story.bibleReference != null && story.bibleReference!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppTheme.kPrimaryGold.withValues(alpha: 0.55),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Text(
                                    story.bibleReference!,
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.kPrimaryGold,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Reações Rápidas e Botão de Abrir na Bíblia
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Chips de Reação Rápida ao Story
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildQuickReaction('🙏 Amém!'),
                              const SizedBox(width: 8),
                              _buildQuickReaction('❤️ Glória a Deus!'),
                              const SizedBox(width: 8),
                              _buildQuickReaction('🙌 Bênção!'),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Botão ABRIR NA BÍBLIA
                          ElevatedButton.icon(
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
                                letterSpacing: 1.2,
                                color: Colors.black,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.kPrimaryGold,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickReaction(String text) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reação enviada: $text'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
