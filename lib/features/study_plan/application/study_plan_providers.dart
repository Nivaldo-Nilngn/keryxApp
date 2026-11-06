import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/core/state/font_state.dart';
import '../data/plan_repository.dart';
import '../domain/domain.dart';
export '../data/study_history_service.dart';

/// Informações do dia de leitura de hoje
@immutable
class TodayPlanInfo {
  final int day; // Dia global do plano (1..N)
  final int week; // Semana do plano (1..N)
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

// ─────────────────────────────────────────────────────────────────────────────
// GERENCIADOR DE PLANOS ATIVOS (ATÉ 5 PLANOS SIMULTÂNEOS)
// ─────────────────────────────────────────────────────────────────────────────

class ActivePlanIdsNotifier extends StateNotifier<List<String>> {
  final SharedPreferences? _prefs;
  static const String _keyActivePlans = 'study_plan_active_plan_ids';

  ActivePlanIdsNotifier(this._prefs) : super(const ['cronologico-52']) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    if (_prefs == null) return;
    final list = _prefs.getStringList(_keyActivePlans);
    if (list != null && list.isNotEmpty) {
      state = list.take(5).toList();
    }
  }

  /// Adiciona um novo plano à lista ativa (máximo de 5 planos)
  Future<bool> addPlan(String planId) async {
    if (state.contains(planId)) return true;
    if (state.length >= 5) return false;

    final updated = [...state, planId];
    state = updated;
    if (_prefs != null) {
      await _prefs.setStringList(_keyActivePlans, updated);
    }
    return true;
  }

  /// Remove um plano da lista de planos ativos e limpa seu progresso
  Future<void> removePlan(
    String planId, {
    String? currentSelectedPlanId,
    Future<void> Function(String nextPlanId)? onSwitchPlan,
  }) async {
    final updated = state.where((id) => id != planId).toList();
    state = updated;
    if (_prefs != null) {
      await _prefs.setStringList(_keyActivePlans, updated);
      // Remove chaves salvas do plano excluído
      await _prefs.remove('study_plan_start_date_$planId');
      await _prefs.remove('study_plan_completed_days_$planId');
      await _prefs.remove('study_plan_streak_$planId');
      await _prefs.remove('study_plan_last_date_$planId');
      await _prefs.remove('study_plan_notes_$planId');
      await _prefs.remove('study_plan_is_started_$planId');
    }

    // Se o plano removido era o atualmente selecionado, seleciona o próximo ou fallback
    if (currentSelectedPlanId == planId && onSwitchPlan != null) {
      final next = updated.isNotEmpty ? updated.first : 'cronologico-52';
      await onSwitchPlan(next);
      if (updated.isEmpty) {
        await addPlan('cronologico-52');
      }
    }
  }
}

final activePlanIdsProvider =
    StateNotifierProvider<ActivePlanIdsNotifier, List<String>>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {}
  return ActivePlanIdsNotifier(prefs);
});

// ─────────────────────────────────────────────────────────────────────────────
// PLANO ATUALMENTE SELECIONADO NA INTERFACE
// ─────────────────────────────────────────────────────────────────────────────

class CurrentPlanIdNotifier extends StateNotifier<String> {
  final SharedPreferences? _prefs;
  static const String _keyCurrentPlan = 'study_plan_current_plan_id';

  CurrentPlanIdNotifier(this._prefs) : super('cronologico-52') {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    if (_prefs == null) return;
    final saved = _prefs.getString(_keyCurrentPlan);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> selectPlan(String planId) async {
    state = planId;
    if (_prefs != null) {
      await _prefs.setString(_keyCurrentPlan, planId);
    }
  }
}

final currentPlanIdProvider =
    StateNotifierProvider<CurrentPlanIdNotifier, String>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {}
  return CurrentPlanIdNotifier(prefs);
});

/// Carrega o modelo StudyPlan do plano atualmente selecionado
final currentStudyPlanProvider = FutureProvider<StudyPlan>((ref) async {
  final planId = ref.watch(currentPlanIdProvider);
  final repo = ref.watch(planRepositoryProvider);
  return repo.loadPlan(planId);
});

/// Índice em memória do plano atualmente selecionado para acesso O(1)
final currentPlanIndexProvider = FutureProvider<PlanIndex>((ref) async {
  final plan = await ref.watch(currentStudyPlanProvider.future);
  return PlanIndex(plan);
});

// Aliases para compatibilidade reversa com telas existentes
final chronologicalPlanProvider = currentStudyPlanProvider;
final chronologicalIndexProvider = currentPlanIndexProvider;

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER DE PROGRESSO DO PLANO SELECIONADO
// ─────────────────────────────────────────────────────────────────────────────

class StudyPlanNotifier extends StateNotifier<PlanProgress> {
  final SharedPreferences? _prefs;
  final String planId;

  StudyPlanNotifier(this._prefs, {required this.planId})
      : super(PlanProgress.initial(planId)) {
    _loadFromStorage();
  }

  String get _keyStartDate => 'study_plan_start_date_$planId';
  String get _keyCompletedDays => 'study_plan_completed_days_$planId';
  String get _keyStreak => 'study_plan_streak_$planId';
  String get _keyLastDate => 'study_plan_last_date_$planId';
  String get _keyNotes => 'study_plan_notes_$planId';
  String get _keyIsStarted => 'study_plan_is_started_$planId';

