import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import '../model/study_plan_model.dart';
import '../repository/study_plan_repository.dart';
import 'study_plan_detail_screen.dart';

class StudyPlanCatalogScreen extends ConsumerWidget {
  const StudyPlanCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(studyCatalogStreamProvider);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: const MBibliaTopBar(
        title: "Planos de Estudo",
        isScrolled: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1E), Color(0xFF1E1E3F)],
          ),
        ),
        child: catalogAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.kPrimaryGold)),
          error: (e, st) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.white))),
          data: (plans) {
            if (plans.isEmpty) {
              return Center(
                child: Text(
                  "Nenhum plano disponível no momento.",
                  style: GoogleFonts.outfit(color: Colors.white54),
                ),
              );
            }

            // Agrupa planos por nível
            final beginner = plans.where((p) => p.level == 'beginner').toList();
            final intermediate = plans.where((p) => p.level == 'intermediate').toList();
            final advanced = plans.where((p) => p.level == 'advanced').toList();
            final premium = plans.where((p) => p.level == 'premium').toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 120, 20, 120),
              children: [
                Text(
                  "Roteiros guiados para crescimento espiritual",
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                
                if (beginner.isNotEmpty) ...[
                  const _SectionHeader(title: "Iniciantes", icon: Icons.star_border_rounded),
                  ...beginner.map((p) => _PlanCard(plan: p)),
                  const SizedBox(height: 16),
                ],

                if (intermediate.isNotEmpty) ...[
                  const _SectionHeader(title: "Intermediário", icon: Icons.star_half_rounded),
                  ...intermediate.map((p) => _PlanCard(plan: p)),
                  const SizedBox(height: 16),
                ],

                if (advanced.isNotEmpty) ...[
                  const _SectionHeader(title: "Avançado", icon: Icons.star_rounded),
                  ...advanced.map((p) => _PlanCard(plan: p)),
                  const SizedBox(height: 16),
                ],

                if (premium.isNotEmpty) ...[
                  const _SectionHeader(title: "Premium", icon: Icons.workspace_premium_rounded, isGold: true),
                  ...premium.map((p) => _PlanCard(plan: p)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isGold;
  const _SectionHeader({required this.title, required this.icon, this.isGold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Icon(icon, color: isGold ? AppTheme.kPrimaryGold : Colors.white38, size: 20),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.outfit(
              color: isGold ? AppTheme.kPrimaryGold : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.05))),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final StudyPlan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: plan.isPremium ? AppTheme.kPrimaryGold.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => StudyPlanDetailScreen(plan: plan)),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getLevelColor(plan.level).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getLevelLabel(plan.level),
                      style: GoogleFonts.outfit(
                        color: _getLevelColor(plan.level),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (plan.isPremium)
                    const Icon(Icons.workspace_premium_rounded, color: AppTheme.kPrimaryGold, size: 18),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                plan.title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                plan.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _InfoItem(icon: Icons.calendar_today, label: "${plan.durationDays} dias"),
                  const SizedBox(width: 20),
                  if (plan.category != null)
                    _InfoItem(icon: Icons.label_outline_rounded, label: plan.category!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLevelLabel(String level) {
    switch (level.toLowerCase()) {
      case 'beginner': return "INICIANTE";
      case 'intermediate': return "INTERMEDIÁRIO";
      case 'advanced': return "AVANÇADO";
      case 'premium': return "PREMIUM";
      default: return level.toUpperCase();
    }
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'beginner': return Colors.greenAccent;
      case 'intermediate': return Colors.orangeAccent;
      case 'advanced': return Colors.redAccent;
      case 'premium': return AppTheme.kPrimaryGold;
      default: return Colors.blueAccent;
    }
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white24, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
