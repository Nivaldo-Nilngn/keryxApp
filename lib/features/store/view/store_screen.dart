import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/core/widgets/glass_card.dart';
import 'package:keryx_app/features/bible/navigation/view/commentary_selection_screen.dart';
import 'package:keryx_app/features/bible/reading/view/commentary_reader_screen.dart';
import 'package:keryx_app/features/store/view/book_reader_screen.dart';
import 'package:keryx_app/features/store/view/html_book_reader_screen.dart';
import 'package:keryx_app/features/study/view/dictionary_screen.dart';
import 'package:keryx_app/features/store/view/store_item_details_screen.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/core/services/bible_service.dart';
import 'package:keryx_app/core/widgets/keryx_top_bar.dart';

final selectedCategoryProvider = StateProvider<StoreCategory?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');
final isLibraryModeProvider = StateProvider<bool>((ref) => false);

String _getDestinationText(StoreCategory cat) {
  switch (cat) {
    case StoreCategory.bibles: return 'Lido na aba Bíblia';
    case StoreCategory.books: return 'Lido na Biblioteca';
    case StoreCategory.commentaries: return 'Aba Bíblia (Comentários)';
    case StoreCategory.expository: return 'Aba Bíblia (Expositivos)';
    case StoreCategory.homiletics: return 'Aba Bíblia (Esboços)';
    case StoreCategory.culture: return 'Aba Bíblia (Cultura)';
    case StoreCategory.dictionaries: return 'Lido em Dicionários';
    case StoreCategory.fonts: return 'Usado em Configurações';
    case StoreCategory.journals: return 'Lido na Biblioteca';
    case StoreCategory.audios: return 'Ouvido no Player';
    case StoreCategory.outros: return 'Módulos Diversos';
  }
}

class StoreScreen extends ConsumerStatefulWidget {
  final bool initialLibraryMode;
  final StoreCategory? initialCategory;

  const StoreScreen({
    super.key,
    this.initialLibraryMode = false,
    this.initialCategory,
  });

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  bool _isSelectionMode = false;
  final Set<StoreItem> _selectedItems = {};
  bool _isDownloadsExpanded = false;

