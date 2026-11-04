import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/features/pdf/view/pdf_books_screen.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/features/study/view/dictionary_screen.dart';
import 'package:keryx_app/features/ai/view/chat_assistant_screen.dart';
import 'package:keryx_app/features/home/service/devocional_service.dart';
import 'package:keryx_app/features/home/view/devocional_screen.dart';
import 'package:keryx_app/features/home/view/guide_screen.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/services/bible_service.dart';
import 'package:keryx_app/features/store/view/book_reader_screen.dart';
import 'package:keryx_app/features/store/view/store_screen.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/features/study_plan/presentation/study_plan_window.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/widgets/update_banner.dart';
import 'package:keryx_app/core/services/app_update_service.dart';
import 'package:keryx_app/core/services/release_notes_service.dart';

const Color _secondaryColor = Color(0xFFFFB95F);
const Color _primaryContainer = Color(0xFF4F46E5);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  bool _isHarpaDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHarpaDismissState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(latestUpdateInfoProvider);
      ref.read(releaseNotesServiceProvider).checkAndShowAfterUpdate(context);
    });
  }

  Future<void> _loadHarpaDismissState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isHarpaDismissed = prefs.getBool('harpa_home_card_dismissed') ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _dismissHarpaCard() async {
    setState(() {
      _isHarpaDismissed = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('harpa_home_card_dismissed', true);
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Atalho da Harpa Cristã removido da tela inicial.'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Desfazer',
            textColor: AppTheme.kPrimaryGold,
            onPressed: () async {
              setState(() {
                _isHarpaDismissed = false;
              });
              try {
                final p = await SharedPreferences.getInstance();
                await p.setBool('harpa_home_card_dismissed', false);
              } catch (_) {}
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(latestUpdateInfoProvider);
      ref.invalidate(currentAppVersionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 720;
    final topPadding = isTablet ? 24.0 : 16.0;
    final horizontalPadding = isTablet ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverSafeArea(
                top: true,
                bottom: false,
                sliver: SliverPadding(
                  padding: EdgeInsets.only(
                    top: topPadding,
                    bottom: 100,
                    left: horizontalPadding,
                    right: horizontalPadding,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const UpdateBanner(),
                      _buildHeroBanner(),
                      const SizedBox(height: 24),
                      _buildCarousel(),
                      const SizedBox(height: 32),
                      _buildContinueReading(),
                      const SizedBox(height: 32),
                      _buildMainTools(),
                      const SizedBox(height: 32),
                      _buildDevotional(),
                      const SizedBox(height: 32),
                      _buildPrimeirosPassosBanner(),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Bom dia';
    } else if (hour >= 12 && hour < 18) {
      return 'Boa tarde';
    } else {
      return 'Boa noite';
    }
  }

  Widget _buildHeroBanner() {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final userData = ref.watch(userDataProvider);
    String name = userData.value?['name'] ?? user?.displayName ?? 'Visitante';
    if (name.contains(' ')) {
      name = name.split(' ')[0]; // Pega só o primeiro nome
    }

    final greeting = _getGreeting();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -30,
            child: Icon(
              Icons.menu_book_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 120,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $name!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Seja bem-vindo de volta! Estude e medite na Palavra.',
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

  Widget _buildPrimeirosPassosBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GuideScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFFFFB95F), // Dourado
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Primeiros passos',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Conheça todas as ferramentas',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _buildCarouselCard(
            title: 'IATheos Chat',
            subtitle:
                'Estude a bíblia conversando com a nossa IA teológica avançada.',
            badgeText: 'Novo',
            badgeIcon: Icons.smart_toy_outlined,
            badgeColor: const Color(0xFF7C3AED), // #7C3AED
            actionIcon: Icons.auto_awesome_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatAssistantScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
          _buildCarouselCard(
            title: 'Primeiros Passos',
            subtitle:
                'Descubra como usar o app e desfrutar de todos os recursos bíblicos.',
            badgeText: 'Guia',
            badgeIcon: null,
            badgeColor: const Color(0xFFD97706),
            actionIcon: Icons.school_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GuideScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
          _buildCarouselCard(
            title: 'Plano de Estudo',
            subtitle:
                'Leitura bíblica cronológica em 1 ano (52 semanas).',
            badgeText: 'Novo',
            badgeIcon: Icons.calendar_month_rounded,
            badgeColor: const Color(0xFF0284C7),
            actionIcon: Icons.auto_stories_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudyPlanWindow()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselCard({
    required String title,
    required String subtitle,
    required String badgeText,
    IconData? badgeIcon,
    required Color badgeColor,
    required IconData actionIcon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 256,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
              Icon(actionIcon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), size: 18),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
    ));
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildContinueReading() {
    final lastRead = ref.watch(lastReadProvider);
    final selectedVersion = ref.watch(selectedVersionProvider);

    const versionNames = {
      'NVI': 'Nova Versão Internacional (NVI)',
      'ACF': 'Almeida Corrigida Fiel (ACF)',
      'ARA_S': 'Almeida Revista Atualizada + Strong (ARA_S)',
      'ARC': 'Almeida Revista e Corrigida (ARC)',
      'NVT': 'Nova Versão Transformadora (NVT)',
      'NAA': 'Nova Almeida Atualizada (NAA)',
      'NBV': 'Nova Bíblia Viva (NBV)',
      'NTLH': 'Nova Tradução na Linguagem de Hoje (NTLH)',
      'AS21': 'Almeida Século 21 (AS21)',
      'JFAA': 'João Ferreira de Almeida Atualizada (JFAA)',
      'TB': 'Tradução Brasileira 1917 (TB)',
      'KJA': 'King James Atualizada (KJA)',
      'KJF': 'King James Fiel 2000 (KJF)',
      'LTT2009': 'Bíblia Literal (Anotada)',
    };

    final versionName = versionNames[selectedVersion] ?? selectedVersion;
    final bookName = lastRead?.book.name ?? 'Gênesis';
    final chapter = lastRead?.chapter ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Continue Lendo'),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            if (lastRead != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReadingScreen(
                    book: lastRead.book,
                    initialChapter: lastRead.chapter,
                  ),
                ),
              );
            } else {
              ref.read(navigationProvider.notifier).setIndex(1); // Vai para Bíblia
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$bookName $chapter',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        versionName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 13,
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
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainTools() {
    final storeState = ref.watch(downloadedStorePackagesProvider);
        final localVersions = BibleService.availableVersions.where((v) {
          return storeState.isDownloaded('$v.sqlite') || 
                 storeState.isDownloaded('$v.mybible') || 
                 storeState.isDownloaded('$v.bbl.mybible') || 
                 storeState.isDownloaded('$v.db') ||
                 v == 'NVI' || v == 'ACF' || v == 'ARA_S';
        }).toList();

    final downloadedBibles = storeState.availablePackages
        .where((p) => p.category == StoreCategory.bibles && storeState.isDownloaded(p.filename));
    
    for (var bible in downloadedBibles) {
      String key = bible.filename.split('/').last;
      if (key.contains('ARA+STRONG - ATUALIZADA + STRONG')) continue; // Skip duplicate of ARA_S

      if (key.toLowerCase().endsWith('.sqlite')) {
        key = key.substring(0, key.length - 7);
      } else if (key.toLowerCase().endsWith('.bbl.mybible')) {
        key = key.substring(0, key.length - 12);
      } else if (key.toLowerCase().endsWith('.mybible')) {
        key = key.substring(0, key.length - 8);
      } else if (key.toLowerCase().endsWith('.db')) {
        key = key.substring(0, key.length - 3);
      }
      
      final existingKey = BibleService.availableVersions.firstWhere(
        (k) => k.toUpperCase() == key.toUpperCase(), 
        orElse: () => ''
      );
      
      key = existingKey.isNotEmpty ? existingKey : key.toUpperCase();

      if (!localVersions.contains(key)) {
        localVersions.add(key);
      }
    }
    
    final availableCount = localVersions.length;
    final downloadedBooks = storeState.availablePackages
        .where((p) => p.category == StoreCategory.books && storeState.isDownloaded(p.filename))
        .toList();

    final harpaPackage = storeState.availablePackages
        .where((p) =>
            p.name.toLowerCase().contains('harpa') ||
            p.filename.toLowerCase().contains('harpa'))
        .firstOrNull;

    final isHarpaDownloaded = downloadedBooks.any((b) =>
            b.name.toLowerCase().contains('harpa') ||
            b.filename.toLowerCase().contains('harpa')) ||
        (harpaPackage != null && storeState.isDownloaded(harpaPackage.filename)) ||
        storeState.isDownloaded('books/Harpa.bok.mybible') ||
        storeState.isDownloaded('Harpa.bok.mybible');

    final harpaBook = downloadedBooks
            .where((b) =>
                b.name.toLowerCase().contains('harpa') ||
                b.filename.toLowerCase().contains('harpa'))
            .firstOrNull ??
        harpaPackage ??
        const StoreItem(
          id: 'harpa_crista',
          name: 'Harpa Cristã',
          filename: 'books/Harpa.bok.mybible',
          category: StoreCategory.books,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Ferramentas Principais'),
        const SizedBox(height: 12),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            mainAxisExtent: 160, // Fixed height to prevent giant cards
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          children: [
            _buildToolCard(
              title: 'Bíblia Sagrada',
              subtitle: 'Leia e estude em $availableCount versões diferentes',
              icon: Icons.menu_book_rounded,
              colors: const [Color(0xFF4F46E5), Color(0xFF3B82F6)],
              badge: _buildBadge(
                'IA',
                Icons.auto_awesome_rounded,
                Colors.black.withValues(alpha: 0.3),
                Colors.white,
              ),
              onTap: () {
                ref.read(navigationProvider.notifier).setIndex(1); // Bíblia
              },
            ),
            _buildToolCard(
              title: 'Biblioteca de Arquivos',
              subtitle: 'Seus materiais e ebooks',
              icon: Icons.library_books_rounded,
              colors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PdfBooksScreen(),
                  ),
                );
              },
            ),
            _buildToolCard(
              title: 'Comentários',
              subtitle: 'Coment. bíblicos de grandes teólogos',
              icon: Icons.menu_open_rounded,
              colors: const [Color(0xFF065F46), Color(0xFF059669)],
              badge: _buildBadge(
                'Novo',
                null,
                Colors.black.withValues(alpha: 0.3),
                Colors.white,
              ),
              onTap: () {
                ref.read(navigationProvider.notifier).setIndex(2); // Comentários
              },
            ),
            _buildToolCard(
              title: 'Versículos Favoritos',
              subtitle: 'Seus trechos bíblicos marcados',
              icon: Icons.favorite_rounded,
              colors: const [Color(0xFFEA580C), Color(0xFFF97316)],
              badge: _buildBadge(
                'Novidade',
                null,
                Colors.black.withValues(alpha: 0.3),
                Colors.white,
              ),
              onTap: () {
                ref.read(navigationProvider.notifier).setIndex(4); // Favoritos (assumindo que vamos adicionar no MainLayout index 4)
              },
            ),
            _buildToolCard(
              title: 'Minhas Anotações',
              subtitle: 'Seus cadernos e estudos pessoais',
              icon: Icons.note_alt_rounded,
              colors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
              badge: _buildBadge(
                'Novidade',
                null,
                Colors.black.withValues(alpha: 0.3),
                Colors.white,
              ),
              onTap: () {
                ref.read(navigationProvider.notifier).setIndex(3); // Anotações
              },
            ),
            _buildToolCard(
              title: 'Comunidade',
              subtitle: 'Feed de Fé, Stories e Oração',
              icon: Icons.people_alt_rounded,
              colors: const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              badge: _buildBadge(
                'Novo',
                null,
                Colors.black.withValues(alpha: 0.3),
                Colors.white,
              ),
              onTap: () {
                ref.read(navigationProvider.notifier).setIndex(6); // Comunidade
              },
            ),
            _buildToolCard(
              title: 'Dicionário e Concordância',
              subtitle: '8.362 termos e definições',
              icon: Icons.library_books_rounded,
              colors: const [Color(0xFF059669), Color(0xFF10B981)],
              badge: _buildBadge(
                'Novo',
                null,
                Colors.black.withValues(alpha: 0.3),
                Colors.white,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                );
              },
            ),
            _buildToolCard(
              title: 'IATheos Teologia',
              subtitle: 'Inteligência Artificial Teológica',
              icon: Icons.auto_awesome_rounded,
              colors: const [Color(0xFF7C3AED), Color(0xFF9333EA)],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatAssistantScreen()),
                );
              },
            ),
            _buildToolCard(
              title: 'Plano de Estudo',
              subtitle: 'Leitura bíblica cronológica em 1 ano',
              icon: Icons.calendar_month_rounded,
              colors: const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
              badge: _buildBadge(
                'Novo',
                null,
                Colors.black.withValues(alpha: 0.3),
                Colors.white,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudyPlanWindow()),
                );
              },
            ),
            if (isHarpaDownloaded || !_isHarpaDismissed)
              _buildHarpaCard(
                context: context,
                harpaPackage: harpaPackage,
                isDownloaded: isHarpaDownloaded,
                harpaBook: harpaBook,
              ),
          ],
        ),
        if (isHarpaDownloaded)
          ...[
            const SizedBox(height: 24),
            _buildHymnOfTheDay(harpaBook, context),
          ],
      ],
    );
  }

  Widget _buildHarpaCard({
    required BuildContext context,
    required StoreItem? harpaPackage,
    required bool isDownloaded,
    required StoreItem harpaBook,
  }) {
    if (isDownloaded) {
      return _buildToolCard(
        title: 'Harpa Cristã',
        subtitle: '640 hinos e cânticos de louvor',
        icon: Icons.music_note_rounded,
        colors: const [Color(0xFFB45309), Color(0xFFF59E0B)],
        badge: _buildBadge(
          '640 Hinos',
          Icons.music_note_rounded,
          Colors.black.withValues(alpha: 0.3),
          Colors.white,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookReaderScreen(book: harpaBook),
            ),
          );
        },
      );
    }

    final downloadProgress = ref.watch(
      storeProvider.select(
        (s) => s.downloadProgress[harpaPackage?.filename ?? 'books/Harpa.bok.mybible'],
      ),
    );
    final isDownloading = downloadProgress != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (isDownloading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Baixando Harpa Cristã (${(downloadProgress * 100).toInt()}%)...',
              ),
              duration: const Duration(seconds: 1),
            ),
          );
          return;
        }

        if (harpaPackage != null && (harpaPackage.downloadUrl?.isNotEmpty ?? false)) {
          ref.read(storeProvider.notifier).downloadPackage(harpaPackage);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Iniciando download da Harpa Cristã...'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StoreScreen(initialCategory: StoreCategory.books),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF232530), Color(0xFF191B22)]
                : const [Color(0xFFF1F3F5), Color(0xFFE2E8F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.12),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Topo: Ícone monocromático à esquerda + (Badge Baixar + botão X) à direita
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.music_note_rounded,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xFF475569),
                      size: 22,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDownloading)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.kPrimaryGold.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.kPrimaryGold,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${(downloadProgress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.kPrimaryGold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.download_rounded,
                              size: 11,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Baixar',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _dismissHarpaCard,
                      child: Tooltip(
                        message: 'Ocultar da tela inicial',
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Rodapé: Título e Subtítulo / Barra de progresso
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Harpa Cristã',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.9)
                        : const Color(0xFF1E293B),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                if (isDownloading) ...[
                  Text(
                    'Baixando da loja...',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.65)
                          : const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: downloadProgress > 0 ? downloadProgress : null,
                      minHeight: 4,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.kPrimaryGold),
                    ),
                  ),
                ] else
                  Text(
                    '640 hinos · Toque para baixar',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.55)
                          : const Color(0xFF64748B),
                      fontSize: 12,
                      height: 1.2,
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

  Widget _buildHymnOfTheDay(StoreItem book, BuildContext context) {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final hymnIndex = seed % 640; 
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Hino do Dia'),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BookReaderScreen(book: book, initialHymnIndex: hymnIndex)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Icon(Icons.music_note_rounded, color: Color(0xFFFFA726))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HARPA CRISTÃ • ${hymnIndex + 1}', style: GoogleFonts.outfit(color: const Color(0xFFF07994), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('Hino de Adoração', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Um hino para sua devocional', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFA726),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Icon(Icons.chevron_right_rounded, color: Colors.black87)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildBadge(
    String text,
    IconData? icon,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 10),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    Widget? badge,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                if (badge != null) badge,
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.2,
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

  Widget _buildDevotional() {
    final devocionalAsync = ref.watch(devocionalDiarioProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Devocional do Dia'),
        const SizedBox(height: 12),
        devocionalAsync.when(
          data: (devocional) {
            if (devocional == null) {
              return Center(
                child: Text(
                  'Não foi possível carregar o devocional de hoje.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              );
            }
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'REFLEXÃO ESPIRITUAL',
                              style: TextStyle(
                                color: _secondaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              devocional.title,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.wb_sunny_rounded,
                            color: _secondaryColor,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: const Border(
                        left: BorderSide(color: _primaryContainer, width: 4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          devocional.verse,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '— ${devocional.verseReference}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    devocional.content.length > 200
                        ? '${devocional.content.substring(0, 200)}...'
                        : devocional.content,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DevocionalScreen(devocional: devocional),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ler devocional completo',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: _secondaryColor),
            ),
          ),
          error: (error, stack) => const Center(
            child: Text(
              'Erro ao carregar devocional.',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }
}
