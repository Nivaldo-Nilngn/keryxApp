import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/core/state/font_state.dart';
import '../data/plan_repository.dart';
import '../domain/domain.dart';

/// Informações do dia de leitura de hoje
@immutable
class TodayPlanInfo {
  final int day; // Dia global do plano (1..364)
  final int week; // Semana do plano (1..52)
  final int dayOfWeek; // Dia da semana no plano (1..7)
  final bool isCompleted;

  const TodayPlanInfo({
    required this.day,
    required this.week,
    required this.dayOfWeek,
    required this.isCompleted,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodayPlanInfo &&
          runtimeType == other.runtimeType &&
          day == other.day &&
          week == other.week &&
          dayOfWeek == other.dayOfWeek &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode => Object.hash(day, week, dayOfWeek, isCompleted);

  @override
  String toString() =>
      'TodayPlanInfo(day: $day, week: $week, dayOfWeek: $dayOfWeek, isCompleted: $isCompleted)';
}

/// Carrega o plano cronológico de 52 semanas em memória uma única vez
final chronologicalPlanProvider = FutureProvider<StudyPlan>((ref) async {
  final repo = ref.watch(planRepositoryProvider);
  return repo.loadChronologicalPlan();
});

/// Índice em memória do plano para acesso O(1)
final chronologicalIndexProvider = FutureProvider<PlanIndex>((ref) async {
  final plan = await ref.watch(chronologicalPlanProvider.future);
  return PlanIndex(plan);
});

/// Notifier que gerencia o estado e progresso do plano de estudo
class StudyPlanNotifier extends StateNotifier<PlanProgress> {
  final SharedPreferences? _prefs;
  final String planId;

  StudyPlanNotifier(this._prefs, {this.planId = 'cronologico-52'})
      : super(PlanProgress.initial(planId)) {
    _loadFromStorage();
  }

  String get _keyStartDate => 'study_plan_start_date_$planId';
  String get _keyCompletedDays => 'study_plan_completed_days_$planId';
  String get _keyStreak => 'study_plan_streak_$planId';
  String get _keyLastDate => 'study_plan_last_date_$planId';
  String get _keyNotes => 'study_plan_notes_$planId';

  void _loadFromStorage() {
    if (_prefs == null) return;

    final startStr = _prefs.getString(_keyStartDate);
    final startDate = startStr != null
        ? DateTime.tryParse(startStr) ?? DateTime.now()
        : DateTime.now();

    final completedList = _prefs.getStringList(_keyCompletedDays) ?? [];
    final completedDays = completedList
        .map((s) => int.tryParse(s))
        .whereType<int>()
        .toSet();

    final streak = _prefs.getInt(_keyStreak) ?? 0;

    final lastStr = _prefs.getString(_keyLastDate);
    final lastCompletedDate =
        lastStr != null ? DateTime.tryParse(lastStr) : null;

    final notesStr = _prefs.getString(_keyNotes);
    Map<int, String> notes = {};
    if (notesStr != null) {
      try {
        final decoded = jsonDecode(notesStr) as Map<String, dynamic>;
        notes = decoded.map((k, v) => MapEntry(int.parse(k), v.toString()));
      } catch (_) {}
    }

    state = PlanProgress(
      planId: planId,
      startDate: startDate,
      completedDays: completedDays,
      streak: streak,
      lastCompletedDate: lastCompletedDate,
      notes: notes,
    );
  }

  /// Define a data de início do plano (ex.: 1º de Janeiro ou hoje)
  Future<void> setStartDate(DateTime date) async {
    state = state.copyWith(startDate: date);
    if (_prefs != null) {
      await _prefs.setString(_keyStartDate, date.toIso8601String());
    }
  }

  /// Salva ou remove uma anotação/reflexão de um dia específico
  Future<void> saveNote(int dayNumber, String text) async {
    final updatedNotes = Map<int, String>.from(state.notes);
    if (text.trim().isEmpty) {
      updatedNotes.remove(dayNumber);
    } else {
      updatedNotes[dayNumber] = text.trim();
    }
    state = state.copyWith(notes: updatedNotes);
    if (_prefs != null) {
      await _prefs.setString(
        _keyNotes,
        jsonEncode(updatedNotes.map((k, v) => MapEntry(k.toString(), v))),
      );
    }
  }

  /// Exporta o progresso completo em formato JSON para backup
  String exportProgressJson() {
    return const JsonEncoder.withIndent('  ').convert(state.toJson());
  }

  /// Importa e restaura o progresso a partir de uma string JSON
  Future<bool> importProgressJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final imported = PlanProgress.fromJson(decoded);
      state = imported;
      if (_prefs != null) {
        await _prefs.setString(
          _keyStartDate,
          imported.startDate.toIso8601String(),
        );
        await _prefs.setStringList(
          _keyCompletedDays,
          imported.completedDays.map((e) => e.toString()).toList(),
        );
        await _prefs.setInt(_keyStreak, imported.streak);
        if (imported.lastCompletedDate != null) {
          await _prefs.setString(
            _keyLastDate,
            imported.lastCompletedDate!.toIso8601String(),
          );
        } else {
          await _prefs.remove(_keyLastDate);
        }
        await _prefs.setString(
          _keyNotes,
          jsonEncode(imported.notes.map((k, v) => MapEntry(k.toString(), v))),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Alterna o estado de conclusão de um dia (1..364)
  Future<void> toggleDay(int dayNumber, {DateTime? now}) async {
    final currentCompleted = Set<int>.from(state.completedDays);
    final currentTime = now ?? DateTime.now();
    int newStreak = state.streak;
    DateTime? newLastDate = state.lastCompletedDate;

    if (currentCompleted.contains(dayNumber)) {
      // Desmarcar
      currentCompleted.remove(dayNumber);
    } else {
      // Marcar como concluído
      currentCompleted.add(dayNumber);

      // Atualiza o streak baseado na data
      if (newLastDate == null) {
        newStreak = 1;
      } else {
        final todayNorm = DateTime(currentTime.year, currentTime.month, currentTime.day);
        final lastNorm = DateTime(newLastDate.year, newLastDate.month, newLastDate.day);
        final diffDays = todayNorm.difference(lastNorm).inDays;

        if (diffDays == 1) {
          // Leu no dia seguinte: incrementa sequência
          newStreak += 1;
        } else if (diffDays == 0) {
          // Já leu hoje: mantém streak atual
          newStreak = newStreak == 0 ? 1 : newStreak;
        } else {
          // Quebrou a sequência: reinicia em 1
          newStreak = 1;
        }
      }
      newLastDate = currentTime;
    }

    state = state.copyWith(
      completedDays: currentCompleted,
      streak: newStreak,
      lastCompletedDate: newLastDate,
    );

    if (_prefs != null) {
      await _prefs.setStringList(
        _keyCompletedDays,
        currentCompleted.map((e) => e.toString()).toList(),
      );
      await _prefs.setInt(_keyStreak, newStreak);
      if (newLastDate != null) {
        await _prefs.setString(_keyLastDate, newLastDate.toIso8601String());
      }
    }
  }

  /// Reinicia todo o progresso do plano
  Future<void> reset() async {
    final now = DateTime.now();
    state = PlanProgress.initial(planId).copyWith(startDate: now);

    if (_prefs != null) {
      await _prefs.remove(_keyStartDate);
      await _prefs.remove(_keyCompletedDays);
      await _prefs.remove(_keyStreak);
      await _prefs.remove(_keyLastDate);
      await _prefs.remove(_keyNotes);
    }
  }
}

/// Provider do estado e progresso do plano
final studyPlanProgressProvider =
    StateNotifierProvider<StudyPlanNotifier, PlanProgress>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // Para ambientes de teste isolados sem override
  }
  return StudyPlanNotifier(prefs);
});

/// Calcula dinamicamente o dia de leitura correspondente a hoje
final todayPlanDayProvider = Provider<TodayPlanInfo>((ref) {
  final progress = ref.watch(studyPlanProgressProvider);
  return calculateTodayPlanInfo(progress.startDate, progress.completedDays);
});

/// Helper puro testável para cálculo da data/dia de hoje
TodayPlanInfo calculateTodayPlanInfo(
  DateTime startDate,
  Set<int> completedDays, {
  DateTime? currentDate,
}) {
  final now = currentDate ?? DateTime.now();

  // Normaliza eliminando as horas para contagem precisa de dias civis
  final startNorm = DateTime(startDate.year, startDate.month, startDate.day);
  final todayNorm = DateTime(now.year, now.month, now.day);

  final diffDays = todayNorm.difference(startNorm).inDays;

  // Se a data de início for hoje, diffDays = 0 -> dia 1
  // Se começou antes, avança proporcionalmente
  // Se a data for no futuro (start > today), trava no dia 1
  final dayNumber = (diffDays + 1).clamp(1, 364);
  final weekNumber = PlanIndex.weekOf(dayNumber);
  final dayOfWeek = PlanIndex.dayOfWeek(dayNumber);
  final isCompleted = completedDays.contains(dayNumber);

  return TodayPlanInfo(
    day: dayNumber,
    week: weekNumber,
    dayOfWeek: dayOfWeek,
    isCompleted: isCompleted,
  );
}
