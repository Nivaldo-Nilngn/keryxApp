import 'package:flutter/foundation.dart';

@immutable
class PlanProgress {
  final String planId;
  final DateTime startDate;
  final Set<int>? _completedDays; // Conjunto de dias concluídos (1..364)
  final int streak; // Sequência atual de dias seguidos lidos
  final DateTime? lastCompletedDate; // Data da última leitura realizada
  final Map<int, String>? _notes; // Anotações e reflexões por dia (dia -> texto)

  Set<int> get completedDays => _completedDays ?? const {};
  Map<int, String> get notes => _notes ?? const {};

  const PlanProgress({
    required this.planId,
    required this.startDate,
    Set<int>? completedDays,
    this.streak = 0,
    this.lastCompletedDate,
    Map<int, String>? notes,
  })  : _completedDays = completedDays,
        _notes = notes;

  /// Progresso vazio/inicial para um plano
  factory PlanProgress.initial(String planId) {
    return PlanProgress(
      planId: planId,
      startDate: DateTime.now(),
      completedDays: const {},
      streak: 0,
      notes: const {},
    );
  }

  /// Verifica se um dia específico está marcado como concluído
  bool isDayCompleted(int day) => completedDays.contains(day);

  /// Verifica se há anotação registrada para o dia
  bool hasNote(int day) => notes[day]?.trim().isNotEmpty ?? false;

  /// Retorna a anotação do dia ou null
  String? getNote(int day) => notes[day];

  /// Total de dias com anotação registrada
  int get totalNotes => notes.values.where((n) => n.trim().isNotEmpty).length;

  /// Total de dias já concluídos
  int get totalCompleted => completedDays.length;

  /// Percentual de conclusão baseado no total de dias do plano
  double getPercentage(int totalDays) {
    if (totalDays <= 0) return 0.0;
    return (completedDays.length / totalDays).clamp(0.0, 1.0);
  }

  PlanProgress copyWith({
    String? planId,
    DateTime? startDate,
    Set<int>? completedDays,
    int? streak,
    DateTime? lastCompletedDate,
    Map<int, String>? notes,
  }) {
    return PlanProgress(
      planId: planId ?? this.planId,
      startDate: startDate ?? this.startDate,
      completedDays: completedDays ?? this.completedDays,
      streak: streak ?? this.streak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      notes: notes ?? this.notes,
    );
  }

  factory PlanProgress.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['notes'] as Map<dynamic, dynamic>?;
    final Map<int, String> parsedNotes = {};
    if (rawNotes != null) {
      for (final entry in rawNotes.entries) {
        final day = int.tryParse(entry.key.toString());
        if (day != null && entry.value != null) {
          parsedNotes[day] = entry.value.toString();
        }
      }
    }

    return PlanProgress(
      planId: json['planId'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      completedDays: ((json['completedDays'] as List<dynamic>?) ?? [])
          .map((d) => d as int)
          .toSet(),
      streak: (json['streak'] as int?) ?? 0,
      lastCompletedDate: json['lastCompletedDate'] != null
          ? DateTime.tryParse(json['lastCompletedDate'] as String)
          : null,
      notes: parsedNotes,
    );
  }

  Map<String, dynamic> toJson() => {
    'planId': planId,
    'startDate': startDate.toIso8601String(),
    'completedDays': completedDays.toList()..sort(),
    'streak': streak,
    if (lastCompletedDate != null)
      'lastCompletedDate': lastCompletedDate!.toIso8601String(),
    if (notes.isNotEmpty)
      'notes': notes.map((k, v) => MapEntry(k.toString(), v)),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanProgress &&
          runtimeType == other.runtimeType &&
          planId == other.planId &&
          startDate == other.startDate &&
          setEquals(completedDays, other.completedDays) &&
          streak == other.streak &&
          lastCompletedDate == other.lastCompletedDate &&
          mapEquals(notes, other.notes);

  @override
  int get hashCode => Object.hash(
        planId,
        startDate,
        Object.hashAll(completedDays),
        streak,
        lastCompletedDate,
        Object.hashAll(notes.entries),
      );

  @override
  String toString() =>
      'PlanProgress(planId: $planId, completed: ${completedDays.length}, streak: $streak, notes: ${notes.length})';
}
