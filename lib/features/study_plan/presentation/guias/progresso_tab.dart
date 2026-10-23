import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import '../../application/study_plan_providers.dart';
import '../../domain/domain.dart';

class ProgressoTab extends ConsumerWidget {
  const ProgressoTab({super.key});

  void _exportBackup(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(studyPlanProgressProvider.notifier);
    final jsonString = notifier.exportProgressJson();

    await Clipboard.setData(ClipboardData(text: jsonString));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup copiado para a Área de Transferência!'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: jsonString,
          subject: 'Backup do Plano de Leitura Bíblica Cronológica',
        ),
      );
    } catch (_) {
      // Ignora em plataformas onde share_plus não estiver configurado
    }
  }

  void _importBackup(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainer,
        title: Text(
          'Restaurar Backup em JSON',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cole abaixo o código JSON do seu backup anterior para restaurar seus dias concluídos e anotações:',
              style: GoogleFonts.manrope(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 5,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '{\n  "planId": "cronologico-52",\n  ...\n}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Theme.of(ctx).scaffoldBackgroundColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              final success = await ref
                  .read(studyPlanProgressProvider.notifier)
                  .importProgressJson(text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Backup restaurado com sucesso!'
                          : 'Falha ao restaurar: JSON inválido.',
                    ),
                    backgroundColor:
                        success ? const Color(0xFF10B981) : Colors.redAccent,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.kPrimaryGold,
              foregroundColor: Colors.black,
            ),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(chronologicalPlanProvider);
    final progress = ref.watch(studyPlanProgressProvider);
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return planAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
      data: (plan) {
        final totalDays = plan.totalDays;
        final completedCount = progress.completedDays.length;
        final percentage = progress.getPercentage(totalDays);
        final percentFormatted = (percentage * 100).toStringAsFixed(1);
        int completedWeeks = 0;
        for (int w = 1; w <= plan.totalWeeks; w++) {
          if (PlanIndex.completedDaysInWeek(w, progress.completedDays) == 7) {
            completedWeeks++;
          }
        }

        final startFormatted =
            '${progress.startDate.day.toString().padLeft(2, '0')}/'
            '${progress.startDate.month.toString().padLeft(2, '0')}/'
            '${progress.startDate.year}';

        final mainProgressCard = _buildMainProgressCard(
          context: context,
          percentage: percentage,
          percentFormatted: percentFormatted,
          completedCount: completedCount,
          totalDays: totalDays,
        );

        final metricsCard = _buildMetricsRow(
          context: context,
          progress: progress,
          completedWeeks: completedWeeks,
          totalWeeks: plan.totalWeeks,
        );

        final startDateCard = _buildStartDateCard(
          context: context,
          ref: ref,
          progress: progress,
          startFormatted: startFormatted,
        );

        final backupCard = _buildBackupCard(
          context: context,
          ref: ref,
        );

        final resetBtn = _buildResetButton(context, ref);

        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: isTablet ? 32.0 : 16.0,
            right: isTablet ? 32.0 : 16.0,
            top: 20.0,
            bottom: 120.0, // Espaço para a CustomBottomNav flutuante
          ),
          child: isTablet
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Coluna Esquerda: Progresso Geral e Métricas
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          mainProgressCard,
                          const SizedBox(height: 16),
                          metricsCard,
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Coluna Direita: Datas, Backup e Reset
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          startDateCard,
                          const SizedBox(height: 16),
                          backupCard,
                          const SizedBox(height: 20),
                          resetBtn,
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    mainProgressCard,
                    const SizedBox(height: 16),
                    metricsCard,
                    const SizedBox(height: 16),
                    startDateCard,
                    const SizedBox(height: 16),
                    backupCard,
                    const SizedBox(height: 24),
                    resetBtn,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMainProgressCard({
    required BuildContext context,
    required double percentage,
    required String percentFormatted,
    required int completedCount,
    required int totalDays,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? AppTheme.kPrimaryGold.withValues(alpha: 0.3)
              : const Color(0xFFD97706).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progresso Geral',
                style: GoogleFonts.plusJakartaSans(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.kPrimaryGold.withValues(alpha: 0.15)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percentFormatted%',
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFB45309),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Barra de Progresso Principal
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 12,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppTheme.kPrimaryGold : const Color(0xFFF59E0B),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedCount de $totalDays dias lidos',
                style: GoogleFonts.manrope(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              Text(
                '${totalDays - completedCount} restantes',
                style: GoogleFonts.manrope(
                  color: textColor.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow({
    required BuildContext context,
    required PlanProgress progress,
    required int completedWeeks,
    required int totalWeeks,
  }) {
    return Row(
      children: [
        // Card Streak
        Expanded(
          child: _buildMetricCard(
            context,
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFF97316),
            label: 'Sequência',
            value: '${progress.streak} dias',
          ),
        ),
        const SizedBox(width: 10),
        // Card Semanas
        Expanded(
          child: _buildMetricCard(
            context,
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF10B981),
            label: 'Semanas 100%',
            value: '$completedWeeks de $totalWeeks',
          ),
        ),
        const SizedBox(width: 10),
        // Card Anotações
        Expanded(
          child: _buildMetricCard(
            context,
            icon: Icons.edit_note_rounded,
            iconColor: const Color(0xFF38BDF8),
            label: 'Anotações',
            value: '${progress.totalNotes} dias',
          ),
        ),
      ],
    );
  }

  Widget _buildStartDateCard({
    required BuildContext context,
    required WidgetRef ref,
    required PlanProgress progress,
    required String startFormatted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: AppTheme.kPrimaryGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Início do Plano',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  startFormatted,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: progress.startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                ref
                    .read(studyPlanProgressProvider.notifier)
                    .setStartDate(picked);
              }
            },
            child: const Text('Alterar'),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCard({
    required BuildContext context,
    required WidgetRef ref,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_sync_rounded,
                color: AppTheme.kPrimaryGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Backup & Exportação',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Salve uma cópia do seu progresso e anotações para nunca perder seus dados.',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportBackup(context, ref),
                  icon: const Icon(Icons.upload_rounded, size: 16),
                  label: const Text('Exportar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.kPrimaryGold,
                    side: BorderSide(
                      color: AppTheme.kPrimaryGold.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _importBackup(context, ref),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Restaurar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).colorScheme.surfaceContainer,
            title: Text(
              'Reiniciar Plano de Leitura?',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Isso limpará todo o seu histórico de dias lidos, anotações e reiniciará a data de início para hoje.',
              style: GoogleFonts.manrope(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
                child: const Text('Reiniciar'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          ref.read(studyPlanProgressProvider.notifier).reset();
        }
      },
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Reiniciar Progresso do Plano'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent.withValues(alpha: 0.8),
        side: BorderSide(
          color: Colors.redAccent.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
