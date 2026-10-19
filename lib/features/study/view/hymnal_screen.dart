import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/services/database_service.dart';
import 'package:keryx_app/core/widgets/glass_card.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/features/store/repository/store_repository.dart';
import 'package:keryx_app/features/store/view/store_screen.dart';

class HymnalScreen extends ConsumerStatefulWidget {
  final String filename;
  final String title;

  const HymnalScreen({
    super.key,
    this.filename = 'books/Harpa.bok.mybible',
    this.title = 'Harpa Cristã',
  });

  @override
  ConsumerState<HymnalScreen> createState() => _HymnalScreenState();
}

class _HymnalScreenState extends ConsumerState<HymnalScreen> {
  List<Map<String, dynamic>> _hymns = [];
  List<Map<String, dynamic>> _filteredHymns = [];
  bool _isLoading = true;
  bool _isDownloaded = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
  }

  Future<void> _checkAndLoad() async {
    final storeRepo = StoreRepository();
    final downloaded = await storeRepo.fileExists(widget.filename);
    
    if (mounted) {
      setState(() {
        _isDownloaded = downloaded;
      });
    }

    if (downloaded) {
      final dbService = DatabaseService();
      final items = await dbService.getBookStories(widget.filename);
      
      // Limpar IDs e Títulos (pegar apenas números para o ID e texto para o título)
      final cleanedItems = items.map((item) {
        String rawId = item['id'].toString();
        String title = item['title'].toString();
        
        // Extrai APENAS os números iniciais para o badge dourado (ex: "1" de "1. CHUVAS")
        final idRegex = RegExp(r'^\d+');
        final cleanId = idRegex.stringMatch(rawId) ?? rawId;
        
        // Remove QUALQUER número inicial, pontos ou traços do título (ex: "01.", "1 - ", "2. ")
        final titleRegex = RegExp(r'^\d+[\s\.\-:\/]*');
        title = title.replaceFirst(titleRegex, '').trim();
        
        // Se após a remoção o título ficou vazio (ex: o título era só o número), usa o original
        if (title.isEmpty) title = item['title'].toString();
        
        return {
          ...item,
          'displayId': cleanId,
          'displayTitle': title,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _hymns = cleanedItems;
          _filteredHymns = cleanedItems;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterHymns(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredHymns = _hymns;
      } else {
        _filteredHymns = _hymns.where((h) {
          final title = (h['displayTitle'] as String).toLowerCase();
          final text = (h['text'] as String).toLowerCase();
          final displayId = h['displayId'].toString();
          final originalId = h['id'].toString().toLowerCase();
          final q = query.toLowerCase();
          
          return title.contains(q) || 
                 text.contains(q) || 
                 displayId == query || 
                 originalId.startsWith(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1F),
      appBar: MBibliaTopBar(
        title: widget.title,
        showLogo: false,
        isScrolled: true,
      ),
      body: Stack(
        children: [
          !_isDownloaded
              ? _buildDownloadPrompt()
              : _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.kPrimaryGold))
                  : Column(
                      children: [
                        _buildSearchBar(),
                        Expanded(
                          child: _filteredHymns.isEmpty
                              ? _buildEmptyState()
                              : ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                                  itemCount: _filteredHymns.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final hymn = _filteredHymns[index];
                                    return _buildHymnItem(hymn);
                                  },
                                ),
                        ),
                      ],
                    ),
          
          // Navbar Fixa
          Align(
            alignment: Alignment.bottomCenter,
            child: StudyBottomNav(
              currentIndex: 3,
              onTap: (index) {
                if (index == 0) {
                  Navigator.pop(context);
                } else if (index == 1) {
                  ref.read(navigationProvider.notifier).setIndex(0);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (index == 2) {
                  ref.read(navigationProvider.notifier).setIndex(1);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadPrompt() {
    return Center(
      child: GlassCard(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_for_offline_rounded, color: AppTheme.kPrimaryGold, size: 70),
            const SizedBox(height: 24),
            Text(
              'Harpa não encontrada',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'Baixe os hinos da Harpa Cristã na loja para começar a ler.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white60),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const StoreScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.kPrimaryGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ir para a Loja', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: GlassCard(
        borderRadius: 16,
        padding: EdgeInsets.zero,
        child: TextField(
          onChanged: _filterHymns,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Número ou título do hino...',
            hintStyle: TextStyle(color: Colors.white38),
            prefixIcon: Icon(Icons.search_rounded, color: AppTheme.kPrimaryGold),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off_rounded, color: Colors.white.withValues(alpha: 0.05), size: 100),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'Nenhum hino encontrado' : 'Hino não encontrado',
            style: GoogleFonts.outfit(color: Colors.white24, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildHymnItem(Map<String, dynamic> hymn) {
    final number = hymn['displayId'] as String;
    final title = hymn['displayTitle'] as String;
    final id = hymn['id'].toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openHymnDetails(hymn),
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.kPrimaryGold, AppTheme.kPrimaryGold.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  number,
                  style: GoogleFonts.outfit(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (title != number)
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white10, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _openHymnDetails(Map<String, dynamic> hymn) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            // Header do Hino
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.kPrimaryGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'HINO ${hymn['id']}',
                      style: GoogleFonts.outfit(
                        color: AppTheme.kPrimaryGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white38),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Conteúdo
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    if (hymn['displayTitle'] != hymn['id'].toString()) ...[
                      Text(
                        hymn['displayTitle'],
                        style: GoogleFonts.merriweather(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    Html(
                      data: hymn['text'],
                      style: {
                        "body": Style(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: FontSize(20),
                          fontFamily: 'Outfit',
                          lineHeight: LineHeight.em(1.6),
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                        ),
                        "p": Style(
                          margin: Margins.only(bottom: 24),
                        ),
                        "br": Style(
                          display: Display.block,
                        ),
                      },
                    ),
                    const SizedBox(height: 20),
                    // Rodapé decorativo
                    Center(
                      child: Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.kPrimaryGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
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
}
