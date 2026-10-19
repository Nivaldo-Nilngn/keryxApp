import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudyProgress {
  final int versesReadToday;
  final int totalVersesRead;
  final double weeklyProgress; // 0.0 to 1.0
  final List<int> weeklyHistory; // 7 days of counts

  StudyProgress({
    this.versesReadToday = 0,
    this.totalVersesRead = 0,
    this.weeklyProgress = 0,
    this.weeklyHistory = const [0, 0, 0, 0, 0, 0, 0],
  });
}

class StudyProgressNotifier extends StateNotifier<StudyProgress> {
  StudyProgressNotifier() : super(StudyProgress(
    versesReadToday: 12,
    totalVersesRead: 1450,
    weeklyProgress: 0.75,
    weeklyHistory: [5, 12, 8, 20, 15, 10, 12],
  ));

  void incrementReadCount() {
    state = StudyProgress(
      versesReadToday: state.versesReadToday + 1,
      totalVersesRead: state.totalVersesRead + 1,
      weeklyProgress: state.weeklyProgress,
      weeklyHistory: state.weeklyHistory,
    );
  }
}

final studyProgressProvider = StateNotifierProvider<StudyProgressNotifier, StudyProgress>((ref) {
  return StudyProgressNotifier();
});
