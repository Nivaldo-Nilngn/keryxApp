import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import '../model/study_plan_model.dart';
import '../repository/study_plan_repository.dart';
import 'study_lesson_screen.dart';


class StudyPlanDetailScreen extends ConsumerStatefulWidget {
  final StudyPlan? plan;
  final String? planId;
  const StudyPlanDetailScreen({super.key, this.plan, this.planId});

  @override
  ConsumerState<StudyPlanDetailScreen> createState() => _StudyPlanDetailScreenState();
}

class _StudyPlanDetailScreenState extends ConsumerState<StudyPlanDetailScreen> {
  @override
  Widget build(BuildContext context) {
    // Se não temos o objeto plan, assistimos o catálogo para encontrá-lo
    StudyPlan? targetPlan = widget.plan;
    if (targetPlan == null && widget.planId != null) {
      final catalog = ref.watch(studyCatalogStreamProvider).value;
      targetPlan = catalog?.firstWhere((p) => p.id == widget.planId);
    }

    if (targetPlan == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final planInstance = targetPlan; // Capture instance as non-nullable
    final progressAsync = ref.watch(activePlanProgressProvider);
    final lessonsAsync = ref.watch(planLessonsProvider(planInstance.id));
    final authUser = ref.watch(authStateProvider).value;

    return progressAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Erro: $e'))),
      data: (userProgress) {
        final isActive = userProgress?.planId == planInstance.id;
        final currentLessonIdx = isActive ? userProgress!.currentLessonIndex : 1;
        final completedLessons = isActive ? userProgress!.completedLessons : [];

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F1E),
          extendBody: true,
          extendBodyBehindAppBar: true,
          appBar: MBibliaTopBar(
            title: planInstance.title,
            isScrolled: true,
          ),
          body: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 120, left: 24, right: 24, bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(planInstance),
                          const SizedBox(height: 24),
                          if (isActive) 
                            _buildProgressSection(userProgress!)
                          else
                            _buildStartButton(context, ref, authUser, planInstance),
                        ],
                      ),
                    ),
                  ),
                  lessonsAsync.when(
                    loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                    error: (e, st) => SliverToBoxAdapter(child: Center(child: Text('Erro: $e'))),
                    data: (lessons) {
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final lesson = lessons[index];
                              final isCompleted = completedLessons.contains(lesson.lessonIndex);
                              final isLocked = !isActive || (lesson.lessonIndex > currentLessonIdx && !isCompleted);

                              return _LessonTile(
                                lesson: lesson,
                                isCompleted: isCompleted,
                                isLocked: isLocked,
                                isActive: isActive,
                                onTap: () {
                                  if (!isActive) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Inicie o plano para ver esta aula!')),
                                    );
                                    return;
                                  }
                                  if (isLocked) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Conclua a aula anterior para liberar esta!')),
                                    );
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StudyLessonScreen(
                                        planId: planInstance.id,
                                        lesson: lesson,
                                        totalLessons: lessons.length,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            childCount: lessons.length,
                          ),
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
              
              // Navbar Fixa
              Align(
                alignment: Alignment.bottomCenter,
                child: StudyBottomNav(
                  currentIndex: 3,
                  onTap: (index) {
                    if (index == 0) {
                      Navigator.pop(context);
                    } else if (index == 1) {
                      ref.read(navigationProvider.notifier).setIndex(0);
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    } else if (index == 2) {
                      ref.read(navigationProvider.notifier).setIndex(1);
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                ),
              ),
            ],
          ),
        );
    },
  );
}

  Widget _buildHeader(StudyPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Badge(text: plan.level.toUpperCase(), isPremium: plan.level == 'premium'),
            const SizedBox(width: 8),
            _Badge(text: "${plan.durationDays} DIAS", isOutline: true),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          plan.description,
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildStartButton(BuildContext context, WidgetRef ref, dynamic authUser, StudyPlan plan) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          if (authUser == null) return;
          await ref.read(studyPlanRepositoryProvider).enrollInPlan(authUser.uid, plan);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Plano "${plan.title}" iniciado!')),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.kPrimaryGold,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          "INICIAR PLANO DE ESTUDO",
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildProgressSection(UserPlanProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Seu Progresso",
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              "${(progress.progress * 100).toInt()}%",
              style: GoogleFonts.outfit(color: AppTheme.kPrimaryGold, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress.progress,
            minHeight: 8,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.kPrimaryGold),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final bool isOutline;
  final bool isPremium;
  const _Badge({required this.text, this.isOutline = false, this.isPremium = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOutline ? Colors.transparent : (isPremium ? AppTheme.kPrimaryGold : AppTheme.kPrimaryGold.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.kPrimaryGold.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: isPremium && !isOutline ? Colors.black : AppTheme.kPrimaryGold,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final StudyLesson lesson;
  final bool isCompleted;
  final bool isLocked;
  final bool isActive;
  final VoidCallback onTap;

  const _LessonTile({
    required this.lesson,
    required this.isCompleted,
    required this.isLocked,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withValues(alpha: isLocked ? 0.01 : 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isCompleted ? AppTheme.kPrimaryGold.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted ? AppTheme.kPrimaryGold : (isLocked ? Colors.white10 : const Color(0xFF2C2C4E)),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted 
              ? const Icon(Icons.check_rounded, color: Colors.black, size: 20)
              : Text(
                  "${lesson.lessonIndex}",
                  style: GoogleFonts.outfit(
                    color: isLocked ? Colors.white24 : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ),
        title: Text(
          lesson.title,
          style: GoogleFonts.outfit(
            color: isLocked ? Colors.white24 : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          isLocked ? "Bloqueado" : (isCompleted ? "Concluído" : "Disponível"),
          style: GoogleFonts.outfit(
            color: isCompleted ? AppTheme.kPrimaryGold.withValues(alpha: 0.7) : Colors.white30,
            fontSize: 11,
          ),
        ),
        trailing: Icon(
          isLocked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
          color: isLocked ? Colors.white10 : Colors.white38,
        ),
      ),
      ),
    );
  }
}
