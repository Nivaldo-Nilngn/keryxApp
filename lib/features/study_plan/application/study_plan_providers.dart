import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/core/services/auth_service.dart';
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
// NOTIFIER DE PROGRESSO DO PLANO SELECIONADO (COM SUPORTE MULTI-USUÁRIO E FIRESTORE)
// ─────────────────────────────────────────────────────────────────────────────

class StudyPlanNotifier extends StateNotifier<PlanProgress> {
  final SharedPreferences? _prefs;
  final String planId;
  final String? uid;

  StudyPlanNotifier(this._prefs, {required this.planId, this.uid})
      : super(PlanProgress.initial(planId)) {
    _loadFromStorage();
  }

  String get _prefix =>
      (uid != null && uid!.isNotEmpty) ? 'study_plan_${uid}_' : 'study_plan_';

  String get _keyStartDate => '${_prefix}start_date_$planId';
  String get _keyCompletedDays => '${_prefix}completed_days_$planId';
  String get _keyCurrentDay => '${_prefix}current_day_$planId';
  String get _keyStreak => '${_prefix}streak_$planId';
  String get _keyLastDate => '${_prefix}last_date_$planId';
  String get _keyNotes => '${_prefix}notes_$planId';
  String get _keyIsStarted => '${_prefix}is_started_$planId';

  PlanProgress get currentProgress => state;

  void _loadFromStorage() {
    if (_prefs == null) return;

    final startStr = _prefs.getString(_keyStartDate) ??
        _prefs.getString('study_plan_start_date_$planId');
    final startDate = startStr != null
        ? DateTime.tryParse(startStr) ?? DateTime.now()
        : DateTime.now();

    final completedList = _prefs.getStringList(_keyCompletedDays) ??
        (uid != null ? _prefs.getStringList('study_plan_completed_days_$planId') : null) ??
        [];
    final completedDays = completedList
        .map((s) => int.tryParse(s))
        .whereType<int>()
        .toSet();

    final currentDay = _prefs.getInt(_keyCurrentDay) ??
        (uid != null ? _prefs.getInt('study_plan_current_day_$planId') : null);

    final streak = _prefs.getInt(_keyStreak) ??
        (uid != null ? _prefs.getInt('study_plan_streak_$planId') : null) ??
        0;

    final lastStr = _prefs.getString(_keyLastDate) ??
        (uid != null ? _prefs.getString('study_plan_last_date_$planId') : null);
    final lastCompletedDate =
        lastStr != null ? DateTime.tryParse(lastStr) : null;

    final notesStr = _prefs.getString(_keyNotes) ??
        (uid != null ? _prefs.getString('study_plan_notes_$planId') : null);
    Map<int, String> notes = {};
    if (notesStr != null) {
      try {
        final decoded = jsonDecode(notesStr) as Map<String, dynamic>;
        notes = decoded.map((k, v) => MapEntry(int.parse(k), v.toString()));
      } catch (_) {}
    }

    final isStarted = _prefs.getBool(_keyIsStarted) ??
        (uid != null ? _prefs.getBool('study_plan_is_started_$planId') : null) ??
        completedDays.isNotEmpty;

    state = PlanProgress(
      planId: planId,
      startDate: startDate,
      completedDays: completedDays,
      currentDay: currentDay,
      streak: streak,
      lastCompletedDate: lastCompletedDate,
      notes: notes,
      isStarted: isStarted,
    );

    // Sincroniza em segundo plano com o Firebase Firestore se o usuário estiver logado
    if (uid != null && uid!.isNotEmpty) {
      _syncFromFirestore();
    }
  }

