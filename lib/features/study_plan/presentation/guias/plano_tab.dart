import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import '../../application/study_plan_providers.dart';
import '../../domain/domain.dart';
import '../study_plan_reader_screen.dart';

class PlanoTab extends ConsumerWidget {
  const PlanoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(chronologicalPlanProvider);
    final progress = ref.watch(studyPlanProgressProvider);
    final todayInfo = ref.watch(todayPlanDayProvider);
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return planAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
      data: (plan) {
        return ListView.builder(
          padding: EdgeInsets.only(
            left: isTablet ? 32.0 : 16.0,
            right: isTablet ? 32.0 : 16.0,
            top: 16.0,
            bottom: 120.0, // Espaço para a CustomBottomNav flutuante
          ),
          itemCount: plan.weeks.length,
          itemBuilder: (context, index) {
            final week = plan.weeks[index];
            final weekNum = week.week;
            final completedCount =
                PlanIndex.completedDaysInWeek(weekNum, progress.completedDays);
            final weekRatio = completedCount / 7.0;
            final isWeekFullyCompleted = completedCount == 7;
            final isCurrentWeek = todayInfo.week == weekNum;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrentWeek
                      ? AppTheme.kPrimaryGold.withValues(alpha: 0.6)
                      : isWeekFullyCompleted
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.08),
                  width: isCurrentWeek ? 1.5 : 1.0,
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  initiallyExpanded: isCurrentWeek,
                  tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  childrenPadding: const EdgeInsets.only(
                      bottom: 12, left: 16, right: 16),
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isWeekFullyCompleted
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : isCurrentWeek
                              ? AppTheme.kPrimaryGold.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$weekNum',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isWeekFullyCompleted
                            ? const Color(0xFF10B981)
                            : isCurrentWeek
                                ? AppTheme.kPrimaryGold
                                : Theme.of(context).colorScheme.onSurface,
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.kPrimaryGold,
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            Text(
                              '${(weekRatio * 100).toInt()}%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isWeekFullyCompleted
                                    ? const Color(0xFF10B981)
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
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
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isWeekFullyCompleted
                                  ? const Color(0xFF10B981)
                                  : AppTheme.kPrimaryGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useGrid = constraints.maxWidth >= 600;
                        final itemWidth = useGrid
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: week.days.asMap().entries.map((entry) {
                            final dayIndexInWeek = entry.key + 1; // 1..7
                            final planDay = entry.value;
                            final globalDayNumber =
                                (weekNum - 1) * 7 + dayIndexInWeek;
                            final isDayCompleted = progress.completedDays
                                .contains(globalDayNumber);
                            final isToday = todayInfo.day == globalDayNumber;

                            return SizedBox(
                              width: itemWidth,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? AppTheme.kPrimaryGold
                                          .withValues(alpha: 0.08)
                                      : Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(10),
                                  border: isToday
                                      ? Border.all(
                                          color: AppTheme.kPrimaryGold
                                              .withValues(alpha: 0.4),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    // Checkbox redondo
                                    InkWell(
                                      onTap: () {
                                        ref
                                            .read(studyPlanProgressProvider
                                                .notifier)
                                            .toggleDay(globalDayNumber);
                                      },
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Icon(
                                          isDayCompleted
                                              ? Icons.check_circle_rounded
                                              : Icons
                                                  .radio_button_unchecked_rounded,
                                          color: isDayCompleted
                                              ? const Color(0xFF10B981)
                                              : Colors.white
                                                  .withValues(alpha: 0.4),
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  StudyPlanReaderScreen(
                                                planDay: planDay,
                                                globalDayNumber:
                                                    globalDayNumber,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4.0),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          'Dia $dayIndexInWeek',
                                                          style: GoogleFonts
                                                              .plusJakartaSans(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: isToday
                                                                ? AppTheme
                                                                    .kPrimaryGold
                                                                : Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withValues(
                                                                        alpha:
                                                                            0.6),
                                                          ),
                                                        ),
                                                        if (isToday) ...[
                                                          const SizedBox(
                                                              width: 6),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 4,
                                                              vertical: 1,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: AppTheme
                                                                  .kPrimaryGold
                                                                  .withValues(
                                                                      alpha:
                                                                          0.2),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                            ),
                                                            child: Text(
                                                              'HOJE',
                                                              style: GoogleFonts
                                                                  .manrope(
                                                                fontSize: 8,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: AppTheme
                                                                    .kPrimaryGold,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      planDay.formattedSummary,
                                                      style:
                                                          GoogleFonts.manrope(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isDayCompleted
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                    alpha: 0.5)
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .onSurface,
                                                        decoration:
                                                            isDayCompleted
                                                                ? TextDecoration
                                                                    .lineThrough
                                                                : null,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.menu_book_rounded,
                                                size: 16,
                                                color: isToday
                                                    ? AppTheme.kPrimaryGold
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                            alpha: 0.35),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.chevron_right_rounded,
                                                size: 18,
                                                color: isToday
                                                    ? AppTheme.kPrimaryGold
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                            alpha: 0.35),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
