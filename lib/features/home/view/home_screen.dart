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
import 'package:keryx_app/core/theme/app_fonts.dart';
import 'package:keryx_app/core/widgets/update_banner.dart';
import 'package:keryx_app/core/services/app_update_service.dart';
import 'package:keryx_app/core/services/release_notes_service.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';


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
                      const RepaintBoundary(child: _HomeHeroBanner()),
                      const SizedBox(height: 24),
                      const RepaintBoundary(child: _HomeCarousel()),
                      const SizedBox(height: 32),
                      const RepaintBoundary(child: _HomeContinueReading()),
                      const SizedBox(height: 32),
                      RepaintBoundary(
                        child: _HomeMainTools(
                          isHarpaDismissed: _isHarpaDismissed,
                          onDismissHarpa: _dismissHarpaCard,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const RepaintBoundary(child: _HomeDevotional()),
                      const SizedBox(height: 32),
                      const _HomePrimeirosPassosBanner(),
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
}

// ============================================================================
// ISOLATED CONSUMER WIDGETS (FASE 4 - ZERO UNNECESSARY REBUILDS)
// ============================================================================

class _HomeHeroBanner extends ConsumerWidget {
  const _HomeHeroBanner();

  static String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Bom dia';
    } else if (hour >= 12 && hour < 18) {
      return 'Boa tarde';
    } else {
      return 'Boa noite';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userDataProvider.select((u) => u.value?['name'] as String?));
    final authDisplayName = ref.watch(authStateProvider.select((a) => a.value?.displayName));
    String name = userName ?? authDisplayName ?? 'Visitante';
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
}

class _HomeCarousel extends StatelessWidget {
  const _HomeCarousel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _buildCarouselCard(
            context: context,
            title: 'IATheos Chat',
            subtitle:
                'Estude a bíblia conversando com a nossa IA teológica avançada.',
            badgeText: 'Novo',
            badgeIcon: Icons.smart_toy_outlined,
            badgeColor: const Color(0xFF7C3AED),
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
            context: context,
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
            context: context,
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
    required BuildContext context,
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
      ),
    );
  }
}

class _HomeContinueReading extends ConsumerWidget {
  const _HomeContinueReading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        _buildSectionHeader(context, 'Continue Lendo'),
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
}

class _HomeMainTools extends ConsumerWidget {
  final bool isHarpaDismissed;
  final VoidCallback onDismissHarpa;

