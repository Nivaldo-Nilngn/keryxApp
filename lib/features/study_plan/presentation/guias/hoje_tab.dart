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
                onPressed: () => ref
                    .read(currentPlanIdProvider.notifier)
                    .selectPlan('cronologico-52'),
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

        final tipCard = _buildTipCard(context, currentPlanId);

        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: isTablet ? 32.0 : 16.0,
            right: isTablet ? 32.0 : 16.0,
            top: 16.0,
            bottom: isTablet ? 32.0 : 155.0, // Espaço seguro para CustomBottomNav flutuante no mobile
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

  // ── SELETOR DE PLANOS ATIVOS (MODERNO, COMPACTO E RESPONSIVO) ─────────────
  Widget _buildPlanSwitcher(
    BuildContext context,
    WidgetRef ref,
    List<String> activePlanIds,
    String currentPlanId,
    bool isDark,
  ) {
    final info = PlanRepository.getPlanInfo(currentPlanId);
    final theme = Theme.of(context);
    final goldColor = isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Lado esquerdo: Plano Ativo com ícone, títulos e chevron de troca
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showSwitchPlanBottomSheet(
                context,
                ref,
                activePlanIds,
                currentPlanId,
                isDark,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: goldColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      info.icon,
                      size: 18,
                      color: goldColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'PLANO ATIVO',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: goldColor,
                              ),
                            ),
                            if (activePlanIds.length > 1) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${activePlanIds.length} ativos',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          info.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Divisor discreto
          Container(
            width: 1,
            height: 28,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          const SizedBox(width: 10),
          // Lado direito: Botão de adicionar novo plano
          if (activePlanIds.length < 5)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () =>
                    _showAddPlanCatalogDialog(context, ref, activePlanIds),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: goldColor.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: goldColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Novo',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: goldColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── BOTTOM SHEET PARA SELEÇÃO E TROCA DE PLANOS ATIVOS ────────────────────
  void _showSwitchPlanBottomSheet(
    BuildContext context,
    WidgetRef ref,
    List<String> activePlanIds,
    String currentPlanId,
    bool isDark,
  ) {
    final goldColor = isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Planos de Leitura',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${activePlanIds.length} de 5 planos em andamento',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  if (activePlanIds.length < 5)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: goldColor.withValues(alpha: 0.12),
                        foregroundColor: goldColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddPlanCatalogDialog(context, ref, activePlanIds);
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        'Novo Plano',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(
                color: Theme.of(ctx)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.08),
                height: 1,
              ),
              const SizedBox(height: 8),
              ...activePlanIds.map((id) {
                final isSelected = id == currentPlanId;
                final planInfo = PlanRepository.getPlanInfo(id);

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? goldColor.withValues(alpha: 0.1)
                        : Theme.of(ctx)
                            .colorScheme
                            .surfaceContainer
                            .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? goldColor.withValues(alpha: 0.4)
                          : Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.06),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: goldColor.withValues(
                            alpha: isSelected ? 0.2 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          planInfo.icon,
                          color: goldColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        planInfo.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14,
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        '${planInfo.totalDays} dias • ${planInfo.tag}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: goldColor,
                              size: 22,
                            )
                          : const Icon(
                              Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: Colors.grey,
                            ),
                      onTap: () {
                        ref.read(currentPlanIdProvider.notifier).selectPlan(id);
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ── DIÁLOGO DE CONFIRMAÇÃO PARA REINICIAR PLANO ───────────────────────────
  Future<void> _confirmResetPlan(
    BuildContext context,
    WidgetRef ref,
    String planTitle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: AppTheme.kPrimaryGold, size: 24),
            SizedBox(width: 8),
            Text('Reiniciar Plano?'),
          ],
        ),
        content: Text(
          'Deseja zerar os dias concluídos e o streak do plano "$planTitle"? Suas anotações anteriores serão mantidas.',
          style: GoogleFonts.manrope(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.kPrimaryGold,
              foregroundColor: Colors.black,
            ),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(studyPlanProgressProvider.notifier).reset();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Progresso do plano "$planTitle" reiniciado.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Excluir Plano?'),
          ],
        ),
        content: Text(
          'Tem certeza que deseja excluir o plano "$planTitle"? O progresso e as anotações deste plano serão apagados.',
          style: GoogleFonts.manrope(fontSize: 14),
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
                                                      'Plano "${item.title}" adicionado com sucesso!'),
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

  // ── CARD PRINCIPAL: LEITURA DE HOJE ──────────────────────────────────────
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
    final isTablet = MediaQuery.sizeOf(context).width >= 720;
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
          // Linha Superior: Semana / Dia, Status e Menu de Opções Discreto
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (progress.isStarted
                                ? (isDark ? AppTheme.kPrimaryGold.withValues(alpha: 0.15) : const Color(0xFFFEF3C7))
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCompleted
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : (progress.isStarted
                                  ? (isDark ? AppTheme.kPrimaryGold.withValues(alpha: 0.4) : const Color(0xFFFDE68A))
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCompleted) ...[
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            isCompleted
                                ? 'Concluído'
                                : (progress.isStarted ? 'Em andamento' : 'Não iniciado'),
                            style: GoogleFonts.plusJakartaSans(
                              color: isCompleted
                                  ? const Color(0xFF10B981)
                                  : (progress.isStarted
                                      ? (isDark ? AppTheme.kPrimaryGold : const Color(0xFFB45309))
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFF97316).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFF97316),
                          size: 16,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${progress.streak} dias',
                          style: GoogleFonts.manrope(
                            color: const Color(0xFFF97316),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  // Menu discreto de opções (substitui o botão de lixeira agressivo)
                  PopupMenuButton<String>(
                    tooltip: 'Opções do Plano',
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (value) {
                      if (value == 'reset') {
                        _confirmResetPlan(context, ref, planIndex.plan.title);
                      } else if (value == 'delete') {
                        _confirmDeletePlan(
                            context, ref, currentPlanId, planIndex.plan.title);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'reset',
                        child: Row(
                          children: [
                            Icon(Icons.restart_alt_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Reiniciar Progresso'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent, size: 18),
                            SizedBox(width: 10),
                            Text('Excluir este Plano',
                                style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Título e Categoria do Plano Selecionado
          Text(
            planIndex.plan.title.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            planDay.formattedSummary,
            style: GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: isTablet ? 28 : 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dia ${todayInfo.day} de ${planIndex.totalDays} • Leitura Bíblica Diária',
            style: GoogleFonts.manrope(
              color: subtitleColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          // Hero Card: Passagem Bíblica clicável que convida à leitura
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCompleted
                        ? const Color(0xFF10B981).withValues(alpha: 0.35)
                        : (isDark
                            ? AppTheme.kPrimaryGold.withValues(alpha: 0.25)
                            : const Color(0xFFD97706).withValues(alpha: 0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (isDark
                                ? AppTheme.kPrimaryGold.withValues(alpha: 0.15)
                                : const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.auto_stories_rounded,
                        color: isCompleted
                            ? const Color(0xFF10B981)
                            : (isDark
                                ? AppTheme.kPrimaryGold
                                : const Color(0xFFD97706)),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'TEXTO BÍBLICO DO DIA',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: isDark
                                      ? AppTheme.kPrimaryGold
                                      : const Color(0xFFD97706),
                                ),
                              ),
                              if (isCompleted) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'LIDO',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            planDay.formattedSummary,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Toque para abrir no leitor com Strong',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: isDark
                          ? AppTheme.kPrimaryGold
                          : const Color(0xFFD97706),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Botão Primário: Iniciar / Continuar Leitura com Strong
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
            icon: Icon(
              isCompleted ? Icons.visibility_rounded : Icons.menu_book_rounded,
              size: 20,
            ),
            label: Text(
              isCompleted
                  ? 'Revisar Leitura com Strong'
                  : (progress.isStarted
                      ? 'Continuar Leitura com Strong'
                      : 'Iniciar Leitura com Strong'),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.kPrimaryGold : const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF111223),
              minimumSize: Size.fromHeight(isTablet ? 52 : 48),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Botão Secundário: Marcar / Alternar Concluído
          Consumer(
            builder: (context, ref, _) {
              if (isCompleted) {
                return OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(studyPlanProgressProvider.notifier)
                        .toggleDay(todayInfo.day);
                  },
                  icon: const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: Color(0xFF10B981),
                  ),
                  label: Text(
                    'Leitura Concluída Hoje ✓',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                    side: const BorderSide(
                      color: Color(0xFF10B981),
                      width: 1.2,
                    ),
                    minimumSize: Size.fromHeight(isTablet ? 48 : 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                );
              }

              return OutlinedButton.icon(
                onPressed: () {
                  ref
                      .read(studyPlanProgressProvider.notifier)
                      .toggleDay(todayInfo.day);
                },
                icon: Icon(
                  Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isDark ? Colors.white70 : textColor.withValues(alpha: 0.6),
                ),
                label: Text(
                  'Marcar como Concluído',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : textColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.25)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
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

  // ── CARD DE ANOTAÇÕES / REFLEXÃO DO DIA ───────────────────────────────────
  Widget _buildNotesCard({
    required BuildContext context,
    required WidgetRef ref,
    required TodayPlanInfo todayInfo,
    required PlanDay planDay,
    required bool hasTodayNote,
    required String? todayNote,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.sizeOf(context).width >= 720;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasTodayNote
              ? (isDark
                  ? AppTheme.kPrimaryGold.withValues(alpha: 0.4)
                  : const Color(0xFFD97706).withValues(alpha: 0.4))
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
                    Icon(
                      Icons.edit_note_rounded,
                      color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isTablet ? 'Minha Reflexão' : 'Minha Reflexão de Hoje',
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
                ),
                label: Text(
                  hasTodayNote ? 'Editar' : 'Anotar',
                  style: TextStyle(
                    color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasTodayNote && todayNote != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
                    width: 3.5,
                  ),
                ),
              ),
              child: Text(
                todayNote,
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.9),
                ),
              ),
            )
          else
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showNotesBottomSheet(
                  context,
                  ref,
                  todayInfo.day,
                  planDay.formattedSummary,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.create_rounded,
                        size: 18,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Escreva suas reflexões, orações e o que Deus ministrou ao seu coração...',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── CARD DE PROGRESSO RÁPIDO ──────────────────────────────────────────────
  Widget _buildQuickStatsCard({
    required BuildContext context,
    required PlanProgress progress,
    required PlanIndex planIndex,
  }) {
    final completedCount = progress.completedDays.length;
    final totalDays = planIndex.totalDays;
    final percent = (progress.getPercentage(totalDays) * 100).toInt();
    final remainingDays = (totalDays - completedCount).clamp(0, totalDays);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    Icon(
                      Icons.insights_rounded,
                      color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
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
                  fontSize: 15,
                  color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
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
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$completedCount de $totalDays lidos • $remainingDays restantes',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
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

  // ── CARD DE DICA DE ESTUDO CONTEXTUAL POR PLANO ───────────────────────────
  Widget _buildTipCard(BuildContext context, String currentPlanId) {
    final tipData = _getTipForPlan(currentPlanId);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tipData.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              tipData.icon,
              color: tipData.accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Dica de Estudo',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tipData.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tipData.badge,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: tipData.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tipData.text,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    height: 1.45,
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

  _PlanTipData _getTipForPlan(String planId) {
    switch (planId) {
      case 'cronologico-52':
        return const _PlanTipData(
          badge: 'ORDEM HISTÓRICA',
          text:
              'A leitura cronológica conecta os livros bíblicos à linha do tempo real dos acontecimentos. Observe os Salmos no contexto das lutas de Davi e os Profetas durante os reinos de Israel e Judá.',
          icon: Icons.history_edu_rounded,
          accentColor: Color(0xFF3B82F6),
        );
      case 'canonico-365':
        return const _PlanTipData(
          badge: 'BÍBLIA COMPLETA',
          text:
              'A ordem canônica percorre os 66 livros de Gênesis ao Apocalipse. Mantenha um ritmo diário de 3 a 4 capítulos para completar toda a Escritura em 1 ano com compreensão consistente.',
          icon: Icons.menu_book_rounded,
          accentColor: Color(0xFF8B5CF6),
        );
      case 'novo-testamento-180':
        return const _PlanTipData(
          badge: 'NOVA ALIANÇA',
          text:
              'Mergulhe no Novo Testamento contemplando o cumprimento das promessas em Cristo, o testemunho dos apóstolos e as cartas de edificação para a Igreja.',
          icon: Icons.auto_stories_rounded,
          accentColor: Color(0xFF10B981),
        );
      case 'evangelhos-90':
        return const _PlanTipData(
          badge: 'VIDA DE JESUS',
          text:
              'Observe a perspectiva de cada evangelista: Mateus apresenta o Rei Messias, Marcos o Servo fiel, Lucas o Filho do Homem e João o Filho eterno de Deus.',
          icon: Icons.local_fire_department_rounded,
          accentColor: Color(0xFFF97316),
        );
      case 'salmos-proverbios-60':
        return const _PlanTipData(
          badge: 'SABEDORIA & LOUVOR',
          text:
              'Ore os Salmos como diálogo íntimo com Deus em momentos de alegria ou dor, e use Provérbios como sabedoria prática para decisões, relacionamentos e conduta diária.',
          icon: Icons.favorite_rounded,
          accentColor: Color(0xFFEC4899),
        );
      case 'cartas-paulinas-30':
        return const _PlanTipData(
          badge: 'DOUTRINA & FÉ',
          text:
              'Nas cartas de Paulo, atente-se às bases teológicas da salvação pela graça, santificação e instruções práticas sobre como viver em comunidade e perseverança cristã.',
          icon: Icons.mail_outline_rounded,
          accentColor: Color(0xFF06B6D4),
        );
      default:
        return const _PlanTipData(
          badge: 'DEVOCIONAL',
          text:
              'Dedique alguns instantes de oração antes da leitura, pedindo ao Espírito Santo que ilumine as Escrituras e fale ao seu coração.',
          icon: Icons.lightbulb_outline_rounded,
          accentColor: Color(0xFF3B82F6),
        );
    }
  }

  // ── MODAL DE ANOTAÇÕES / REFLEXÃO ─────────────────────────────────────────
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

class _PlanTipData {
  final String badge;
  final String text;
  final IconData icon;
  final Color accentColor;

  const _PlanTipData({
    required this.badge,
    required this.text,
    required this.icon,
    required this.accentColor,
  });
}
