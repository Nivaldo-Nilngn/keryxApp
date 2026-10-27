import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/community/model/community_story.dart';
import 'package:keryx_app/features/community/model/user_stories_group.dart';
import 'package:keryx_app/core/utils/bible_reference_helper.dart';
import 'package:keryx_app/features/community/view/widgets/community_user_avatar.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  final List<UserStoriesGroup> groups;
  final int initialGroupIndex;
  final int initialStoryIndex;

  StoryViewerScreen({
    super.key,
    List<UserStoriesGroup>? groups,
    List<CommunityStory>? stories,
    CommunityStory? story,
    this.initialGroupIndex = 0,
    this.initialStoryIndex = 0,
  }) : groups = groups ??
            (stories != null && stories.isNotEmpty
                ? UserStoriesGroup.fromStories(stories)
                : (story != null
                    ? [
                        UserStoriesGroup(
                          authorName: story.authorName,
                          authorAvatar: story.authorAvatar,
                          stories: [story],
                        )
                      ]
                    : []));

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late int _currentGroupIndex;
  late int _currentStoryIndex;
  bool _isPaused = false;
  static const int _storyDurationSeconds = 25; // 25s para meditação bíblica serena

  UserStoriesGroup? get _currentGroup {
    if (widget.groups.isEmpty ||
        _currentGroupIndex < 0 ||
        _currentGroupIndex >= widget.groups.length) {
      return null;
    }
    return widget.groups[_currentGroupIndex];
  }

  CommunityStory? get _currentStory {
    final group = _currentGroup;
    if (group == null ||
        group.stories.isEmpty ||
        _currentStoryIndex < 0 ||
        _currentStoryIndex >= group.stories.length) {
      return null;
    }
    return group.stories[_currentStoryIndex];
  }

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex.clamp(
      0,
      widget.groups.isEmpty ? 0 : widget.groups.length - 1,
    );
    final group = _currentGroup;
    _currentStoryIndex = widget.initialStoryIndex.clamp(
      0,
      group == null || group.stories.isEmpty ? 0 : group.stories.length - 1,
    );

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
    _advanceToNext();
  }

  void _advanceToNext() {
    final group = _currentGroup;
    if (group == null) return;

    // Se ainda há stories deste usuário, avança para o próximo story dele
    if (_currentStoryIndex < group.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
        _isPaused = false;
      });
      _progressController.reset();
      _progressController.forward();
    } else {
      // Acabaram os stories deste usuário! Vai para o próximo usuário
      if (_currentGroupIndex < widget.groups.length - 1) {
        setState(() {
          _currentGroupIndex++;
          _currentStoryIndex = 0;
          _isPaused = false;
        });
        _progressController.reset();
        _progressController.forward();
      } else {
        // Último story do último usuário: pausa para contemplação
        _progressController.stop();
        if (mounted) setState(() => _isPaused = true);
      }
    }
  }

  void _advanceToPrevious() {
    final group = _currentGroup;
    if (group == null) return;

    // Se não está no primeiro story do usuário, volta para o anterior dele
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
        _isPaused = false;
      });
      _progressController.reset();
      _progressController.forward();
    } else {
      // Está no primeiro story deste usuário: volta para o usuário anterior (no último story dele)
      if (_currentGroupIndex > 0) {
        setState(() {
          _currentGroupIndex--;
          final prevGroup = widget.groups[_currentGroupIndex];
          _currentStoryIndex = prevGroup.stories.isNotEmpty ? prevGroup.stories.length - 1 : 0;
          _isPaused = false;
        });
        _progressController.reset();
        _progressController.forward();
      } else {
        // Primeiro story do primeiro usuário: apenas reinicia a barra
        _progressController.reset();
        _progressController.forward();
      }
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

  void _shareStory(CommunityStory story) {
    setState(() {
      _isPaused = true;
      _progressController.stop();
    });

    final buffer = StringBuffer();
    if (story.verseText != null && story.verseText!.isNotEmpty) {
      buffer.writeln('“${story.verseText}”');
    }
    if (story.bibleReference != null && story.bibleReference!.isNotEmpty) {
      buffer.writeln('— ${story.bibleReference}');
    }
    if (story.reflection != null && story.reflection!.isNotEmpty) {
      buffer.writeln('\n${story.reflection}');
    }
    buffer.writeln('\nCompartilhado via KeryxApp 📖✨');

    try {
      SharePlus.instance.share(ShareParams(text: buffer.toString()));
    } catch (e) {
      debugPrint('⚠️ Erro ao compartilhar story: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _currentGroup;
    final story = _currentStory;

    if (group == null || story == null) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final totalStoriesInGroup = group.stories.length;
    final isOfficial = group.isOfficial;

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

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _advanceToPrevious,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _advanceToNext,
        const SingleActivator(LogicalKeyboardKey.space): _togglePlayPause,
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF0C0C12),
          body: GestureDetector(
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 300) {
                Navigator.pop(context);
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;
                final viewport = _buildStoryViewport(
                  context: context,
                  story: story,
                  group: group,
                  totalStoriesInGroup: totalStoriesInGroup,
                  isOfficial: isOfficial,
                  gradientOverlay: gradientOverlay,
                  isDesktop: isDesktop,
                );

                if (!isDesktop) {
                  return viewport;
                }

                // Layout Desktop / Web Estilo Instagram Web
                return Stack(
                  children: [
                    // Fundo escuro imersivo
                    Positioned.fill(
                      child: Container(color: const Color(0xFF0A0A0F)),
                    ),

                    // Botão Fechar no Canto Superior Direito (Desktop)
                    Positioned(
                      top: 18,
                      right: 22,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 30),
                        tooltip: 'Fechar (Esc)',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // Navegação Lateral e Story Centralizado em Formato 9:16
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Seta Esquerda (Anterior)
                          if (_currentStoryIndex > 0 || _currentGroupIndex > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Material(
                                color: Colors.white.withValues(alpha: 0.16),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _advanceToPrevious,
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 66),

                          // Quadro 9:16 Centralizado do Story
                          Container(
                            width: 420,
                            height: (constraints.maxHeight * 0.94).clamp(620.0, 840.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  blurRadius: 40,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: viewport,
                          ),

                          // Seta Direita (Próximo)
                          if (_currentStoryIndex < totalStoriesInGroup - 1 ||
                              _currentGroupIndex < widget.groups.length - 1)
                            Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: Material(
                                color: Colors.white.withValues(alpha: 0.16),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _advanceToNext,
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 22),
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 66),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryViewport({
    required BuildContext context,
    required CommunityStory story,
    required UserStoriesGroup group,
    required int totalStoriesInGroup,
    required bool isOfficial,
    required LinearGradient gradientOverlay,
    required bool isDesktop,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isDesktop ? 24 : 0),
      child: Stack(
        children: [
          // 1. Imagem de Fundo (se houver)
          if (story.mediaUrl != null && story.mediaUrl!.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                story.mediaUrl!,
                semanticLabel: 'Imagem de fundo do story de ${story.authorName}',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          // 2. Camada de Gradiente Atmosférico Escuro
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(gradient: gradientOverlay),
            ),
          ),

          // 3. Áreas de Toque Laterais para Navegar (30% esquerda / 70% direita)
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _advanceToPrevious,
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
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _advanceToNext,
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

          // 4. Conteúdo Visual Completo com Story Perfeitamente Centralizado
          SafeArea(
            child: Column(
              children: [
                // Barras de Progresso Segmentadas no Topo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: List.generate(totalStoriesInGroup, (index) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, _) {
                              double val = 0.0;
                              if (index < _currentStoryIndex) {
                                val = 1.0;
                              } else if (index == _currentStoryIndex) {
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

                // Header do Story (Autor, Play/Pausa, Compartilhar, Fechar)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      CommunityUserAvatar(
                        photoUrl: group.resolvedAvatar,
                        name: group.displayName,
                        radius: 18,
                        isOfficial: isOfficial,
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
                                    group.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (totalStoriesInGroup > 1) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_currentStoryIndex + 1}/$totalStoriesInGroup',
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.kPrimaryGold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              story.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: AppTheme.kPrimaryGold,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Botão Pausar / Continuar
                      IconButton(
                        icon: Icon(
                          _isPaused ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        tooltip: _isPaused ? 'Continuar tempo' : 'Pausar tempo',
                        onPressed: _togglePlayPause,
                      ),
                      // Botão Compartilhar
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                        tooltip: 'Compartilhar Story',
                        onPressed: () => _shareStory(story),
                      ),
                      // Botão Fechar
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // 5. CONTEÚDO STORY PERFEITAMENTE CENTRALIZADO
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.52),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppTheme.kPrimaryGold.withValues(alpha: 0.40),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.65),
                                blurRadius: 28,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Ícone de Aspas Douradas
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.16),
                                  border: Border.all(
                                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.45),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.format_quote_rounded,
                                  size: 26,
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
                                    fontSize: 17.5,
                                    height: 1.6,
                                    fontStyle: FontStyle.italic,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 10,
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
                                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppTheme.kPrimaryGold.withValues(alpha: 0.55),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    story.bibleReference!,
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.kPrimaryGold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),

                              // Reflexão Devocional Acolhedora
                              if (story.reflection != null && story.reflection!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Divider(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  height: 1,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  story.reflection!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 13.5,
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
                  ),
                ),

                // 6. BARRA INFERIOR ESTILO INSTAGRAM STORIES (Responder ao story + Reações)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: Row(
                    children: [
                      // Campo Pílula de Responder
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openStoryReplySheet(story),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Responder a ${group.displayName}...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Reação Rápida Amém ❤️
                      _buildStoryReactionBtn('❤️', 'Amém'),
                      const SizedBox(width: 6),

                      // Reação Rápida Orar 🙏
                      _buildStoryReactionBtn('🙏', 'Orar'),
                      const SizedBox(width: 6),

                      // Botão Abrir na Bíblia
                      if (story.bibleReference != null && story.bibleReference!.isNotEmpty)
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.kPrimaryGold.withValues(alpha: 0.20),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.kPrimaryGold.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.menu_book_rounded, color: AppTheme.kPrimaryGold, size: 20),
                            tooltip: 'Abrir na Bíblia',
                            onPressed: () {
                              Navigator.pop(context);
                              BibleReferenceHelper.openReference(
                                context,
                                ref,
                                story.bibleReference,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryReactionBtn(String emoji, String tooltip) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reação $emoji enviada com sucesso! ✨'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E293B),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 17),
        ),
      ),
    );
  }

  void _openStoryReplySheet(CommunityStory story) {
    setState(() => _isPaused = true);
    _progressController.stop();

    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    CommunityUserAvatar(
                      photoUrl: _currentGroup?.resolvedAvatar,
                      name: _currentGroup?.displayName ?? 'Autor',
                      radius: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Responder a ${_currentGroup?.displayName ?? "story"}',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildReplyQuickChip('🙏 Em oração!', textController),
                      const SizedBox(width: 8),
                      _buildReplyQuickChip('❤️ Glória a Deus!', textController),
                      const SizedBox(width: 8),
                      _buildReplyQuickChip('🙌 Bênção tremenda!', textController),
                      const SizedBox(width: 8),
                      _buildReplyQuickChip('✨ Amém!', textController),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textController,
                        autofocus: true,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Envie uma palavra de bênção...',
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF14141E) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppTheme.kPrimaryGold),
                      onPressed: () {
                        final msg = textController.text.trim();
                        if (msg.isNotEmpty) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Mensagem enviada para ${_currentGroup?.displayName ?? "o autor"}! ✨'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isPaused = false);
        _progressController.forward();
      }
    });
  }

  Widget _buildReplyQuickChip(String text, TextEditingController controller) {
    return GestureDetector(
      onTap: () {
        controller.text = text;
        controller.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.kPrimaryGold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.kPrimaryGold.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.kPrimaryGold,
          ),
        ),
      ),
    );
  }
}
