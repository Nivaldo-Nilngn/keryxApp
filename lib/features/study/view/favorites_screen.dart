import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/features/auth/widgets/auth_guard.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/widgets/keryx_top_bar.dart';

class FavoritesScreen extends ConsumerWidget {
  final bool showTopBar;

  const FavoritesScreen({super.key, this.showTopBar = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final bibleService = ref.watch(bibleServiceProvider);

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
        body: favorites.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border, color: Colors.orange, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Nenhum versículo favorito ainda.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Clique em um versículo e escolha ❤ Favoritar',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
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
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          height: 72,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
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
              ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