  void _toggleSelection(StoreItem item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
        if (_selectedItems.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedItems.add(item);
      }
    });
  }

  void _enterSelectionMode(StoreItem item) {
    setState(() {
      _isSelectionMode = true;
      _selectedItems.add(item);
    });
  }

  Future<void> _deleteSelectedItems() async {
    final itemsToDelete = _selectedItems.toList();
    if (itemsToDelete.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Excluir ${itemsToDelete.length} itens?', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text('Tem certeza que deseja excluir ${itemsToDelete.length} itens? Esta ação não pode ser desfeita.', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Cancelar', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text('Excluir Todos', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSelectionMode = false;
      _selectedItems.clear();
    });

    // Mostrar diálogo de carregamento centralizado e bloqueante
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) => PopScope(
        canPop: false,
        child: Center(
          child: GlassCard(
            width: 250,
            height: 200,
            borderRadius: 24,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.redAccent),
                const SizedBox(height: 24),
                Text(
                  'Removendo...',
                  style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aguarde, excluindo itens...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      for (final item in itemsToDelete) {
        await ref.read(storeProvider.notifier).deletePackage(item);
      }
      
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // fecha dialog de loading
        setState(() {}); // Força atualização imediata da lista
        
        showDialog(
          context: context,
          barrierDismissible: false, 
          builder: (dialogContext) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            });

            return Center(
              child: GlassCard(
                width: 280,
                height: 250,
                borderRadius: 24,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 80),
                    const SizedBox(height: 24),
                    Text(
                      'Sucesso!',
                      style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${itemsToDelete.length} itens excluídos!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // fecha dialog em caso de erro
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isLibraryModeProvider.notifier).state = widget.initialLibraryMode;
      if (widget.initialCategory != null) {
        ref.read(selectedCategoryProvider.notifier).state = widget.initialCategory;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    
    // Filtrar itens para a biblioteca
    final libraryItems = state.availablePackages.where((item) {
      final matchesLibrary = state.isDownloaded(item.filename);
      final matchesCategory = selectedCategory == null || item.category == selectedCategory;
      final matchesSearch = searchQuery.isEmpty || 
                            item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                            item.id.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesLibrary && matchesCategory && matchesSearch;
    }).toList();

    return PopScope(
      canPop: selectedCategory == null && searchQuery.isEmpty && !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedItems.clear();
          });
          return;
        }
        if (searchQuery.isNotEmpty) {
          ref.read(searchQueryProvider.notifier).state = '';
          return;
        }
        if (selectedCategory != null) {
          ref.read(selectedCategoryProvider.notifier).state = null;
          return;
        }
      },
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: KeryxTopBar(
          title: 'KeryxApp',
          showBackButton: false,
          additionalActions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              onPressed: () => ref.read(storeProvider.notifier).refresh(),
            )
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar Premium
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: GlassCard(
                  borderRadius: 24,
                  padding: EdgeInsets.zero,
                  child: TextField(
                    onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar Bíblias, Comentários...',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                      prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.primary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      suffixIcon: searchQuery.isNotEmpty ? IconButton(
                        icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), size: 20),
                        onPressed: () {
                          ref.read(searchQueryProvider.notifier).state = '';
                          FocusScope.of(context).unfocus();
                        },
                      ) : null,
                    ),
                  ),
                ),
              ),
              
              if (_isSelectionMode)
                 Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
                              onPressed: () => setState(() {
                                _isSelectionMode = false;
                                _selectedItems.clear();
                              }),
                            ),
                            Text(
                              '${_selectedItems.length} selecionados',
                              style: GoogleFonts.outfit(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                          ),
                          onPressed: _deleteSelectedItems,
                          icon: Icon(Icons.delete_outline_rounded, size: 18),
                          label: Text('Excluir', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
              
              // TabBar Estilo Google Play
              if (searchQuery.isEmpty && selectedCategory == null)
                TabBar(
                  isScrollable: true,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 3,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                  unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16),
                  dividerColor: Colors.transparent,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  tabs: const [
                    Tab(text: 'Para Você'),
                    Tab(text: 'Categorias'),
                    Tab(text: 'Minha Biblioteca'),
                  ],
                ),
                
              if (selectedCategory != null && searchQuery.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => ref.read(selectedCategoryProvider.notifier).state = null,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.onSurface, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _getCategoryLabel(selectedCategory),
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(selectedCategory).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getCategoryColor(selectedCategory).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${state.availablePackages.where((i) => i.category == selectedCategory).length} itens',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getCategoryColor(selectedCategory),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
              _buildActiveDownloadsIndicator(context, state, ref),
              
              const SizedBox(height: 8),

              // Conteúdo Principal
              Expanded(
                child: state.error != null && state.availablePackages.isEmpty
                    ? _buildErrorView(state.error!, ref)
                    : searchQuery.isNotEmpty || selectedCategory != null
                        ? _buildStoreContent(context, state.availablePackages.where((item) {
                      final matchesCategory = selectedCategory == null || item.category == selectedCategory;
                      final matchesSearch = item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                                            item.id.toLowerCase().contains(searchQuery.toLowerCase());
                      return matchesCategory && matchesSearch;
                    }).toList(), state, ref)
                  : TabBarView(
                      children: [
                        _buildDestaquesTab(context, state, ref),
                        _buildCategoryGrid(context, ref, state, false),
                        libraryItems.isEmpty 
                            ? _buildEmptyLibraryView(ref) 
                            : _buildStoreContent(context, libraryItems, state, ref),
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

  // --- NOVA ABA DESTAQUES ESTILO PLAY STORE ---
  Widget _buildDestaquesTab(BuildContext context, StoreState state, WidgetRef ref) {
    if (state.isLoading && state.availablePackages.isEmpty) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }
    
    // Lógica Inteligente para criar coleções baseada em prefixos comuns ou categorias
    
    // 1. Lançamentos (Top 10 Bíblias ou Livros Aleatórios/Recentes)
    final lancamentos = state.availablePackages.take(8).toList();
    
    // 2. Dicionários Populares
    final dicionarios = state.availablePackages.where((i) => i.category == StoreCategory.dictionaries).take(10).toList();
    
    // 3. Comentários
    final comentarios = state.availablePackages.where((i) => i.category == StoreCategory.commentaries).take(10).toList();
    
    // 4. Bíblias
    final biblias = state.availablePackages.where((i) => i.category == StoreCategory.bibles).take(10).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _buildHorizontalCollection('Lançamentos Premium', lancamentos, state, ref, onTap: null),
        _buildHorizontalCollection('Bíblias Essenciais', biblias, state, ref, 
            onTap: () => ref.read(selectedCategoryProvider.notifier).state = StoreCategory.bibles),
        _buildHorizontalCollection('Dicionários Completos', dicionarios, state, ref, 
            onTap: () => ref.read(selectedCategoryProvider.notifier).state = StoreCategory.dictionaries),
        _buildHorizontalCollection('Comentários de Peso', comentarios, state, ref, 
            onTap: () => ref.read(selectedCategoryProvider.notifier).state = StoreCategory.commentaries),
      ],
    );
  }

  Widget _buildHorizontalCollection(String title, List<StoreItem> items, StoreState state, WidgetRef ref, {VoidCallback? onTap}) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
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
          height: 245,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length > 10 ? 10 : items.length,
            itemBuilder: (context, index) {
              return _buildAppCard(items[index], state, ref);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAppCard(StoreItem item, StoreState state, WidgetRef ref) {
    final isDownloaded = state.isDownloaded(item.filename);
    final downloadProgress = state.downloadProgress[item.filename];
    final isDownloading = downloadProgress != null;
    final color = _getCategoryColor(item.category);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => StoreItemDetailsScreen(item: item)));
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Capa Estilo Play Store Books (Livro Compacto)
            Container(
              width: 130,
              height: 152,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.9),
                    color.withValues(alpha: 0.6),
                    const Color(0xFF0F172A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    // Lombada 3D do livro à esquerda
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.white.withValues(alpha: 0.12),
                              Colors.transparent,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                    // Conteúdo interno da capa
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(item.categoryIcon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                              ),
                              if (isDownloaded)
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, size: 10, color: Colors.black),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            item.name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.15,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (item.sizeBytes != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${(item.sizeBytes! / 1024 / 1024).toStringAsFixed(1)} MB',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Overlay de download com opção de cancelar
                    if (isDownloading)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            ref.read(storeProvider.notifier).cancelDownload(item);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Download de ${item.name} cancelado.'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.75),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: downloadProgress,
                                          strokeWidth: 2.8,
                                          color: Colors.redAccent,
                                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                                        ),
                                        const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${(downloadProgress * 100).toInt()}% • Cancelar',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Título do Livro
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            // Metadados estilo Play Store
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                const SizedBox(width: 2),
                Text(
                  '4.9',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  ' • ${_getCategoryLabel(item.category)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildActiveDownloadsIndicator(BuildContext context, StoreState state, WidgetRef ref) {
    if (state.downloadProgress.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.cloud_download_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Baixando ${state.downloadProgress.length} item(ns)...',
                  style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...state.downloadProgress.entries
                .take(_isDownloadsExpanded ? state.downloadProgress.length : 1)
                .map((entry) {
              final item = state.availablePackages.firstWhere(
                (p) => p.filename == entry.key,
                orElse: () => StoreItem(id: '', name: entry.key, filename: entry.key, category: StoreCategory.commentaries),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(entry.value * 100).toInt()}%',
                          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            ref.read(storeProvider.notifier).cancelDownload(item);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Download de ${item.name} cancelado.'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: entry.value,
                      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
              );
            }),
            if (state.downloadProgress.length > 1)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isDownloadsExpanded = !_isDownloadsExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isDownloadsExpanded 
                            ? 'Ocultar fila...'
                            : '+ ${state.downloadProgress.length - 1} outro(s) na fila...',
                        style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isDownloadsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context, WidgetRef ref, StoreState state, bool isLibraryMode) {
    // Pré-filtrar categorias para não deixar buracos na GridView
    final activeCategories = StoreCategory.values.where((cat) {
      final items = state.availablePackages.where((item) => item.category == cat);
      final count = isLibraryMode 
          ? items.where((item) => state.isDownloaded(item.filename)).length
          : items.where((item) => !state.isDownloaded(item.filename)).length;
      return count > 0;
    }).toList();

    return Column(
      children: [
        _buildSearchField(context, ref, ''),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: activeCategories.length,
            itemBuilder: (context, index) {
              final cat = activeCategories[index];
              final label = _getCategoryLabel(cat);
              final items = state.availablePackages.where((item) => item.category == cat);
              final itemCount = isLibraryMode 
                  ? items.where((item) => state.isDownloaded(item.filename)).length
                  : items.where((item) => !state.isDownloaded(item.filename)).length;
              
              return _AnimatedCategoryCard(
                category: cat,
                label: label,
                itemCount: itemCount,
                iconData: _getCategoryIcon(cat),
                baseColor: _getCategoryColor(cat),
                onTap: () => ref.read(selectedCategoryProvider.notifier).state = cat,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context, WidgetRef ref, String searchQuery) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: GlassCard(
        borderRadius: 16,
        padding: EdgeInsets.zero,
        child: TextField(
          onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'O que você está procurando?',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
            prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.primary),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            suffixIcon: searchQuery.isNotEmpty ? IconButton(
              icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), size: 20),
              onPressed: () => ref.read(searchQueryProvider.notifier).state = '',
            ) : null,
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(StoreCategory cat) {
    switch (cat) {
      case StoreCategory.bibles: return Icons.menu_book_rounded;
      case StoreCategory.books: return Icons.collections_bookmark_rounded;
      case StoreCategory.commentaries: return Icons.auto_stories_rounded;
      case StoreCategory.expository: return Icons.library_books_rounded;
      case StoreCategory.homiletics: return Icons.record_voice_over_rounded;
      case StoreCategory.culture: return Icons.public_rounded;
      case StoreCategory.dictionaries: return Icons.translate_rounded;
      case StoreCategory.fonts: return Icons.font_download_rounded;
      case StoreCategory.journals: return Icons.article_rounded;
      case StoreCategory.audios: return Icons.audiotrack_rounded;
      case StoreCategory.outros: return Icons.extension_rounded;
    }
  }

  Color _getCategoryColor(StoreCategory cat) {
    switch (cat) {
      case StoreCategory.bibles: return const Color(0xFFE2B93B); // Dourado Bíblia
      case StoreCategory.books: return const Color(0xFFF39C12); // Laranja Clássico
      case StoreCategory.commentaries: return const Color(0xFF9B59B6); // Roxo Profundo
      case StoreCategory.expository: return const Color(0xFF1ABC9C); // Verde Água
      case StoreCategory.homiletics: return const Color(0xFFE74C3C); // Vermelho Vibrante
      case StoreCategory.culture: return const Color(0xFF2ECC71); // Verde Esmeralda
      case StoreCategory.dictionaries: return const Color(0xFF3498DB); // Azul Claro
      case StoreCategory.fonts: return const Color(0xFF00CEC9); // Ciano
      case StoreCategory.journals: return const Color(0xFF6C5CE7); // Indigo
      case StoreCategory.audios: return const Color(0xFFFFA726); // Dourado Harpa
      case StoreCategory.outros: return const Color(0xFF95A5A6); // Cinza Neutro
    }
  }

  String _getCategoryLabel(StoreCategory cat) {
    switch (cat) {
      case StoreCategory.bibles: return 'Bíblias';
      case StoreCategory.books: return 'Livros';
      case StoreCategory.commentaries: return 'Comentários';
      case StoreCategory.expository: return 'Expositivos';
      case StoreCategory.homiletics: return 'Esboços e Homilética';
      case StoreCategory.culture: return 'Cultura e História';
      case StoreCategory.dictionaries: return 'Dicionários';
      case StoreCategory.fonts: return 'Fontes';
      case StoreCategory.journals: return 'Jornais';
      case StoreCategory.audios: return 'Áudios e Louvores';
      case StoreCategory.outros: return 'Diversos';
    }
  }

  Widget _buildEmptyLibraryView(WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_add_rounded, color: Colors.white.withValues(alpha: 0.1), size: 80),
          const SizedBox(height: 24),
          Text(
            'Sua biblioteca está vazia',
            style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Baixe Bíblias e comentários na loja.',
            style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navegar para a primeira aba "Para Você"
              DefaultTabController.of(context).animateTo(0);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: Icon(Icons.storefront_rounded),
            label: Text('Explorar Loja'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar loja',
            style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60), fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.read(storeProvider.notifier).refresh(),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            child: Text('Tentar Novamente', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreContent(BuildContext context, List<StoreItem> filteredItems, StoreState state, WidgetRef ref) {
    if (filteredItems.isEmpty) {
      final isLibrary = ref.read(isLibraryModeProvider);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isLibrary ? Icons.library_books_rounded : Icons.check_circle_outline_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24), size: 64),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                isLibrary 
                  ? 'Nenhum item encontrado nesta categoria.'
                  : 'Todos os itens desta categoria já foram baixados.\nEles estão disponíveis na aba "Biblioteca".',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60), fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(selectedCategoryProvider.notifier).state = null;
                ref.read(searchQueryProvider.notifier).state = '';
              },
              icon: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.primary),
              label: Text('Voltar para Categorias', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.primary)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      );
    }

    // Agrupar itens filtrados por subcategoria (para criar divisões dentro da pasta)
    final groups = <String, List<StoreItem>>{};
    for (var item in filteredItems) {
      String groupName = item.categoryDisplayName;
      
      if (item.category == StoreCategory.commentaries) {
        final name = item.name.toLowerCase();
        if (name.contains('expositivo') || name.contains('exposição')) {
          groupName = 'COMENTÁRIOS EXPOSITIVOS';
        } else if (name.contains('cultura') || name.contains('história') || name.contains('costumes') || name.contains('geografia') || name.contains('arqueologia') || name.contains('manners') || name.contains('tempos')) {
          groupName = 'CULTURA E HISTÓRIA BÍBLICA';
        } else if (name.contains('esboço') || name.contains('tema') || name.contains('homilética') || name.contains('sermão') || name.contains('sermões') || name.contains('tópico')) {
          groupName = 'ESBOÇOS E HOMILÉTICA';
        } else if (name.contains('teologia') || name.contains('sistemática') || name.contains('doutrina')) {
          groupName = 'TEOLOGIA SISTEMÁTICA';
        } else {
          groupName = 'VERSÍCULO A VERSÍCULO';
        }
      }
      
      groups.putIfAbsent(groupName, () => []).add(item);
    }

    final sortedGroups = groups.keys.toList()
      ..sort((a, b) => a.compareTo(b)); // Sort alphabetically by subcategory name

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: sortedGroups.length,
      itemBuilder: (context, index) {
        final groupName = sortedGroups[index];
        final items = groups[groupName]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(items.first.categoryIcon, color: Theme.of(context).colorScheme.primary, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          groupName,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${items.length})',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
            ...items.map((item) => _buildStoreItem(context, item, state, ref)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildStoreItem(BuildContext context, StoreItem item, StoreState state, WidgetRef ref) {
    final isDownloaded = state.isDownloaded(item.filename);
    final downloadProgress = state.downloadProgress[item.filename];
    final isDownloading = downloadProgress != null;
    final color = _getCategoryColor(item.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: isDownloaded && !_isSelectionMode ? () => _enterSelectionMode(item) : null,
          onTap: _isSelectionMode && isDownloaded 
              ? () => _toggleSelection(item) 
              : () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreItemDetailsScreen(item: item))),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: _selectedItems.contains(item) 
                  ? Border.all(color: Colors.redAccent, width: 2) 
                  : Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                if (_isSelectionMode && isDownloaded)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      _selectedItems.contains(item) ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _selectedItems.contains(item) ? Colors.redAccent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                // 1. Ícone Squircle Estilo Play Store
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.9),
                        color.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      item.categoryIcon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // 2. Coluna Central de Detalhes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            '4.9',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                          Text(
                            ' • ',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                          ),
                          if (item.sizeBytes != null) ...[
                            Text(
                              '${(item.sizeBytes! / 1024 / 1024).toStringAsFixed(1)} MB',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            Text(
                              ' • ',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                            ),
                          ],
                          Flexible(
                            child: Text(
                              _getCategoryLabel(item.category),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: color.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // 3. Botão Play Store à Direita
                if (isDownloaded && !_isSelectionMode)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botão Abrir Estilo Play Store
                      GestureDetector(
                        onTap: () {
                          if (item.category == StoreCategory.books) {
                            if (item.filename.contains('Harpa')) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => BookReaderScreen(book: item)),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => HtmlBookReaderScreen(book: item)),
                              );
                            }
                          } else if (item.category == StoreCategory.commentaries) {
                            ref.read(selectedCommentaryVersionProvider.notifier).state = CommentaryMetadata(
                              id: item.id,
                              name: item.name,
                              filename: item.filename,
                              category: CommentaryCategory.estudo,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CommentarySelectionScreen()),
                            );
                          } else if (item.category == StoreCategory.dictionaries) {
                            ref.read(selectedDictionaryProvider.notifier).state = item.filename;
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                            );
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => StoreItemDetailsScreen(item: item)));
                          }
                        },
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                          ),
                          child: Center(
                            child: Text(
                              'Abrir',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Menu de Opções / Excluir
                      IconButton(
                        icon: Icon(Icons.more_vert_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => _showItemActionsBottomSheet(context, item, ref),
                      ),
                    ],
                  )
                else if (isDownloading)
                  GestureDetector(
                    onTap: () {
                      ref.read(storeProvider.notifier).cancelDownload(item);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Download de ${item.name} cancelado.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              value: downloadProgress,
                              strokeWidth: 2,
                              color: Colors.redAccent,
                              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(downloadProgress * 100).toInt()}%',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                        ],
                      ),
                    ),
                  )
                else
                  // Botão "Baixar" estilo Play Store Pill
                  GestureDetector(
                    onTap: () => ref.read(storeProvider.notifier).downloadPackage(item),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Baixar',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
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

  void _showItemActionsBottomSheet(BuildContext context, StoreItem item, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bottomCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text('Ver detalhes completos', style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(bottomCtx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => StoreItemDetailsScreen(item: item)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: Text('Excluir do dispositivo', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(bottomCtx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        backgroundColor: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Excluir item?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        content: Text('Tem certeza que deseja excluir ${item.name} do dispositivo?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancelar')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref.read(storeProvider.notifier).deletePackage(item);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedCategoryCard extends StatefulWidget {
  final StoreCategory category;
  final String label;
  final int itemCount;
  final IconData iconData;
  final Color baseColor;
  final VoidCallback onTap;

  const _AnimatedCategoryCard({
    required this.category,
    required this.label,
    required this.itemCount,
    required this.iconData,
    required this.baseColor,
    required this.onTap,
  });

  @override
  State<_AnimatedCategoryCard> createState() => _AnimatedCategoryCardState();
}

class _AnimatedCategoryCardState extends State<_AnimatedCategoryCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).cardColor, // Fundo mais escuro e sólido, estilo do app
              border: Border.all(
                color: _isHovered ? widget.baseColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.baseColor.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Ícone de fundo transparente
                    Positioned(
                      right: -15,
                      bottom: -15,
                      child: Icon(
                        widget.iconData,
                        size: 90,
                        color: widget.baseColor.withValues(alpha: 0.06),
                      ),
                    ),
                    // Etiqueta de itens (Top Right)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.baseColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: widget.baseColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          widget.itemCount > 0 ? '${widget.itemCount}' : 'Em breve',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: widget.itemCount > 0 ? widget.baseColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(widget.iconData, color: widget.baseColor, size: 36),
                          const Spacer(),
                          Text(
                            widget.label,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.baseColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getDestinationText(widget.category),
                              style: GoogleFonts.outfit(
                                fontSize: 9, 
                                color: widget.baseColor, 
                                fontWeight: FontWeight.bold
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}
