import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: MBibliaTopBar(
        title: 'KeryxApp',
        showLogo: true,
        showBackButton: false,
        isScrolled: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.kPrimaryGold,
          labelColor: AppTheme.kPrimaryGold,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: GoogleFonts.manrope(
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Hoje', icon: Icon(Icons.today_rounded, size: 20)),
            Tab(text: 'Plano', icon: Icon(Icons.view_agenda_rounded, size: 20)),
            Tab(text: 'Progresso', icon: Icon(Icons.insights_rounded, size: 20)),
            Tab(text: 'Planos', icon: Icon(Icons.auto_stories_rounded, size: 20)),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: const [
              HojeTab(),
              PlanoTab(),
              ProgressoTab(),
              GuiasTab(),
            ],
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
  }
}
