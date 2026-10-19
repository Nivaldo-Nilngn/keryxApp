import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/services/pdf_service.dart';
// import 'package:keryx_app/core/services/graph_service.dart';
import 'package:keryx_app/core/utils/search_helper.dart';
import 'package:keryx_app/features/pdf/view/pdf_details_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/services/telegram/telegram_download_service.dart';
import 'package:keryx_app/core/services/telegram/telegram_bootstrap.dart';
import 'package:keryx_app/core/services/telegram/cloudflare_pdf_service.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/services/book_cover_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/store/view/book_reader_screen.dart';
import 'package:keryx_app/features/store/view/html_book_reader_screen.dart';
import 'package:keryx_app/features/pdf/view/pdf_viewer_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ─────────────────────────────────────────────────────────────────────────────
// Modelo
// ─────────────────────────────────────────────────────────────────────────────
class OneDriveBook {
  final String id;
  final String name;
  final String? downloadUrl;
  final int size;

  OneDriveBook({
    required this.id,
    required this.name,
    this.downloadUrl,
    required this.size,
  });
}

String cleanPdfName(String raw) {
  String n = raw;
  n = n.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  n = n.replaceAll(RegExp(r'@\w+\s*-\s*'), '');
  n = n.replaceAll(RegExp(r'@\w+\s*'), '');
  n = n.replaceAll(RegExp(r'#\s*-\s*'), '');
  n = n.replaceAll('#', '');
  n = n.replaceAll(RegExp(r'^\s*\(\d*\)\s*'), '');
  n = n.replaceAll(RegExp(r'^\s*-\s*'), '');
  return n.trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// Tela Principal
// ─────────────────────────────────────────────────────────────────────────────
class PdfBooksScreen extends ConsumerStatefulWidget {
  const PdfBooksScreen({super.key});

  @override
  ConsumerState<PdfBooksScreen> createState() => _PdfBooksScreenState();
}

class _PdfBooksScreenState extends ConsumerState<PdfBooksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // final _graphService = GraphService(); // 👈
  final _pdfService = PdfService();
  List<OneDriveBook> _allDriveBooks = [];
  List<OneDriveBook> _driveBooks = [];
  List<Map<String, String>> _localBooks = [];
  bool _isLoadingDrive = false;
  bool _isFetchingAll = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scroll = ScrollController();
  Timer? _debounce;
  String? _driveError;

  List<Map<String, dynamic>> _telegramBooks = [];
  bool _isLoadingTelegram = false;
  String? _telegramError;

  String _selectedCategory = 'Para Você';

  static const List<({String name, IconData icon})> _categoryItemList = [
    (name: 'Para Você', icon: Icons.stars_rounded),
    (name: 'Bíblias', icon: Icons.auto_stories_rounded),
    (name: 'Livros', icon: Icons.menu_book_rounded),
    (name: 'Comentários', icon: Icons.mode_comment_outlined),
    (name: 'Dicionários', icon: Icons.spellcheck_rounded),
    (name: 'Teologia', icon: Icons.school_rounded),
    (name: 'Outros', icon: Icons.folder_open_rounded),
  ];

  static const List<({IconData icon, String title})> _readerFeatures = [
    (
      icon: Icons.wifi_off_rounded,
      title: '100% Offline após baixar',
    ),
    (
      icon: Icons.splitscreen_rounded,
      title: 'Modo 2 Colunas em Tablets',
    ),
    (
      icon: Icons.translate_rounded,
      title: 'Dicionário Strong Integrado',
    ),
    (
      icon: Icons.dark_mode_rounded,
      title: 'Temas Escuro, Claro e Sépia',
    ),
    (
      icon: Icons.format_size_rounded,
      title: 'Ajuste de Tipografia & Zoom',
    ),
  ];

  int get _totalDownloadedEbooks {
    final storeState = ref.watch(storeProvider);
    return storeState.availablePackages
        .where((p) => p.category == StoreCategory.books && storeState.isDownloaded(p.filename))
        .where((p) => !p.filename.contains('Harpa.bok.mybible'))
        .length;
  }

  int get _totalDownloadedPdfs {
    return _localBooks.where((b) {
      final isAsset = b['path']?.startsWith('assets/') == true;
      return !isAsset && !(b['path']?.startsWith('store_book:') ?? false);
    }).length;
  }

  // Fila de Downloads (apenas em memória para este exemplo)
  final List<_QueueEntry> _downloadQueue = [];

  int _libraryAreaIndex = 0; // 0 = E-books, 1 = PDFs

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // if (_tabController.index == 1 && !_tabController.indexIsChanging) _loadDrive();
      if (_tabController.index == 1 && !_tabController.indexIsChanging) _loadTelegram();
    });
    _scroll.addListener(_onScroll);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 450), () {
        if (_tabController.index == 1) _applyFilters();
      });
    });
    // _graphService.clearLegacyCache();
    _loadLocalBooks();
    // _loadDrive();
    _loadTelegram();
  }

  bool get _isAdmin {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim();
    return email == 'nivaldo.nilngn@gmail.com';
  }

  Future<void> _deleteReadingProgress(String bookName) async {
    try {
      final docId = bookName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final uid = FirebaseAuth.instance.currentUser?.uid;
      
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('highlights')
            .doc(docId)
            .delete();
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pdf_progress_${docId}_page');
      await prefs.remove('pdf_progress_${docId}_bookmarks');
    } catch (e) {
      debugPrint('Erro ao apagar progresso: $e');
    }
  }

  Future<void> _confirmDeleteFromOneDrive(OneDriveBook book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text(
              'Excluir do OneDrive?',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Atenção, Administrador:\n\nTem certeza de que deseja apagar permanentemente o arquivo:\n\n"${cleanPdfName(book.name)}"\n\ndo seu OneDrive na nuvem? Ele será removido do catálogo de todos os usuários.',
          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Excluir da Nuvem', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      );

      // await _graphService.deleteDriveItem(book.id);
      await _pdfService.deleteBook(book.name);

      if (mounted) {
        Navigator.pop(context); // Fecha loading
        setState(() {
          _allDriveBooks.removeWhere((b) => b.id == book.id);
          _driveBooks.removeWhere((b) => b.id == book.id);
        });
        _loadLocalBooks();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Livro excluído com sucesso do OneDrive!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fecha loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir do OneDrive: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadLocalBooks() async {
    final downloaded = await _pdfService.listDownloadedBooks();
    if (mounted) {
      setState(() => _localBooks = downloaded);
    }
  }


  List<OneDriveBook> _toBooks(List items) => items
      .map((i) => OneDriveBook(
            id: i['id'] ?? '',
            name: i['name'] ?? '',
            size: i['size'] ?? 0,
          ))
      .toList();

  Future<void> _loadTelegram() async {
    if (_telegramBooks.isNotEmpty) return;
    if (mounted) setState(() { _isLoadingTelegram = true; _telegramError = null; });

    try {

      // 2. Busca a lista RÁPIDA no Cloudflare KV (sem sobrecarregar o TDLib)
      final results = await CloudflarePdfService.instance.fetchPdfs();
      
      if (mounted) {
        setState(() {
          _telegramBooks = results;
          _isLoadingTelegram = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _telegramError = '$e'; _isLoadingTelegram = false; });
    }
  }

  Future<void> _loadDrive({bool force = false}) async {
    if (_isFetchingAll) return;
    if (!force && _allDriveBooks.isNotEmpty) {
      _applyFilters();
      return;
    }

    setState(() {
      _isLoadingDrive = true;
      _driveError = null;
      _allDriveBooks = [];
    });

    _isFetchingAll = true;
    try {
      /*
      String? next;
      do {
        final r = await _graphService.getPdfPage(nextLink: next, pageSize: 100);
        if (!mounted) return;
        _allDriveBooks.addAll(_toBooks(r['items'] as List));
        next = r['nextLink'] as String?;
        _applyFilters();
      } while (next != null);
      */
    } catch (e) {
      if (mounted) setState(() => _driveError = e.toString());
    } finally {
      _isFetchingAll = false;
      if (mounted) {
        setState(() => _isLoadingDrive = false);
        _applyFilters();
      }
    }
  }

  void _applyFilters() {
    final normQuery = SearchHelper.normalize(_searchQuery);
    
    // Filter Acervo
    _driveBooks = _allDriveBooks.where((b) {
      final normName = SearchHelper.normalize(b.name);
      if (_searchQuery.isNotEmpty && !normName.contains(normQuery)) return false;
      return _matchCategory(normName);
    }).toList();

    setState(() {});
  }
  
  bool _matchCategory(String normName) {
    if (_selectedCategory == 'Para Você' || _selectedCategory == 'Todos') return true;
    if (_selectedCategory == 'Bíblias' && normName.contains('biblia')) return true;
    if (_selectedCategory == 'Comentários' && (normName.contains('comentario') || normName.contains('expositivo'))) return true;
    if (_selectedCategory == 'Dicionários' && (normName.contains('dicionario') || normName.contains('enciclopedia') || normName.contains('lexico'))) return true;
    if (_selectedCategory == 'Teologia' && normName.contains('teologia')) return true;
    
    if (_selectedCategory == 'Livros') {
      if (normName.contains('biblia') || normName.contains('comentario') || normName.contains('expositivo') || normName.contains('dicionario') || normName.contains('enciclopedia') || normName.contains('lexico')) return false;
      return true;
    }

    if (_selectedCategory == 'Outros') {
      if (!normName.contains('biblia') && !normName.contains('comentario') && 
          !normName.contains('expositivo') && !normName.contains('dicionario') && 
          !normName.contains('enciclopedia') && !normName.contains('lexico') && 
          !normName.contains('teologia')) {
        return true;
      }
    }
    return false;
  }

  void _onScroll() {
    // Pagination removed, loading all in background
  }

  void _startDownload(OneDriveBook book) async {
    if (PdfDownloadManager().isDownloading(book.name)) return;
    
    try {
      /*
      final freshData = await _graphService.getDirectAccessData(book.id);
      final url = freshData['url'];
      final auth = freshData['Authorization'];
      if (url == null) return;

      PdfDownloadManager().startDownload(
        url: url,
        fileName: book.name,
        headers: auth != null ? {'Authorization': auth} : null,
        expectedSize: book.size,
        refreshAccess: () => _graphService.getDirectAccessData(book.id),
        onCompleted: () {
          if (mounted) {
            _loadLocalBooks();
          }
        },
        onError: (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Falha ao baixar ${book.name}: $e')),
            );
          }
        },
      );
      */
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao obter link de ${book.name}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: MBibliaTopBar(
        title: 'KeryxApp',
        showLogo: true,
        isScrolled: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Biblioteca', icon: Icon(Icons.folder_shared_rounded)),
            Tab(text: 'Acervo Online', icon: Icon(Icons.cloud_download_rounded)),
          ],
        ),
      ),
        body: Stack(
          children: [
            Column(
              children: [
                // Header Banner
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    final isLibrary = _tabController.index == 0;
                    if (!isLibrary) {
                      return const SizedBox.shrink();
                    } else {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildSegmentOption(
                                      title: 'E-books',
                                      icon: Icons.auto_stories_rounded,
                                      count: _totalDownloadedEbooks,
                                      isSelected: _libraryAreaIndex == 0,
                                      onTap: () => setState(() => _libraryAreaIndex = 0),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _buildSegmentOption(
                                      title: 'PDFs & Docs',
                                      icon: Icons.picture_as_pdf_rounded,
                                      count: _totalDownloadedPdfs,
                                      isSelected: _libraryAreaIndex == 1,
                                      onTap: () => setState(() => _libraryAreaIndex = 1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Pesquisar por título, autor ou palavra-chave...',
                            hintStyle: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                              size: 22,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.cancel_rounded,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : null,
                            filled: false,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // CATEGORY CHIPS
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categoryItemList.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final item = _categoryItemList[index];
                          final isSelected = _selectedCategory == item.name;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = item.name;
                                  _applyFilters();
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          colors: [
                                            Theme.of(context).colorScheme.primary,
                                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                                          ],
                                        )
                                      : null,
                                  color: isSelected
                                      ? null
                                      : Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                                    width: isSelected ? 1.2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 15,
                                      color: isSelected
                                          ? Colors.white
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      item.name,
                                      style: GoogleFonts.outfit(
                                        color: isSelected
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBibliotecaTab(), 
                      _buildTelegramTab(),
                    ],
                  ),
                ),
              ],
            ),
            
            // Floating Navbar
            Align(
              alignment: Alignment.bottomCenter,
              child: CustomBottomNav(
                currentIndex: 2,
                onBack: () => Navigator.pop(context),
                onTap: (index) {
                  ref.read(navigationProvider.notifier).setIndex(index);
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildTelegramTab() {
    if (_isLoadingTelegram) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }
    if (_telegramError != null) {
      return _buildEmptyState('Erro', _telegramError!, Icons.error_outline);
    }
    
    final normQuery = SearchHelper.normalize(_searchQuery);
    final filtered = _telegramBooks.where((b) {
      final normName = SearchHelper.normalize(b['name']);
      if (_searchQuery.isNotEmpty && !normName.contains(normQuery)) return false;
      return _matchCategory(normName);
    }).toList();

    if (filtered.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _buildEmptyState('Sem resultados', 'Nenhum arquivo encontrado nas novidades.', Icons.search_off);
      }
      return _buildEmptyState('Sem novidades', 'Nenhum arquivo adicionado recentemente.', Icons.new_releases_outlined);
    }

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      onRefresh: () async {
        setState(() {
          _telegramBooks.clear();
        });
        await _loadTelegram();
      },
      child: CustomScrollView(
      slivers: [
        
        if (_selectedCategory == 'Para Você' && _searchQuery.isEmpty)
          SliverToBoxAdapter(
            child: _buildDestaquesPDF(),
          )
        else
          SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              childAspectRatio: 0.65,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final b = filtered[index];
                final alreadyDownloaded = _localBooks.any((l) => l['name'] == b['name']);
                final localBook = alreadyDownloaded 
                    ? _localBooks.firstWhere((l) => l['name'] == b['name']) 
                    : null;

                return _BookCard(
                  key: ValueKey(b['id']),
                  name: b['name'],
                  isLocal: false,
                  alreadyDownloaded: alreadyDownloaded,
                  path: localBook?['path'],
                  bookSize: b['size'],
                  onTap: (metadata) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PdfDetailsScreen(
                          name: b['name'],
                          cleanName: cleanPdfName(b['name']),
                          isLocal: false,
                          alreadyDownloaded: alreadyDownloaded,
                          localPath: localBook?['path'],
                          metadata: metadata,
                          bookId: 'tg:${b['id']}', // Passa o file_id do Telegram
                          bookSize: b['size'],
                          onDownloadCompleted: () => _loadLocalBooks(),
                          onDeletedFromDrive: () {
                            setState(() {
                              _telegramBooks.removeWhere((item) => item['id'] == b['id']);
                            });
                            _loadLocalBooks();
                          },
                        ),
                      ),
                    ).then((_) {
                      _loadLocalBooks();
                    });
                  },
                );
              },
              childCount: filtered.length,
            ),
          ),
        ),
      ],
    ));
  }

  Widget _buildDestaquesPDF() {
    final lancamentos = _telegramBooks.take(10).toList();
    final biblias = _telegramBooks.where((b) => _matchCategorySpecific(b['name'], 'Bíblias')).take(10).toList();
    final dicionarios = _telegramBooks.where((b) => _matchCategorySpecific(b['name'], 'Dicionários')).take(10).toList();
    final comentarios = _telegramBooks.where((b) => _matchCategorySpecific(b['name'], 'Comentários')).take(10).toList();
    final livros = _telegramBooks.where((b) => _matchCategorySpecific(b['name'], 'Livros')).take(10).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(Icons.category_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Categorias',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        _buildCategoryGridPDF(),
        _buildHorizontalCollectionPDF('Lançamentos', lancamentos, onTap: null),
        _buildHorizontalCollectionPDF('Bíblias Premium', biblias, onTap: () => setState(() => _selectedCategory = 'Bíblias')),
        _buildHorizontalCollectionPDF('Livros e Autores', livros, onTap: () => setState(() => _selectedCategory = 'Livros')),
        _buildHorizontalCollectionPDF('Dicionários', dicionarios, onTap: () => setState(() => _selectedCategory = 'Dicionários')),
        _buildHorizontalCollectionPDF('Comentários de Peso', comentarios, onTap: () => setState(() => _selectedCategory = 'Comentários')),
        SizedBox(height: 120),
      ],
    );
  }

  Widget _buildCategoryGridPDF() {
    final categoriesList = [
      {'label': 'Bíblias', 'icon': Icons.menu_book_rounded, 'color': const Color(0xFFE2B93B)},
      {'label': 'Livros', 'icon': Icons.collections_bookmark_rounded, 'color': const Color(0xFFF39C12)},
      {'label': 'Comentários', 'icon': Icons.auto_stories_rounded, 'color': const Color(0xFF9B59B6)},
      {'label': 'Dicionários', 'icon': Icons.translate_rounded, 'color': const Color(0xFF3498DB)},
      {'label': 'Teologia', 'icon': Icons.account_balance_rounded, 'color': const Color(0xFFE74C3C)},
      {'label': 'Outros', 'icon': Icons.extension_rounded, 'color': const Color(0xFF95A5A6)},
    ];

    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categoriesList.length,
        itemBuilder: (context, index) {
          final cat = categoriesList[index];
          final label = cat['label'] as String;
          final icon = cat['icon'] as IconData;
          final color = cat['color'] as Color;

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = label),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _matchCategorySpecific(String name, String cat) {
    final normName = SearchHelper.normalize(name);
    if (cat == 'Bíblias' && normName.contains('biblia')) return true;
    if (cat == 'Comentários' && (normName.contains('comentario') || normName.contains('expositivo'))) return true;
    if (cat == 'Dicionários' && (normName.contains('dicionario') || normName.contains('enciclopedia') || normName.contains('lexico'))) return true;
    if (cat == 'Teologia' && normName.contains('teologia')) return true;
    if (cat == 'Livros') {
      if (normName.contains('biblia') || normName.contains('comentario') || normName.contains('expositivo') || normName.contains('dicionario') || normName.contains('enciclopedia') || normName.contains('lexico')) return false;
      return true; // Se não é os outros, é livro.
    }
    return false;
  }

  Widget _buildHorizontalCollectionPDF(String title, List<Map<String, dynamic>> items, {VoidCallback? onTap}) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.arrow_forward_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final b = items[index];
              final alreadyDownloaded = _localBooks.any((l) => l['name'] == b['name']);
              final localBook = alreadyDownloaded 
                  ? _localBooks.firstWhere((l) => l['name'] == b['name']) 
                  : null;

              return Container(
                width: 170,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: _BookCard(
                  key: ValueKey(b['id']),
                  name: b['name'],
                  isLocal: false,
                  alreadyDownloaded: alreadyDownloaded,
                  path: localBook?['path'],
                  bookSize: b['size'],
                  onTap: (metadata) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PdfDetailsScreen(
                          name: b['name'],
                          cleanName: cleanPdfName(b['name']),
                          isLocal: false,
                          alreadyDownloaded: alreadyDownloaded,
                          localPath: localBook?['path'],
                          metadata: metadata,
                          bookId: 'tg:${b['id']}',
                          bookSize: b['size'],
                          onDownloadCompleted: () => _loadLocalBooks(),
                          onDeletedFromDrive: () {
                            setState(() {
                              _telegramBooks.removeWhere((item) => item['id'] == b['id']);
                            });
                            _loadLocalBooks();
                          },
                        ),
                      ),
                    ).then((_) => _loadLocalBooks());
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildBibliotecaTab() {
    final normQuery = SearchHelper.normalize(_searchQuery);

    // Watch Store state
    final storeState = ref.watch(storeProvider);
    final storeBooks = storeState.availablePackages
        .where((p) => p.category == StoreCategory.books && storeState.isDownloaded(p.filename))
        .where((p) => !p.filename.contains('Harpa.bok.mybible'))
        .toList();

    final downloadedBooks = <Map<String, String>>[..._localBooks];

    // Adiciona os livros da Store (fake path to identify them)
    for (final sb in storeBooks) {
      downloadedBooks.add({
        'name': sb.name,
        'path': 'store_book:${sb.filename}',
        'store_id': sb.id,
      });
    }

    // Filtrar livros baixados pela busca e categoria selecionada
    final filteredDownloaded = downloadedBooks.where((b) {
      final isEbook = b['path']?.startsWith('store_book:') ?? false;
      
      // Filtra pela aba selecionada (0 = E-books, 1 = PDFs)
      if (_libraryAreaIndex == 0 && !isEbook) return false;
      if (_libraryAreaIndex == 1 && isEbook) return false;
      
      final normName = SearchHelper.normalize(b['name']!);
      if (_searchQuery.isNotEmpty && !normName.contains(normQuery)) return false;
      return _matchCategory(normName);
    }).toList();

    // Se a busca estiver ativa e nada for encontrado
    if (_searchQuery.isNotEmpty && filteredDownloaded.isEmpty) {
      return _buildEmptySearchResults();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPad = screenWidth > 960
        ? (screenWidth - 960) / 2 + 20
        : 20.0;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(left: horizontalPad, right: horizontalPad, top: 16, bottom: 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (filteredDownloaded.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _libraryAreaIndex == 0 ? Icons.auto_stories_rounded : Icons.picture_as_pdf_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _libraryAreaIndex == 0 ? 'Seus E-books Baixados' : 'Seus Documentos PDF',
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${filteredDownloaded.length} ${filteredDownloaded.length == 1 ? 'livro' : 'livros'}',
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  _buildEmptyLibraryHub(isEbooks: _libraryAreaIndex == 0),
                ],
              ],
            ),
          ),
        ),
        if (filteredDownloaded.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.only(left: horizontalPad, right: horizontalPad, bottom: 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 22,
                crossAxisSpacing: 18,
                childAspectRatio: 0.65,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final book = filteredDownloaded[index];
                  final bookName = book['name']!;
                  final bookPath = book['path']!;
                  return _BookCard(
                    key: ValueKey(bookName),
                    name: bookName,
                    path: bookPath,
                    isLocal: true,
                    onTap: (metadata) {
                      if (bookPath.startsWith('store_book:')) {
                        final filename = bookPath.replaceFirst('store_book:', '');
                        final storeState = ref.read(storeProvider);
                        try {
                          final storeItem = storeState.availablePackages.firstWhere((p) => p.filename == filename);
                          if (storeItem.filename.contains('Harpa')) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => BookReaderScreen(book: storeItem)));
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => HtmlBookReaderScreen(book: storeItem)));
                          }
                        } catch(e) {
                          debugPrint('StoreItem não encontrado');
                        }
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfDetailsScreen(
                              name: bookName,
                              cleanName: cleanPdfName(bookName),
                              isLocal: true,
                              alreadyDownloaded: true,
                              localPath: bookPath,
                              metadata: metadata,
                            ),
                          ),
                        );
                      }
                    },
                    onDelete: () async {
                      if (bookPath.startsWith('store_book:')) {
                        final filename = bookPath.replaceFirst('store_book:', '');
                        final storeState = ref.read(storeProvider);
                        try {
                          final storeItem = storeState.availablePackages.firstWhere((p) => p.filename == filename);
                          await ref.read(storeProvider.notifier).deletePackage(storeItem);
                        } catch(e) {}
                      } else {
                        await _pdfService.deleteBook(bookName);
                        await _deleteReadingProgress(bookName);
                        _loadLocalBooks();
                      }
                    },
                  );
                },
                childCount: filteredDownloaded.length,
              ),
            ),
          )
        else
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
      ],
    );
  }



  Widget _buildSegmentOption({
    required String title,
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  width: 1.2,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLibraryHub({required bool isEbooks}) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hero Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.cardColor,
                theme.colorScheme.surfaceContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative background glow
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  isEbooks ? Icons.auto_stories_rounded : Icons.picture_as_pdf_rounded,
                  size: isMobile ? 110 : 140,
                  color: primaryColor.withValues(alpha: 0.05),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars_rounded, size: 14, color: primaryColor),
                              const SizedBox(width: 5),
                              Text(
                                'BIBLIOTECA CRISTÃ KERYX',
                                style: GoogleFonts.outfit(
                                  color: primaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isEbooks
                          ? 'Sua Estante de E-books Interativos'
                          : 'Sua Coleção de Documentos & PDFs',
                      style: GoogleFonts.outfit(
                        color: theme.colorScheme.onSurface,
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEbooks
                          ? 'Baixe Bíblias de estudo, comentários versículo por versículo, teologia e dicionários bíblicos. Obras completas com numeração Strong para leitura offline.'
                          : 'Adicione documentos em PDF ou baixe materiais de estudo teológicos para leitura com marcações e anotações.',
                      style: GoogleFonts.outfit(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: isMobile ? 12 : 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _tabController.animateTo(1),
                      icon: const Icon(Icons.cloud_download_rounded, size: 18, color: Colors.white),
                      label: Text(
                        'Explorar Acervo Online',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 2. Coleções em Destaque
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.explore_rounded, size: 16, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  'COLEÇÕES DISPONÍVEIS NO ACERVO',
                  style: GoogleFonts.outfit(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _tabController.animateTo(1),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ver todas',
                      style: GoogleFonts.outfit(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 4 Discovery Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isWide ? 4 : 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: isWide ? 1.3 : 1.35,
              children: [
                _buildDiscoveryCategoryCard(
                  title: 'Bíblias & Textos',
                  subtitle: 'Almeida, NVI, King James e Strong.',
                  icon: Icons.auto_stories_rounded,
                  category: 'Bíblias',
                ),
                _buildDiscoveryCategoryCard(
                  title: 'Comentários',
                  subtitle: 'Moody, Shedd, Matthew Henry.',
                  icon: Icons.mode_comment_outlined,
                  category: 'Comentários',
                ),
                _buildDiscoveryCategoryCard(
                  title: 'Teologia',
                  subtitle: 'Sistemática, história e doutrina.',
                  icon: Icons.school_rounded,
                  category: 'Teologia',
                ),
                _buildDiscoveryCategoryCard(
                  title: 'Dicionários',
                  subtitle: 'Termos bíblicos, léxicos e mapas.',
                  icon: Icons.spellcheck_rounded,
                  category: 'Dicionários',
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 22),

        // 3. Recursos do Leitor Keryx (Card Centralizado de Canto a Canto em Formato de Lista)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.25 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_stories_rounded, size: 18, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Recursos do Leitor Keryx',
                    style: GoogleFonts.outfit(
                      color: theme.colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 650;

                  Widget buildPill(({IconData icon, String title}) item) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.surfaceContainerLow
                            : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(item.icon, size: 17, color: primaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.title,
                              style: GoogleFonts.outfit(
                                color: theme.colorScheme.onSurface,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (isWide) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 44,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _readerFeatures.length,
                      itemBuilder: (context, index) => buildPill(_readerFeatures[index]),
                    );
                  } else {
                    return Column(
                      children: _readerFeatures.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: buildPill(item),
                      )).toList(),
                    );
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDiscoveryCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String category,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = category;
            _applyFilters();
          });
          _tabController.animateTo(1);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: primaryColor),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              'Nenhum resultado encontrado',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Não encontramos nenhum livro com o termo "$_searchQuery" na sua biblioteca.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                _tabController.animateTo(1);
              },
              icon: const Icon(Icons.cloud_download_outlined, size: 18, color: Colors.white),
              label: Text(
                'Pesquisar no Acervo Online',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildAcervoTab() {

    return Column(
      children: [
        if (_downloadQueue.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: _downloadQueue.map((e) => _QueueCard(entry: e)).toList(),
            ),
          ),
        Expanded(
          child: _driveBooks.isEmpty && _isLoadingDrive
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                    SizedBox(height: 16),
                    Text('Carregando o acervo...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                  ],
                ))
              : _driveBooks.isEmpty && _driveError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi_off_rounded, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
                            SizedBox(height: 16),
                            Text('Não foi possível carregar o acervo',
                                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
                            SizedBox(height: 8),
                            Text(_driveError!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12)),
                            SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await _loadDrive(force: true);
                              },
                              icon: Icon(Icons.refresh),
                              label: Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _driveBooks.isEmpty
                      ? _buildEmptyState(
                          _searchQuery.isNotEmpty ? 'Nenhum resultado' : 'OneDrive Vazio', 
                          _searchQuery.isNotEmpty ? 'Nenhum PDF encontrado com esse nome.' : 'Não encontramos arquivos PDF no seu OneDrive.', 
                          _searchQuery.isNotEmpty ? Icons.search_off : Icons.cloud_off_rounded)
                  : RefreshIndicator(
                      onRefresh: () => _loadDrive(force: true),
                      child: GridView.builder(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          childAspectRatio: 0.65,
                        ),
                        itemCount: _driveBooks.length,
                        itemBuilder: (context, index) {
                          final book = _driveBooks[index];
                          final alreadyDownloaded = _localBooks.any((l) => l['name'] == book.name);
                          final localBook = alreadyDownloaded 
                              ? _localBooks.firstWhere((l) => l['name'] == book.name) 
                              : null;

                          return _BookCard(
                            key: ValueKey(book.id),
                            name: book.name,
                            isLocal: false,
                            alreadyDownloaded: alreadyDownloaded,
                            path: localBook?['path'],
                            bookSize: book.size,
                            onDelete: _isAdmin ? () => _confirmDeleteFromOneDrive(book) : null,
                            onTap: (metadata) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PdfDetailsScreen(
                                    name: book.name,
                                    cleanName: cleanPdfName(book.name),
                                    isLocal: false,
                                    alreadyDownloaded: alreadyDownloaded,
                                    localPath: localBook?['path'],
                                    metadata: metadata,
                                    bookId: book.id,
                                    bookSize: book.size,
                                    onDownload: () => _startDownload(book),
                                    onDownloadCompleted: () => _loadLocalBooks(),
                                    onDeletedFromDrive: () {
                                      setState(() {
                                        _allDriveBooks.removeWhere((b) => b.id == book.id);
                                        _driveBooks.removeWhere((b) => b.id == book.id);
                                      });
                                      _loadLocalBooks();
                                    },
                                  ),
                                ),
                              ).then((_) {
                                _loadLocalBooks();
                              });
                            },
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets de Suporte
// ─────────────────────────────────────────────────────────────────────────────

class _BookCard extends StatefulWidget {
  final String name;
  final bool isLocal;
  final bool alreadyDownloaded;
  final void Function(BookMetadata? metadata)? onTap;
  final VoidCallback? onDelete;
  final String? path;
  final int? bookSize;

  const _BookCard({
    super.key,
    required this.name,
    required this.isLocal,
    this.alreadyDownloaded = false,
    this.onTap,
    this.onDelete,
    this.path,
    this.bookSize,
  });

  @override
  State<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<_BookCard> {
  final BookCoverService _coverService = BookCoverService();
  BookMetadata? _metadata;

  @override
  void initState() {
    super.initState();
    _metadata = _coverService.getCachedMetadata(widget.name);
    if (_metadata == null || (widget.isLocal && !_metadata!.isRealPdfCover)) {
      _loadCover();
    }
  }

  Future<void> _loadCover() async {
    final clean = cleanPdfName(widget.name);
    final meta = await _coverService.getBookMetadata(
      clean,
      localPath: widget.isLocal ? widget.path : null,
    );
    if (mounted && meta != _metadata) {
      setState(() {
        _metadata = meta;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanName = cleanPdfName(widget.name);

    return ValueListenableBuilder<Map<String, double>>(
      valueListenable: PdfDownloadManager().activeDownloadsNotifier,
      builder: (context, activeDownloads, _) {
        final isDownloading = activeDownloads.containsKey(widget.name);
        final downloadProgress = activeDownloads[widget.name] ?? 0.0;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () {
                if (widget.onTap != null) {
                  widget.onTap!(_metadata);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Cover Area (Full bleed 70% height)
                      Expanded(
                        flex: 7,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildCoverImage(),
                              // Badges
                              if (isDownloading)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 10,
                                          height: 10,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '${(downloadProgress * 100).toInt()}%',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (widget.alreadyDownloaded || widget.isLocal)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 11),
                                        SizedBox(width: 3),
                                        Text(
                                          'Baixado',
                                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'PDF',
                                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              if (widget.onDelete != null)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: GestureDetector(
                                    onTap: widget.onDelete,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.75),
                                        shape: BoxShape.circle,
                                        border: !widget.isLocal
                                            ? Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1)
                                            : null,
                                      ),
                                      child: Icon(
                                        !widget.isLocal ? Icons.delete_forever_rounded : Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom Info Area (Centered Title + Author)
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                cleanName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _metadata?.authors.isNotEmpty == true
                                    ? _metadata!.authors.join(', ')
                                    : (widget.isLocal ? 'Offline' : 'Acervo Online'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                                  const SizedBox(width: 2),
                                  Text(
                                    '4,8',
                                    style: GoogleFonts.outfit(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (widget.bookSize != null) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '•',
                                      style: GoogleFonts.outfit(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(widget.bookSize! / (1024 * 1024)).toStringAsFixed(1)} MB',
                                      style: GoogleFonts.outfit(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Barra linear no fundo do card durante o download
                  if (isDownloading)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                        child: LinearProgressIndicator(
                          value: downloadProgress > 0 ? downloadProgress : null,
                          backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          minHeight: 3.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverImage() {
    if (_metadata?.coverUrl != null && _metadata!.coverUrl!.isNotEmpty) {
      if (!kIsWeb && _metadata!.coverUrl!.startsWith('file://')) {
        return Image.file(
          File(_metadata!.coverUrl!.replaceFirst('file://', '')),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } else if (_metadata!.coverUrl!.startsWith('data:image')) {
        try {
          final bytes = base64Decode(_metadata!.coverUrl!.split(',').last);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        } catch (_) {
          return _buildPlaceholder();
        }
      } else {
        return Image.network(
          _metadata!.coverUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Theme.of(context).colorScheme.surfaceContainer, Theme.of(context).cardColor],
        ),
      ),
      child: Stack(
        children: [
          // Book spine shadow
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 10,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 0,
            bottom: 0,
            width: 1,
            child: Container(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 32,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueEntry {
  final OneDriveBook book;
  double? progress;
  _QueueEntry({required this.book});
}

class _QueueCard extends StatefulWidget {
  final _QueueEntry entry;
  const _QueueCard({required this.entry});

  @override
  State<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<_QueueCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Baixando ${widget.entry.book.name}...',
            style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
          ),
          if (widget.entry.progress == null || widget.entry.progress! >= 0) ...[
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: widget.entry.progress,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
              borderRadius: BorderRadius.circular(10),
            ),
          ]
        ],
      ),
    );
  }
}
