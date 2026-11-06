import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import '../../application/study_plan_providers.dart';
import '../../data/biblical_studies_repository.dart';
import '../../data/plan_repository.dart';
import '../../domain/biblical_study.dart';
import '../estudos/study_article_reader_screen.dart';

class GuiasTab extends ConsumerStatefulWidget {
  const GuiasTab({super.key});

  @override
  ConsumerState<GuiasTab> createState() => _GuiasTabState();
}

class _GuiasTabState extends ConsumerState<GuiasTab> {
  final TextEditingController _searchController = TextEditingController();
  int _visibleCount = 20;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activePlanIds = ref.watch(activePlanIdsProvider);
    final currentPlanId = ref.watch(currentPlanIdProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 720;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categoriesAsync = ref.watch(studyCategoriesProvider);
    final selectedCategory = ref.watch(selectedStudyCategoryProvider);
    final filteredStudies = ref.watch(filteredBiblicalStudiesProvider);
    final displayedStudies = filteredStudies.take(_visibleCount).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: isTablet ? 32.0 : 16.0,
        right: isTablet ? 32.0 : 16.0,
        top: 20.0,
        bottom: isTablet ? 32.0 : 120.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── TÍTULO DA SEÇÃO ───────────────────────────────────────────────
          Text(
            'Planos & Estudos Bíblicos',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Aprofunde seu conhecimento com planos de leitura bíblica simultâneos (até 5) e centenas de estudos teológicos completos.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),

          // ── SEÇÃO: MEUS PLANOS DE LEITURA (ATÉ 5) ─────────────────────────
          _buildMyPlansSection(context, activePlanIds, currentPlanId, isDark),

          const SizedBox(height: 32),

          // ── SEÇÃO: ACERVO DE ESTUDOS TEOLÓGICOS ───────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppTheme.kPrimaryGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acervo de Estudos Bíblicos',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Artigos doutrinários, exegéticos e devocionais completos',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
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
          const SizedBox(height: 16),

          // ── BARRA DE PESQUISA ─────────────────────────────────────────────
          Container(
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
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(studySearchQueryProvider.notifier).state = val;
                setState(() => _visibleCount = 20);
              },
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Buscar por título, passagem ou palavra-chave...',
                hintStyle: GoogleFonts.outfit(
                  fontSize: 13.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(studySearchQueryProvider.notifier).state = '';
                          setState(() => _visibleCount = 20);
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── CHIPS DE CATEGORIAS ───────────────────────────────────────────
          categoriesAsync.maybeWhen(
            data: (cats) {
              return SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: cats.length + 1,
                  itemBuilder: (context, index) {
                    final isAll = index == 0;
                    final catName = isAll ? null : cats[index - 1].name;
                    final isSelected = selectedCategory == catName;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        showCheckmark: false,
                        label: Text(
                          isAll ? 'Todos (${filteredStudies.length})' : catName!,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? (isDark ? Colors.black : Colors.white)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainer,
                        selectedColor: isDark
                            ? AppTheme.kPrimaryGold
                            : const Color(0xFFD97706),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.1),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (_) {
                          ref
                              .read(selectedStudyCategoryProvider.notifier)
                              .state = catName;
                          setState(() => _visibleCount = 20);
                        },
                      ),
                    );
                  },
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          const SizedBox(height: 18),

          // ── LISTA DE ESTUDOS ──────────────────────────────────────────────
          if (filteredStudies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhum estudo encontrado',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              '${filteredStudies.length} estudos disponíveis',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),

            // Grid no tablet ou lista no mobile
            if (isTablet)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 210,
                ),
                itemCount: displayedStudies.length,
                itemBuilder: (context, index) {
                  return _buildStudyCard(
                      context, displayedStudies[index], isDark);
                },
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedStudies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  return _buildStudyCard(
                      context, displayedStudies[index], isDark);
                },
              ),

