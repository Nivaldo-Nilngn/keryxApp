import 'package:flutter/foundation.dart';
import 'plan_day.dart';

@immutable
class PlanWeek {
  final int week; // Semana do plano (1..52)
  final List<PlanDay> days;

  const PlanWeek({
    required this.week,
    required this.days,
  });

  int get totalDays => days.length;

  factory PlanWeek.fromJson(Map<String, dynamic> json) {
    return PlanWeek(
      week: json['week'] as int,
      days: (json['days'] as List<dynamic>)
          .map((d) => PlanDay.fromJson(d as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'week': week,
    'days': days.map((d) => d.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanWeek &&
          runtimeType == other.runtimeType &&
          week == other.week &&
          listEquals(days, other.days);

  @override
  int get hashCode => Object.hash(week, Object.hashAll(days));

  @override
  String toString() => 'PlanWeek(week: $week, days: ${days.length})';
}
