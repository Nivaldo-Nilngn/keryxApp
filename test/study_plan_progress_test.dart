import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/features/study_plan/domain/domain.dart';
import 'package:keryx_app/features/study_plan/application/study_plan_providers.dart';

void main() {
  group('Cálculo de TodayPlanInfo e Sequência de Dias', () {
    test('Plano novo sem currentDay aponta para o Dia 1 pendente', () {
      final progress = PlanProgress.initial('cronologico-52');
      final info = calculateProgressTodayPlanInfo(progress, 364);

      expect(info.day, 1);
      expect(info.week, 1);
      expect(info.dayOfWeek, 1);
      expect(info.isCompleted, isFalse);
    });

    test('Quando o Dia 1 é concluído, aponta automaticamente para o Dia 2', () {
      final progress = PlanProgress.initial('cronologico-52').copyWith(
        completedDays: {1},
        currentDay: 2,
      );
      final info = calculateProgressTodayPlanInfo(progress, 364);

      expect(info.day, 2);
      expect(info.week, 1);
      expect(info.dayOfWeek, 2);
      expect(info.isCompleted, isFalse);
    });

    test('Navegação manual de dia respeita currentDay selecionado', () {
      // Usuário quis olhar a Semana 3 (Dia 15)
      final progress = PlanProgress.initial('cronologico-52').copyWith(
        completedDays: {1, 2},
        currentDay: 15,
      );
      final info = calculateProgressTodayPlanInfo(progress, 364);

      expect(info.day, 15);
      expect(info.week, 3); // ((15 - 1) ~/ 7) + 1 = 3
      expect(info.dayOfWeek, 1); // ((15 - 1) % 7) + 1 = 1
      expect(info.isCompleted, isFalse);
    });
  });

  group('StudyPlanNotifier - Cenários Reais Solicitados', () {
    test('Cenário 1 e 2: Concluir Dia 1, salvar e avançar para o Dia 2', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = StudyPlanNotifier(
        prefs,
        planId: 'cronologico-52',
        uid: 'user_test_123',
      );

      // Conclui o Dia 1
      await notifier.toggleDay(1, totalDays: 364);

      expect(notifier.state.completedDays.contains(1), isTrue);
      expect(notifier.state.currentDay, 2);
      expect(notifier.state.streak, 1);

      // Simula fechar e reabrir o app / recarregar a página com o mesmo usuário
      final reloadedNotifier = StudyPlanNotifier(
        prefs,
        planId: 'cronologico-52',
        uid: 'user_test_123',
      );

      // Verifica se o Dia 1 continua concluído permanentemente e o Dia 2 é o próximo
      expect(reloadedNotifier.state.completedDays.contains(1), isTrue);
      expect(reloadedNotifier.state.currentDay, 2);

      final nextInfo = calculateProgressTodayPlanInfo(reloadedNotifier.state, 364);
      expect(nextInfo.day, 2);
      expect(nextInfo.isCompleted, isFalse);
    });

    test('Cenário 3: Iniciar diretamente pelo Dia 2 e confirmar que o Dia 1 NÃO é marcado', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = StudyPlanNotifier(
        prefs,
        planId: 'cronologico-52',
        uid: 'user_test_456',
      );

      // Define Dia 2 e marca como concluído
      await notifier.setCurrentDay(2);
      await notifier.toggleDay(2, totalDays: 364);

      // Apenas o Dia 2 deve estar concluído
      expect(notifier.state.completedDays.contains(1), isFalse);
      expect(notifier.state.completedDays.contains(2), isTrue);
      expect(notifier.state.completedDays.length, 1);
      // Avança para o Dia 3
      expect(notifier.state.currentDay, 3);
    });

    test('Cenário 4: Concluir dia da Semana 1 NÃO contamina as semanas 2, 3 e 4', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = StudyPlanNotifier(
        prefs,
        planId: 'cronologico-52',
        uid: 'user_test_789',
      );

      // Marca o Dia 1 (Semana 1)
      await notifier.toggleDay(1, totalDays: 364);

      final completed = notifier.state.completedDays;

      // Semana 1: dias 1 a 7
      final week1Days = List.generate(7, (i) => i + 1);
      final week1Completed = week1Days.where((d) => completed.contains(d)).length;
      expect(week1Completed, 1); // 1 de 7 lidos

      // Semana 2: dias 8 a 14
      final week2Days = List.generate(7, (i) => i + 8);
      final week2Completed = week2Days.where((d) => completed.contains(d)).length;
      expect(week2Completed, 0); // 0 de 7 (0%)

      // Semana 3: dias 15 a 21
      final week3Days = List.generate(7, (i) => i + 15);
      final week3Completed = week3Days.where((d) => completed.contains(d)).length;
      expect(week3Completed, 0); // 0 de 7 (0%)

      // Semana 4: dias 22 a 28
      final week4Days = List.generate(7, (i) => i + 22);
      final week4Completed = week4Days.where((d) => completed.contains(d)).length;
      expect(week4Completed, 0); // 0 de 7 (0%)
    });

    test('Isolamento entre usuários diferentes no mesmo dispositivo', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Usuário A conclui Dia 1 e 2
      final userANotifier = StudyPlanNotifier(
        prefs,
        planId: 'cronologico-52',
        uid: 'user_A',
      );
      await userANotifier.toggleDay(1, totalDays: 364);
      await userANotifier.toggleDay(2, totalDays: 364);
      expect(userANotifier.state.completedDays, {1, 2});

      // Usuário B faz login no mesmo dispositivo
      final userBNotifier = StudyPlanNotifier(
        prefs,
        planId: 'cronologico-52',
        uid: 'user_B',
      );
      // O progresso de B deve estar zerado e independente
      expect(userBNotifier.state.completedDays, isEmpty);
      expect(userBNotifier.state.streak, 0);
    });

    test('Desmarcar dia atualiza corretamente', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = StudyPlanNotifier(
        prefs,
        planId: 'cronologico-52',
        uid: 'user_test_desmarcar',
      );

      await notifier.toggleDay(1, totalDays: 364);
      expect(notifier.state.completedDays.contains(1), isTrue);

      // Desmarca o Dia 1
      await notifier.toggleDay(1, totalDays: 364);
      expect(notifier.state.completedDays.contains(1), isFalse);
      expect(notifier.state.completedDays, isEmpty);
    });
  });
}
