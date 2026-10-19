import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import '../../application/study_plan_providers.dart';

class GuiasTab extends ConsumerWidget {
  const GuiasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(studyPlanProgressProvider);
    final percent = (progress.getPercentage(364) * 100).toInt();
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: isTablet ? 32.0 : 16.0,
        right: isTablet ? 32.0 : 16.0,
        top: 20.0,
        bottom: 120.0, // Espaço para a CustomBottomNav flutuante
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Planos de Estudo',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Escolha um plano estruturado para aprofundar sua leitura diária da Bíblia.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),

          // Card do Plano Ativo: Ordem Cronológica
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E1E38),
                  Theme.of(context).colorScheme.surfaceContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppTheme.kPrimaryGold.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'PLANO ATIVO',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$percent% Concluído',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.kPrimaryGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Bíblia em Ordem Cronológica',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Leia toda a Escritura Sagrada em 1 ano, acompanhando a ordem dos acontecimentos históricos e proféticos do Gênesis ao Apocalipse.',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTag('52 Semanas'),
                    _buildTag('364 Dias'),
                    _buildTag('1.189 Capítulos'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'Novos Planos em Breve',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 14),

          if (isTablet)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildUpcomingCard(
                    context,
                    title: 'Novo Testamento em 6 Meses',
                    description:
                        'Uma jornada focada nos quatro evangelhos, nos atos dos apóstolos e em todas as epístolas.',
                    duration: '26 Semanas',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildUpcomingCard(
                    context,
                    title: 'Sabedoria: Salmos e Provérbios',
                    description:
                        'Leituras poéticas e de sabedoria diária para oração, adoração e reflexão espiritual.',
                    duration: '12 Semanas',
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildUpcomingCard(
                  context,
                  title: 'Novo Testamento em 6 Meses',
                  description:
                      'Uma jornada focada nos quatro evangelhos, nos atos dos apóstolos e em todas as epístolas.',
                  duration: '26 Semanas',
                ),
                const SizedBox(height: 12),
                _buildUpcomingCard(
                  context,
                  title: 'Sabedoria: Salmos e Provérbios',
                  description:
                      'Leituras poéticas e de sabedoria diária para oração, adoração e reflexão espiritual.',
                  duration: '12 Semanas',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildUpcomingCard(
    BuildContext context, {
    required String title,
    required String description,
    required String duration,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  duration,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: GoogleFonts.manrope(
              fontSize: 12,
              height: 1.4,
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
