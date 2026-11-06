import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/features/auth/widgets/auth_guard.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/widgets/keryx_top_bar.dart';
import 'package:keryx_app/core/state/navigation_state.dart';

class FavoritesScreen extends ConsumerWidget {
  final bool showTopBar;

  const FavoritesScreen({super.key, this.showTopBar = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final bibleService = ref.watch(bibleServiceProvider);
    final isTablet = MediaQuery.of(context).size.width >= 720;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPad = screenWidth > 1100
        ? (screenWidth - 1100) / 2 + 20
        : (isTablet ? 24.0 : 16.0);

    return AuthGuard(
      featureName: 'Versículos Favoritos',
      featureIcon: Icons.favorite_outline,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: showTopBar
            ? const KeryxTopBar(
                title: 'KeryxApp',
                showLogo: true,
                showBackButton: false,
              )
            : null,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontalPad, isTablet ? 24 : 12, horizontalPad, 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── HERO CARD COM NOME DA PÁGINA (ESTILO HOME) ────────────
                    _buildFavoritesHeroCard(context),
                    const SizedBox(height: 20),
                    _buildFavoritesTopCards(context, ref, favorites.length),
                    const SizedBox(height: 8),
                    if (favorites.isEmpty)
                      _buildEmptyState(context, ref),
                  ],
                ),
              ),
            ),
            if (favorites.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.only(left: horizontalPad, right: horizontalPad, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final key = favorites.elementAt(index);
                      final parts = key.split('_');
                      if (parts.length != 3) return const SizedBox.shrink();

                      final bookName = parts[0];
                      final chapter = int.tryParse(parts[1]) ?? 1;
                      final verseNumber = int.tryParse(parts[2]) ?? 1;

                      return FutureBuilder(
                        future: Future.wait([
                          bibleService.getBooks(version: ref.read(selectedVersionProvider)),
                          bibleService.getChapter(
                            ref.read(selectedVersionProvider),
                            bookName,
                            chapter,
                          ),
                        ]),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                              height: 72,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
                              ),
                            );
                          }

                          final books = snapshot.data![0] as List<BibleBook>;
                          final chapterData = snapshot.data![1] as BibleChapter;

                          BibleBook? book;
                          try {
                            book = books.firstWhere((b) => b.name == bookName);
                          } catch (_) {
                            return const SizedBox.shrink();
                          }

                          String verseText = '';
                          try {
                            final verse = chapterData.verses.firstWhere((v) => v.number == verseNumber);
                            verseText = verse.text;
                          } catch (_) {}

                          // Remove Strong's tags like <WH7225> for a cleaner preview
                          verseText = verseText.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

                          return _FavoriteCard(
                            book: book,
                            chapter: chapter,
                            verseNumber: verseNumber,
                            verseText: verseText,
                            verseKey: key,
                          );
                        },
                      );
                    },
                    childCount: favorites.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
              : [const Color(0xFF4F46E5), const Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -20,
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.white.withValues(alpha: 0.15),
              size: 110,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'VERSÍCULOS & MEMORIZAÇÃO',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Versículos Favoritos',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Guarde no coração as passagens e promessas que inspiram o seu caminhar com Deus.',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesTopCards(BuildContext context, WidgetRef ref, int count) {
    final isTablet = MediaQuery.of(context).size.width >= 720;

    final cards = [
      _buildTopNavCard(
        context,
        title: 'Seus Favoritos',
        subtitle: 'Passagens marcadas para leitura e memorização.',
        badgeText: '$count Salvos',
        badgeColor: const Color(0xFFE11D48),
        icon: Icons.favorite_rounded,
        onTap: () {},
      ),
      _buildTopNavCard(
        context,
        title: 'Meditar na Palavra',
        subtitle: 'Reflita nas suas passagens salvas no coração.',
        badgeText: 'Devocional',
        badgeColor: const Color(0xFF4F46E5),
        icon: Icons.self_improvement_rounded,
        onTap: () {},
      ),
      _buildTopNavCard(
        context,
        title: 'Ler na Bíblia',
        subtitle: 'Abra as Escrituras completas e continue a leitura.',
        badgeText: 'Leitor',
        badgeColor: const Color(0xFF0284C7),
        icon: Icons.menu_book_rounded,
        onTap: () {
          ref.read(navigationProvider.notifier).setIndex(1);
        },
      ),
    ];

    if (isTablet) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
            const SizedBox(width: 12),
            Expanded(child: cards[2]),
          ],
        ),
      );
    }

    return SizedBox(
      height: 136,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) => SizedBox(width: 255, child: cards[index]),
      ),
    );
  }

  Widget _buildTopNavCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.outfit(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      icon,
                      size: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        height: 1.25,
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

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border_rounded, color: Colors.redAccent, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhum versículo favorito ainda',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ao ler a Bíblia, toque em qualquer versículo e selecione ❤ Favoritar para salvá-lo aqui.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => ref.read(navigationProvider.notifier).setIndex(1),
            icon: const Icon(Icons.menu_book_rounded, size: 18),
            label: Text(
              'Explorar a Bíblia',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteCard extends ConsumerStatefulWidget {
  final BibleBook book;
  final int chapter;
  final int verseNumber;
  final String verseText;
  final String verseKey;

  const _FavoriteCard({
    required this.book,
    required this.chapter,
    required this.verseNumber,
    required this.verseText,
    required this.verseKey,
  });

  @override
  ConsumerState<_FavoriteCard> createState() => _FavoriteCardState();
}

class _FavoriteCardState extends ConsumerState<_FavoriteCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isExpanded ? Colors.orange.withValues(alpha: 0.3) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.favorite, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.book.name} ${widget.chapter}:${widget.verseNumber}',
                          style: GoogleFonts.outfit(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (widget.verseText.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '"${widget.verseText}"',
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                            ),
                            maxLines: _isExpanded ? null : 2,
                            overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 16),
                Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(Icons.auto_stories, 'Ler', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReadingScreen(
                            book: widget.book,
                            initialChapter: widget.chapter,
                          ),
                        ),
                      );
                    }),
                    _buildActionButton(Icons.delete_outline, 'Remover', () {
                      ref.read(favoritesProvider.notifier).toggleFavorite(widget.verseKey);
                    }, color: Colors.redAccent),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final finalColor = color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: finalColor, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(color: finalColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