            // Botão "Carregar Mais Estudos"
            if (_visibleCount < filteredStudies.length)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Center(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.kPrimaryGold,
                      side: const BorderSide(color: AppTheme.kPrimaryGold),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _visibleCount = (_visibleCount + 20)
                            .clamp(0, filteredStudies.length);
                      });
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      'Carregar Mais Estudos (${filteredStudies.length - _visibleCount} restantes)',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── SEÇÃO DE PLANOS ATIVOS (ATÉ 5 SIMULTÂNEOS) ───────────────────────────
  Widget _buildMyPlansSection(
    BuildContext context,
    List<String> activePlanIds,
    String currentPlanId,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bookmarks_rounded,
                    color: AppTheme.kPrimaryGold,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Meus Planos de Leitura (${activePlanIds.length}/5)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (activePlanIds.length < 5)
              OutlinedButton.icon(
                onPressed: () => _showPlanCatalogModal(context, activePlanIds),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Adicionar Plano'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? AppTheme.kPrimaryGold : const Color(0xFFD97706),
                  side: BorderSide(
                    color: isDark
                        ? AppTheme.kPrimaryGold.withValues(alpha: 0.4)
                        : const Color(0xFFD97706).withValues(alpha: 0.4),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (activePlanIds.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.08),
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 40,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nenhum plano ativo no momento',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Você pode adicionar até 5 planos de leitura bíblica para acompanhar juntos.',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => _showPlanCatalogModal(context, activePlanIds),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Explorar e Iniciar um Plano'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark
                          ? AppTheme.kPrimaryGold
                          : const Color(0xFFD97706),
                      foregroundColor:
                          isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...activePlanIds.map((planId) {
            final isSelected = planId == currentPlanId;
            final planInfo = PlanRepository.getPlanInfo(planId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildPlanCardItem(
                  context, planInfo, isSelected, isDark, activePlanIds),
            );
          }),
      ],
    );
  }

  // ── CARD INDIVIDUAL DE PLANO ATIVO ─────────────────────────────────────────
  Widget _buildPlanCardItem(
    BuildContext context,
    AvailablePlanInfo planInfo,
    bool isSelected,
    bool isDark,
    List<String> activePlanIds,
  ) {
    return Consumer(
      builder: (context, ref, _) {
        final progress = ref.watch(planProgressFamilyProvider(planInfo.id));
        final percent = (progress.getPercentage(planInfo.totalDays) * 100).toInt();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? (isDark
                      ? AppTheme.kPrimaryGold.withValues(alpha: 0.6)
                      : const Color(0xFFD97706).withValues(alpha: 0.5))
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.08),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isDark
                              ? AppTheme.kPrimaryGold
                              : const Color(0xFFD97706))
                          .withValues(alpha: isDark ? 0.1 : 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF10B981).withValues(alpha: 0.5)
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.play_circle_outline_rounded,
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSelected ? 'PLANO ATIVO' : 'EM ANDAMENTO',
                          style: GoogleFonts.plusJakartaSans(
                            color: isSelected
                                ? const Color(0xFF10B981)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '$percent% Concluído',
                        style: GoogleFonts.plusJakartaSans(
                          color: isDark
                              ? AppTheme.kPrimaryGold
                              : const Color(0xFFD97706),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Excluir Plano',
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 19, color: Colors.redAccent),
                        onPressed: () => _confirmDeletePlan(
                            context, planInfo.id, planInfo.title),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                planInfo.title,
                style: GoogleFonts.plusJakartaSans(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                planInfo.description,
                style: GoogleFonts.manrope(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.75),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildTag(context, '${planInfo.totalWeeks} Semanas'),
                  _buildTag(context, '${planInfo.totalDays} Dias'),
                  _buildTag(context, planInfo.tag),
                  if (!isSelected) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        ref
                            .read(currentPlanIdProvider.notifier)
                            .selectPlan(planInfo.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Plano "${planInfo.title}" selecionado para a aba Hoje!'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_rounded, size: 15),
                      label: const Text('Selecionar Plano'),
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.kPrimaryGold
                            : const Color(0xFFD97706),
                        foregroundColor:
                            isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── DIÁLOGO DE CONFIRMAÇÃO DE EXCLUSÃO DE PLANO ────────────────────────────
  Future<void> _confirmDeletePlan(
      BuildContext context, String planId, String planTitle) async {
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
          'Tem certeza que deseja excluir o plano "$planTitle"? Todo o histórico de leitura e anotações deste plano serão apagados.',
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

    if (confirmed == true && mounted) {
      final current = ref.read(currentPlanIdProvider);
      await ref.read(activePlanIdsProvider.notifier).removePlan(
            planId,
            currentSelectedPlanId: current,
            onSwitchPlan: (next) =>
                ref.read(currentPlanIdProvider.notifier).selectPlan(next),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plano "$planTitle" removido com sucesso.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── MODAL: CATÁLOGO DE PLANOS DISPONÍVEIS (ATÉ 5) ──────────────────────────
  void _showPlanCatalogModal(
      BuildContext context, List<String> activePlanIds) {
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
                        'Catálogo de Planos Bíblicos',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Adicione até 5 planos simultâneos (${activePlanIds.length}/5 ativos)',
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
                                      'Já Adicionado',
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
                                      : 'Iniciar Plano'),
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

  // ── CARD INDIVIDUAL DE ESTUDO ─────────────────────────────────────────────
  Widget _buildStudyCard(
      BuildContext context, BiblicalStudy study, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudyArticleReaderScreen(study: study),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Categoria, status de leitura e tempo de leitura
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (study.categories.isNotEmpty) ...[
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.kPrimaryGold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              study.categories.first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.kPrimaryGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Consumer(
                        builder: (context, ref, _) {
                          final history = ref.watch(studyHistoryProvider);
                          if (history.isCompleted(study.id)) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF10B981), size: 11),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Lido',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (history.isStarted(study.id)) {
                            final p = (history.getProgress(study.id) * 100).toInt();
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_stories_rounded,
                                      color: Color(0xFFF59E0B), size: 11),
                                  const SizedBox(width: 3),
                                  Text(
                                    p > 0 ? 'Lendo $p%' : 'Lendo',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFFF59E0B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  study.estimatedReadTime,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Título
            Text(
              study.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),

            // Resumo do estudo (sem Expanded para evitar crash em listas scrolláveis)
            Text(
              study.excerpt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                height: 1.4,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.65),
              ),
            ),

            const SizedBox(height: 12),

            // Botão "Ler Estudo"
            Row(
              children: [
                Text(
                  'Ler Estudo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.kPrimaryGold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppTheme.kPrimaryGold,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
