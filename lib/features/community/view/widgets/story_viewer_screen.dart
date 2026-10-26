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
  static const int _storyDurationSeconds = 25; // 25s para leitura meditativa com calma

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.isEmpty ? 0 : widget.stories.length - 1);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _storyDurationSeconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onProgressCompleted();
        }
      });
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _onProgressCompleted() {
    if (_currentIndex < widget.stories.length - 1) {
      _goToNextStory();
    } else {
      // NÃO fecha a tela automaticamente! Permanece no último story pausado para contemplação.
      _progressController.stop();
      if (mounted) setState(() => _isPaused = true);
    }
  }

  void _goToNextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _isPaused = false;
      });
      _progressController.reset();
      _progressController.forward();
    } else {
      // No último story, pausa e mantém aberto para meditação
      _progressController.stop();
      setState(() => _isPaused = true);
    }
  }

  void _goToPreviousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isPaused = false;
      });
      _progressController.reset();
      _progressController.forward();
    } else {
      _progressController.reset();
      _progressController.forward();
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _progressController.stop();
      } else {
        if (_progressController.isCompleted) {
          _progressController.reset();
        }
        _progressController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final story = widget.stories[_currentIndex];
    final totalStories = widget.stories.length;

    LinearGradient gradientOverlay;
    switch (story.backgroundStyle) {
      case 'indigo_gradient':
        gradientOverlay = LinearGradient(
          colors: [
            const Color(0xFF0F172A).withValues(alpha: 0.90),
            const Color(0xFF1E1B4B).withValues(alpha: 0.85),
            const Color(0xFF312E81).withValues(alpha: 0.94),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        break;
      case 'emerald_gradient':
        gradientOverlay = LinearGradient(
          colors: [
            const Color(0xFF022C22).withValues(alpha: 0.90),
            const Color(0xFF064E3B).withValues(alpha: 0.85),
            const Color(0xFF065F46).withValues(alpha: 0.94),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        break;
      case 'crimson_gradient':
        gradientOverlay = LinearGradient(
          colors: [
            const Color(0xFF4C0519).withValues(alpha: 0.90),
            const Color(0xFF881337).withValues(alpha: 0.85),
            const Color(0xFF9F1239).withValues(alpha: 0.94),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        break;
      case 'gold_gradient':
      default:
        gradientOverlay = LinearGradient(
          colors: [
            const Color(0xFF1C1917).withValues(alpha: 0.90),
            const Color(0xFF292524).withValues(alpha: 0.85),
            const Color(0xFF78350F).withValues(alpha: 0.94),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        break;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) {
            Navigator.pop(context);
          }
        },
        child: Stack(
          children: [
            // 1. Imagem de Fundo (se houver)
            if (story.mediaUrl != null && story.mediaUrl!.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  story.mediaUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

            // 2. Camada de Gradiente Atmosférico Escuro (garante 100% de contraste)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(gradient: gradientOverlay),
              ),
            ),

            // 3. Áreas de Toque Laterais para Navegar
            Positioned.fill(
              child: Row(
                children: [
                  // Lado Esquerdo: Voltar
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _goToPreviousStory,
                      onLongPressStart: (_) {
                        setState(() => _isPaused = true);
                        _progressController.stop();
                      },
                      onLongPressEnd: (_) {
                        setState(() => _isPaused = false);
                        _progressController.forward();
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                  // Lado Direito: Avançar
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _goToNextStory,
                      onLongPressStart: (_) {
                        setState(() => _isPaused = true);
                        _progressController.stop();
                      },
                      onLongPressEnd: (_) {
                        setState(() => _isPaused = false);
                        _progressController.forward();
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Conteúdo Visual Completo
            SafeArea(
              child: Column(
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
                                    minHeight: 3.0,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Header do Story (Autor, Play/Pausa, Fechar)
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
                              Text(
                                story.authorName,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
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
                        // Botão de Pausar / Continuar
                        IconButton(
                          icon: Icon(
                            _isPaused ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          tooltip: _isPaused ? 'Continuar tempo' : 'Pausar tempo',
                          onPressed: _togglePlayPause,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Card Central de Meditação (Preenchimento Visual Nobre)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppTheme.kPrimaryGold.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                              ),
                              child: const Icon(
                                Icons.format_quote_rounded,
                                size: 28,
                                color: AppTheme.kPrimaryGold,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Versículo Bíblico em Destaque
                            if (story.verseText != null && story.verseText!.isNotEmpty)
                              Text(
                                '“${story.verseText}”',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.merriweather(
                                  color: Colors.white,
                                  fontSize: 18.5,
                                  height: 1.6,
                                  fontStyle: FontStyle.italic,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 12),

                            // Badge da Referência
                            if (story.bibleReference != null && story.bibleReference!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  story.bibleReference!,
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.kPrimaryGold,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),

                            // Reflexão Devocional Acolhedora
                            if (story.reflection != null && story.reflection!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Divider(
                                color: Colors.white.withValues(alpha: 0.15),
                                height: 1,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                story.reflection!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.90),
                                  fontSize: 14,
                                  height: 1.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Controles de Navegação e Botão ABRIR NA BÍBLIA
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Setas de navegação discretas
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_currentIndex > 0)
                              TextButton.icon(
                                onPressed: _goToPreviousStory,
                                icon: const Icon(Icons.arrow_back_ios_rounded, size: 14, color: Colors.white70),
                                label: Text(
                                  'Anterior',
                                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                                ),
                              )
                            else
                              const SizedBox(width: 80),

                            // Indicador de Story 1 de 4
                            Text(
                              '${_currentIndex + 1} de $totalStories',
                              style: GoogleFonts.outfit(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            if (_currentIndex < totalStories - 1)
                              TextButton.icon(
                                onPressed: _goToNextStory,
                                label: Text(
                                  'Próximo',
                                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                                ),
                                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                              )
                            else
                              const SizedBox(width: 80),
                          ],
                        ),
                        const SizedBox(height: 8),

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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReaction(String text) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reação enviada: $text ✨'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
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
