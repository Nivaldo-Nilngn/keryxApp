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
                      semanticLabel: 'Imagem de fundo do story de ${story.authorName}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),

                // 2. Camada de Gradiente Atmosférico Escuro (garante legibilidade máxima)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(gradient: gradientOverlay),
                  ),
                ),

                // 3. Áreas de Toque Laterais para Navegar
                Positioned.fill(
                  child: Row(
                    children: [
                      // Lado Esquerdo: Voltar (story anterior ou usuário anterior)
                      Expanded(
                        flex: 1,
                        child: Semantics(
                          label: 'Story anterior',
                          button: true,
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
                      ),
                      // Lado Direito: Avançar (próximo story deste usuário ou próximo usuário)
                      Expanded(
                        flex: 2,
                        child: Semantics(
                          label: 'Próximo story',
                          button: true,
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
                      ),
                    ],
                  ),
                ),

            // 4. Conteúdo Visual Completo
            SafeArea(
              child: Column(
                children: [
                  // Barras de Progresso Segmentadas no Topo (pertencem ao autor atual)
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

                  // Header do Story (Autor, Play/Pausa, Fechar)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        CommunityUserAvatar(
                          photoUrl: group.resolvedAvatar,
                          name: group.displayName,
                          radius: 19,
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
                                        fontSize: 14.5,
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
                        // Botão de Compartilhar
                        IconButton(
                          icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                          tooltip: 'Compartilhar Story',
                          onPressed: () => _shareStory(story),
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
                            if (_currentStoryIndex > 0 || _currentGroupIndex > 0)
                              TextButton.icon(
                                onPressed: _advanceToPrevious,
                                icon: const Icon(Icons.arrow_back_ios_rounded, size: 14, color: Colors.white70),
                                label: Text(
                                  _currentStoryIndex > 0 ? 'Anterior' : 'Autor anterior',
                                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                                ),
                              )
                            else
                              const SizedBox(width: 80),

                            // Indicador de Story do Autor
                            Text(
                              'Story ${_currentStoryIndex + 1} de $totalStoriesInGroup',
                              style: GoogleFonts.outfit(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            if (_currentStoryIndex < totalStoriesInGroup - 1 ||
                                _currentGroupIndex < widget.groups.length - 1)
                              TextButton.icon(
                                onPressed: _advanceToNext,
                                label: Text(
                                  _currentStoryIndex < totalStoriesInGroup - 1
                                      ? 'Próximo'
                                      : 'Próximo autor',
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

                        // Botão ABRIR NA BÍBLIA e COMPARTILHAR STORY
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  BibleReferenceHelper.openReference(
                                    context,
                                    ref,
                                    story.bibleReference,
                                  );
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
                                  minimumSize: const Size(0, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.share_rounded, color: Colors.white, size: 21),
                                tooltip: 'Compartilhar Story',
                                onPressed: () => _shareStory(story),
                              ),
                            ),
                          ],
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
