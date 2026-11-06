import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/widgets/instagram_tablet_sidebar.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
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

  Widget _buildStudyHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
              : [const Color(0xFF4F46E5), const Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -20,
            child: Icon(
              Icons.calendar_month_rounded,
              color: Colors.white.withValues(alpha: 0.15),
              size: 110,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'ESTUDOS & DEVOCIONAL',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Plano de Estudo Bíblico',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Leitura bíblica cronológica em 1 ano, acompanhamento diário, progresso e reflexões.',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeledTabBar(BuildContext context) {
    return Container(
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
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        indicator: BoxDecoration(
          color: AppTheme.kPrimaryGold,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.kPrimaryGold.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.black,
        unselectedLabelColor:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.outfit(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.today_rounded, size: 15),
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
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.view_agenda_rounded, size: 15),
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
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insights_rounded, size: 15),
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
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_rounded, size: 15),
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

    final Widget mainColumn = Column(
      children: [
        // ── HERO CARD COM NOME DA PÁGINA (ACIMA DAS ABAS) ───────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            isTablet ? 32.0 : 16.0,
            16.0,
            isTablet ? 32.0 : 16.0,
            12.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: _buildStudyHeroCard(context),
            ),
          ),
        ),
        // ── ABAS DE NAVEGAÇÃO MODELADAS ─────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            isTablet ? 32.0 : 16.0,
            0,
            isTablet ? 32.0 : 16.0,
            12.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: _buildModeledTabBar(context),
            ),
          ),
        ),
        Expanded(child: tabViews),
      ],
    );

    final Widget content = isTablet
        ? SafeArea(
            top: true,
            bottom: false,
            child: mainColumn,
          )
        : SafeArea(
            top: false,
            bottom: false,
            child: Stack(
              children: [
                mainColumn,
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

    final Widget innerScaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isTablet
          ? null
          : const MBibliaTopBar(
              title: 'KeryxApp',
              showBackButton: false,
            ),
      body: content,
    );

    if (isTablet) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: InstagramTabletSidebar(
          currentIndex: 7, // Plano de Estudo
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
}
