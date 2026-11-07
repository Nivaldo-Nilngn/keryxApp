import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Exibe feedback háptico e um SnackBar flutuante elegante ao alternar a conclusão de um dia de leitura
void showStudyPlanCelebrationSnackbar({
  required BuildContext context,
  required int dayNumber,
  required bool wasCompleted,
  int? nextDay,
}) {
  try {
    HapticFeedback.lightImpact();
  } catch (_) {}

  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();

  final isCelebrating = !wasCompleted;

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isCelebrating
          ? const Color(0xFF0F766E) // teal refinado comemorativo
          : const Color(0xFF334155), // slate neutro se desmarcar
      content: Row(
        children: [
          Icon(
            isCelebrating
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            color: isCelebrating ? const Color(0xFF34D399) : Colors.white70,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isCelebrating
                  ? (nextDay != null && nextDay > dayNumber
                      ? '🎉 Dia $dayNumber concluído com sucesso!\nAvançando para o Dia $nextDay.'
                      : '🎉 Dia $dayNumber concluído com sucesso!')
                  : 'Dia $dayNumber desmarcado.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 2800),
    ),
  );
}

