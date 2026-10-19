import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/features/home/service/devocional_service.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/core/widgets/smart_hide_nav.dart' as keryx_nav;
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';

// Constantes de cores do design









class DevocionalScreen extends ConsumerWidget {
  final DevocionalData devocional;

  const DevocionalScreen({super.key, required this.devocional});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const MBibliaTopBar(
        title: 'KeryxApp',
        showBackButton: false,
      ),
      extendBody: true,
      bottomNavigationBar: BookDetailBottomNav(
        currentIndex: 0,
        onTap: (index) {
          ref.read(navigationProvider.notifier).setIndex(index);
          Navigator.popUntil(context, (route) => route.isFirst);
        },
        onBack: () => Navigator.pop(context),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          return keryx_nav.handleNavbarScrollNotification(
            notification,
            ref.read(navbarVisibleProvider),
            (visible) => ref.read(navbarVisibleProvider.notifier).state = visible,
          );
        },
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wb_sunny_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'REFLEXÃO DO DIA',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    devocional.title,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Versículo Base
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    devocional.verse.replaceAll('“', '').replaceAll('”', '').replaceAll('...', ''),
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '— ${devocional.verseReference}',
                      style: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Texto do Devocional com Referências Clicáveis
            _buildContentWithLinks(context, ref, devocional.content),
            const SizedBox(height: 48),

            // Botão para ler na Bíblia
            InkWell(
              onTap: () {
                final books = ref.read(booksProvider).value ?? [];
                if (books.isNotEmpty) {
                  String refParts = devocional.verseReference.replaceAll('—', '').trim();
                  final bookNameOrAbbrev = refParts.split(RegExp(r'\s+')).first.toLowerCase();
                  
                  final book = books.firstWhere(
                    (b) => b.name.toLowerCase() == bookNameOrAbbrev || 
                           b.abbrev.toLowerCase() == bookNameOrAbbrev ||
                           refParts.toLowerCase().startsWith(b.name.toLowerCase()) ||
                           refParts.toLowerCase().startsWith('${b.name.toLowerCase()} '),
                    orElse: () => books.firstWhere((b) => b.name == 'Salmos' || b.abbrev.toLowerCase() == 'sl', orElse: () => books.first)
                  );
                  
                  int chapter = 1;
                  final match = RegExp(r'(\d+):').firstMatch(refParts);
                  if (match != null) {
                    chapter = int.tryParse(match.group(1) ?? '1') ?? 1;
                  }

                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Container(
                      height: MediaQuery.of(context).size.height * 0.9,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: ReadingScreen(
                        book: book,
                        initialChapter: chapter,
                      ),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B37C2), Color(0xFF1E1E7F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E1E7F).withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_stories, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Ler Capítulo Completo',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
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

  Widget _buildContentWithLinks(BuildContext context, WidgetRef ref, String content) {
    // Regex para encontrar algo como "Atos 1:8", "Mateus 5:13-16", "1 João 3:1"
    final refRegex = RegExp(r'([1-3]?\s?[A-ZÇÃ][a-záãçéíóú]+\s+\d+:\d+(?:-\d+)?)');
    final matches = refRegex.allMatches(content);
    
    if (matches.isEmpty) {
      return Text(
        content,
        style: GoogleFonts.outfit(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          fontSize: 17,
          height: 1.7,
        ),
      );
    }
    
    List<TextSpan> spans = [];
    int lastMatchEnd = 0;
    
    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: content.substring(lastMatchEnd, match.start)));
      }
      
      final verseRef = match.group(0)!;
      spans.add(TextSpan(
        text: verseRef,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface, 
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.bold,
        ),
        recognizer: TapGestureRecognizer()..onTap = () {
          _showVerseModal(context, ref, verseRef);
        },
      ));
      lastMatchEnd = match.end;
    }
    
    if (lastMatchEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastMatchEnd)));
    }
    
    return RichText(
      text: TextSpan(
        style: GoogleFonts.outfit(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          fontSize: 17,
          height: 1.7,
        ),
        children: spans,
      ),
    );
  }

  void _showVerseModal(BuildContext context, WidgetRef ref, String reference) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.menu_book_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(reference, style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: FutureBuilder<String>(
          future: _fetchVerseText(ref, reference),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 100, 
                child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
              );
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Text(
                'Não foi possível carregar os versículos.', 
                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 16),
              );
            }
            return SingleChildScrollView(
              child: Text(
                snapshot.data!,
                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 17, height: 1.6),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('FECHAR', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<String> _fetchVerseText(WidgetRef ref, String reference) async {
    final books = ref.read(booksProvider).value ?? [];
    if (books.isEmpty) return '';

    final bookNameOrAbbrev = reference.split(RegExp(r'\s+\d')).first.trim().toLowerCase();
    
    final book = books.firstWhere(
      (b) => b.name.toLowerCase() == bookNameOrAbbrev || 
             b.abbrev.toLowerCase() == bookNameOrAbbrev ||
             reference.toLowerCase().startsWith(b.name.toLowerCase()) ||
             reference.toLowerCase().startsWith('${b.name.toLowerCase()} '),
      orElse: () => books.first
    );

    final match = RegExp(r'(\d+):(\d+)(?:-(\d+))?').firstMatch(reference);
    if (match == null) return '';

    int chapter = int.parse(match.group(1)!);
    int startVerse = int.parse(match.group(2)!);
    int endVerse = match.group(3) != null ? int.parse(match.group(3)!) : startVerse;

    try {
      final bibleService = ref.read(bibleServiceProvider);
      final version = ref.read(selectedVersionProvider);
      final chapterData = await bibleService.getChapter(version, book.abbrev, chapter);
      
      String text = '';
      for (final v in chapterData.verses) {
        if (v.number >= startVerse && v.number <= endVerse) {
          text += '${v.number}. ${v.text}\n\n';
        }
      }
      return text.trim();
    } catch (e) {
      return '';
    }
  }
}