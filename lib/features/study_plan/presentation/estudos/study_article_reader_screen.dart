import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:keryx_app/core/theme/app_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/instagram_tablet_sidebar.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:share_plus/share_plus.dart';
import '../../application/study_plan_providers.dart';
import '../../domain/biblical_study.dart';
import '../../data/biblical_studies_repository.dart';

class StudyArticleReaderScreen extends ConsumerStatefulWidget {
  final BiblicalStudy study;

  const StudyArticleReaderScreen({
    super.key,
    required this.study,
  });

  @override
  ConsumerState<StudyArticleReaderScreen> createState() =>
      _StudyArticleReaderScreenState();
}

class _StudyArticleReaderScreenState
    extends ConsumerState<StudyArticleReaderScreen> {
  double _fontSize = 17.0;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollProgress = ValueNotifier<double>(0.0);

  // Cache para renderização ultra-fluida do HTML
  static final String? _merriweatherFamily = GoogleFonts.merriweather().fontFamily;
  static final String? _plusJakartaFamily = GoogleFonts.plusJakartaSans().fontFamily;

  Widget? _cachedHtmlWidget;
  double? _cachedHtmlFontSize;
  String? _cachedHtmlRaw;
  bool? _cachedIsDark;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studyHistoryProvider.notifier).markStarted(widget.study.id);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      final p = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
      _scrollProgress.value = p;
      ref.read(studyHistoryProvider.notifier).updateProgress(widget.study.id, p);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  void _shareStudy() {
    Share.share(
      '${widget.study.title}\n\nLeia este estudo teológico completo no KeryxApp: ${widget.study.slug}',
      subject: widget.study.title,
    );
  }

  String _cleanHtml(String html) {
    var cleaned = html;
    // Remove containers pesados de sumário do wordpress que deixam o parse lento
    cleaned = cleaned.replaceAll(RegExp(r'<div id="ez-toc-container".*?</div>', dotAll: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'<span class="ez-toc-section".*?</span>'), '');
    cleaned = cleaned.replaceAll(RegExp(r'<span class="ez-toc-section-end".*?</span>'), '');
    cleaned = cleaned.replaceAll(RegExp(r'<p>\s*(?:&nbsp;|<br\s*/?>)?\s*</p>'), '');
    return cleaned;
  }

  Widget _getOrBuildHtmlView(BuildContext context, String rawHtml, bool isDark) {
    if (_cachedHtmlWidget != null &&
        _cachedHtmlFontSize == _fontSize &&
        _cachedHtmlRaw == rawHtml &&
        _cachedIsDark == isDark) {
      return _cachedHtmlWidget!;
    }

    _cachedHtmlRaw = rawHtml;
    _cachedHtmlFontSize = _fontSize;
    _cachedIsDark = isDark;
    _cachedHtmlWidget = _buildHtmlViewer(context, _cleanHtml(rawHtml), isDark);
    return _cachedHtmlWidget!;
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 720;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fullContentAsync = ref.watch(studyContentProvider(widget.study.id));

    final Widget readerContent = Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isTablet ? 36.0 : 20.0,
            20.0,
            isTablet ? 36.0 : 20.0,
            60.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadados
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (widget.study.categories.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.kPrimaryGold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            widget.study.categories.first,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.kPrimaryGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      Text(
                        '• ${widget.study.estimatedReadTime}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                      if (widget.study.formattedDate.isNotEmpty)
                        Text(
                          '• ${widget.study.formattedDate}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Título Principal
                  Text(
                    widget.study.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isTablet ? 26 : 22,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),

                  // Divisor sutil
                  const SizedBox(height: 18),
                  Container(
                    height: 1.5,
                    width: double.infinity,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 20),

                  // Conteúdo do Estudo
                  fullContentAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.kPrimaryGold,
                        ),
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Erro ao carregar o artigo: $err',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ),
                    data: (rawHtml) {
                      final htmlToRender = rawHtml ?? widget.study.content ?? widget.study.excerpt;
                      return _getOrBuildHtmlView(context, htmlToRender, isDark);
                    },
                  ),
                  const SizedBox(height: 36),
                  Consumer(
                    builder: (context, ref, _) {
                      final history = ref.watch(studyHistoryProvider);
                      final isDone = history.isCompleted(widget.study.id);
                      return Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDone
                                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              isDone ? Icons.verified_rounded : Icons.menu_book_rounded,
                              size: 36,
                              color: isDone ? const Color(0xFF10B981) : AppTheme.kPrimaryGold,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isDone ? 'Estudo Concluído!' : 'Terminou este estudo?',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isDone
                                  ? 'Este estudo foi marcado como concluído no seu acervo.'
                                  : 'Marque como lido para registrar seu progresso teológico.',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () {
                                ref.read(studyHistoryProvider.notifier).toggleCompleted(widget.study.id);
                              },
                              icon: Icon(isDone ? Icons.replay_rounded : Icons.check_circle_rounded, size: 18),
                              label: Text(isDone ? 'Desmarcar Conclusão' : 'Marcar como Concluído'),
                              style: FilledButton.styleFrom(
                                backgroundColor: isDone ? Colors.grey.shade700 : const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),

        // Barra de progresso de leitura no topo com ValueListenableBuilder (zero rebuilds no texto)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<double>(
            valueListenable: _scrollProgress,
            builder: (_, progress, __) => LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.kPrimaryGold),
            ),
          ),
        ),
      ],
    );

    final Widget innerScaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.study.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final readingState = ref.watch(studyHistoryProvider);
              final isDone = readingState.isCompleted(widget.study.id);
              return IconButton(
                tooltip: isDone ? 'Concluído (Toque para desmarcar)' : 'Marcar como Concluído',
                icon: Icon(
                  isDone ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                  color: isDone
                      ? const Color(0xFF10B981)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 22,
                ),
                onPressed: () {
                  ref.read(studyHistoryProvider.notifier).toggleCompleted(widget.study.id);
                },
              );
            },
          ),
          // Controle de tamanho de fonte
          IconButton(
            tooltip: 'Diminuir fonte',
            icon: const Icon(Icons.text_decrease_rounded, size: 20),
            onPressed: _fontSize > 13
                ? () => setState(() => _fontSize -= 1.5)
                : null,
          ),
          IconButton(
            tooltip: 'Aumentar fonte',
            icon: const Icon(Icons.text_increase_rounded, size: 20),
            onPressed: _fontSize < 28
                ? () => setState(() => _fontSize += 1.5)
                : null,
          ),
          IconButton(
            tooltip: 'Compartilhar',
            icon: const Icon(Icons.share_rounded, size: 20),
            onPressed: _shareStudy,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: readerContent,
    );

    if (isTablet) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: InstagramTabletSidebar(
          currentIndex: -1,
          isRoute: true,
          body: innerScaffold,
          onSelectIndex: (index) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            ref.read(navigationProvider.notifier).setIndex(index);
          },
        ),
      );
    }

    return innerScaffold;
  }

  Widget _buildHtmlViewer(BuildContext context, String htmlContent, bool isDark) {
    final textTheme = Theme.of(context).colorScheme.onSurface;

    return Html(
      data: htmlContent,
      style: {
        "body": Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(_fontSize),
          fontFamily: _merriweatherFamily,
          lineHeight: LineHeight(_fontSize > 18 ? 1.7 : 1.75),
          color: textTheme.withValues(alpha: 0.92),
        ),
        "p": Style(
          margin: Margins.only(bottom: 16),
          lineHeight: const LineHeight(1.75),
          fontFamily: _merriweatherFamily,
        ),
        "h1": Style(
          fontSize: FontSize(_fontSize + 6),
          fontWeight: FontWeight.bold,
          fontFamily: _plusJakartaFamily,
          color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
          margin: Margins.only(top: 24, bottom: 12),
        ),
        "h2": Style(
          fontSize: FontSize(_fontSize + 4),
          fontWeight: FontWeight.bold,
          fontFamily: _plusJakartaFamily,
          color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
          margin: Margins.only(top: 24, bottom: 12),
        ),
        "h3": Style(
          fontSize: FontSize(_fontSize + 2),
          fontWeight: FontWeight.w700,
          fontFamily: _plusJakartaFamily,
          color: textTheme,
          margin: Margins.only(top: 18, bottom: 8),
        ),
        "blockquote": Style(
          margin: Margins.symmetric(vertical: 16),
          padding: HtmlPaddings.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: textTheme.withValues(alpha: 0.05),
          border: const Border(
            left: BorderSide(color: AppTheme.kPrimaryGold, width: 3.5),
          ),
          fontStyle: FontStyle.italic,
        ),
        "strong": Style(
          fontWeight: FontWeight.bold,
          color: textTheme,
        ),
        "ul": Style(
          margin: Margins.only(bottom: 16),
        ),
        "li": Style(
          margin: Margins.only(bottom: 8),
          lineHeight: const LineHeight(1.6),
        ),
      },
      onLinkTap: (url, _, __) {
        if (url != null && url.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Link: $url'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }
}
