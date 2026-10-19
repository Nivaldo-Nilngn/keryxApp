import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/features/study_plan/application/study_plan_providers.dart';

void main() {
  group('Cálculo de TodayPlanInfo', () {
    test('início hoje resulta no dia 1, semana 1, dia da semana 1', () {
      final now = DateTime(2026, 1, 1, 14, 30);
      final info = calculateTodayPlanInfo(
        DateTime(2026, 1, 1, 8, 0),
        {},
        currentDate: now,
      );

      expect(info.day, 1);
      expect(info.week, 1);
      expect(info.dayOfWeek, 1);
      expect(info.isCompleted, isFalse);
    });

    test('início há 6 dias resulta no dia 7 da semana 1', () {
      final start = DateTime(2026, 1, 1);
      final current = DateTime(2026, 1, 7); // 6 dias depois
      final info = calculateTodayPlanInfo(
        start,
        {7},
        currentDate: current,
      );

      expect(info.day, 7);
      expect(info.week, 1);
      expect(info.dayOfWeek, 7);
      expect(info.isCompleted, isTrue);
    });

    test('início há 7 dias resulta no dia 8 da semana 2, dia da semana 1', () {
      final start = DateTime(2026, 1, 1);
      final current = DateTime(2026, 1, 8); // 7 dias depois
      final info = calculateTodayPlanInfo(
        start,
        {},
        currentDate: current,
      );

      expect(info.day, 8);
      expect(info.week, 2);
      expect(info.dayOfWeek, 1);
    });

    test('início no meio do plano (dia 150)', () {
      final start = DateTime(2026, 1, 1);
      final current = start.add(const Duration(days: 149)); // dia 150
      final info = calculateTodayPlanInfo(
        start,
        {},
        currentDate: current,
      );

      expect(info.day, 150);
      expect(info.week, 22); // ((150 - 1) ~/ 7) + 1 = 21 + 1 = 22
      expect(info.dayOfWeek, 3); // ((150 - 1) % 7) + 1 = 2 + 1 = 3
    });

    test('depois do fim do plano (mais de 364 dias) limita ao dia 364', () {
      final start = DateTime(2025, 1, 1);
      final current = DateTime(2026, 6, 1); // mais de 500 dias depois
      final info = calculateTodayPlanInfo(
        start,
        {},
        currentDate: current,
      );

      expect(info.day, 364);
      expect(info.week, 52);
      expect(info.dayOfWeek, 7);
    });

    test('data no futuro limita ao dia 1', () {
      final start = DateTime(2026, 2, 1);
      final current = DateTime(2026, 1, 1); // 1 mês antes
      final info = calculateTodayPlanInfo(
        start,
        {},
        currentDate: current,
      );

      expect(info.day, 1);
      expect(info.week, 1);
      expect(info.dayOfWeek, 1);
    });
  });

  group('StudyPlanNotifier com SharedPreferences mock', () {
    test('alternar dias e atualizar streak', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = StudyPlanNotifier(prefs);

      // Marca o dia 1 hoje
      final day1Time = DateTime(2026, 1, 1, 10, 0);
      await notifier.toggleDay(1, now: day1Time);

      expect(notifier.state.completedDays.contains(1), isTrue);
      expect(notifier.state.streak, 1);

      // Marca o dia 2 no dia seguinte -> streak vira 2
      final day2Time = DateTime(2026, 1, 2, 10, 0);
      await notifier.toggleDay(2, now: day2Time);

      expect(notifier.state.completedDays.contains(2), isTrue);
      expect(notifier.state.streak, 2);

      // Desmarca o dia 2
      await notifier.toggleDay(2, now: day2Time);
      expect(notifier.state.completedDays.contains(2), isFalse);

      // Reset
      await notifier.reset();
      expect(notifier.state.completedDays, isEmpty);
      expect(notifier.state.streak, 0);
    });
  });
}
