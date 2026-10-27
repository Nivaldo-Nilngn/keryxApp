import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/constants/bible_summaries.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';

import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookSummaryScreen extends ConsumerStatefulWidget {
  final BibleBook book;
  const BookSummaryScreen({super.key, required this.book});

  @override
  ConsumerState<BookSummaryScreen> createState() => _BookSummaryScreenState();
}

class _BookSummaryScreenState extends ConsumerState<BookSummaryScreen> {
  bool _isDetailsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bookId = widget.book.id ?? BibleMetadata.findBookId(widget.book.abbrev);
    final summary = BibleSummaries.getSummary(bookId);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      appBar: const MBibliaTopBar(
        title: 'KeryxApp',
        showLogo: true,
        showBackButton: false,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Espaçamento topo ajustado
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.book.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.kPrimaryGold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escolha um capítulo para começar a leitura.',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Escolher Capítulo movido para o topo
                  _buildChapterGrid(context),
                  const SizedBox(height: 20),
                  _buildReadNowButton(context),
                  const SizedBox(height: 36),

                  // Visão Geral e Detalhes
                  _buildSection(
                    label: '💡  VISÃO GERAL',
                    accentColor: AppTheme.kPrimaryGold,
                    child: Text(
                      summary?.overview ??
                          'O livro de ${widget.book.name} faz parte do grupo ${widget.book.group}. Explore as profundezas da Palavra de Deus.',
                      style: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                        height: 1.65,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDetailsExpanded = !_isDetailsExpanded;
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionLabel('ℹ️  MAIS DETALHES', Colors.blueAccent),
                        Icon(
                          _isDetailsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: Colors.blueAccent.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isDetailsExpanded) ...[
                    Row(
                      children: [
                        _buildStatChip('${widget.book.chapters}', 'Capítulos', const Color(0xFF3B37C2)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatChip(widget.book.group, 'Grupo', const Color(0xFF1E5C6E)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.book.author,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (summary != null) ...[
                      if (summary.period.isNotEmpty)
                        _buildAccentField(Icons.schedule_outlined, 'Período', summary.period, const Color(0xFF00BCD4)),
                      if (summary.context.isNotEmpty)
                        _buildAccentField(Icons.map_outlined, 'Contexto', summary.context, const Color(0xFFFF9800)),
                      if (summary.audience.isNotEmpty)
                        _buildAccentField(Icons.people_outline, 'Público', summary.audience, const Color(0xFF9C27B0)),
                      if (summary.purpose.isNotEmpty)
                        _buildAccentField(Icons.flag_outlined, 'Propósito', summary.purpose, const Color(0xFF4CAF50)),
                    ],
                    const SizedBox(height: 28),
                    if (summary != null) ...[
                      _buildSectionLabel('⚡  IMPACTO', Colors.purpleAccent),
                      const SizedBox(height: 12),
                      _buildImpactTimeline(summary),
                      const SizedBox(height: 28),
                    ],
                  ],
                ],
              ),
            ),
            
            // Navbar Fixa
            Align(
              alignment: Alignment.bottomCenter,
              child: BookDetailBottomNav(
                currentIndex: 1, // Sempre na aba da Bíblia
                onTap: (index) {
                  Navigator.pop(context); // Sai do resumo
                  ref.read(navigationProvider.notifier).setIndex(index); // Muda a aba
                },
                onBack: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── WIDGETS ─────────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text, Color color) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: color.withValues(alpha: 0.7),
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _buildSection({required String label, required Color accentColor, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label, accentColor),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccentField(IconData icon, String label, String value, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactTimeline(BookSummary summary) {
    final items = <Map<String, dynamic>>[];
    if (summary.biblicalConnections.isNotEmpty) {
      items.add({'label': 'Conexões Bíblicas', 'text': summary.biblicalConnections, 'color': const Color(0xFFD4AF37), 'icon': Icons.link_outlined});
    }
    if (summary.theologicalRelevance.isNotEmpty) {
      items.add({'label': 'Relevância Teológica', 'text': summary.theologicalRelevance, 'color': const Color(0xFF7C4DFF), 'icon': Icons.auto_awesome_outlined});
    }
    if (summary.practicalApplication.isNotEmpty) {
      items.add({'label': 'Aplicação Prática', 'text': summary.practicalApplication, 'color': const Color(0xFF00E676), 'icon': Icons.offline_bolt_outlined});
    }

    return Column(
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        final color = item['color'] as Color;
        final isLast = i == items.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline track
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Icon(item['icon'] as IconData, color: color, size: 16),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        item['label'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['text'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChapterGrid(BuildContext context) {
    return Container(
      height: 320, // Altura maior para acomodar melhor a rolagem
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07)),
      ),
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: GridView.builder(
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, // Botões maiores
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: widget.book.chapters,
          itemBuilder: (context, index) {
            final chapter = index + 1;
            return InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReadingScreen(book: widget.book, initialChapter: chapter),
                ),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08), // Mais claro para destaque
                  borderRadius: BorderRadius.circular(16), // Mais arredondado
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$chapter',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 18, // Fonte maior
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReadNowButton(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingScreen(book: widget.book, initialChapter: 1),
        ),
      ),
      child: Container(
        width: double.infinity,
        height: 68,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B37C2), Color(0xFF1E1E7F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
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
            const Icon(Icons.auto_stories, color: Colors.white, size: 26),
            const SizedBox(width: 14),
            Text(
              'Ler Agora  •  ${widget.book.name} 1',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
