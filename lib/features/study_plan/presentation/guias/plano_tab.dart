import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import '../../application/study_plan_providers.dart';
import '../../domain/domain.dart';
import '../study_plan_reader_screen.dart';
import '../widgets/study_plan_celebration.dart';

class PlanoTab extends ConsumerStatefulWidget {
  const PlanoTab({super.key});

  @override
  ConsumerState<PlanoTab> createState() => _PlanoTabState();
}

class _PlanoTabState extends ConsumerState<PlanoTab> {
  String _filter = 'all'; // 'all', 'pending', 'completed'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _searchQuery = val.trim();
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(chronologicalPlanProvider);
    final progress = ref.watch(studyPlanProgressProvider);
    final todayInfo = ref.watch(todayPlanDayProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 768;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goldColor = isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706);

    return planAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
      data: (plan) {
        // Estatísticas gerais
        int completedWeeksCount = 0;
        for (final week in plan.weeks) {
          final daysInWeek = week.days.isNotEmpty ? week.days.length : 7;
          final done = week.days.where((d) => progress.completedDays.contains(d.day)).length;
          if (done == daysInWeek) {
            completedWeeksCount++;
          }
        }
        final pendingWeeksCount = plan.weeks.length - completedWeeksCount;

        // Filtragem e busca
        final filteredWeeks = plan.weeks.where((week) {
          final daysInWeek = week.days.isNotEmpty ? week.days.length : 7;
          final done = week.days.where((d) => progress.completedDays.contains(d.day)).length;
          final isWeekCompleted = done == daysInWeek;

          if (_filter == 'pending' && isWeekCompleted) return false;
          if (_filter == 'completed' && !isWeekCompleted) return false;

          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matchesWeek = 'semana ${week.week}'.contains(q) || '${week.week}'.contains(q);
            final matchesDays = week.days.any((d) => d.formattedSummary.toLowerCase().contains(q));
            if (!matchesWeek && !matchesDays) return false;
          }

          return true;
        }).toList();

        // Barra de Ferramentas / Filtros
        final toolbar = Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // Campo de busca
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Buscar livro (ex: Gênesis, Salmos) ou semana...',
                          hintStyle: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: goldColor),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _debounceTimer?.cancel();
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: goldColor, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isTablet) ...[
                    const SizedBox(width: 12),
                    // Botão Ir para Semana Atual
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: goldColor,
                        side: BorderSide(color: goldColor.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        setState(() {
                          _filter = 'all';
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      icon: const Icon(Icons.my_location_rounded, size: 16),
                      label: Text(
                        'Semana Atual (${todayInfo.week})',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Filtros rápidos
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFilterChip('all', 'Todas (${plan.weeks.length})', goldColor),
                      const SizedBox(width: 8),
                      _buildFilterChip('pending', 'Pendentes ($pendingWeeksCount)', goldColor),
                      const SizedBox(width: 8),
                      _buildFilterChip('completed', 'Concluídas ($completedWeeksCount)', goldColor),
                    ],
                  ),
                  if (isTablet)
                    Text(
                      '$completedWeeksCount de ${plan.weeks.length} semanas concluídas (${((completedWeeksCount / plan.weeks.length) * 100).toInt()}%)',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );

        final horizontalPadding = isTablet ? 24.0 : 16.0;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    isTablet ? 20.0 : 16.0,
                    horizontalPadding,
                    14.0,
                  ),
                  sliver: SliverToBoxAdapter(child: toolbar),
                ),
                if (filteredWeeks.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: goldColor.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma semana encontrada',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tente buscar outro termo ou redefinir os filtros.',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: horizontalPadding,
                      right: horizontalPadding,
                      bottom: isTablet ? 36.0 : 155.0,
                    ),
                    sliver: SliverList.builder(
                      itemCount: filteredWeeks.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildWeekCard(
                            context,
                            filteredWeeks[index],
                            plan,
                            progress,
                            todayInfo,
                            isTablet,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String key, String label, Color goldColor) {
    final isSelected = _filter == key;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _filter = key;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? goldColor : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? goldColor : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.black : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekCard(
    BuildContext context,
    PlanWeek week,
    StudyPlan plan,
    PlanProgress progress,
    TodayPlanInfo todayInfo,
    bool isTablet,
  ) {
    final weekNum = week.week;
    final daysInWeek = week.days.isNotEmpty ? week.days.length : 7;
    final completedCount = week.days.where((d) => progress.completedDays.contains(d.day)).length;
    final weekRatio = daysInWeek > 0 ? completedCount / daysInWeek : 0.0;
    final isWeekFullyCompleted = completedCount == daysInWeek;
    final isCurrentWeek = todayInfo.week == weekNum;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goldColor = isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCurrentWeek
              ? goldColor.withValues(alpha: 0.6)
              : isWeekFullyCompleted
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: isCurrentWeek ? 1.5 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('week_${week.week}'),
          initiallyExpanded: isCurrentWeek,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
            leading: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isWeekFullyCompleted
                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                    : isCurrentWeek
                        ? goldColor.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isWeekFullyCompleted
                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                      : isCurrentWeek
                          ? goldColor.withValues(alpha: 0.3)
                          : Colors.transparent,
                ),
              ),
              child: isWeekFullyCompleted
                  ? const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 20)
                  : Text(
                      '$weekNum',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isCurrentWeek ? goldColor : theme.colorScheme.onSurface,
                      ),
                    ),
            ),
            title: Row(
              children: [
                Text(
                  'Semana $weekNum',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (isCurrentWeek) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: goldColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ATUAL',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
                if (isWeekFullyCompleted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'CONCLUÍDO',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$completedCount de 7 dias lidos',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        '${(weekRatio * 100).toInt()}%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isWeekFullyCompleted
                              ? const Color(0xFF10B981)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: weekRatio,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isWeekFullyCompleted ? const Color(0xFF10B981) : goldColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            children: [
              const SizedBox(height: 6),
              ...week.days.asMap().entries.map((entry) {
                final dayIndexInWeek = entry.key + 1; // 1..7
                final planDay = entry.value;
                final globalDayNumber = planDay.day;
                final isDayCompleted = progress.completedDays.contains(globalDayNumber);
                final isToday = todayInfo.day == globalDayNumber;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isToday
                        ? goldColor.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: isToday ? Border.all(color: goldColor.withValues(alpha: 0.35)) : null,
                  ),
                  child: Row(
                    children: [
                      // Checkbox redondo
                      InkWell(
                        onTap: () {
                          final nextDay = globalDayNumber < plan.totalDays ? globalDayNumber + 1 : null;
                          ref.read(studyPlanProgressProvider.notifier).toggleDay(
                                globalDayNumber,
                                totalDays: plan.totalDays,
                              );
                          showStudyPlanCelebrationSnackbar(
                            context: context,
                            dayNumber: globalDayNumber,
                            wasCompleted: isDayCompleted,
                            nextDay: nextDay,
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            isDayCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isDayCompleted ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.35),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            ref.read(studyPlanProgressProvider.notifier).setCurrentDay(globalDayNumber);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudyPlanReaderScreen(
                                  planDay: planDay,
                                  globalDayNumber: globalDayNumber,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Dia $dayIndexInWeek',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: isToday
                                                  ? goldColor
                                                  : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                            ),
                                          ),
                                          if (isToday) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: goldColor.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'HOJE',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: goldColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        planDay.formattedSummary,
                                        style: GoogleFonts.manrope(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDayCompleted
                                              ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                                              : theme.colorScheme.onSurface,
                                          decoration: isDayCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 15,
                                  color: isToday ? goldColor : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: isToday ? goldColor : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
  }
}