  Future<void> _syncFromFirestore() async {
    if (uid == null || uid!.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('study_plan_progress')
          .doc(planId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final firestoreCompleted =
            ((data['completedDays'] as List<dynamic>?) ?? [])
                .map((d) => d as int)
                .toSet();
        final firestoreCurrentDay = data['currentDay'] as int?;
        final firestoreStreak = (data['streak'] as int?) ?? state.streak;
        final firestoreIsStarted =
            (data['isStarted'] as bool?) ?? state.isStarted;
        final startStr = data['startDate'] as String?;
        final firestoreStart =
            startStr != null ? DateTime.tryParse(startStr) : null;
        final lastStr = data['lastCompletedDate'] as String?;
        final firestoreLastDate =
            lastStr != null ? DateTime.tryParse(lastStr) : null;

        // União dos dias concluídos para não perder marcações
        final mergedCompleted = {...state.completedDays, ...firestoreCompleted};
        final mergedCurrentDay = firestoreCurrentDay ?? state.currentDay;

        state = state.copyWith(
          completedDays: mergedCompleted,
          currentDay: mergedCurrentDay,
          streak: firestoreStreak > state.streak ? firestoreStreak : state.streak,
          isStarted: firestoreIsStarted || state.isStarted,
          startDate: firestoreStart ?? state.startDate,
          lastCompletedDate: firestoreLastDate ?? state.lastCompletedDate,
        );

        if (_prefs != null) {
          await _prefs.setStringList(
            _keyCompletedDays,
            mergedCompleted.map((e) => e.toString()).toList(),
          );
          if (mergedCurrentDay != null) {
            await _prefs.setInt(_keyCurrentDay, mergedCurrentDay);
          }
          await _prefs.setInt(_keyStreak, state.streak);
          await _prefs.setBool(_keyIsStarted, state.isStarted);
        }
      } else {
        // Envia o estado atual para inicializar no Firestore
        _saveToFirestore();
      }
    } catch (e) {
      debugPrint('Firestore study plan syncFromFirestore error: $e');
    }
  }

