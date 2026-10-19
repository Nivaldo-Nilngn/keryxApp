import 'package:freezed_annotation/freezed_annotation.dart';

part 'study_plan_model.freezed.dart';
part 'study_plan_model.g.dart';

@freezed
abstract class StudyPlan with _$StudyPlan {
  const factory StudyPlan({
    required String id,
    required String title,
    required String description,
    required String level, // beginner, intermediate, advanced, premium
    required int durationDays,
    @Default(false) bool isPremium,
    String? category,
    String? coverImage,
  }) = _StudyPlan;

  factory StudyPlan.fromJson(Map<String, dynamic> json) => _$StudyPlanFromJson(json);
}

@freezed
abstract class StudyLesson with _$StudyLesson {
  const factory StudyLesson({
    required String id,
    required int lessonIndex,
    required String title,
    @Default([]) List<BibleReference> verses,
    required String devotional,
    @Default([]) List<String> questions,
    @Default([]) List<StudyTopic> topics,
    @Default([]) List<StudyQuestion> quiz,
  }) = _StudyLesson;

  factory StudyLesson.fromJson(Map<String, dynamic> json) => _$StudyLessonFromJson(json);
}

@freezed
abstract class StudyTopic with _$StudyTopic {
  const factory StudyTopic({
    required String title,
    required String summary,
    @Default([]) List<String> questions,
  }) = _StudyTopic;

  factory StudyTopic.fromJson(Map<String, dynamic> json) => _$StudyTopicFromJson(json);
}

@freezed
abstract class StudyQuestion with _$StudyQuestion {
  const factory StudyQuestion({
    required String text,
    required bool isTrue,
    String? explanation,
  }) = _StudyQuestion;

  factory StudyQuestion.fromJson(Map<String, dynamic> json) => _$StudyQuestionFromJson(json);
}

@freezed
abstract class BibleReference with _$BibleReference {
  const factory BibleReference({
    required String book,
    required int chapter,
    required int verseStart,
    int? verseEnd,
    String? label, // Ex: "João 3:16"
  }) = _BibleReference;

  factory BibleReference.fromJson(Map<String, dynamic> json) => _$BibleReferenceFromJson(json);
}

@freezed
abstract class UserPlanProgress with _$UserPlanProgress {
  const factory UserPlanProgress({
    required String planId,
    required DateTime startedAt,
    @Default(1) int currentLessonIndex,
    @Default([]) List<int> completedLessons,
    @Default('active') String status, // active, completed
    @Default(0.0) double progress,
    String? planTitle,
  }) = _UserPlanProgress;

  factory UserPlanProgress.fromJson(Map<String, dynamic> json) => _$UserPlanProgressFromJson(json);
}
