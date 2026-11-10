import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/theme/app_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:keryx_app/core/services/push_notification_service.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import '../../application/study_plan_providers.dart';
import '../../domain/domain.dart';

class ProgressoTab extends ConsumerStatefulWidget {
  const ProgressoTab({super.key});

  @override
  ConsumerState<ProgressoTab> createState() => _ProgressoTabState();
}

class _ProgressoTabState extends ConsumerState<ProgressoTab> {
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
  }

  Future<void> _loadReminderSettings() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final enabled = prefs.getBool('study_plan_reminder_enabled') ?? false;
    final hour = prefs.getInt('study_plan_reminder_hour') ?? 7;
    final minute = prefs.getInt('study_plan_reminder_minute') ?? 0;
    if (mounted) {
      setState(() {
        _reminderEnabled = enabled;
        _reminderTime = TimeOfDay(hour: hour, minute: minute);
      });
    }
  }

  Future<void> _toggleReminder(bool value) async {
    setState(() {
      _reminderEnabled = value;
    });
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('study_plan_reminder_enabled', value);

    final notifService = ref.read(pushNotificationServiceProvider);
    if (value) {
      await notifService.scheduleStudyPlanReminder(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              '⏰ Lembrete diário agendado para às ${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}!',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      await notifService.cancelStudyPlanReminder();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('🛑 Lembrete diário desativado.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _reminderTime = picked;
      });
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setInt('study_plan_reminder_hour', picked.hour);
      await prefs.setInt('study_plan_reminder_minute', picked.minute);

      if (_reminderEnabled) {
        final notifService = ref.read(pushNotificationServiceProvider);
        await notifService.scheduleStudyPlanReminder(
          hour: picked.hour,
          minute: picked.minute,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                '⏰ Horário do lembrete atualizado para às ${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}!',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void _exportBackup(BuildContext context) async {
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
    } catch (_) {}
  }

  void _importBackup(BuildContext context) {
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
  Widget build(BuildContext context) {
    final planAsync = ref.watch(chronologicalPlanProvider);
    final progress = ref.watch(studyPlanProgressProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 768;

    return planAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
      data: (plan) {
        final totalDays = plan.totalDays;
        final completedCount = progress.completedDays.where((d) => d <= totalDays).length;
        final percentage = progress.getPercentage(totalDays);
        final percentFormatted = (percentage * 100).toStringAsFixed(1);
        final remainingDays = (totalDays - completedCount).clamp(0, totalDays);

        int completedWeeks = 0;
        for (final week in plan.weeks) {
          final daysInWeek = week.days.isNotEmpty ? week.days.length : 7;
          if (week.days.where((d) => progress.completedDays.contains(d.day)).length == daysInWeek) {
            completedWeeks++;
          }
        }

        final now = DateTime.now();
        final daysElapsed = DateTime(now.year, now.month, now.day)
            .difference(DateTime(
                progress.startDate.year, progress.startDate.month, progress.startDate.day))
            .inDays;

        final bool isFinished = completedCount >= totalDays;
        String estimatedCompletionFormatted;
        String paceText;

        if (isFinished) {
          estimatedCompletionFormatted = 'Plano Concluído! 🎉';
          paceText = 'Meta 100% atingida';
        } else if (completedCount == 0) {
          final estimatedDate = now.add(Duration(days: remainingDays));
          estimatedCompletionFormatted =
              '${estimatedDate.day.toString().padLeft(2, '0')}/${estimatedDate.month.toString().padLeft(2, '0')}/${estimatedDate.year}';
          paceText = '1 dia / dia (estimado)';
        } else {
          final double realPace =
              completedCount / (daysElapsed > 0 ? daysElapsed : 1);
          final clampedPace = realPace.clamp(0.2, 5.0);
          final daysToFinish = (remainingDays / clampedPace).round();
          final estimatedDate = now.add(Duration(days: daysToFinish));
          estimatedCompletionFormatted =
              '${estimatedDate.day.toString().padLeft(2, '0')}/${estimatedDate.month.toString().padLeft(2, '0')}/${estimatedDate.year}';
          paceText = '${realPace.toStringAsFixed(1)} leituras / dia';
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

        final estimationCard = _buildEstimationCard(
          context: context,
          remainingDays: remainingDays,
          paceText: paceText,
          estimatedCompletionFormatted: estimatedCompletionFormatted,
          isFinished: isFinished,
        );

        final metricsCard = _buildMetricsRow(
          context: context,
          progress: progress,
          completedWeeks: completedWeeks,
          totalWeeks: plan.totalWeeks,
        );

        final reminderCard = _buildReminderCard(context);

        final startDateCard = _buildStartDateCard(
          context: context,
          ref: ref,
          progress: progress,
          startFormatted: startFormatted,
        );

        final backupCard = _buildBackupCard(
          context: context,
        );

        final resetBtn = _buildResetButton(context, ref);

        final horizontalPadding = isTablet ? 24.0 : 16.0;

        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: horizontalPadding,
            top: 20.0,
            bottom: isTablet ? 36.0 : 155.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  mainProgressCard,
                  const SizedBox(height: 16),
                  metricsCard,
                  const SizedBox(height: 16),
                  estimationCard,
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 640;
                      if (isWide) {
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: reminderCard),
                              const SizedBox(width: 16),
                              Expanded(child: startDateCard),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: [
                          reminderCard,
                          const SizedBox(height: 16),
                          startDateCard,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  backupCard,
                  const SizedBox(height: 24),
                  Center(child: resetBtn),
                ],
              ),
            ),
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
                '${(totalDays - completedCount).clamp(0, totalDays)} restantes',
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

  Widget _buildEstimationCard({
    required BuildContext context,
    required int remainingDays,
    required String paceText,
    required String estimatedCompletionFormatted,
    required bool isFinished,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.kPrimaryGold.withValues(alpha: 0.15)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_graph_rounded,
                  color: isDark ? AppTheme.kPrimaryGold : const Color(0xFFB45309),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previsão & Ritmo de Conclusão',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Calculado a partir do seu histórico real',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Dias Restantes
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DIAS RESTANTES',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textColor.withValues(alpha: 0.6),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFinished ? '0' : '$remainingDays dias',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.kPrimaryGold
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Ritmo Médio
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RITMO MÉDIO',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textColor.withValues(alpha: 0.6),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        paceText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Previsão de Término
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isFinished
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFinished
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isFinished
                      ? Icons.verified_rounded
                      : Icons.event_available_rounded,
                  size: 18,
                  color: isFinished
                      ? const Color(0xFF10B981)
                      : (isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706)),
                ),
                const SizedBox(width: 10),
                Text(
                  isFinished ? 'Status: ' : 'Data estimada de término: ',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
                Expanded(
                  child: Text(
                    estimatedCompletionFormatted,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isFinished
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFF818CF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lembrete Diário de Leitura',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Notificação pontual para manter o hábito diário',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _reminderEnabled,
                activeTrackColor:
                    isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
                onChanged: _toggleReminder,
              ),
            ],
          ),
          if (_reminderEnabled) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.alarm_rounded,
                          size: 18, color: Color(0xFF818CF8)),
                      const SizedBox(width: 8),
                      Text(
                        'Horário do Lembrete:',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: textColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: Text(
                      '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? AppTheme.kPrimaryGold
                          : const Color(0xFFD97706),
                      side: BorderSide(
                        color: isDark
                            ? AppTheme.kPrimaryGold.withValues(alpha: 0.4)
                            : const Color(0xFFD97706).withValues(alpha: 0.4),
                      ),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 580;

        final streakCard = _buildMetricCard(
          context,
          icon: Icons.local_fire_department_rounded,
          iconColor: const Color(0xFFF97316),
          label: 'Sequência Atual',
          value: '${progress.streak} dias',
        );

        final weeksCard = _buildMetricCard(
          context,
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF10B981),
          label: 'Semanas 100%',
          value: '$completedWeeks de $totalWeeks',
        );

        final notesCard = _buildMetricCard(
          context,
          icon: Icons.edit_note_rounded,
          iconColor: const Color(0xFF38BDF8),
          label: 'Anotações Feitas',
          value: '${progress.totalNotes} dias',
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: streakCard),
              const SizedBox(width: 12),
              Expanded(child: weeksCard),
              const SizedBox(width: 12),
              Expanded(child: notesCard),
            ],
          );
        }

        return Column(
          children: [
            streakCard,
            const SizedBox(height: 10),
            weeksCard,
            const SizedBox(height: 10),
            notesCard,
          ],
        );
      },
    );
  }

  Widget _buildStartDateCard({
    required BuildContext context,
    required WidgetRef ref,
    required PlanProgress progress,
    required String startFormatted,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.kPrimaryGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: AppTheme.kPrimaryGold,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Início do Plano',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Iniciado em $startFormatted',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: progress.startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                ref
                    .read(studyPlanProgressProvider.notifier)
                    .setStartDate(picked);
              }
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Alterar',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCard({
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
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
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.backup_rounded,
                  color: AppTheme.kPrimaryGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Backup & Sincronização do Progresso',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Exporte seu progresso para salvar em arquivo seguro ou importe para transferir para outro dispositivo.',
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportBackup(context),
                  icon: const Icon(Icons.upload_rounded, size: 16),
                  label: Text(
                    'Exportar Backup',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.kPrimaryGold,
                    side: BorderSide(
                      color: AppTheme.kPrimaryGold.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _importBackup(context),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    'Restaurar Backup',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
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
              const SnackBar(
                content: Text('Progresso do plano reiniciado com sucesso.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
      icon: const Icon(Icons.restart_alt_rounded, color: Colors.redAccent, size: 18),
      label: const Text(
        'Reiniciar Progresso do Plano',
        style: TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: Colors.redAccent.withValues(alpha: 0.35),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
