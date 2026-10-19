// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_history_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReadingHistory _$ReadingHistoryFromJson(Map<String, dynamic> json) =>
    _ReadingHistory(
      date: json['date'] as String,
      chapters:
          (json['chapters'] as List<dynamic>?)
              ?.map((e) => ChapterRead.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ReadingHistoryToJson(_ReadingHistory instance) =>
    <String, dynamic>{
      'date': instance.date,
      'chapters': instance.chapters,
      'durationSeconds': instance.durationSeconds,
    };

_ChapterRead _$ChapterReadFromJson(Map<String, dynamic> json) => _ChapterRead(
  book: json['book'] as String,
  chapter: (json['chapter'] as num).toInt(),
);

Map<String, dynamic> _$ChapterReadToJson(_ChapterRead instance) =>
    <String, dynamic>{'book': instance.book, 'chapter': instance.chapter};
