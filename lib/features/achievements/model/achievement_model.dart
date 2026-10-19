import 'package:freezed_annotation/freezed_annotation.dart';

part 'achievement_model.freezed.dart';
part 'achievement_model.g.dart';

@freezed
abstract class Achievement with _$Achievement {
  const factory Achievement({
    required String id,
    required String title,
    required String description,
    required String icon,
    @Default(false) bool isUnlocked,
    DateTime? unlockedAt,
    required String type, // 'streak', 'sessions', 'total_days', 'books_read'
    required int requirement,
    @Default(0) int progress,
  }) = _Achievement;

  factory Achievement.fromJson(Map<String, dynamic> json) => _$AchievementFromJson(json);
}
