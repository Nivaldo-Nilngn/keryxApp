import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_history_model.freezed.dart';
part 'reading_history_model.g.dart';

@freezed
abstract class ReadingHistory with _$ReadingHistory {
  const factory ReadingHistory({
    required String date, // Formato "YYYY-MM-DD"
    @Default([]) List<ChapterRead> chapters,
    @Default(0) int durationSeconds,
  }) = _ReadingHistory;

  factory ReadingHistory.fromJson(Map<String, dynamic> json) =>
      _$ReadingHistoryFromJson(json);
}

@freezed
abstract class ChapterRead with _$ChapterRead {
  const factory ChapterRead({
    required String book, // Ex: "GEN"
    required int chapter, // Ex: 1
  }) = _ChapterRead;

  factory ChapterRead.fromJson(Map<String, dynamic> json) =>
      _$ChapterReadFromJson(json);
}