  void _saveToFirestore() {
    if (uid == null || uid!.isEmpty) return;
    try {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('study_plan_progress')
          .doc(planId)
          .set({
        'planId': planId,
        'startDate': state.startDate.toIso8601String(),
        'completedDays': state.completedDays.toList()..sort(),
        if (state.currentDay != null) 'currentDay': state.currentDay,
        'streak': state.streak,
        'isStarted': state.isStarted,
        if (state.lastCompletedDate != null)
          'lastCompletedDate': state.lastCompletedDate!.toIso8601String(),
        if (state.notes.isNotEmpty)
          'notes': state.notes.map((k, v) => MapEntry(k.toString(), v)),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((e) {
        debugPrint('Firestore save study plan error: $e');
      });
    } catch (e) {
      debugPrint('Firestore study plan save error: $e');
    }
  }

  /// Define o dia atual onde o usuário escolheu ler
  Future<void> setCurrentDay(int dayNumber) async {
    state = state.copyWith(currentDay: dayNumber, isStarted: true);
    if (_prefs != null) {
      await _prefs.setInt(_keyCurrentDay, dayNumber);
      await _prefs.setBool(_keyIsStarted, true);
    }
    _saveToFirestore();
  }

  /// Marca que o usuário iniciou a leitura deste plano
  Future<void> startPlan({int? startingDay}) async {
    final now = DateTime.now();
    final day = startingDay ?? state.currentDay ?? 1;
    state = state.copyWith(isStarted: true, startDate: now, currentDay: day);
    if (_prefs != null) {
      await _prefs.setBool(_keyIsStarted, true);
      await _prefs.setString(_keyStartDate, now.toIso8601String());
      await _prefs.setInt(_keyCurrentDay, day);
    }
    _saveToFirestore();
  }

  /// Define a data de início do plano
  Future<void> setStartDate(DateTime date) async {
    state = state.copyWith(startDate: date, isStarted: true);
    if (_prefs != null) {
      await _prefs.setString(_keyStartDate, date.toIso8601String());
      await _prefs.setBool(_keyIsStarted, true);
    }
    _saveToFirestore();
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
    _saveToFirestore();
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
        if (imported.currentDay != null) {
          await _prefs.setInt(_keyCurrentDay, imported.currentDay!);
        }
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
      _saveToFirestore();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Alterna o estado de conclusão de um dia e avança para o próximo dia na sequência
  Future<void> toggleDay(int dayNumber,
      {DateTime? now, int totalDays = 364}) async {
    final currentCompleted = Set<int>.from(state.completedDays);
    final currentTime = now ?? DateTime.now();
    int newStreak = state.streak;
    DateTime? newLastDate = state.lastCompletedDate;
    int? newCurrentDay = state.currentDay;

    if (currentCompleted.contains(dayNumber)) {
      // Desmarcar apenas este dia
      currentCompleted.remove(dayNumber);
      newCurrentDay = dayNumber;
    } else {
      // Marcar como concluído
      currentCompleted.add(dayNumber);

      if (newLastDate == null) {
        newStreak = 1;
      } else {
        final todayNorm =
            DateTime(currentTime.year, currentTime.month, currentTime.day);
        final lastNorm =
            DateTime(newLastDate.year, newLastDate.month, newLastDate.day);
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

      // Avança automaticamente para o próximo dia pendente na sequência
      int nextPending = dayNumber + 1;
      while (currentCompleted.contains(nextPending) && nextPending < totalDays) {
        nextPending++;
      }
      if (nextPending <= totalDays) {
        newCurrentDay = nextPending;
      }
    }

    state = state.copyWith(
      completedDays: currentCompleted,
      currentDay: newCurrentDay,
      streak: newStreak,
      lastCompletedDate: newLastDate,
      isStarted: true,
    );

    if (_prefs != null) {
      await _prefs.setStringList(
        _keyCompletedDays,
        currentCompleted.map((e) => e.toString()).toList(),
      );
      if (newCurrentDay != null) {
        await _prefs.setInt(_keyCurrentDay, newCurrentDay);
      }
      await _prefs.setInt(_keyStreak, newStreak);
      await _prefs.setBool(_keyIsStarted, true);
      if (newLastDate != null) {
        await _prefs.setString(_keyLastDate, newLastDate.toIso8601String());
      }
    }

    _saveToFirestore();
  }

  /// Reinicia todo o progresso do plano atual
  Future<void> reset() async {
    final now = DateTime.now();
    state = PlanProgress.initial(planId)
        .copyWith(startDate: now, currentDay: 1, isStarted: false);

    if (_prefs != null) {
      await _prefs.remove(_keyStartDate);
      await _prefs.remove(_keyCompletedDays);
      await _prefs.remove(_keyCurrentDay);
      await _prefs.remove(_keyStreak);
      await _prefs.remove(_keyLastDate);
      await _prefs.remove(_keyNotes);
      await _prefs.remove(_keyIsStarted);
    }

    if (uid != null && uid!.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('study_plan_progress')
            .doc(planId)
            .delete();
      } catch (_) {}
    }
  }
}

/// Provider do estado e progresso do plano atualmente selecionado
final studyPlanProgressProvider =
    StateNotifierProvider<StudyPlanNotifier, PlanProgress>((ref) {
  final planId = ref.watch(currentPlanIdProvider);
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final uid = authUser?.uid;
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {}
  return StudyPlanNotifier(prefs, planId: planId, uid: uid);
});

/// Provider para consultar progresso de qualquer plano (usado em listas de planos)
final planProgressFamilyProvider =
    Provider.family<PlanProgress, String>((ref, planId) {
  final current = ref.watch(currentPlanIdProvider);
  if (current == planId) {
    return ref.watch(studyPlanProgressProvider);
  }
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final uid = authUser?.uid;
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {}
  return StudyPlanNotifier(prefs, planId: planId, uid: uid).currentProgress;
});

/// Calcula dinamicamente o dia de leitura correspondente a hoje / próximo dia a realizar
final todayPlanDayProvider = Provider<TodayPlanInfo>((ref) {
  final progress = ref.watch(studyPlanProgressProvider);
  final planIndexAsync = ref.watch(currentPlanIndexProvider);
  final totalDays = planIndexAsync.value?.totalDays ?? 364;
  return calculateTodayPlanInfo(
    progress.startDate,
    progress.completedDays,
    currentDay: progress.currentDay,
    totalDays: totalDays,
  );
});

/// Helper puro testável para cálculo da data/dia de hoje ou próximo dia sequencial
TodayPlanInfo calculateProgressTodayPlanInfo(
  PlanProgress progress, [
  int totalDays = 364,
]) {
  return calculateTodayPlanInfo(
    progress.startDate,
    progress.completedDays,
    currentDay: progress.currentDay,
    totalDays: totalDays,
  );
}

TodayPlanInfo calculateTodayPlanInfo(
  DateTime startDate,
  Set<int> completedDays, {
  int? currentDay,
  DateTime? currentDate,
  int totalDays = 364,
}) {
  final effectiveTotal = totalDays > 0 ? totalDays : 1;

  // 1. Se o usuário tiver um dia ativo definido, respeita exatamente o dia onde ele está
  int dayNumber;
  if (currentDay != null && currentDay >= 1 && currentDay <= effectiveTotal) {
    dayNumber = currentDay;
  } else {
    // 2. Caso contrário, encontra o primeiro dia pendente na sequência contínua
    int firstPending = 1;
    while (completedDays.contains(firstPending) && firstPending < effectiveTotal) {
      firstPending++;
    }
    dayNumber = firstPending;
  }

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
