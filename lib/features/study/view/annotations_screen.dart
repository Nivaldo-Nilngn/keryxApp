import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/auth/widgets/auth_guard.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/study/model/note_card.dart';
import 'package:keryx_app/features/study/view/note_detail_screen.dart';
import 'package:keryx_app/features/study/view_model/note_cards_provider.dart';

// ──────────────────────────────────────────────────────────────────────────────
// TELA DE ANOTAÇÕES — versão reescrita
// ──────────────────────────────────────────────────────────────────────────────
class AnnotationsScreen extends ConsumerStatefulWidget {
  const AnnotationsScreen({super.key});

  @override
  ConsumerState<AnnotationsScreen> createState() => _AnnotationsScreenState();
}

class _AnnotationsScreenState extends ConsumerState<AnnotationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _search = '';
  final _searchCtrl = TextEditingController();

  static const _gold = AppTheme.kPrimaryGold;
  
  

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Migrar anotações legadas ao abrir
    WidgetsBinding.instance.addPostFrameCallback((_) => _migrateLegacy());
  }

  /// Converte anotações antigas (Map<String,String>) para NoteCards
  void _migrateLegacy() {
    final legacyMap = ref.read(annotationsProvider);
    if (legacyMap.isEmpty) return;
    final notifier = ref.read(noteCardsProvider.notifier);
    final existing = ref.read(noteCardsProvider).map((n) => n.id).toSet();
    for (final entry in legacyMap.entries) {
      if (existing.contains(entry.key)) continue;
      final card = entry.key.startsWith('iatheos_')
          ? NoteCard.fromIaTheos(entry.key, entry.value)
          : NoteCard.fromLegacy(entry.key, entry.value);
      notifier.save(card);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navbarVisibleProvider.notifier).state = true;
    });

    final allNotes = ref.watch(noteCardsProvider);

    // Filtra por busca
    final filtered = _search.isEmpty
        ? allNotes
        : allNotes.where((n) {
            final q = _search.toLowerCase();
            return n.title.toLowerCase().contains(q) ||
                n.body.toLowerCase().contains(q) ||
                n.tags.any((t) => t.toLowerCase().contains(q));
          }).toList();

    final personalNotes = filtered.where((n) => !n.isCommunityOnly).toList();
    final publicNotes = filtered.where((n) => n.isPublic && !n.isCommunityOnly).toList();

    return AuthGuard(
      featureName: 'Minhas Anotações',
      featureIcon: Icons.edit_note_outlined,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(allNotes.length),
            _buildSearchBar(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _NotesList(
                    notes: personalNotes,
                    emptyIcon: Icons.menu_book_outlined,
                    emptyMsg: 'Nenhuma anotação salva ainda.\nToque em um versículo na tela de leitura ou em "Nova Nota".',
                    onOpen: _openNote,
                    onDelete: _delete,
                    onToggleCollapse: _toggleCollapse,
                    onTogglePublic: _togglePublic,
                  ),
                  _NotesList(
                    notes: publicNotes,
                    emptyIcon: Icons.public_outlined,
                    emptyMsg: 'Nenhuma nota marcada como pública.',
                    onOpen: _openNote,
                    onDelete: _delete,
                    onToggleCollapse: _toggleCollapse,
                    onTogglePublic: _togglePublic,
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 110),
          child: FloatingActionButton.extended(
            backgroundColor: Theme.of(context).colorScheme.primary,
            onPressed: _createNew,
            icon: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.onPrimary),
            label: Text('Nova Nota',
                style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int count) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suas Anotações',
              style: GoogleFonts.outfit(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count ${count == 1 ? 'nota salva' : 'notas salvas'} · pensamentos, estudos e revelações',
              style: GoogleFonts.outfit(
                  fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
            ),
          ],
        ),
      );

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: TextField(
          controller: _searchCtrl,
          style: GoogleFonts.outfit(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
          cursorColor: _gold,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Buscar notas...',
            hintStyle: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
            prefixIcon:
                Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      );

  Widget _buildTabBar() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TabBar(
          controller: _tabController,
          indicatorColor: _gold,
          labelColor: _gold,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
          labelStyle:
              GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13),
          dividerColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          tabs: const [
            Tab(text: 'Pessoais'),
            Tab(text: 'Públicas'),
          ],
        ),
      );

  void _openNote(NoteCard note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)),
    );
  }

  void _delete(String id) {
    ref.read(noteCardsProvider.notifier).delete(id);
  }

  void _toggleCollapse(String id) {
    ref.read(noteCardsProvider.notifier).toggleCollapse(id);
  }

  void _togglePublic(String id) {
    final list = ref.read(noteCardsProvider);
    final note = list.firstWhere((n) => n.id == id);
    ref.read(noteCardsProvider.notifier).save(note.copyWith(
      isPublic: !note.isPublic,
      updatedAt: DateTime.now(),
      lastActivityAt: !note.isPublic ? DateTime.now() : note.lastActivityAt,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(note.isPublic ? 'Anotação agora é privada' : 'Anotação tornada pública')),
    );
  }

  Future<void> _createNew() async {
    final now = DateTime.now();
    final card = NoteCard(
      id: 'note_${now.millisecondsSinceEpoch}',
      title: 'Nova Nota',
      body: '',
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(noteCardsProvider.notifier).save(card);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoteDetailScreen(note: card)),
      );
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// WIDGET: Lista de notas com cards colapsáveis
// ──────────────────────────────────────────────────────────────────────────────
class _NotesList extends StatelessWidget {
  final List<NoteCard> notes;
  final IconData emptyIconData;
  final String emptyMsg;
  final void Function(NoteCard) onOpen;
  final void Function(String) onDelete;
  final void Function(String) onToggleCollapse;
  final void Function(String) onTogglePublic;

