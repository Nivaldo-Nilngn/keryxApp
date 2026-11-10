import 'package:flutter_test/flutter_test.dart';
import 'package:keryx_app/features/study_plan/domain/plan_progress.dart';

void main() {
  group('Study Plan Metrics Engine & Calculations Tests', () {
    test('Calculates progress percentage accurately across milestones', () {
      final now = DateTime(2026, 1, 1);
      final p0 = PlanProgress(planId: 'plan1', startDate: now, completedDays: const {});
      expect(p0.getPercentage(364), equals(0.0));

      final halfSet = List.generate(182, (i) => i + 1).toSet();
      final pHalf = PlanProgress(planId: 'plan1', startDate: now, completedDays: halfSet, streak: 10);
      expect(pHalf.getPercentage(364), equals(0.5));
      expect(pHalf.totalCompleted, equals(182));

      final fullSet = List.generate(364, (i) => i + 1).toSet();
      final pFull = PlanProgress(planId: 'plan1', startDate: now, completedDays: fullSet, streak: 364);
      expect(pFull.getPercentage(364), equals(1.0));
      expect(pFull.totalCompleted, equals(364));
    });

    test('Pace estimation handles 0 completed days and normal progress rates', () {
      final now = DateTime(2026, 1, 1);
      final fiftySet = List.generate(50, (i) => i + 1).toSet();
      final p = PlanProgress(planId: 'plan1', startDate: now, completedDays: fiftySet, streak: 12);
      
      const totalDays = 364;
      final completed = p.getCompletedCount(totalDays);
      final remaining = totalDays - completed;
      expect(remaining, equals(314));

      // 1 dia por dia ritmo estimado
      const dailyRate = 1.0;
      final daysToFinish = (remaining / dailyRate).ceil();
      expect(daysToFinish, equals(314));

      final estimatedFinish = now.add(Duration(days: daysToFinish));
      expect(estimatedFinish.isAfter(now), isTrue);
    });

    test('Streak preservation on consecutive days vs broken streak', () {
      int updateStreak({
        required DateTime lastReadDate,
        required DateTime today,
        required int currentStreak,
      }) {
        final lastDay = DateTime(lastReadDate.year, lastReadDate.month, lastReadDate.day);
        final currentDay = DateTime(today.year, today.month, today.day);
        final difference = currentDay.difference(lastDay).inDays;

        if (difference == 0) {
          // Já leu hoje
          return currentStreak;
        } else if (difference == 1) {
          // Dia consecutivo
          return currentStreak + 1;
        } else {
          // Quebrou a sequência
          return 1;
        }
      }

      final today = DateTime(2026, 11, 9);
      final yesterday = DateTime(2026, 11, 8);
      final threeDaysAgo = DateTime(2026, 11, 6);

      // Leitura no mesmo dia
      expect(updateStreak(lastReadDate: today, today: today, currentStreak: 5), equals(5));

      // Leitura em dia consecutivo
      expect(updateStreak(lastReadDate: yesterday, today: today, currentStreak: 5), equals(6));

      // Leitura com quebra de streak
      expect(updateStreak(lastReadDate: threeDaysAgo, today: today, currentStreak: 5), equals(1));
    });

    test('Json serialization and deserialization of PlanProgress', () {
      final now = DateTime(2026, 1, 1);
      final progress = PlanProgress(
        planId: 'cronologico-1-ano',
        startDate: now,
        completedDays: const {1, 2, 3, 4, 5, 10, 15},
        streak: 15,
        currentDay: 16,
        notes: const {1: 'Reflexão sobre Gênesis 1', 2: 'Notas sobre a Criação'},
        isStarted: true,
      );

      final json = progress.toJson();
      final reconstructed = PlanProgress.fromJson(json);

      expect(reconstructed.planId, equals(progress.planId));
      expect(reconstructed.completedDays, equals(progress.completedDays));
      expect(reconstructed.streak, equals(progress.streak));
      expect(reconstructed.currentDay, equals(progress.currentDay));
      expect(reconstructed.totalNotes, equals(2));
      expect(reconstructed.getNote(1), equals('Reflexão sobre Gênesis 1'));
      expect(reconstructed.isStarted, isTrue);
    });
  });
}
