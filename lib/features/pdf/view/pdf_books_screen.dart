import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:keryx_app/core/theme/app_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/services/pdf_service.dart';
// import 'package:keryx_app/core/services/graph_service.dart';
import 'package:keryx_app/core/utils/search_helper.dart';
import 'package:keryx_app/features/pdf/view/pdf_details_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/services/telegram/cloudflare_pdf_service.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/widgets/instagram_tablet_sidebar.dart';
import 'package:keryx_app/core/services/book_cover_service.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/store/view/book_reader_screen.dart';
import 'package:keryx_app/features/store/view/html_book_reader_screen.dart';
import 'package:keryx_app/features/pdf/view/pdf_viewer_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  List<Map<String, String>> _localBooks = [];
  List<Map<String, dynamic>> _cloudPdfs = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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

  int get _totalDownloadedEbooks {
    final storeState = ref.watch(downloadedStorePackagesProvider);
    return storeState.availablePackages
        .where((p) => p.category == StoreCategory.books && (storeState.isDownloaded(p.filename) || storeState.isInCloudLibrary(p.filename)))
        .where((p) => !p.filename.contains('Harpa.bok.mybible'))
        .length;
  }

  int get _totalDownloadedPdfs {
    final localNames = _localBooks.map((b) => b['name'] ?? '').toSet();
    final cloudCount = _cloudPdfs.where((cp) {
      final name = cp['name']?.toString() ?? '';
      return name.isNotEmpty && !localNames.contains(name) && !localNames.contains('$name.pdf');
    }).length;
    return _localBooks.where((b) {
      final isAsset = b['path']?.startsWith('assets/') == true;
      return !isAsset && !(b['path']?.startsWith('store_book:') ?? false);
    }).length + cloudCount;
  }

  int get _totalDownloadedAll => _totalDownloadedEbooks + _totalDownloadedPdfs;

  int _libraryAreaIndex = 0; // 0 = Todos, 1 = PDFs & Docs, 2 = E-books

  String? _lastReadPdfTitle;
  String? _lastReadPdfPath;
  int? _lastReadPdfPage;
  int? _lastReadPdfTotal;
  String? _lastReadPdfBookId;

  Future<void> _loadLastReadPdf() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final title = prefs.getString('last_read_pdf_title');
      if (title != null && mounted) {
        setState(() {
          _lastReadPdfTitle = title;
          _lastReadPdfPath = prefs.getString('last_read_pdf_path');
          _lastReadPdfPage = prefs.getInt('last_read_pdf_page');
          _lastReadPdfTotal = prefs.getInt('last_read_pdf_total');
          _lastReadPdfBookId = prefs.getString('last_read_pdf_book_id');
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) _loadTelegram();
    });
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (_searchQuery != q) {
        setState(() => _searchQuery = q);
      }
    });
    _loadLocalBooks();
    _loadTelegram();
    _loadLastReadPdf();
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

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalBooks() async {
    final downloaded = await _pdfService.listDownloadedBooks();
    List<Map<String, dynamic>> cloudPdfs = [];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      cloudPdfs = await _pdfService.getCloudPdfs();
      // Auto-sincroniza PDFs locais que ainda não estejam na nuvem do Firestore
      for (final local in downloaded) {
        final name = local['name'];
        if (name != null && !cloudPdfs.any((cp) => cp['name'] == name)) {
          await _pdfService.syncPdfToCloud(name);
        }
      }
    }
    if (mounted) {
      setState(() {
        _localBooks = downloaded;
        _cloudPdfs = cloudPdfs;
      });
    }
  }

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

  Widget _buildSegmentSelectorWidget() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmallMobile = screenWidth < 400;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          height: 46,
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
                  title: 'Todos',
                  icon: Icons.collections_bookmark_rounded,
                  count: _totalDownloadedAll,
                  isSelected: _libraryAreaIndex == 0,
                  onTap: () => setState(() => _libraryAreaIndex = 0),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSegmentOption(
                  title: isSmallMobile ? 'PDFs' : 'PDFs & Docs',
                  icon: Icons.picture_as_pdf_rounded,
                  count: _totalDownloadedPdfs,
                  isSelected: _libraryAreaIndex == 1,
                  onTap: () => setState(() => _libraryAreaIndex = 1),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSegmentOption(
                  title: 'E-books',
                  icon: Icons.auto_stories_rounded,
                  count: _totalDownloadedEbooks,
                  isSelected: _libraryAreaIndex == 2,
                  onTap: () => setState(() => _libraryAreaIndex = 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBarWidget({String hintText = 'Pesquisar por título, autor ou palavra-chave...'}) {
    return Center(
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
              hintText: hintText,
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
    );
  }

  Widget _buildCategoryChipsWidget() {
    final isTablet = MediaQuery.sizeOf(context).width >= 720;

    Widget buildChip(({String name, IconData icon}) item) {
      final isSelected = _selectedCategory == item.name;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedCategory = item.name;
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
    }

    if (isTablet) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _categoryItemList.map(buildChip).toList(),
          ),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _categoryItemList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => buildChip(_categoryItemList[index]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 720;

    final Widget content = Stack(
      children: [
        TabBarView(
          controller: _tabController,
          children: [
            _buildBibliotecaTab(), 
            _buildTelegramTab(),
          ],
        ),
        
        // Floating Navbar
        if (!isTablet)
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
    );

    final tabBarWidget = Container(
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
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppTheme.kPrimaryGold,
          boxShadow: [
            BoxShadow(
              color: AppTheme.kPrimaryGold.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
        labelStyle: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_shared_rounded, size: 16),
                SizedBox(width: 8),
                Text('Biblioteca'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_download_rounded, size: 16),
                SizedBox(width: 8),
                Text('Acervo Online'),
              ],
            ),
          ),
        ],
      ),
    );

    final topBar = MBibliaTopBar(
      title: 'KeryxApp',
      showLogo: true,
      showBackButton: false,
      isScrolled: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: tabBarWidget,
        ),
      ),
    );

    final Widget innerScaffold = Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isTablet ? null : topBar,
      body: SafeArea(
        top: true,
        bottom: false,
        child: isTablet
            ? Column(
                children: [
                  Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    padding: const EdgeInsets.only(top: 14, bottom: 10),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: tabBarWidget,
                      ),
                    ),
                  ),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
    );

    if (isTablet) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: InstagramTabletSidebar(
          currentIndex: 9, // Biblioteca
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

    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth > 1100
        ? (screenWidth - 1100) / 2 + 20
        : (screenWidth < 600 ? 16.0 : 20.0);

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
          SliverPadding(
            padding: EdgeInsets.only(left: horizontalPad, right: horizontalPad, top: 16, bottom: 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_searchQuery.isEmpty && _selectedCategory == 'Para Você') ...[
                    _buildAcervoHeroCard(),
                    const SizedBox(height: 18),
                    _buildLibraryCarousel(),
                    const SizedBox(height: 18),
                  ],
                  _buildSearchBarWidget(hintText: 'Pesquisar no Acervo Online (22.500+ obras)...'),
                  const SizedBox(height: 12),
                  _buildCategoryChipsWidget(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                _searchQuery.isNotEmpty ? 'Sem resultados' : 'Sem novidades',
                _searchQuery.isNotEmpty
                    ? 'Nenhum arquivo encontrado nas novidades.'
                    : 'Nenhum arquivo adicionado recentemente.',
                _searchQuery.isNotEmpty ? Icons.search_off : Icons.new_releases_outlined,
              ),
            )
          else if (_selectedCategory == 'Para Você' && _searchQuery.isEmpty)
            SliverPadding(
              padding: EdgeInsets.only(left: horizontalPad, right: horizontalPad),
              sliver: SliverToBoxAdapter(
                child: _buildDestaquesPDF(),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.only(left: horizontalPad, right: horizontalPad, top: 16, bottom: 100),
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
    final isTablet = MediaQuery.sizeOf(context).width >= 720;
    final categoriesList = [
      {'label': 'Bíblias', 'icon': Icons.menu_book_rounded, 'color': const Color(0xFFE2B93B)},
      {'label': 'Livros', 'icon': Icons.collections_bookmark_rounded, 'color': const Color(0xFFF39C12)},
      {'label': 'Comentários', 'icon': Icons.auto_stories_rounded, 'color': const Color(0xFF9B59B6)},
      {'label': 'Dicionários', 'icon': Icons.translate_rounded, 'color': const Color(0xFF3498DB)},
      {'label': 'Teologia', 'icon': Icons.account_balance_rounded, 'color': const Color(0xFFE74C3C)},
      {'label': 'Outros', 'icon': Icons.extension_rounded, 'color': const Color(0xFF95A5A6)},
    ];

    Widget buildCatItem(Map<String, Object> cat) {
      final label = cat['label'] as String;
      final icon = cat['icon'] as IconData;
      final color = cat['color'] as Color;

      return GestureDetector(
        onTap: () => setState(() => _selectedCategory = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isTablet) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: categoriesList.map((cat) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: buildCatItem(cat),
              ),
            );
          }).toList(),
        ),
      );
    }

    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categoriesList.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: buildCatItem(categoriesList[index]),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver todas',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: Theme.of(context).colorScheme.primary, size: 16),
                    ],
                  ),
              ],
            ),
          ),
        ),
        _HorizontalBookListWithControls(
          items: items,
          localBooks: _localBooks,
          onTapBook: (b, metadata) {
            final alreadyDownloaded = _localBooks.any((l) => l['name'] == b['name']);
            final localBook = alreadyDownloaded 
                ? _localBooks.firstWhere((l) => l['name'] == b['name']) 
                : null;
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
      ],
    );
  }

  Widget _buildBibliotecaTab() {
    final normQuery = SearchHelper.normalize(_searchQuery);

    // Watch Store state
    final storeState = ref.watch(downloadedStorePackagesProvider);
    final storeBooks = storeState.availablePackages
        .where((p) => p.category == StoreCategory.books && (storeState.isDownloaded(p.filename) || storeState.isInCloudLibrary(p.filename)))
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

    // Adiciona os PDFs da nuvem da conta que ainda não foram baixados localmente
    final localPdfNames = _localBooks.map((b) => b['name'] ?? '').toSet();
    for (final cp in _cloudPdfs) {
      final name = cp['name']?.toString() ?? '';
      if (name.isNotEmpty && !localPdfNames.contains(name) && !localPdfNames.contains('$name.pdf')) {
        downloadedBooks.add({
          'name': name,
          'path': 'cloud_pdf:${cp['bookId'] ?? ''}',
          'cloud_id': cp['bookId']?.toString() ?? '',
        });
      }
    }

    // Filtrar livros baixados pela busca e área selecionada (0 = Todos, 1 = PDFs, 2 = E-books)
    final filteredDownloaded = downloadedBooks.where((b) {
      final isEbook = b['path']?.startsWith('store_book:') ?? false;
      
      if (_libraryAreaIndex == 1 && isEbook) return false;
      if (_libraryAreaIndex == 2 && !isEbook) return false;
      
      final normName = SearchHelper.normalize(b['name']!);
      if (_searchQuery.isNotEmpty && !normName.contains(normQuery)) return false;
      return true;
    }).toList();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth > 1100
        ? (screenWidth - 1100) / 2 + 20
        : (screenWidth < 600 ? 16.0 : 20.0);

    final missingCloudCount = filteredDownloaded.where((b) {
      final p = b['path'] ?? '';
      if (p.startsWith('cloud_pdf:')) return true;
      if (p.startsWith('store_book:')) {
        return !storeState.isDownloaded(p.replaceFirst('store_book:', ''));
      }
      return false;
    }).length;

    final isSearchingWithNoResults = _searchQuery.isNotEmpty && filteredDownloaded.isEmpty;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(left: horizontalPad, right: horizontalPad, top: 16, bottom: 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HERO CARD DA SUA ESTANTE (FOCO EM LEITURAS SALVAS) ───────
                if (_searchQuery.isEmpty) ...[
                  _buildLibraryHeroCard(
                    totalCount: downloadedBooks.length,
                    pdfCount: _totalDownloadedPdfs,
                    ebookCount: _totalDownloadedEbooks,
                  ),
                  const SizedBox(height: 18),
                  if (_lastReadPdfTitle != null && _lastReadPdfTitle!.isNotEmpty) ...[
                    _buildContinueReadingSection(),
                    const SizedBox(height: 4),
                  ],
                ],
                // ── SELETOR DE ÁREA (Todos / PDFs & Docs / E-books) ──────────
                _buildSegmentSelectorWidget(),
                const SizedBox(height: 14),
                // ── BARRA DE BUSCA NA ESTANTE ───────────────────────────────
                _buildSearchBarWidget(hintText: 'Buscar nos seus livros e documentos baixados...'),
                const SizedBox(height: 18),
                if (missingCloudCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_sync_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Você possui $missingCloudCount item(ns) na sua nuvem salvos em outros aparelhos.',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (filteredDownloaded.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              _libraryAreaIndex == 1
                                  ? Icons.picture_as_pdf_rounded
                                  : (_libraryAreaIndex == 2
                                      ? Icons.auto_stories_rounded
                                      : Icons.collections_bookmark_rounded),
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _libraryAreaIndex == 1
                                    ? 'Seus Documentos PDF'
                                    : (_libraryAreaIndex == 2
                                        ? 'Seus E-books'
                                        : 'Suas Leituras Salvas'),
                                style: GoogleFonts.outfit(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${filteredDownloaded.length} ${filteredDownloaded.length == 1 ? 'leitura' : 'leituras'}',
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
                ] else if (isSearchingWithNoResults) ...[
                  _buildEmptySearchResults(),
                ] else ...[
                  _buildEmptyShelfCard(),
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
                  final isCloudPdf = bookPath.startsWith('cloud_pdf:');
                  final isStoreBook = bookPath.startsWith('store_book:');
                  final storeBookFilename = isStoreBook ? bookPath.replaceFirst('store_book:', '') : '';
                  final isStoreBookDownloaded = isStoreBook && storeState.isDownloaded(storeBookFilename);
                  final isDownloaded = !isCloudPdf && (!isStoreBook || isStoreBookDownloaded);

                  return _BookCard(
                    key: ValueKey(bookName),
                    name: bookName,
                    path: bookPath,
                    isLocal: isDownloaded,
                    alreadyDownloaded: isDownloaded,
                    onTap: (metadata) {
                      if (isStoreBook) {
                        try {
                          final storeItem = storeState.availablePackages.firstWhere((p) => p.filename == storeBookFilename);
                          if (!isStoreBookDownloaded) {
                            ref.read(storeProvider.notifier).downloadPackage(storeItem);
                            return;
                          }
                          if (storeItem.filename.contains('Harpa')) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => BookReaderScreen(book: storeItem)));
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => HtmlBookReaderScreen(book: storeItem)));
                          }
                        } catch(e) {
                          debugPrint('StoreItem não encontrado');
                        }
                      } else if (isCloudPdf) {
                        final bookId = bookPath.replaceFirst('cloud_pdf:', '');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfDetailsScreen(
                              name: bookName,
                              cleanName: cleanPdfName(bookName),
                              bookId: bookId.isNotEmpty ? bookId : null,
                              isLocal: false,
                              alreadyDownloaded: false,
                              metadata: metadata,
                              onDownloadCompleted: () => _loadLocalBooks(),
                            ),
                          ),
                        );
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
                      if (isStoreBook) {
                        try {
                          final storeItem = storeState.availablePackages.firstWhere((p) => p.filename == storeBookFilename);
                          await ref.read(storeProvider.notifier).deletePackage(storeItem);
                        } catch(e) {}
                      } else {
                        await _pdfService.deleteBook(bookName);
                        await _pdfService.removePdfFromCloud(bookName);
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
        ),
      ),
    );
  }

  // ── SEÇÃO: CONTINUAR LEITURA (ESTILO HOME) ──────────────────────────────────
  Widget _buildContinueReadingSection() {
    // Se temos um PDF salvo como última leitura
    final title = _lastReadPdfTitle;
    if (title == null || title.isEmpty) {
      return const SizedBox.shrink();
    }

    final page = _lastReadPdfPage ?? 1;
    final total = _lastReadPdfTotal;
    final progressText = total != null && total > 0
        ? 'Página $page de $total (${((page / total) * 100).toInt()}%)'
        : 'Página $page';

    return _buildContinueReadingCard(
      title: cleanPdfName(title),
      subtitle: progressText,
      badgeText: 'Última Leitura',
      icon: Icons.auto_stories_rounded,
      iconGradient: const [Color(0xFF0284C7), Color(0xFF38BDF8)],
      onTap: () {
        if (_lastReadPdfPath != null && _lastReadPdfPath!.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerScreen(
                title: title,
                pdfUrl: _lastReadPdfPath!,
                pdfId: _lastReadPdfBookId,
              ),
            ),
          ).then((_) {
            _loadLocalBooks();
            _loadLastReadPdf();
          });
        } else {
          _tabController.animateTo(1);
        }
      },
    );
  }

  Widget _buildContinueReadingCard({
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required List<Color> iconGradient,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 16, color: AppTheme.kPrimaryGold),
                  const SizedBox(width: 8),
                  Text(
                    'CONTINUAR LEITURA',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppTheme.kPrimaryGold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.kPrimaryGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: iconGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: iconGradient.first.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CARROSSEL DE CARDS DE DESTAQUE (ESTILO HOME) ───────────────────────────
  Widget _buildLibraryCarousel() {
    final cards = [
      _buildFeatureCard(
        title: 'Acervo Online',
        subtitle: 'Mais de 22.500 livros, comentários e teologia.',
        badgeText: '22.500+ Obras',
        badgeIcon: Icons.cloud_download_rounded,
        badgeColor: const Color(0xFF0284C7),
        actionIcon: Icons.explore_rounded,
        onTap: () => _tabController.animateTo(1),
      ),
      _buildFeatureCard(
        title: 'Bíblias & Textos',
        subtitle: 'Almeida, NVI, King James, Strong e notas.',
        badgeText: 'Estudo Bíblico',
        badgeIcon: Icons.menu_book_rounded,
        badgeColor: const Color(0xFF7C3AED),
        actionIcon: Icons.auto_stories_rounded,
        onTap: () {
          setState(() => _selectedCategory = 'Bíblias');
          _tabController.animateTo(1);
        },
      ),
      _buildFeatureCard(
        title: 'Comentários de Peso',
        subtitle: 'Moody, Shedd, Spurgeon e Matthew Henry.',
        badgeText: 'Exegese',
        badgeIcon: Icons.mode_comment_rounded,
        badgeColor: const Color(0xFFD97706),
        actionIcon: Icons.school_rounded,
        onTap: () {
          setState(() => _selectedCategory = 'Comentários');
          _tabController.animateTo(1);
        },
      ),
      _buildFeatureCard(
        title: 'Teologia Sistemática',
        subtitle: 'Doutrina, teologia reformada e história.',
        badgeText: 'Clássicos',
        badgeIcon: Icons.stars_rounded,
        badgeColor: const Color(0xFF10B981),
        actionIcon: Icons.workspace_premium_rounded,
        onTap: () {
          setState(() => _selectedCategory = 'Teologia');
          _tabController.animateTo(1);
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.kPrimaryGold),
              const SizedBox(width: 8),
              Text(
                'DESTAQUES & ACERVO',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppTheme.kPrimaryGold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => cards[index],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required String badgeText,
    IconData? badgeIcon,
    required Color badgeColor,
    required IconData actionIcon,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 256,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
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
                    color: badgeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (badgeIcon != null) ...[
                        Icon(badgeIcon, color: badgeColor, size: 12),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  actionIcon,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  size: 18,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryHeroCard({
    int totalCount = 0,
    int pdfCount = 0,
    int ebookCount = 0,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -30,
            child: Icon(
              Icons.collections_bookmark_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sua Estante de Leituras',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Seus livros, comentários e documentos salvos no aparelho para leitura rápida e offline.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcervoHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -30,
            child: Icon(
              Icons.cloud_download_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mais de 22.500 Obras',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bíblias de estudo, comentários, teologia e e-books gratuitos para download.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyShelfCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8, bottom: 40),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sua estante está vazia',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                _libraryAreaIndex == 1
                    ? 'Você ainda não possui documentos ou PDFs salvos offline. Acesse o Acervo Online para baixar livros e estudos.'
                    : (_libraryAreaIndex == 2
                        ? 'Você ainda não possui E-books baixados da Loja. Acesse o Acervo Online ou a Loja para baixar suas obras.'
                        : 'Você ainda não possui livros ou PDFs salvos no aparelho. Acesse o Acervo Online com mais de 22.500 títulos gratuitos para download.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.cloud_download_rounded, size: 18),
              label: Text(
                'Explorar Acervo Online (22.500+ Obras)',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
            ),
          ],
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

class _HorizontalBookListWithControls extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final List<Map<String, String>> localBooks;
  final void Function(Map<String, dynamic> book, BookMetadata? metadata) onTapBook;

  const _HorizontalBookListWithControls({
    required this.items,
    required this.localBooks,
    required this.onTapBook,
  });

  @override
  State<_HorizontalBookListWithControls> createState() => _HorizontalBookListWithControlsState();
}

class _HorizontalBookListWithControlsState extends State<_HorizontalBookListWithControls> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollButtons());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollButtons);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final canLeft = offset > 10;
    final canRight = offset < max - 10;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      if (mounted) {
        setState(() {
          _canScrollLeft = canLeft;
          _canScrollRight = canRight;
        });
      }
    }
  }

  void _scroll(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.sizeOf(context).width >= 720;

    return SizedBox(
      height: 280,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemExtent: 186.0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.items.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final b = widget.items[index];
              final alreadyDownloaded = widget.localBooks.any((l) => l['name'] == b['name']);
              final localBook = alreadyDownloaded
                  ? widget.localBooks.firstWhere((l) => l['name'] == b['name'])
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
                  onTap: (metadata) => widget.onTapBook(b, metadata),
                ),
              );
            },
          ),
          // Seta de navegação para a Esquerda
          if (isTablet && _canScrollLeft)
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _scroll(-380),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: theme.colorScheme.primary,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Seta de navegação para a Direita
          if (isTablet && _canScrollRight)
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _scroll(380),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.primary,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
  Uint8List? _cachedBase64Bytes;
  String? _lastCoverUrl;

  @override
  void initState() {
    super.initState();
    _metadata = _coverService.getCachedMetadata(widget.name);
    _updateCachedBytes();
    if (_metadata == null || (widget.isLocal && !_metadata!.isRealPdfCover)) {
      _loadCover();
    }
  }

  @override
  void didUpdateWidget(_BookCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name || oldWidget.path != widget.path) {
      _metadata = _coverService.getCachedMetadata(widget.name);
      _updateCachedBytes();
      if (_metadata == null || (widget.isLocal && !_metadata!.isRealPdfCover)) {
        _loadCover();
      }
    }
  }

  void _updateCachedBytes() {
    final coverUrl = _metadata?.coverUrl;
    if (coverUrl != _lastCoverUrl) {
      _lastCoverUrl = coverUrl;
      if (coverUrl != null && coverUrl.startsWith('data:image')) {
        try {
          _cachedBase64Bytes = base64Decode(coverUrl.split(',').last);
        } catch (_) {
          _cachedBase64Bytes = null;
        }
      } else {
        _cachedBase64Bytes = null;
      }
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
        _updateCachedBytes();
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
                                  const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.kPrimaryGold, size: 12),
                                  const SizedBox(width: 3),
                                  Text(
                                    'PDF',
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
          cacheWidth: 340,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } else if (_metadata!.coverUrl!.startsWith('data:image')) {
        if (_cachedBase64Bytes != null) {
          return Image.memory(
            _cachedBase64Bytes!,
            fit: BoxFit.cover,
            cacheWidth: 340,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        }
        return _buildPlaceholder();
      } else {
        return Image.network(
          _metadata!.coverUrl!,
          fit: BoxFit.cover,
          cacheWidth: 340,
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