  const _HomeMainTools({
    required this.isHarpaDismissed,
    required this.onDismissHarpa,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        _buildSectionHeader(context, 'Ferramentas Principais'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth <= 0) {
              return const SizedBox.shrink();
            }
            final width = constraints.maxWidth;
            final int crossAxisCount = width >= 1000 ? 4 : (width >= 620 ? 3 : 2);
            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisExtent: 98,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              children: [
                _buildToolCard(
                  context,
                  title: 'Bíblia Sagrada',
                  subtitle: 'Leia e estude em $availableCount versões',
                  icon: Icons.menu_book_rounded,
                  colors: const [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                  badge: _buildBadge(
                    'IA',
                    Icons.auto_awesome_rounded,
                    const Color(0xFF7C3AED).withValues(alpha: 0.18),
                    const Color(0xFFA855F7),
                  ),
                  onTap: () {
                    ref.read(navigationProvider.notifier).setIndex(1); // Bíblia
                  },
                ),
                _buildToolCard(
                  context,
                  title: 'Biblioteca',
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
                  context,
                  title: 'Comentários',
                  subtitle: 'Comentários de teólogos',
                  icon: Icons.menu_open_rounded,
                  colors: const [Color(0xFF065F46), Color(0xFF059669)],
                  badge: _buildBadge(
                    'Novo',
                    null,
                    const Color(0xFF059669).withValues(alpha: 0.18),
                    const Color(0xFF10B981),
                  ),
                  onTap: () {
                    ref.read(navigationProvider.notifier).setIndex(2); // Comentários
                  },
                ),
                _buildToolCard(
                  context,
                  title: 'Favoritos',
                  subtitle: 'Seus versículos marcados',
                  icon: Icons.favorite_rounded,
                  colors: const [Color(0xFFEA580C), Color(0xFFF97316)],
                  badge: _buildBadge(
                    'Novidade',
                    null,
                    const Color(0xFFEA580C).withValues(alpha: 0.18),
                    const Color(0xFFF97316),
                  ),
                  onTap: () {
                    ref.read(navigationProvider.notifier).setIndex(4); // Favoritos
                  },
                ),
                _buildToolCard(
                  context,
                  title: 'Anotações',
                  subtitle: 'Cadernos e estudos',
                  icon: Icons.note_alt_rounded,
                  colors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                  badge: _buildBadge(
                    'Novidade',
                    null,
                    const Color(0xFFD97706).withValues(alpha: 0.18),
                    const Color(0xFFF59E0B),
                  ),
                  onTap: () {
                    ref.read(navigationProvider.notifier).setIndex(3); // Anotações
                  },
                ),
                _buildToolCard(
                  context,
                  title: 'Comunidade',
                  subtitle: 'Feed de Fé e Oração',
                  icon: Icons.people_alt_rounded,
                  colors: const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  badge: _buildBadge(
                    'Novo',
                    null,
                    const Color(0xFF4F46E5).withValues(alpha: 0.18),
                    const Color(0xFF818CF8),
                  ),
                  onTap: () {
                    ref.read(navigationProvider.notifier).setIndex(6); // Comunidade
                  },
                ),
                _buildToolCard(
                  context,
                  title: 'Dicionário',
                  subtitle: '8.362 termos bíblicos',
                  icon: Icons.auto_stories_rounded,
                  colors: const [Color(0xFF059669), Color(0xFF10B981)],
                  badge: _buildBadge(
                    'Novo',
                    null,
                    const Color(0xFF059669).withValues(alpha: 0.18),
                    const Color(0xFF10B981),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                    );
                  },
                ),
                _buildToolCard(
                  context,
                  title: 'IATheos',
                  subtitle: 'Inteligência Artificial Teológica',
                  icon: Icons.auto_awesome_rounded,
                  colors: const [Color(0xFF7C3AED), Color(0xFF9333EA)],
                  badge: _buildBadge(
                    'IA',
                    Icons.auto_awesome_rounded,
                    const Color(0xFF7C3AED).withValues(alpha: 0.18),
                    const Color(0xFFA855F7),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatAssistantScreen()),
                    );
                  },
                ),
                _buildToolCard(
                  context,
                  title: 'Plano de Estudo',
                  subtitle: 'Cronológico em 1 ano',
                  icon: Icons.calendar_month_rounded,
                  colors: const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                  badge: _buildBadge(
                    'Novo',
                    null,
                    const Color(0xFF0284C7).withValues(alpha: 0.18),
                    const Color(0xFF38BDF8),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StudyPlanWindow()),
                    );
                  },
                ),
                if (isHarpaDownloaded || !isHarpaDismissed)
                  _HomeHarpaCard(
                    harpaPackage: harpaPackage,
                    isDownloaded: isHarpaDownloaded,
                    harpaBook: harpaBook,
                    onDismiss: onDismissHarpa,
                  ),
              ],
            );
          },
        ),
        if (isHarpaDownloaded) ...[
          const SizedBox(height: 24),
          _buildHymnOfTheDay(harpaBook, context),
        ],
      ],
    );
  }

  Widget _buildHymnOfTheDay(StoreItem book, BuildContext context) {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final hymnIndex = seed % 640; 
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Hino do Dia'),
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
}

class _HomeHarpaCard extends ConsumerWidget {
  final StoreItem? harpaPackage;
  final bool isDownloaded;
  final StoreItem harpaBook;
  final VoidCallback onDismiss;

