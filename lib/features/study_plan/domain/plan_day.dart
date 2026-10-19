import 'package:flutter/foundation.dart';
import 'passage.dart';

@immutable
class PlanDay {
  final int day; // Dia do plano (1..364 ou índice do dia)
  final List<Passage> passages;

  const PlanDay({
    required this.day,
    required this.passages,
  });

  /// Descrição textual resumida de todas as passagens do dia (ex.: "Gênesis 1-3" ou "Lucas 1:1, João 1:1-14")
  String get formattedSummary => passages.map((p) => p.formattedReference).join(', ');

  factory PlanDay.fromJson(Map<String, dynamic> json) {
    return PlanDay(
      day: json['day'] as int,
      passages: (json['passages'] as List<dynamic>)
          .map((p) => Passage.fromJson(p as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'day': day,
    'passages': passages.map((p) => p.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanDay &&
          runtimeType == other.runtimeType &&
          day == other.day &&
          listEquals(passages, other.passages);

  @override
  int get hashCode => Object.hash(day, Object.hashAll(passages));

  @override
  String toString() => 'PlanDay(day: $day, passages: $formattedSummary)';
}
