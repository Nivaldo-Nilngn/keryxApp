import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/core/state/font_state.dart';

@immutable
class StudyReadingState {
  final Set<int> startedIds;
  final Set<int> completedIds;
  final Map<int, double> progressMap;

  const StudyReadingState({
    this.startedIds = const {},
    this.completedIds = const {},
    this.progressMap = const {},
  });

  bool isStarted(int id) => startedIds.contains(id);
  bool isCompleted(int id) => completedIds.contains(id);
  double getProgress(int id) => progressMap[id] ?? 0.0;

  StudyReadingState copyWith({
    Set<int>? startedIds,
    Set<int>? completedIds,
    Map<int, double>? progressMap,
  }) {
    return StudyReadingState(
      startedIds: startedIds ?? this.startedIds,
      completedIds: completedIds ?? this.completedIds,
      progressMap: progressMap ?? this.progressMap,
    );
  }
}

class StudyHistoryNotifier extends StateNotifier<StudyReadingState> {
  final SharedPreferences? _prefs;

  StudyHistoryNotifier(this._prefs) : super(const StudyReadingState()) {
    _loadFromStorage();
  }

  static const String _keyStarted = 'estudos_started_ids';
  static const String _keyCompleted = 'estudos_completed_ids';
  static const String _keyProgressPrefix = 'estudos_progress_';

  void _loadFromStorage() {
    if (_prefs == null) return;

    final startedList = _prefs.getStringList(_keyStarted) ?? [];
    final startedIds = startedList.map((e) => int.tryParse(e)).whereType<int>().toSet();

    final completedList = _prefs.getStringList(_keyCompleted) ?? [];
    final completedIds = completedList.map((e) => int.tryParse(e)).whereType<int>().toSet();

    final Map<int, double> progress = {};
    for (final id in startedIds) {
      final p = _prefs.getDouble('$_keyProgressPrefix$id');
      if (p != null) {
        progress[id] = p;
      }
    }

    state = StudyReadingState(
      startedIds: startedIds,
      completedIds: completedIds,
      progressMap: progress,
    );
  }

  Future<void> markStarted(int studyId) async {
    if (state.isStarted(studyId)) return;

    final newStarted = Set<int>.from(state.startedIds)..add(studyId);
    state = state.copyWith(startedIds: newStarted);

    if (_prefs != null) {
      await _prefs.setStringList(_keyStarted, newStarted.map((e) => e.toString()).toList());
    }
  }

  Future<void> updateProgress(int studyId, double progress) async {
    final clamped = progress.clamp(0.0, 1.0);
    final newStarted = Set<int>.from(state.startedIds)..add(studyId);
    final newProgress = Map<int, double>.from(state.progressMap)..[studyId] = clamped;
    final newCompleted = Set<int>.from(state.completedIds);

    if (clamped >= 0.9) {
      newCompleted.add(studyId);
    }

    state = state.copyWith(
      startedIds: newStarted,
      progressMap: newProgress,
      completedIds: newCompleted,
    );

    if (_prefs != null) {
      await _prefs.setStringList(_keyStarted, newStarted.map((e) => e.toString()).toList());
      await _prefs.setDouble('$_keyProgressPrefix$studyId', clamped);
      if (clamped >= 0.9) {
        await _prefs.setStringList(_keyCompleted, newCompleted.map((e) => e.toString()).toList());
      }
    }
  }

  Future<void> toggleCompleted(int studyId) async {
    final newCompleted = Set<int>.from(state.completedIds);
    final newStarted = Set<int>.from(state.startedIds)..add(studyId);
    final newProgress = Map<int, double>.from(state.progressMap);

    if (newCompleted.contains(studyId)) {
      newCompleted.remove(studyId);
    } else {
      newCompleted.add(studyId);
      newProgress[studyId] = 1.0;
    }

    state = state.copyWith(
      startedIds: newStarted,
      completedIds: newCompleted,
      progressMap: newProgress,
    );

    if (_prefs != null) {
      await _prefs.setStringList(_keyStarted, newStarted.map((e) => e.toString()).toList());
      await _prefs.setStringList(_keyCompleted, newCompleted.map((e) => e.toString()).toList());
      if (newCompleted.contains(studyId)) {
        await _prefs.setDouble('$_keyProgressPrefix$studyId', 1.0);
      }
    }
  }
}

final studyHistoryProvider = StateNotifierProvider<StudyHistoryNotifier, StudyReadingState>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {}
  return StudyHistoryNotifier(prefs);
});

