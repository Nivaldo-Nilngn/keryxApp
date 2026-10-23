import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:keryx_app/core/widgets/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:keryx_app/core/services/bible_service.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

enum SelectorStage { versions, books, chapters, verses }

class BibleSelectorBottomSheet extends ConsumerStatefulWidget {
  final BibleBook? initialBook;
  final int? initialChapter;
  final String? initialVersion;
  final SelectorStage? initialStage;
  final Set<int>? allowedBookIds;
  final String? commentaryFilename;

  const BibleSelectorBottomSheet({
    super.key,
    this.initialBook,
    this.initialChapter,
    this.initialVersion,
    this.initialStage,
    this.allowedBookIds,
    this.commentaryFilename,
  });

  @override
  ConsumerState<BibleSelectorBottomSheet> createState() => _BibleSelectorBottomSheetState();
}

class _BibleSelectorBottomSheetState extends ConsumerState<BibleSelectorBottomSheet> {
  late SelectorStage _stage;
  String? _selectedVersion;
  int? _selectedChapterForVerse;
  int? _selectedBookId;
  String? _selectedBookName;
  int _chaptersCount = 0;
  String _searchQuery = '';

  final Map<String, String> versionNames = Map.from(BibleMetadata.versionNames);

  bool _isOnline = true;
  bool _isCheckingConnection = true;