  PlanProgress get currentProgress => state;

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

    final isStarted = _prefs.getBool(_keyIsStarted) ?? (completedDays.isNotEmpty);

    state = PlanProgress(
      planId: planId,
      startDate: startDate,
      completedDays: completedDays,
      streak: streak,
      lastCompletedDate: lastCompletedDate,
      notes: notes,
      isStarted: isStarted,
    );
  }

  /// Marca que o usuário iniciou a leitura deste plano
  Future<void> startPlan() async {
    if (state.isStarted) return;
    final now = DateTime.now();
    state = state.copyWith(isStarted: true, startDate: now);
    if (_prefs != null) {
      await _prefs.setBool(_keyIsStarted, true);
      await _prefs.setString(_keyStartDate, now.toIso8601String());
    }
  }

  /// Define a data de início do plano
  Future<void> setStartDate(DateTime date) async {
    state = state.copyWith(startDate: date, isStarted: true);
    if (_prefs != null) {
      await _prefs.setString(_keyStartDate, date.toIso8601String());
      await _prefs.setBool(_keyIsStarted, true);
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
        await _prefs.setBool(_keyIsStarted, imported.isStarted);
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

  /// Alterna o estado de conclusão de um dia
  Future<void> toggleDay(int dayNumber, {DateTime? now}) async {
    final currentCompleted = Set<int>.from(state.completedDays);
    final currentTime = now ?? DateTime.now();
    int newStreak = state.streak;
    DateTime? newLastDate = state.lastCompletedDate;

    if (currentCompleted.contains(dayNumber)) {
      // Desmarcar
      currentCompleted.remove(dayNumber);
    } else {
      // Marcar como concluído e marcar plano como iniciado
      currentCompleted.add(dayNumber);

      if (newLastDate == null) {
        newStreak = 1;
      } else {
        final todayNorm = DateTime(currentTime.year, currentTime.month, currentTime.day);
        final lastNorm = DateTime(newLastDate.year, newLastDate.month, newLastDate.day);
        final diffDays = todayNorm.difference(lastNorm).inDays;

        if (diffDays == 1) {
          newStreak += 1;
        } else if (diffDays == 0) {
          newStreak = newStreak == 0 ? 1 : newStreak;
        } else {
          newStreak = 1;
        }
      }
      newLastDate = currentTime;
    }

    state = state.copyWith(
      completedDays: currentCompleted,
      streak: newStreak,
      lastCompletedDate: newLastDate,
      isStarted: true,
    );

    if (_prefs != null) {
      await _prefs.setStringList(
        _keyCompletedDays,
        currentCompleted.map((e) => e.toString()).toList(),
      );
      await _prefs.setInt(_keyStreak, newStreak);
      await _prefs.setBool(_keyIsStarted, true);
      if (newLastDate != null) {
        await _prefs.setString(_keyLastDate, newLastDate.toIso8601String());
      }
    }
  }

  /// Reinicia todo o progresso do plano atual
  Future<void> reset() async {
    final now = DateTime.now();
    state = PlanProgress.initial(planId).copyWith(startDate: now);

    if (_prefs != null) {
      await _prefs.remove(_keyStartDate);
      await _prefs.remove(_keyCompletedDays);
      await _prefs.remove(_keyStreak);
      await _prefs.remove(_keyLastDate);
      await _prefs.remove(_keyNotes);
      await _prefs.remove(_keyIsStarted);
    }
  }
}

/// Provider do estado e progresso do plano atualmente selecionado
final studyPlanProgressProvider =
    StateNotifierProvider<StudyPlanNotifier, PlanProgress>((ref) {
  final planId = ref.watch(currentPlanIdProvider);
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {}
  return StudyPlanNotifier(prefs, planId: planId);
});

/// Provider para consultar progresso de qualquer plano (usado em listas de planos)
final planProgressFamilyProvider =
    Provider.family<PlanProgress, String>((ref, planId) {
  final current = ref.watch(currentPlanIdProvider);
  if (current == planId) {
    return ref.watch(studyPlanProgressProvider);
  }
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {}
  return StudyPlanNotifier(prefs, planId: planId).currentProgress;
});

/// Calcula dinamicamente o dia de leitura correspondente a hoje
final todayPlanDayProvider = Provider<TodayPlanInfo>((ref) {
  final progress = ref.watch(studyPlanProgressProvider);
  final planIndexAsync = ref.watch(currentPlanIndexProvider);
  final totalDays = planIndexAsync.value?.totalDays ?? 364;
  return calculateTodayPlanInfo(progress.startDate, progress.completedDays, totalDays: totalDays);
});

/// Helper puro testável para cálculo da data/dia de hoje
TodayPlanInfo calculateTodayPlanInfo(
  DateTime startDate,
  Set<int> completedDays, {
  DateTime? currentDate,
  int totalDays = 364,
}) {
  final now = currentDate ?? DateTime.now();

  final startNorm = DateTime(startDate.year, startDate.month, startDate.day);
  final todayNorm = DateTime(now.year, now.month, now.day);

  final diffDays = todayNorm.difference(startNorm).inDays;

  final effectiveTotal = totalDays > 0 ? totalDays : 1;
  final dayNumber = (diffDays + 1).clamp(1, effectiveTotal);
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