  const _NotesList({
    required this.notes,
    IconData emptyIcon = Icons.edit_note_outlined,
    required this.emptyMsg,
    required this.onOpen,
    required this.onDelete,
    required this.onToggleCollapse,
    required this.onTogglePublic,
  }) : emptyIconData = emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return _Empty(icon: emptyIconData, message: emptyMsg);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: notes.length,
      itemBuilder: (ctx, i) => _NoteBlock(
        note: notes[i],
        onOpen: () => onOpen(notes[i]),
        onDelete: () => onDelete(notes[i].id),
        onToggleCollapse: () => onToggleCollapse(notes[i].id),
        onTogglePublic: () => onTogglePublic(notes[i].id),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// WIDGET: Bloco individual de nota com collapse
// ──────────────────────────────────────────────────────────────────────────────
class _NoteBlock extends StatelessWidget {
  final NoteCard note;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onToggleCollapse;
  final VoidCallback onTogglePublic;

  const _NoteBlock({
    required this.note,
    required this.onOpen,
    required this.onDelete,
    required this.onToggleCollapse,
    required this.onTogglePublic,
  });

  static const _gold = AppTheme.kPrimaryGold;
  

  Color get _accentColor =>
      note.isAiGenerated ? _gold : Colors.blueAccent.shade100;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: note.isAiGenerated
                ? _gold.withValues(alpha: 0.2)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: note.isAiGenerated
                  ? _gold.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER do bloco ──────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // ícone tipo
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      note.isAiGenerated
                          ? Icons.auto_awesome
                          : Icons.menu_book_rounded,
                      size: 16,
                      color: _accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // título
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: note.isAiGenerated ? _gold : Theme.of(context).colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (note.isPublic) ...[
                              Icon(Icons.public_rounded,
                                  size: 11, color: Colors.greenAccent.shade400),
                              const SizedBox(width: 4),
                              Text('Público',
                                  style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: Colors.greenAccent.shade400)),
                              const SizedBox(width: 8),
                            ],
                            if (note.verses.isNotEmpty) ...[
                              Icon(Icons.bookmark_rounded,
                                  size: 11, color: _gold.withValues(alpha: 0.8)),
                              const SizedBox(width: 3),
                              Text('${note.verses.length} versículo${note.verses.length > 1 ? 's' : ''}',
                                  style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _fmtDate(note.updatedAt),
                              style: GoogleFonts.outfit(
                                  fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      note.isPublic ? Icons.public : Icons.lock_outline,
                      size: 20,
                    ),
                    color: note.isPublic ? Colors.greenAccent.shade400 : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                    tooltip: note.isPublic ? 'Tornar Privado' : 'Tornar Público',
                    onPressed: onTogglePublic,
                  ),
                  // botão colapsar / expandir
                  IconButton(
                    icon: AnimatedRotation(
                      turns: note.isCollapsed ? 0 : 0.5,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                    onPressed: onToggleCollapse,
                  ),
                ],
              ),
            ),

            // ── CONTEÚDO colapsável ──────────────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: note.isCollapsed
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06), height: 1),
                  // Preview do texto
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text(
                      note.plainTextBody.isEmpty ? '(sem conteúdo)' : note.plainTextBody,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lora(
                        fontSize: 14.5,
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  // Versículos vinculados
                  if (note.verses.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: note.verses
                            .take(3)
                            .map(
                              (v) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _gold.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: _gold.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  v.reference,
                                  style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: _gold,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  // Termos léxicos
                  if (note.lexicalTerms.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: Wrap(
                        spacing: 6,
                        children: note.lexicalTerms
                            .take(4)
                            .map(
                              (t) => Chip(
                                avatar: const Icon(Icons.translate_rounded,
                                    size: 12, color: Colors.cyanAccent),
                                label: Text(t,
                                    style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: Colors.cyanAccent)),
                                backgroundColor:
                                    Colors.cyanAccent.withValues(alpha: 0.07),
                                side: BorderSide(
                                    color:
                                        Colors.cyanAccent.withValues(alpha: 0.25)),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  // Ações
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: Text('Abrir',
                              style: GoogleFonts.outfit(fontSize: 13)),
                          style: TextButton.styleFrom(foregroundColor: _gold),
                          onPressed: onOpen,
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: Text('Copiar',
                              style: GoogleFonts.outfit(fontSize: 13)),
                          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: note.plainTextBody));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Nota copiada para a área de transferência!'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 20),
                          color: Colors.redAccent.withValues(alpha: 0.7),
                          onPressed: onDelete,
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

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'hoje';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return 'há ${diff.inDays} dias';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// WIDGET: Estado vazio
// ──────────────────────────────────────────────────────────────────────────────
class _Empty extends StatelessWidget {
  final IconData icon;
  final String message;
  const _Empty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
