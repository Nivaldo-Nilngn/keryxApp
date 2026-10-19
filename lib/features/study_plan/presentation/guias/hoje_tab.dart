import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import '../../application/study_plan_providers.dart';
import '../../domain/domain.dart';
import '../study_plan_reader_screen.dart';

class HojeTab extends ConsumerWidget {
  final VoidCallback? onOpenReader;

  const HojeTab({super.key, this.onOpenReader});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayInfo = ref.watch(todayPlanDayProvider);
    final progress = ref.watch(studyPlanProgressProvider);
    final planIndexAsync = ref.watch(chronologicalIndexProvider);
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return planIndexAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Erro ao carregar o plano: $err',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (planIndex) {
        final planDay = planIndex.dayAt(todayInfo.day);
        final isCompleted = todayInfo.isCompleted;
        final hasTodayNote = progress.hasNote(todayInfo.day);
        final todayNote = progress.getNote(todayInfo.day);

        final mainCard = _buildTodayMainCard(
          context: context,
          planDay: planDay,
          todayInfo: todayInfo,
          progress: progress,
          planIndex: planIndex,
          isCompleted: isCompleted,
          isTablet: isTablet,
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
            bottom: 120.0, // Espaço para a CustomBottomNav flutuante
          ),
          child: isTablet
              ? Row(
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
              : Column(
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
        );
      },
    );
  }

  Widget _buildTodayMainCard({
    required BuildContext context,
    required PlanDay planDay,
    required TodayPlanInfo todayInfo,
    required PlanProgress progress,
    required PlanIndex planIndex,
    required bool isCompleted,
    required bool isTablet,
  }) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 26.0 : 20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1E38),
            Theme.of(context).colorScheme.surfaceContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : AppTheme.kPrimaryGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha Superior: Semana / Dia e Streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'SEMANA ${todayInfo.week} • DIA ${todayInfo.dayOfWeek}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.kPrimaryGold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
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
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Título do dia
          Text(
            'Leitura de Hoje',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            planDay.formattedSummary,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: isTablet ? 26 : 22,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Dia ${todayInfo.day} de ${planIndex.totalDays} • Bíblia Cronológica',
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.6),
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
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: AppTheme.kPrimaryGold,
                        size: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          passage.formattedReference,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'Ler',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.kPrimaryGold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppTheme.kPrimaryGold,
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
              'Iniciar Leitura com Strong',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.kPrimaryGold,
              foregroundColor: Colors.black,
              minimumSize: Size.fromHeight(isTablet ? 54 : 50),
              elevation: 4,
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
                      : Colors.white70,
                ),
                label: Text(
                  isCompleted ? 'Concluído Hoje ✓' : 'Marcar como Concluído',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : Colors.white.withValues(alpha: 0.25),
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
              Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: AppTheme.kPrimaryGold,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Minha Reflexão de Hoje',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
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
              Row(
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    color: AppTheme.kPrimaryGold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Seu Progresso no Plano',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
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
              Text(
                '$completedCount de $totalDays lidos',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Row(
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
