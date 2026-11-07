import 'package:flutter/foundation.dart';
import 'passage.dart';
import 'plan_day.dart';
import 'plan_week.dart';

@immutable
class StudyPlan {
  final String id;
  final String title;
  final String? description;
  final List<PlanWeek> weeks;

  const StudyPlan({
    required this.id,
    required this.title,
    this.description,
    required this.weeks,
  });

  /// Quantidade total de semanas no plano
  int get totalWeeks => weeks.length;

  /// Quantidade total de dias no plano
  int get totalDays => weeks.fold<int>(0, (acc, w) => acc + w.days.length);

  /// Busca o dia pelo número do dia (global ou relativo)
  PlanDay? findDay(int dayNumber) {
    for (final week in weeks) {
      for (final day in week.days) {
        if (day.day == dayNumber) return day;
      }
    }
    return null;
  }

  /// Busca a semana pelo número
  PlanWeek? findWeek(int weekNumber) {
    for (final week in weeks) {
      if (week.week == weekNumber) return week;
    }
    return null;
  }

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    int runningGlobalDay = 1;
    final rawWeeks = json['weeks'] as List<dynamic>;
    final List<PlanWeek> parsedWeeks = [];

    for (final w in rawWeeks) {
      final wMap = w as Map<String, dynamic>;
      final weekNum = wMap['week'] as int;
      final rawDays = wMap['days'] as List<dynamic>;
      final List<PlanDay> parsedDays = [];
      for (final d in rawDays) {
        final dMap = d as Map<String, dynamic>;
        int dayNum = dMap['day'] as int;
        // Garante numeração estritamente contínua global para cada dia do plano
        if (dayNum < runningGlobalDay) {
          dayNum = runningGlobalDay;
        } else {
          runningGlobalDay = dayNum;
        }
        runningGlobalDay++;
        parsedDays.add(PlanDay(
          day: dayNum,
          passages: (dMap['passages'] as List<dynamic>)
              .map((p) => Passage.fromJson(p as Map<String, dynamic>))
              .toList(growable: false),
        ));
      }
      parsedWeeks.add(PlanWeek(week: weekNum, days: parsedDays));
    }

    return StudyPlan(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      weeks: parsedWeeks,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (description != null) 'description': description,
    'weeks': weeks.map((w) => w.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyPlan &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          listEquals(weeks, other.weeks);

  @override
  int get hashCode => Object.hash(id, title, description, Object.hashAll(weeks));

  @override
  String toString() => 'StudyPlan(id: $id, title: $title, weeks: ${weeks.length})';
}
