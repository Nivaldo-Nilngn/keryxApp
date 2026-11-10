import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/widgets/instagram_tablet_sidebar.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import '../application/study_plan_providers.dart';
import '../data/plan_repository.dart';
import 'guias/hoje_tab.dart';
import 'guias/plano_tab.dart';
import 'guias/progresso_tab.dart';
import 'guias/guias_tab.dart';

class StudyPlanWindow extends ConsumerStatefulWidget {
  const StudyPlanWindow({super.key});

  @override
  ConsumerState<StudyPlanWindow> createState() => _StudyPlanWindowState();
}

class _StudyPlanWindowState extends ConsumerState<StudyPlanWindow>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showPlanSelectorModal(
    BuildContext context,
    List<String> activePlanIds,
    String currentPlanId,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goldColor = isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706);

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: goldColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.auto_stories_rounded, color: goldColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Selecionar Plano Ativo',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${activePlanIds.length} de 5 planos em andamento',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: activePlanIds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final planId = activePlanIds[i];
                      final info = PlanRepository.getPlanInfo(planId);
                      final isSelected = planId == currentPlanId;

                      return Material(
                        color: isSelected
                            ? goldColor.withValues(alpha: 0.12)
                            : theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isSelected
                                ? goldColor
                                : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            ref.read(currentPlanIdProvider.notifier).selectPlan(planId);
                            Navigator.pop(dialogCtx);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  info.icon,
                                  color: isSelected ? goldColor : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        info.title,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 14,
                                          color: isSelected ? goldColor : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        '${info.totalDays} dias • ${info.tag}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, color: goldColor, size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: goldColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _tabController.animateTo(3); // Aba de Estudos & Catálogo
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    'Ver Catálogo de Planos & Estudos',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── CABEÇALHO EXECUTIVO DESKTOP / WEB (FIXO, ELEGANTE E UNIFICADO) ────────
  Widget _buildDesktopHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentPlanId = ref.watch(currentPlanIdProvider);
    final activePlanIds = ref.watch(activePlanIdsProvider);
    final planInfo = PlanRepository.getPlanInfo(currentPlanId);
    final progress = ref.watch(studyPlanProgressProvider);
    final planIndexAsync = ref.watch(currentPlanIndexProvider);
    final totalDays = planIndexAsync.valueOrNull?.totalDays ?? planInfo.totalDays;
    final percent = (progress.getPercentage(totalDays) * 100).toInt();
    final goldColor = isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth < 800 ? 16 : 28,
            12,
            constraints.maxWidth < 800 ? 16 : 28,
            0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Linha Superior Unificada e Elegante (Sem redundâncias de título)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Seletor Interativo do Plano Ativo (O título É o seletor)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showPlanSelectorModal(context, activePlanIds, currentPlanId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: goldColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: goldColor.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(planInfo.icon, size: 18, color: goldColor),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth < 700 ? 170 : 320,
                                ),
                                child: Text(
                                  planInfo.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: goldColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botão sutil para explorar catálogo / novos planos
                      IconButton(
                        tooltip: 'Catálogo de Planos & Estudos',
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _tabController.animateTo(3),
                        icon: const Icon(Icons.add_rounded, size: 18),
                      ),
                      const Spacer(),
                      // Métricas discretas e elegantes
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, color: Color(0xFFF97316), size: 15),
                            const SizedBox(width: 4),
                            Text(
                              '${progress.streak} dias',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFF97316),
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.insights_rounded, color: Color(0xFF10B981), size: 15),
                            const SizedBox(width: 4),
                            Text(
                              '$percent%',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Linha 2: Abas de Navegação Estilo Desktop (Scrollable & Start aligned)
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 3.0,
                    indicatorColor: goldColor,
                    labelColor: goldColor,
                    unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                    height: 42,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.today_rounded, size: 17),
                        SizedBox(width: 8),
                        Text('Hoje'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 42,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.view_week_rounded, size: 17),
                        SizedBox(width: 8),
                        Text('Plano Completo'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 42,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insights_rounded, size: 17),
                        SizedBox(width: 8),
                        Text('Progresso & Métricas'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 42,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_rounded, size: 17),
                        SizedBox(width: 8),
                        Text('Estudos & Guias'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  // ── CARD HERO COMPACTO PARA MOBILE ────────────────────────────────────────
  Widget _buildMobileHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goldColor = isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141722) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? goldColor.withValues(alpha: 0.25) : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: goldColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_stories_rounded, color: goldColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plano de Estudo Bíblico',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Leitura diária em 1 ano com Strong e reflexões.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ABAS EM PÍLULA PARA MOBILE ────────────────────────────────────────────
  Widget _buildModeledTabBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706);

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        indicator: BoxDecoration(
          color: goldColor,
          borderRadius: BorderRadius.circular(18),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Icon(Icons.today_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('Hoje'),
                ],
              ),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Icon(Icons.view_agenda_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('Plano'),
                ],
              ),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Icon(Icons.insights_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('Progresso'),
                ],
              ),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('Estudos'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 720;

    final Widget tabViews = TabBarView(
      controller: _tabController,
      children: const [
        HojeTab(),
        PlanoTab(),
        ProgressoTab(),
        GuiasTab(),
      ],
    );

    // No Web/Tablet: Header fixo no topo, conteúdo fluido com rolagem independente
    if (isTablet) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: InstagramTabletSidebar(
          currentIndex: 7, // Plano de Estudo
          isRoute: true,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDesktopHeader(context),
              Expanded(
                child: ListenableBuilder(
                  listenable: _tabController,
                  builder: (context, _) {
                    switch (_tabController.index) {
                      case 0:
                        return const HojeTab();
                      case 1:
                        return const PlanoTab();
                      case 2:
                        return const ProgressoTab();
                      case 3:
                      default:
                        return const GuiasTab();
                    }
                  },
                ),
              ),
            ],
          ),
          onSelectIndex: (index) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            ref.read(navigationProvider.notifier).setIndex(index);
          },
        ),
      );
    }

    // No Mobile: Mantém comportamento com AppBar, NestedScrollView e BottomNav
    final Widget mobileContent = SafeArea(
      top: false,
      bottom: false,
      child: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 10.0),
                    child: _buildMobileHeroCard(context),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    height: 56.0,
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
                      child: _buildModeledTabBar(context),
                    ),
                  ),
                ),
              ];
            },
            body: tabViews,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: CustomBottomNav(
              currentIndex: -1,
              onTap: (index) {
                ref.read(navigationProvider.notifier).setIndex(index);
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              onBack: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const MBibliaTopBar(
        title: 'KeryxApp',
        showBackButton: false,
      ),
      body: mobileContent,
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SliverTabBarDelegate({
    required this.child,
    required this.height,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: height,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
