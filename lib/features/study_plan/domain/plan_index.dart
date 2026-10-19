import 'package:flutter/foundation.dart';
import 'plan_day.dart';
import 'study_plan.dart';

/// Índice em memória do plano de estudo.
/// Achata as 52 semanas em uma lista contínua de 364 dias para consultas em tempo O(1).
@immutable
class PlanIndex {
  final StudyPlan plan;
  final List<PlanDay> days;

  PlanIndex(this.plan)
      : days = List.unmodifiable([
          for (final w in plan.weeks) ...w.days,
        ]);

  int get totalDays => days.length;

  /// Retorna a leitura do dia 1..364 em tempo constante O(1)
  PlanDay dayAt(int n) {
    if (days.isEmpty) {
      throw StateError('O plano não possui dias cadastrados.');
    }
    return days[(n - 1).clamp(0, days.length - 1)];
  }

  /// Retorna a semana (1..52) correspondente ao dia global (1..364)
  static int weekOf(int n) => ((n - 1) ~/ 7) + 1;

  /// Retorna o dia da semana (1..7) correspondente ao dia global (1..364)
  static int dayOfWeek(int n) => ((n - 1) % 7) + 1;

  /// Quantidade de dias concluídos dentro de uma semana específica
  static int completedDaysInWeek(int weekNumber, Set<int> completedDays) {
    int count = 0;
    final startDay = (weekNumber - 1) * 7 + 1;
    for (int d = startDay; d < startDay + 7; d++) {
      if (completedDays.contains(d)) count++;
    }
    return count;
  }

  /// Percentual de conclusão (0.0 a 1.0) de uma semana específica
  static double weekProgress(int weekNumber, Set<int> completedDays) {
    return completedDaysInWeek(weekNumber, completedDays) / 7.0;
  }
}
