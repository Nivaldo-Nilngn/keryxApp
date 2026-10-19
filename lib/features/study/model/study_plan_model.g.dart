// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_plan_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StudyPlan _$StudyPlanFromJson(Map<String, dynamic> json) => _StudyPlan(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  level: json['level'] as String,
  durationDays: (json['durationDays'] as num).toInt(),
  isPremium: json['isPremium'] as bool? ?? false,
  category: json['category'] as String?,
  coverImage: json['coverImage'] as String?,
);

Map<String, dynamic> _$StudyPlanToJson(_StudyPlan instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'level': instance.level,
      'durationDays': instance.durationDays,
      'isPremium': instance.isPremium,
      'category': instance.category,
      'coverImage': instance.coverImage,
    };

_StudyLesson _$StudyLessonFromJson(Map<String, dynamic> json) => _StudyLesson(
  id: json['id'] as String,
  lessonIndex: (json['lessonIndex'] as num).toInt(),
  title: json['title'] as String,
  verses:
      (json['verses'] as List<dynamic>?)
          ?.map((e) => BibleReference.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  devotional: json['devotional'] as String,
  questions:
      (json['questions'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  topics:
      (json['topics'] as List<dynamic>?)
          ?.map((e) => StudyTopic.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  quiz:
      (json['quiz'] as List<dynamic>?)
          ?.map((e) => StudyQuestion.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$StudyLessonToJson(_StudyLesson instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lessonIndex': instance.lessonIndex,
      'title': instance.title,
      'verses': instance.verses,
      'devotional': instance.devotional,
      'questions': instance.questions,
      'topics': instance.topics,
      'quiz': instance.quiz,
    };

_StudyTopic _$StudyTopicFromJson(Map<String, dynamic> json) => _StudyTopic(
  title: json['title'] as String,
  summary: json['summary'] as String,
  questions:
      (json['questions'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$StudyTopicToJson(_StudyTopic instance) =>
    <String, dynamic>{
      'title': instance.title,
      'summary': instance.summary,
      'questions': instance.questions,
    };

_StudyQuestion _$StudyQuestionFromJson(Map<String, dynamic> json) =>
    _StudyQuestion(
      text: json['text'] as String,
      isTrue: json['isTrue'] as bool,
      explanation: json['explanation'] as String?,
    );

Map<String, dynamic> _$StudyQuestionToJson(_StudyQuestion instance) =>
    <String, dynamic>{
      'text': instance.text,
      'isTrue': instance.isTrue,
      'explanation': instance.explanation,
    };

_BibleReference _$BibleReferenceFromJson(Map<String, dynamic> json) =>
    _BibleReference(
      book: json['book'] as String,
      chapter: (json['chapter'] as num).toInt(),
      verseStart: (json['verseStart'] as num).toInt(),
      verseEnd: (json['verseEnd'] as num?)?.toInt(),
      label: json['label'] as String?,
    );

Map<String, dynamic> _$BibleReferenceToJson(_BibleReference instance) =>
    <String, dynamic>{
      'book': instance.book,
      'chapter': instance.chapter,
      'verseStart': instance.verseStart,
      'verseEnd': instance.verseEnd,
      'label': instance.label,
    };

_UserPlanProgress _$UserPlanProgressFromJson(Map<String, dynamic> json) =>
    _UserPlanProgress(
      planId: json['planId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      currentLessonIndex: (json['currentLessonIndex'] as num?)?.toInt() ?? 1,
      completedLessons:
          (json['completedLessons'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      status: json['status'] as String? ?? 'active',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      planTitle: json['planTitle'] as String?,
    );

Map<String, dynamic> _$UserPlanProgressToJson(_UserPlanProgress instance) =>
    <String, dynamic>{
      'planId': instance.planId,
      'startedAt': instance.startedAt.toIso8601String(),
      'currentLessonIndex': instance.currentLessonIndex,
      'completedLessons': instance.completedLessons,
      'status': instance.status,
      'progress': instance.progress,
      'planTitle': instance.planTitle,
    };