  @override
  void initState() {
    super.initState();
    _selectedVersion = widget.initialVersion ?? ref.read(selectedVersionProvider);
    
    if (widget.initialBook != null) {
      _selectedBookId = widget.initialBook!.id;
      _selectedBookName = widget.initialBook!.name;
      _chaptersCount = widget.initialBook!.chapters;
      _selectedChapterForVerse = widget.initialChapter ?? 1;
    }
    
    if (widget.initialStage != null) {
      _stage = widget.initialStage!;
    } else if (widget.initialBook != null) {
      _stage = SelectorStage.chapters;
    } else {
      _stage = SelectorStage.books;
    }

    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _isOnline = true;
          _isCheckingConnection = false;
        });
      }
      return;
    }

    try {
      // Método mais robusto e rápido: tentar abrir um socket TCP direto para o DNS do Google
      // Ignora cache de DNS e interceptações HTTP de operadoras.
      final socket = await io.Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 2));
      socket.destroy();
      
      if (mounted) {
        setState(() {
          _isOnline = true;
          _isCheckingConnection = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOnline = false;
          _isCheckingConnection = false;
        });
      }
    }
  }

  Future<void> _selectVersion(String version) async {
    final storeState = ref.read(storeProvider);
    // Verifica se é uma versão da nuvem da conta que ainda não está baixada
    StoreItem? cloudBible;
    for (var bible in storeState.availablePackages) {
      if (bible.category == StoreCategory.bibles &&
          storeState.isInCloudLibrary(bible.filename) &&
          !storeState.isDownloaded(bible.filename)) {
        String key = bible.filename.split('/').last;
        if (key.toLowerCase().endsWith('.sqlite')) {
          key = key.substring(0, key.length - 7);
        } else if (key.toLowerCase().endsWith('.bbl.mybible')) {
          key = key.substring(0, key.length - 12);
        } else if (key.toLowerCase().endsWith('.mybible')) {
          key = key.substring(0, key.length - 8);
        } else if (key.toLowerCase().endsWith('.db')) {
          key = key.substring(0, key.length - 3);
        }
        if (key.toUpperCase() == version.toUpperCase()) {
          cloudBible = bible;
          break;
        }
      }
    }

    if (cloudBible != null) {
      try {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Baixando ${cloudBible.name} da sua conta...')),
                ],
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        await ref.read(storeProvider.notifier).downloadPackage(cloudBible);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao baixar versão: $e')));
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedVersion = version;
      ref.read(selectedVersionProvider.notifier).setVersion(version);
    });

    if (widget.initialStage == SelectorStage.versions || 
        (widget.initialBook != null && widget.initialChapter != null)) {
      Navigator.of(context).pop((
        book: widget.initialBook ?? BibleBook(id: 1, name: 'Gênesis', abbrev: 'gn', author: 'Moisés', group: 'Pentateuco', chapters: 50),
        chapter: widget.initialChapter ?? 1,
        verse: null, // Resolves the type mismatch error
        version: version,
      ));
    } else {
      setState(() {
        _stage = SelectorStage.books;
      });
    }
  }

  void _selectBook(int id, String name, int chapters) {
    setState(() {
      _selectedBookId = id;
      _selectedBookName = name;
      _chaptersCount = chapters;
      _selectedChapterForVerse = 1;
      _stage = SelectorStage.chapters;
    });
  }

  void _selectChapter(int chapter) {
    if (_selectedBookId == null || _selectedVersion == null) return;
    
    final details = BibleMetadata.bookDetails[_selectedBookId!];
    if (details == null) return;

    if (ResponsiveLayout.isExpanded(context) || ResponsiveLayout.isMedium(context)) {
      setState(() {
        _selectedChapterForVerse = chapter;
      });
    } else {
      setState(() {
        _selectedChapterForVerse = chapter;
        _stage = SelectorStage.verses;
      });
    }
  }

  void _finishSelection(int chapter, int? verse) {
    if (_selectedBookId == null || _selectedVersion == null) return;
    
    final details = BibleMetadata.bookDetails[_selectedBookId!];
    if (details == null) return;

    final book = BibleBook(
      id: _selectedBookId!,
      name: _selectedBookName!,
      abbrev: details['abbrev'],
      chapters: details['chapters'],
      author: details['author'] ?? 'Desconhecido',
      group: details['group'] ?? 'Bíblia',
    );

    Navigator.of(context).pop((book: book, chapter: chapter, verse: verse, version: _selectedVersion!));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildContent(),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = '';
    String subtitle = '';
    switch (_stage) {
      case SelectorStage.versions:
        title = 'Escolher versão';
        subtitle = 'Toque em uma versão para selecionar.';
        break;
      case SelectorStage.books:
        title = 'Escolher livro';
        subtitle = 'Toque em um livro para abrir a seleção de capítulos.';
        break;
      case SelectorStage.chapters:
        title = 'Escolher capítulo';
        subtitle = _selectedBookName ?? 'Capítulos';
        break;
      case SelectorStage.verses:
        title = 'Escolher versículo';
        subtitle = _selectedBookName ?? 'Versículos';
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onSurface),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_stage) {
      case SelectorStage.versions:
        return _buildVersionsList();
      case SelectorStage.books:
        return _buildBooksList();
      case SelectorStage.chapters:
        return _buildChaptersGrid();
      case SelectorStage.verses:
        return _buildVersesGrid();
    }
  }

  Widget _buildVersionsList() {
    if (_isCheckingConnection) {
      return const Center(child: CircularProgressIndicator());
    }

    final storeState = ref.watch(downloadedStorePackagesProvider);
    final isVersionDownloadedLocally = (String v) {
      if (v == 'NVI' || v == 'ACF' || v == 'ARA_S') return true;
      if (storeState.isDownloaded('$v.sqlite') || 
          storeState.isDownloaded('$v.mybible') || 
          storeState.isDownloaded('$v.bbl.mybible') || 
          storeState.isDownloaded('$v.db')) {
        return true;
      }
      return storeState.availablePackages.any((p) =>
          p.category == StoreCategory.bibles &&
          storeState.isDownloaded(p.filename) &&
          (p.filename.toUpperCase().contains(v.toUpperCase())));
    };

    final availableVersions = versionNames.keys.where(isVersionDownloadedLocally).toList();

    // Adicionar bíblias baixadas dinamicamente ou salvas na nuvem da conta
    final userBibles = storeState.availablePackages
        .where((p) => p.category == StoreCategory.bibles && (storeState.isDownloaded(p.filename) || storeState.isInCloudLibrary(p.filename)));
    
    for (var bible in userBibles) {
      String key = bible.filename.split('/').last;
      if (key.contains('ARA+STRONG - ATUALIZADA + STRONG')) continue; // Skip to avoid duplicate with ARA_S

      if (key.toLowerCase().endsWith('.sqlite')) {
        key = key.substring(0, key.length - 7);
      } else if (key.toLowerCase().endsWith('.bbl.mybible')) {
        key = key.substring(0, key.length - 12);
      } else if (key.toLowerCase().endsWith('.mybible')) {
        key = key.substring(0, key.length - 8);
      } else if (key.toLowerCase().endsWith('.db')) {
        key = key.substring(0, key.length - 3);
      }
      
      // Se a chave já existir mas com capitalização diferente (ex: kja vs KJA), reaproveitamos a key do mapa
      final existingKey = versionNames.keys.cast<String?>().firstWhere(
        (k) => k?.toUpperCase() == key.toUpperCase(), 
        orElse: () => null
      );
      
      if (existingKey != null) {
        key = existingKey;
      } else {
        key = key.toUpperCase();
        versionNames[key] = bible.name;
      }

      if (!availableVersions.contains(key)) {
        availableVersions.add(key);
      }
    }

    if (!_isOnline) {
      // Se estiver offline e a versão atual não for local, volta para NVI
      if (!availableVersions.where(isVersionDownloadedLocally).contains(_selectedVersion)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _selectVersion('NVI');
        });
      }
    }

    return ListView.builder(
      key: const ValueKey('versions_list'),
      padding: const EdgeInsets.all(16),
      itemCount: availableVersions.length,
      itemBuilder: (context, index) {
        final version = availableVersions[index];
        final name = versionNames[version] ?? version;
        final isSelected = _selectedVersion == version;
        final isLocal = isVersionDownloadedLocally(version);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: InkWell(
            onTap: () => _selectVersion(version),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isLocal ? Icons.menu_book_rounded : Icons.cloud_download_rounded,
                      size: 24,
                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        if (isLocal)
                          Row(
                            children: [
                              Icon(
                                Icons.offline_pin,
                                size: 14,
                                color: isSelected 
                                    ? Theme.of(context).colorScheme.primary 
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Disponível Offline',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected 
                                      ? Theme.of(context).colorScheme.primary 
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Icon(
                                Icons.cloud_outlined,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Na Conta • Toque para baixar',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBooksList() {
    var books = BibleMetadata.bookNames.entries.toList();
    
    Set<int>? allowedIds = widget.allowedBookIds;
    if (widget.commentaryFilename == null && allowedIds == null) {
      // It's the bible selector, fetch dynamically
      final availableBibleBooks = ref.read(booksProvider).valueOrNull?.map((b) => b.id).toSet();
      if (availableBibleBooks != null) {
        allowedIds = availableBibleBooks.whereType<int>().toSet();
      }
    }

    if (allowedIds != null) {
      books = books.where((entry) => allowedIds!.contains(entry.key)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      books = books.where((entry) => entry.value.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
            ),
            child: TextField(
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Pesquisar livro...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const ValueKey('books_list'),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final entry = books[index];
              final id = entry.key;
              final name = entry.value;
              final details = BibleMetadata.bookDetails[id]!;
              final isSelected = _selectedBookId == id;
              
              final testament = id <= 39 ? 'Antigo Testamento' : 'Novo Testamento';
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      '$testament • ${details['chapters']} capítulos',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), size: 20),
                    onTap: () => _selectBook(id, name, details['chapters']),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVersesGrid() {
    if (_selectedChapterForVerse == null) {
      return Center(
        child: Text('Selecione um capítulo', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)))
      );
    }

    return FutureBuilder<BibleChapter>(
      future: ref.read(bibleServiceProvider).getChapter(
        _selectedVersion ?? 'NVI',
        BibleMetadata.bookDetails[_selectedBookId!]!['abbrev'], 
        _selectedChapterForVerse!, 
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text('Erro', style: TextStyle(color: Theme.of(context).colorScheme.error)));
        }
        final chapterData = snapshot.data!;
        final isTablet = ResponsiveLayout.isExpanded(context) || ResponsiveLayout.isMedium(context);
        return GridView.builder(
          key: const ValueKey('verses_grid'),
          padding: EdgeInsets.fromLTRB(24, 8, 24, 48 + MediaQuery.of(context).padding.bottom),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTablet ? 4 : 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: chapterData.verses.length,
          itemBuilder: (context, index) {
            final verse = chapterData.verses[index].number;
            return InkWell(
              onTap: () => _finishSelection(_selectedChapterForVerse!, verse),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$verse',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChaptersGrid() {
    if (widget.commentaryFilename != null) {
      return Consumer(
        builder: (context, ref, child) {
          final chaptersAsync = ref.watch(commentedChaptersDetailProvider((
            filename: widget.commentaryFilename!,
            bookId: _selectedBookId ?? 1,
          )));

          return chaptersAsync.when(
            data: (chapters) {
              if (chapters.isEmpty) {
                return Center(
                  child: Text('Nenhum conteúdo encontrado.', style: GoogleFonts.outfit(color: Colors.white54)),
                );
              }
              return ListView.builder(
                key: const ValueKey('chapters_list'),
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, 8, 24, 48 + MediaQuery.of(context).padding.bottom),
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final chapterInfo = chapters[index];
                  final chapter = chapterInfo['chapter'] as int;
                  final marker = chapterInfo['marker'] as String?;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _finishSelection(chapter, null),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.kPrimaryGold.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.menu_book_rounded, color: AppTheme.kPrimaryGold, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(marker ?? 'Capítulo $chapter', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  if (marker != null)
                                    Text('Capítulo inicial: $chapter', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.white24),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.kPrimaryGold)),
            error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.red))),
          );
        },
      );
    }

    final isTablet = ResponsiveLayout.isExpanded(context) || ResponsiveLayout.isMedium(context);

    final chaptersGrid = GridView.builder(
      key: const ValueKey('chapters_grid'),
      padding: EdgeInsets.fromLTRB(24, 8, 24, 48 + MediaQuery.of(context).padding.bottom),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 4 : 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: _chaptersCount,
      itemBuilder: (context, index) {
        final chapter = index + 1;
        final isSelected = _selectedChapterForVerse == chapter;
        return InkWell(
          onTap: () => _selectChapter(chapter),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? Colors.transparent : Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$chapter',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 16,
                color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        );
      },
    );

    if (!isTablet) {
      return chaptersGrid;
    }

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 24.0, bottom: 8.0),
                child: Text('Capítulo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
              ),
              Expanded(child: chaptersGrid),
            ],
          ),
        ),
        Container(
          width: 1, 
          margin: const EdgeInsets.symmetric(vertical: 16),
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1)
        ),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 24.0, bottom: 8.0),
                child: Text('Versículo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
              ),
              Expanded(
                child: _selectedChapterForVerse == null 
                ? Center(
                    child: Text('Selecione um capítulo', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)))
                  )
                : FutureBuilder<BibleChapter>(
                    future: ref.read(bibleServiceProvider).getChapter(
                      _selectedVersion ?? 'NVI',
                      BibleMetadata.bookDetails[_selectedBookId!]!['abbrev'], 
                      _selectedChapterForVerse!, 
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Center(child: Text('Erro', style: TextStyle(color: Theme.of(context).colorScheme.error)));
                      }
                      final chapterData = snapshot.data!;
                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: chapterData.verses.length,
                        itemBuilder: (context, index) {
                          final verse = chapterData.verses[index].number;
                          return InkWell(
                            onTap: () => _finishSelection(_selectedChapterForVerse!, verse),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$verse',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension Gaps on List<Widget> {
  List<Widget> withGaps(double gap) {
    if (isEmpty) return this;
    final list = <Widget>[];
    for (var i = 0; i < length; i++) {
      list.add(this[i]);
      if (i != length - 1) {
        list.add(SizedBox(width: gap, height: gap));
      }
    }
    return list;
  }
}