  const _HomeHarpaCard({
    required this.harpaPackage,
    required this.isDownloaded,
    required this.harpaBook,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDownloaded) {
      return _buildToolCard(
        context,
        title: 'Harpa Cristã',
        subtitle: '640 hinos de louvor',
        icon: Icons.music_note_rounded,
        colors: const [Color(0xFFB45309), Color(0xFFF59E0B)],
        badge: _buildBadge(
          '640',
          Icons.music_note_rounded,
          const Color(0xFFD97706).withValues(alpha: 0.18),
          const Color(0xFFF59E0B),
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

        if (harpaPackage != null && (harpaPackage!.downloadUrl?.isNotEmpty ?? false)) {
          ref.read(storeProvider.notifier).downloadPackage(harpaPackage!);
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1E2B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Topo direito: (Badge Baixar/Progresso + botão X)
            Positioned(
              top: 0,
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDownloading)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.kPrimaryGold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: AppTheme.kPrimaryGold,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${(downloadProgress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.kPrimaryGold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.download_rounded,
                            size: 10,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Baixar',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDismiss,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 11,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Conteúdo do card
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.music_note_rounded,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.8)
                          : const Color(0xFF475569),
                      size: 18,
                    ),
                  ),
                ),
            // Rodapé: Título e Subtítulo / Barra de progresso
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Harpa Cristã',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (isDownloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: downloadProgress > 0 ? downloadProgress : null,
                      minHeight: 3,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.kPrimaryGold),
                    ),
                  ),
                ] else
                  Text(
                    '640 hinos · Baixar',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 11,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ],
        ),
      ],
    ),
  ),
);
  }
}

class _HomeDevotional extends ConsumerWidget {
  const _HomeDevotional();

  TextStyle _getHomeTextStyle(
    String fontName, {
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
    FontStyle? fontStyle,
    double? height,
  }) {
    if (CustomFontLoader.loadedFontFamilies.contains(fontName)) {
      return TextStyle(
        fontFamily: fontName,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontStyle: fontStyle,
        height: height,
      );
    }
    try {
      return GoogleFonts.getFont(
        fontName,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontStyle: fontStyle,
        height: height,
      );
    } catch (_) {
      return TextStyle(
        fontFamily: fontName,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontStyle: fontStyle,
        height: height,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devocionalAsync = ref.watch(devocionalDiarioProvider);
    final fontSettings = ref.watch(fontSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final accentColor = fontSettings.badgeColor != null
        ? Color(fontSettings.badgeColor!)
        : (isDark ? AppTheme.kPrimaryGold : const Color(0xFF4F46E5));

    final textColor = fontSettings.textColor != null
        ? Color(fontSettings.textColor!)
        : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Devocional do Dia'),
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
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Tag de Categoria com linha sutil (Sem ícone de sol)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'REFLEXÃO ESPIRITUAL',
                          style: GoogleFonts.outfit(
                            color: accentColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2. Título do Devocional
                  Text(
                    devocional.title,
                    style: _getHomeTextStyle(
                      fontSettings.fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),

                  // 3. Citação do Versículo Base
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
                          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(
                          color: accentColor,
                          width: 3.5,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          devocional.verse.startsWith('“') || devocional.verse.startsWith('"')
                              ? devocional.verse
                              : '“${devocional.verse}”',
                          style: _getHomeTextStyle(
                            fontSettings.fontFamily,
                            fontSize: 13.5,
                            fontStyle: FontStyle.italic,
                            color: textColor,
                            height: 1.5,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '— ${devocional.verseReference}',
                            style: GoogleFonts.outfit(
                              color: accentColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Trecho da Reflexão
                  Text(
                    devocional.content.length > 200
                        ? '${devocional.content.substring(0, 200)}...'
                        : devocional.content,
                    style: _getHomeTextStyle(
                      fontSettings.fontFamily,
                      fontSize: 13.5,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),

                  // 5. Botão "Ler devocional completo"
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ler devocional completo',
                            style: GoogleFonts.outfit(
                              color: accentColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: accentColor,
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
          loading: () => Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: accentColor),
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

class _HomePrimeirosPassosBanner extends StatelessWidget {
  const _HomePrimeirosPassosBanner();

  @override
  Widget build(BuildContext context) {
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
}

Widget _buildSectionHeader(BuildContext context, String title) {
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

Widget _buildBadge(
  String text,
  IconData? icon,
  Color bgColor,
  Color textColor,
) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: textColor, size: 8.5),
          const SizedBox(width: 2),
        ],
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ],
    ),
  );
}

Widget _buildToolCard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required List<Color> colors,
  Widget? badge,
  VoidCallback? onTap,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1B1E2B)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors[0].withValues(alpha: isDark ? 0.25 : 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: isDark ? 0.12 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: badge,
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors[0].withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 10.5,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
