import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:keryx_app/features/study_plan/domain/domain.dart';
import 'package:keryx_app/features/study_plan/data/plan_repository.dart';
import 'package:keryx_app/features/study_plan/data/study_plan_bible_service.dart';
import 'package:keryx_app/features/study_plan/application/study_plan_providers.dart';

void main() {
  group('Passage Domain Model', () {
    test('formatação legível com capítulo único e múltiplos capítulos', () {
      const p1 = Passage(book: 1, from: 1, to: 3);
      expect(p1.bookName, 'Gênesis');
      expect(p1.formattedReference, 'Gênesis 1-3');

      const p2 = Passage(book: 18, from: 5, to: 5);
      expect(p2.bookName, 'Jó');
      expect(p2.formattedReference, 'Jó 5');

      const p3 = Passage(book: 43, from: 1, to: 1, verseFrom: 1, verseTo: 14);
      expect(p3.bookName, 'João');
      expect(p3.formattedReference, 'João 1:1-14');

      const p4 = Passage(book: 19, from: 90, to: 90);
      expect(p4.bookName, 'Salmos');
      expect(p4.formattedReference, 'Salmos 90');
    });

    test('serialização e deserialização toJson / fromJson', () {
      const passage = Passage(
        book: 42,
        from: 1,
        to: 2,
        verseFrom: 1,
        verseTo: 20,
      );
      final json = passage.toJson();
      final restored = Passage.fromJson(json);

      expect(restored, equals(passage));
      expect(restored.book, 42);
      expect(restored.from, 1);
      expect(restored.to, 2);
      expect(restored.verseFrom, 1);
      expect(restored.verseTo, 20);
    });
  });

  group('PlanDay & PlanWeek Domain Models', () {
    test('PlanDay calcula resumo formatado de múltiplas passagens', () {
      const day = PlanDay(
        day: 14,
        passages: [
          Passage(book: 18, from: 41, to: 42),
          Passage(book: 1, from: 12, to: 15),
        ],
      );

      expect(day.formattedSummary, 'Jó 41-42, Gênesis 12-15');
      final json = day.toJson();
      final restored = PlanDay.fromJson(json);
      expect(restored, equals(day));
    });

    test('PlanWeek serializa e deserializa corretamente', () {
      const week = PlanWeek(
        week: 1,
        days: [
          PlanDay(day: 1, passages: [Passage(book: 1, from: 1, to: 3)]),
          PlanDay(day: 2, passages: [Passage(book: 1, from: 4, to: 7)]),
        ],
      );

      expect(week.totalDays, 2);
      final json = week.toJson();
      final restored = PlanWeek.fromJson(json);
      expect(restored, equals(week));
    });
  });

  group('StudyPlan & PlanRepository Parser', () {
    test('faz o parse do arquivo assets/data/plans/cronologico_52.json', () {
      final file = File('assets/data/plans/cronologico_52.json');
      expect(file.existsSync(), isTrue, reason: 'Arquivo de exemplo deve existir');

      final jsonString = file.readAsStringSync();
      final repo = PlanRepository();
      final plan = repo.parsePlanJson(jsonString);

      expect(plan.id, 'cronologico-52');
      expect(plan.title, 'Bíblia em ordem cronológica em 1 ano');
      expect(plan.totalWeeks, 52);
      expect(plan.totalDays, 364);

      // Semana 1
      final week1 = plan.findWeek(1);
      expect(week1, isNotNull);
      expect(week1!.days.length, 7);

      final day1 = plan.findDay(1);
      expect(day1, isNotNull);
      expect(day1!.passages.first.formattedReference, 'Gênesis 1-3');

      final day4 = plan.findDay(4);
      expect(day4, isNotNull);
      expect(day4!.passages.first.formattedReference, 'Jó 1-5');

      // Semana 52 - Último dia com Apocalipse 12-22
      final week52 = plan.findWeek(52);
      expect(week52, isNotNull);
      expect(week52!.days.length, 7);
      final lastDay = week52.days.last;
      expect(lastDay.day, 7);
      expect(lastDay.passages.first.formattedReference, 'Apocalipse 12-22');

      // Roundtrip toJson / fromJson
      final planJson = plan.toJson();
      final restoredPlan = StudyPlan.fromJson(planJson);
      expect(restoredPlan, equals(plan));
    });

    test('PlanIndex achata 364 dias e permite consulta O(1)', () {
      final file = File('assets/data/plans/cronologico_52.json');
      final plan = PlanRepository().parsePlanJson(file.readAsStringSync());
      final index = PlanIndex(plan);

      expect(index.totalDays, 364);
      expect(index.dayAt(1).passages.first.formattedReference, 'Gênesis 1-3');
      expect(index.dayAt(364).passages.first.formattedReference, 'Apocalipse 12-22');

      // Teste das funções de semana e dia da semana
      expect(PlanIndex.weekOf(1), 1);
      expect(PlanIndex.weekOf(7), 1);
      expect(PlanIndex.weekOf(8), 2);
      expect(PlanIndex.weekOf(364), 52);

      expect(PlanIndex.dayOfWeek(1), 1);
      expect(PlanIndex.dayOfWeek(7), 7);
      expect(PlanIndex.dayOfWeek(8), 1);

      // Progresso da semana
      expect(PlanIndex.completedDaysInWeek(1, const {1, 2, 3}), 3);
      expect(PlanIndex.weekProgress(1, const {1, 2, 3, 4, 5, 6, 7}), 1.0);
    });
  });

  group('PlanProgress Domain Model', () {
    test('cálculo de percentual e alternância de dias', () {
      final now = DateTime(2026, 1, 1);
      final progress = PlanProgress(
        planId: 'cronologico-52',
        startDate: now,
        completedDays: const {1, 2, 3},
        streak: 3,
      );

      expect(progress.isDayCompleted(1), isTrue);
      expect(progress.isDayCompleted(4), isFalse);
      expect(progress.totalCompleted, 3);
      expect(progress.getPercentage(10), 0.3);

      final json = progress.toJson();
      final restored = PlanProgress.fromJson(json);
      expect(restored, equals(progress));
    });

    test('anotações diárias (hasNote, getNote, totalNotes e serialização)', () {
      final now = DateTime(2026, 1, 1);
      final progress = PlanProgress(
        planId: 'cronologico-52',
        startDate: now,
        completedDays: const {1, 2},
        notes: const {
          1: 'Reflexão sobre a Criação.',
          2: 'A queda do homem e a promessa.',
        },
      );

      expect(progress.hasNote(1), isTrue);
      expect(progress.hasNote(3), isFalse);
      expect(progress.getNote(1), 'Reflexão sobre a Criação.');
      expect(progress.getNote(3), isNull);
      expect(progress.totalNotes, 2);

      final json = progress.toJson();
      final restored = PlanProgress.fromJson(json);
      expect(restored, equals(progress));
      expect(restored.hasNote(2), isTrue);
      expect(restored.getNote(2), 'A queda do homem e a promessa.');
    });
  });

  group('StudyPlanNotifier & Backup JSON', () {
    test('salvar e remover anotações por dia', () async {
      final notifier = StudyPlanNotifier(null);
      expect(notifier.state.notes.isEmpty, isTrue);

      await notifier.saveNote(1, 'Primeira nota');
      expect(notifier.state.hasNote(1), isTrue);
      expect(notifier.state.getNote(1), 'Primeira nota');

      // Atualizar nota
      await notifier.saveNote(1, 'Nota atualizada');
      expect(notifier.state.getNote(1), 'Nota atualizada');

      // Remover com texto vazio
      await notifier.saveNote(1, '   ');
      expect(notifier.state.hasNote(1), isFalse);
    });

    test('exportar e importar backup JSON com restauração total', () async {
      final notifier = StudyPlanNotifier(null);
      await notifier.toggleDay(1);
      await notifier.toggleDay(2);
      await notifier.saveNote(1, 'Estudo de Gênesis 1');

      final exportedJson = notifier.exportProgressJson();
      expect(exportedJson.contains('cronologico-52'), isTrue);
      expect(exportedJson.contains('Estudo de Gênesis 1'), isTrue);

      // Novo notifier simulando outro dispositivo/estado limpo
      final freshNotifier = StudyPlanNotifier(null);
      expect(freshNotifier.state.completedDays.isEmpty, isTrue);

      final success = await freshNotifier.importProgressJson(exportedJson);
      expect(success, isTrue);
      expect(freshNotifier.state.isDayCompleted(1), isTrue);
      expect(freshNotifier.state.isDayCompleted(2), isTrue);
      expect(freshNotifier.state.getNote(1), 'Estudo de Gênesis 1');

      // Tentar importar JSON inválido
      final invalidSuccess = await freshNotifier.importProgressJson('not a json');
      expect(invalidSuccess, isFalse);
    });

    test('cálculo do streak diário sequencial', () async {
      final notifier = StudyPlanNotifier(null);
      final day1 = DateTime(2026, 3, 1, 10, 0);
      final day2 = DateTime(2026, 3, 2, 11, 0);

      await notifier.toggleDay(1, now: day1);
      expect(notifier.state.streak, 1);

      await notifier.toggleDay(2, now: day2);
      expect(notifier.state.streak, 2);
    });
  });

  group('calculateTodayPlanInfo', () {
    test('calcula corretamente o dia do plano baseado na data de início', () {
      final start = DateTime(2026, 1, 1);

      // No mesmo dia do início
      final infoDay1 = calculateTodayPlanInfo(start, const {}, currentDate: DateTime(2026, 1, 1));
      expect(infoDay1.day, 1);
      expect(infoDay1.week, 1);
      expect(infoDay1.dayOfWeek, 1);

      // No dia 8 (Semana 2, Dia 1)
      final infoDay8 = calculateTodayPlanInfo(start, const {8}, currentDate: DateTime(2026, 1, 8));
      expect(infoDay8.day, 8);
      expect(infoDay8.week, 2);
      expect(infoDay8.dayOfWeek, 1);
      expect(infoDay8.isCompleted, isTrue);
    });
  });

  group('StudyVerseParser', () {
    test('limpa tags de tempo verbal e preserva tags Strong', () {
      const raw =
          '>No princípio<WH7225> criou<WH1254><H8804> Deus<WH430> os céus<WH8064> e a terra<WH776>.';
      final clean = StudyVerseParser.preprocess(raw);
      expect(clean.contains('<H8804>'), isFalse);
      expect(clean.contains('<WH7225>'), isTrue);
      expect(clean.contains('<WH1254>'), isTrue);
      expect(clean.startsWith('>'), isFalse);
    });

    test('corrige tags malformadas com prefixo colado', () {
      const raw = '><Mas<WG1161> Jesus<WG2424><G5656>';
      final clean = StudyVerseParser.preprocess(raw);
      expect(clean.contains('Mas<WG1161>'), isTrue);
      expect(clean.contains('<G5656>'), isFalse);
    });
  });
}
