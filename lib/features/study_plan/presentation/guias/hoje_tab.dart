import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import '../../application/study_plan_providers.dart';
import '../../data/plan_repository.dart';
import '../../domain/domain.dart';
import '../study_plan_reader_screen.dart';

class HojeTab extends ConsumerWidget {
  final VoidCallback? onOpenReader;

  const HojeTab({super.key, this.onOpenReader});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePlanIds = ref.watch(activePlanIdsProvider);
    final currentPlanId = ref.watch(currentPlanIdProvider);
    final todayInfo = ref.watch(todayPlanDayProvider);
    final progress = ref.watch(studyPlanProgressProvider);
    final planIndexAsync = ref.watch(currentPlanIndexProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return planIndexAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Erro ao carregar o plano: $err',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.read(currentPlanIdProvider.notifier).selectPlan('cronologico-52'),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Carregar Plano Padrão'),
              ),
            ],
          ),
        ),
      ),
      data: (planIndex) {
        final planDay = planIndex.dayAt(todayInfo.day);
        final isCompleted = todayInfo.isCompleted;
        final hasTodayNote = progress.hasNote(todayInfo.day);
        final todayNote = progress.getNote(todayInfo.day);

        final planSwitcher = _buildPlanSwitcher(
          context,
          ref,
          activePlanIds,
          currentPlanId,
          isDark,
        );

        final mainCard = _buildTodayMainCard(
          context: context,
          ref: ref,
          planDay: planDay,
          todayInfo: todayInfo,
          progress: progress,
          planIndex: planIndex,
          isCompleted: isCompleted,
          isTablet: isTablet,
          currentPlanId: currentPlanId,
          activePlanIds: activePlanIds,
        );

        final notesCard = _buildNotesCard(
          context: context,
          ref: ref,
          todayInfo: todayInfo,
          planDay: planDay,
          hasTodayNote: hasTodayNote,
          todayNote: todayNote,
        );

        final quickStatsCard = _buildQuickStatsCard(
          context: context,
          progress: progress,
          planIndex: planIndex,
        );

        final tipCard = _buildTipCard(context);

        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: isTablet ? 32.0 : 16.0,
            right: isTablet ? 32.0 : 16.0,
            top: 20.0,
            bottom: isTablet ? 32.0 : 120.0, // Espaço para a CustomBottomNav flutuante apenas no mobile
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              planSwitcher,
              if (isTablet)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Coluna Esquerda: Leitura Principal do Dia
                    Expanded(
                      flex: 6,
                      child: mainCard,
                    ),
                    const SizedBox(width: 24),
                    // Coluna Direita: Anotações, Progresso e Dica
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          notesCard,
                          const SizedBox(height: 16),
                          quickStatsCard,
                          const SizedBox(height: 16),
                          tipCard,
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    mainCard,
                    const SizedBox(height: 16),
                    notesCard,
                    const SizedBox(height: 16),
                    quickStatsCard,
                    const SizedBox(height: 16),
                    tipCard,
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  // ── SELETOR DE PLANOS ATIVOS (CHIPS HORIZONTAIS) ─────────────────────────
  Widget _buildPlanSwitcher(
    BuildContext context,
    WidgetRef ref,
    List<String> activePlanIds,
    String currentPlanId,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            ...activePlanIds.map((id) {
              final isSelected = id == currentPlanId;
              final info = PlanRepository.getPlanInfo(id);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  showCheckmark: false,
                  avatar: Icon(
                    info.icon,
                    size: 15,
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706)),
                  ),
                  label: Text(
                    info.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? (isDark ? Colors.black : Colors.white)
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  selectedColor:
                      isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
                  side: BorderSide(
                    color: isSelected
                        ? Colors.transparent
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.12),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  onSelected: (_) {
                    ref.read(currentPlanIdProvider.notifier).selectPlan(id);
                  },
                ),
              );
            }),
            if (activePlanIds.length < 5)
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  '+ Adicionar (${activePlanIds.length}/5)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                side: BorderSide(
                  color: isDark
                      ? AppTheme.kPrimaryGold.withValues(alpha: 0.4)
                      : const Color(0xFFD97706).withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                onPressed: () =>
                    _showAddPlanCatalogDialog(context, ref, activePlanIds),
              ),
          ],
        ),
      ),
    );
  }

  // ── DIÁLOGO DE CONFIRMAÇÃO PARA EXCLUIR PLANO ─────────────────────────────
  Future<void> _confirmDeletePlan(
    BuildContext context,
    WidgetRef ref,
    String planId,
    String planTitle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Excluir Plano?'),
          ],
        ),
        content: Text(
          'Tem certeza que deseja excluir o plano "$planTitle"? O progresso e anotações deste plano serão apagados.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Excluir Plano'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final current = ref.read(currentPlanIdProvider);
      await ref.read(activePlanIdsProvider.notifier).removePlan(
            planId,
            currentSelectedPlanId: current,
            onSwitchPlan: (next) =>
                ref.read(currentPlanIdProvider.notifier).selectPlan(next),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plano "$planTitle" removido com sucesso.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // ── MODAL: CATÁLOGO DE PLANOS (ATÉ 5) ──────────────────────────────────────
  void _showAddPlanCatalogDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> activePlanIds,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adicionar Plano de Leitura',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Acompanhe até 5 planos simultaneamente (${activePlanIds.length}/5 ativos)',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: PlanRepository.catalog.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final item = PlanRepository.catalog[index];
                    final isAlreadyActive = activePlanIds.contains(item.id);
                    final canAdd = !isAlreadyActive && activePlanIds.length < 5;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isAlreadyActive
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : Theme.of(ctx)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(item.icon,
                                    color: AppTheme.kPrimaryGold, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${item.totalWeeks} Semanas • ${item.totalDays} Dias',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppTheme.kPrimaryGold
                                            : const Color(0xFFD97706),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.description,
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.tag,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isAlreadyActive)
                                const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        color: Color(0xFF10B981), size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Já Ativo',
                                      style: TextStyle(
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                FilledButton.icon(
                                  onPressed: canAdd
                                      ? () async {
                                          final ok = await ref
                                              .read(activePlanIdsProvider.notifier)
                                              .addPlan(item.id);
                                          if (ok) {
                                            await ref
                                                .read(currentPlanIdProvider.notifier)
                                                .selectPlan(item.id);
                                            if (ctx.mounted) {
                                              Navigator.pop(ctx);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Plano "${item.title}" iniciado com sucesso!'),
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      : null,
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: Text(activePlanIds.length >= 5
                                      ? 'Limite (5/5)'
                                      : 'Adicionar Plano'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isDark
                                        ? AppTheme.kPrimaryGold
                                        : const Color(0xFFD97706),
                                    foregroundColor:
                                        isDark ? Colors.black : Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodayMainCard({
    required BuildContext context,
    required WidgetRef ref,
    required PlanDay planDay,
    required TodayPlanInfo todayInfo,
    required PlanProgress progress,
    required PlanIndex planIndex,
    required bool isCompleted,
    required bool isTablet,
    required String currentPlanId,
    required List<String> activePlanIds,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).colorScheme.surfaceContainer;
    final cardBorder = isCompleted
        ? const Color(0xFF10B981)
        : (isDark
            ? AppTheme.kPrimaryGold.withValues(alpha: 0.35)
            : const Color(0xFFD97706).withValues(alpha: 0.3));
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = textColor.withValues(alpha: 0.65);
    final badgeBg = isDark
        ? AppTheme.kPrimaryGold.withValues(alpha: 0.15)
        : const Color(0xFFFEF3C7);
    final badgeBorder = isDark
        ? AppTheme.kPrimaryGold.withValues(alpha: 0.4)
        : const Color(0xFFFDE68A);
    final badgeText = isDark ? AppTheme.kPrimaryGold : const Color(0xFFB45309);
    final passageCardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final passageCardBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);

    return Container(
      padding: EdgeInsets.all(isTablet ? 26.0 : 20.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: cardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha Superior: Semana / Dia, Status de Início, Streak e Botão Excluir
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: badgeBorder,
                      ),
                    ),
                    child: Text(
                      'SEMANA ${todayInfo.week} • DIA ${todayInfo.dayOfWeek}',
                      style: GoogleFonts.plusJakartaSans(
                        color: badgeText,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: progress.isStarted
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: progress.isStarted
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      progress.isStarted ? 'Iniciado' : 'Não Iniciado',
                      style: GoogleFonts.plusJakartaSans(
                        color: progress.isStarted
                            ? const Color(0xFF10B981)
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFF97316),
                    size: 19,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${progress.streak} dias',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFFF97316),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Excluir este plano',
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 20, color: Colors.redAccent),
                    onPressed: () => _confirmDeletePlan(
                        context, ref, currentPlanId, planIndex.plan.title),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Título do dia
          Text(
            'Leitura de Hoje',
            style: GoogleFonts.plusJakartaSans(
              color: subtitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            planDay.formattedSummary,
            style: GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: isTablet ? 26 : 22,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Dia ${todayInfo.day} de ${planIndex.totalDays} • ${planIndex.plan.title}',
            style: GoogleFonts.manrope(
              color: subtitleColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),

          // Passagens do dia em lista de cards interativos
          ...planDay.passages.map((passage) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  ref.read(studyPlanProgressProvider.notifier).startPlan();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudyPlanReaderScreen(
                        planDay: planDay,
                        globalDayNumber: todayInfo.day,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: passageCardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: passageCardBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
                        size: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          passage.formattedReference,
                          style: GoogleFonts.manrope(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'Ler',
                        style: GoogleFonts.plusJakartaSans(
                          color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
                        size: 13,
                      ),
                      if (isCompleted) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF10B981),
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 20),

          // Botão Iniciar Leitura do Dia com Strong
          ElevatedButton.icon(
            onPressed: () {
              ref.read(studyPlanProgressProvider.notifier).startPlan();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudyPlanReaderScreen(
                    planDay: planDay,
                    globalDayNumber: todayInfo.day,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.auto_stories_rounded, size: 20),
            label: Text(
              progress.isStarted
                  ? 'Continuar Leitura com Strong'
                  : 'Iniciar Leitura com Strong',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.kPrimaryGold : const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF111223),
              minimumSize: Size.fromHeight(isTablet ? 54 : 50),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Botão Marcar como Lido / Concluído
          Consumer(
            builder: (context, ref, _) {
              return OutlinedButton.icon(
                onPressed: () {
                  ref
                      .read(studyPlanProgressProvider.notifier)
                      .toggleDay(todayInfo.day);
                },
                icon: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isCompleted
                      ? const Color(0xFF10B981)
                      : (isDark ? Colors.white70 : textColor.withValues(alpha: 0.6)),
                ),
                label: Text(
                  isCompleted ? 'Concluído Hoje ✓' : 'Marcar como Concluído',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.white : textColor),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.25)
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                  ),
                  minimumSize: Size.fromHeight(isTablet ? 48 : 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard({
    required BuildContext context,
    required WidgetRef ref,
    required TodayPlanInfo todayInfo,
    required PlanDay planDay,
    required bool hasTodayNote,
    required String? todayNote,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasTodayNote
              ? AppTheme.kPrimaryGold.withValues(alpha: 0.4)
              : Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      color: AppTheme.kPrimaryGold,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Minha Reflexão de Hoje',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showNotesBottomSheet(
                  context,
                  ref,
                  todayInfo.day,
                  planDay.formattedSummary,
                ),
                icon: Icon(
                  hasTodayNote ? Icons.edit_rounded : Icons.add_rounded,
                  size: 16,
                  color: AppTheme.kPrimaryGold,
                ),
                label: Text(
                  hasTodayNote ? 'Editar' : 'Anotar',
                  style: const TextStyle(
                    color: AppTheme.kPrimaryGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasTodayNote && todayNote != null)
            Text(
              todayNote,
              style: GoogleFonts.manrope(
                fontSize: 14,
                height: 1.45,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.85),
              ),
            )
          else
            Text(
              'Escreva suas reflexões, orações e o que Deus ministrou ao seu coração durante a leitura de hoje.',
              style: GoogleFonts.manrope(
                fontSize: 12,
                height: 1.4,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard({
    required BuildContext context,
    required PlanProgress progress,
    required PlanIndex planIndex,
  }) {
    final completedCount = progress.completedDays.length;
    final totalDays = planIndex.totalDays;
    final percent = (progress.getPercentage(totalDays) * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.insights_rounded,
                      color: AppTheme.kPrimaryGold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Seu Progresso no Plano',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.kPrimaryGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.getPercentage(totalDays),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.kPrimaryGold),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '$completedCount de $totalDays lidos',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFF97316),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${progress.streak} dias seguidos',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF97316),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: Color(0xFF60A5FA),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dica de Estudo',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'A leitura cronológica segue a linha do tempo dos eventos históricos e proféticos da Bíblia.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNotesBottomSheet(
    BuildContext context,
    WidgetRef ref,
    int dayNumber,
    String summary,
  ) {
    final progress = ref.read(studyPlanProgressProvider);
    final initialNote = progress.getNote(dayNumber) ?? '';
    final controller = TextEditingController(text: initialNote);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded,
                            color: AppTheme.kPrimaryGold, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Reflexão • Dia $dayNumber',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                Text(
                  summary,
                  style: GoogleFonts.manrope(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Escreva suas reflexões, orações e lições aprendidas...',
                      hintStyle: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppTheme.kPrimaryGold.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppTheme.kPrimaryGold,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final text = controller.text;
                    await ref
                        .read(studyPlanProgressProvider.notifier)
                        .saveNote(dayNumber, text);
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            text.trim().isEmpty
                                ? 'Reflexão removida.'
                                : 'Reflexão salva com sucesso!',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Salvar Reflexão'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.kPrimaryGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
