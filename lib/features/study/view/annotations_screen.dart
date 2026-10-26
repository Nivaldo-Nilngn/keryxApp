import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/features/auth/widgets/auth_guard.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/study/model/note_card.dart';
import 'package:keryx_app/features/study/view/note_detail_screen.dart';
import 'package:keryx_app/features/study/view_model/note_cards_provider.dart';
import 'package:keryx_app/features/study/widgets/word_mobile_theme.dart';

// ──────────────────────────────────────────────────────────────────────────────
// TELA DE DOCUMENTOS E ANOTAÇÕES — Estilo Microsoft Word Mobile
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
  bool _isSearching = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

    // Ordena os documentos pelo mais recente modificado
    final sorted = List<NoteCard>.from(filtered)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final personalNotes = sorted.where((n) => !n.isCommunityOnly).toList();
    final sharedNotes = sorted.where((n) => n.isPublic).toList();
    final biblicalStudies = sorted.where((n) => n.verses.isNotEmpty || n.title.toLowerCase().contains('estudo') || n.title.toLowerCase().contains('sermão')).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AuthGuard(
      featureName: 'Documentos e Anotações',
      featureIcon: Icons.edit_document,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF141417) : const Color(0xFFF9FAFB),
        appBar: _buildWordAppBar(allNotes.length),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra de busca expansível
            if (_isSearching) _buildSearchBar(),

            // Carrossel de Modelos do Word Mobile (em branco, sermão, estudo, devocional)
            _buildTemplatesSection(),

            // Abas de Categoria (Recentes, Compartilhados, Bíblicos)
            _buildTabBar(personalNotes.length, sharedNotes.length, biblicalStudies.length),

            // Lista de Documentos estilo Word Mobile
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _WordDocumentListView(
                    notes: personalNotes,
                    emptyIcon: Icons.edit_note_outlined,
                    emptyMsg: 'Nenhum documento salvo ainda.\nToque em "+" ou em um dos modelos acima para começar.',
                    onOpen: _openNote,
                    onDelete: _delete,
                    onDuplicate: _duplicate,
                    onRename: _rename,
                    onTogglePublic: _togglePublic,
                  ),
                  _WordDocumentListView(
                    notes: sharedNotes,
                    emptyIcon: Icons.share_outlined,
                    emptyMsg: 'Nenhum documento compartilhado com a comunidade.',
                    onOpen: _openNote,
                    onDelete: _delete,
                    onDuplicate: _duplicate,
                    onRename: _rename,
                    onTogglePublic: _togglePublic,
                  ),
                  _WordDocumentListView(
                    notes: biblicalStudies,
                    emptyIcon: Icons.auto_stories_outlined,
                    emptyMsg: 'Nenhum estudo bíblico ou sermão identificado ainda.',
                    onOpen: _openNote,
                    onDelete: _delete,
                    onDuplicate: _duplicate,
                    onRename: _rename,
                    onTogglePublic: _togglePublic,
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 90),
          child: FloatingActionButton.extended(
            heroTag: 'fab_word_new',
            backgroundColor: WordMobileTheme.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 4,
            onPressed: () => _createNewWithTemplate(WordDocumentTemplate.defaultTemplates.first),
            icon: const Icon(Icons.add_rounded, size: 24),
            label: Text(
              'Novo Documento',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }

  /// AppBar oficial do Microsoft Word Mobile (Azul #185ABD)
  PreferredSizeWidget _buildWordAppBar(int totalDocs) {
    return AppBar(
      backgroundColor: WordMobileTheme.primaryBlue,
      elevation: 1,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: CircleAvatar(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documentos',
            style: GoogleFonts.outfit(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'Documentos e Estudos · $totalDocs ${totalDocs == 1 ? 'arquivo' : 'arquivos'}',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: Colors.white),
          tooltip: 'Buscar documentos',
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchCtrl.clear();
                _search = '';
              }
            });
          },
        ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            tooltip: 'Novo documento',
            onPressed: _showTemplatePickerBottomSheet,
          ),
        ],
      );
  }

  /// Seção com os modelos rápidos do Word Mobile
  Widget _buildTemplatesSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Criar a partir de modelo',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    letterSpacing: 0.3,
                  ),
                ),
                InkWell(
                  onTap: _showTemplatePickerBottomSheet,
                  child: Text(
                    'Ver todos',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: WordMobileTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 98,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: WordDocumentTemplate.defaultTemplates.length,
              itemBuilder: (ctx, i) {
                final template = WordDocumentTemplate.defaultTemplates[i];
                return _TemplateCard(
                  template: template,
                  onTap: () => _createNewWithTemplate(template),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de Busca rápida
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        style: GoogleFonts.outfit(fontSize: 14),
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Pesquisar pelo título, texto ou tags...',
          hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
          prefixIcon: const Icon(Icons.search_rounded, color: WordMobileTheme.primaryBlue, size: 20),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).cardColor,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: WordMobileTheme.primaryBlue, width: 1.5),
          ),
        ),
      ),
    );
  }

  /// Abas de Categoria
  Widget _buildTabBar(int recCount, int sharedCount, int bibleCount) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: WordMobileTheme.primaryBlue,
        unselectedLabelColor: Colors.grey,
        indicatorColor: WordMobileTheme.primaryBlue,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: [
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Recentes ($recCount)'),
                ],
              ),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Compartilhados ($sharedCount)'),
                ],
              ),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Estudos ($bibleCount)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTemplatePickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Material(
          color: isDark ? WordMobileTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Criar Novo Documento',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Escolha um modelo homilético ou comece do zero',
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ...WordDocumentTemplate.defaultTemplates.map((template) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: template.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(template.icon, color: template.color),
                      ),
                      title: Text(
                        template.title,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Text(
                        template.subtitle,
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                      onTap: () {
                        Navigator.pop(ctx);
                        _createNewWithTemplate(template);
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openNote(NoteCard note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)),
    );
  }

  void _delete(String id) {
    ref.read(noteCardsProvider.notifier).delete(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Documento excluído com sucesso.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _duplicate(NoteCard note) async {
    final now = DateTime.now();
    final dup = NoteCard(
      id: 'doc_${now.millisecondsSinceEpoch}',
      title: '${note.title} (Cópia)',
      body: note.body,
      isAiGenerated: note.isAiGenerated,
      isPublic: note.isPublic,
      isCommunityOnly: note.isCommunityOnly,
      isLocked: note.isLocked,
      isCollapsed: note.isCollapsed,
      verses: note.verses,
      commentaryKeys: note.commentaryKeys,
      lexicalTerms: note.lexicalTerms,
      tags: note.tags,
      blocks: note.blocks,
      pageColor: note.pageColor,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(noteCardsProvider.notifier).save(dup);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Documento duplicado: "${dup.title}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _rename(NoteCard note) async {
    final tc = TextEditingController(text: note.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Renomear Documento', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: tc,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Digite o novo nome...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: WordMobileTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, tc.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && mounted) {
      ref.read(noteCardsProvider.notifier).save(note.copyWith(
        title: newTitle,
        updatedAt: DateTime.now(),
      ));
    }
  }

  void _togglePublic(String id) {
    final list = ref.read(noteCardsProvider);
    final note = list.firstWhere((n) => n.id == id);
    ref.read(noteCardsProvider.notifier).save(note.copyWith(
      isPublic: !note.isPublic,
      updatedAt: DateTime.now(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(note.isPublic ? 'Documento agora é privado.' : 'Documento compartilhado publicamente!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _createNewWithTemplate(WordDocumentTemplate template) async {
    final now = DateTime.now();
    final card = NoteCard(
      id: 'doc_${now.millisecondsSinceEpoch}',
      title: template.id == 'blank' ? 'Novo Documento' : template.title,
      body: template.initialContentJson,
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
// CARD DE MODELO DO WORD MOBILE
// ──────────────────────────────────────────────────────────────────────────────
class _TemplateCard extends StatelessWidget {
  final WordDocumentTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? WordMobileTheme.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: template.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(template.icon, color: template.color, size: 18),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    template.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// LISTA DE DOCUMENTOS ESTILO MICROSOFT WORD MOBILE
// ──────────────────────────────────────────────────────────────────────────────
class _WordDocumentListView extends StatelessWidget {
  final List<NoteCard> notes;
  final IconData emptyIcon;
  final String emptyMsg;
  final Function(NoteCard) onOpen;
  final Function(String) onDelete;
  final Function(NoteCard) onDuplicate;
  final Function(NoteCard) onRename;
  final Function(String) onTogglePublic;

  const _WordDocumentListView({
    required this.notes,
    required this.emptyIcon,
    required this.emptyMsg,
    required this.onOpen,
    required this.onDelete,
    required this.onDuplicate,
    required this.onRename,
    required this.onTogglePublic,
  });

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, size: 56, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                emptyMsg,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
      itemBuilder: (ctx, i) {
        final note = notes[i];
        return _WordDocumentTile(
          note: note,
          onOpen: () => onOpen(note),
          onDelete: () => onDelete(note.id),
          onDuplicate: () => onDuplicate(note),
          onRename: () => onRename(note),
          onTogglePublic: () => onTogglePublic(note.id),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// ITEM INDIVIDUAL DE DOCUMENTO (Microsoft Word Mobile Tile)
// ──────────────────────────────────────────────────────────────────────────────
class _WordDocumentTile extends StatelessWidget {
  final NoteCard note;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onRename;
  final VoidCallback onTogglePublic;

  const _WordDocumentTile({
    required this.note,
    required this.onOpen,
    required this.onDelete,
    required this.onDuplicate,
    required this.onRename,
    required this.onTogglePublic,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return 'Há ${diff.inMinutes == 0 ? 1 : diff.inMinutes} min';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      return 'Hoje às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return 'Há ${diff.inDays} dias';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
  }

  String _getSnippet(String body) {
    if (body.isEmpty) return 'Documento em branco';
    try {
      if (body.startsWith('[') || body.startsWith('{')) {
        final list = jsonDecode(body);
        if (list is List) {
          final buffer = StringBuffer();
          for (final item in list) {
            if (item is Map && item.containsKey('insert') && item['insert'] is String) {
              buffer.write(item['insert']);
            }
          }
          final clean = buffer.toString().replaceAll('\n', ' ').trim();
          return clean.isEmpty ? 'Sem conteúdo adicional' : clean;
        }
      }
    } catch (_) {}
    final clean = body.replaceAll('\n', ' ').trim();
    return clean.isEmpty ? 'Sem conteúdo adicional' : clean;
  }

  @override
  Widget build(BuildContext context) {
    final snippet = _getSnippet(note.body);
    final dateStr = _formatDate(note.updatedAt);

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            // Ícone do Word Oficial (Badge azul com W branco)
            Container(
              width: 44,
              height: 48,
              decoration: BoxDecoration(
                color: WordMobileTheme.primaryBlue,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: WordMobileTheme.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(3)),
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.description_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // Informações do Documento
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title.isEmpty ? 'Sem título' : note.title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (note.isPublic)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Público',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    snippet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      if (note.verses.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.auto_stories_rounded, size: 12, color: WordMobileTheme.primaryBlue),
                        const SizedBox(width: 4),
                        Text(
                          '${note.verses.length} ${note.verses.length == 1 ? 'versículo' : 'versículos'}',
                          style: GoogleFonts.outfit(fontSize: 11, color: WordMobileTheme.primaryBlue),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Menu de Ações (três pontinhos do Word Mobile)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
              onSelected: (action) {
                switch (action) {
                  case 'open':
                    onOpen();
                    break;
                  case 'rename':
                    onRename();
                    break;
                  case 'duplicate':
                    onDuplicate();
                    break;
                  case 'public':
                    onTogglePublic();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'open',
                  child: Row(
                    children: [
                      const Icon(Icons.open_in_new_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Abrir', style: GoogleFonts.outfit()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text('Renomear', style: GoogleFonts.outfit()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      const Icon(Icons.copy_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Duplicar', style: GoogleFonts.outfit()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'public',
                  child: Row(
                    children: [
                      Icon(note.isPublic ? Icons.lock_outline_rounded : Icons.public_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(note.isPublic ? 'Tornar Privado' : 'Compartilhar', style: GoogleFonts.outfit()),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text('Excluir', style: GoogleFonts.outfit(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
