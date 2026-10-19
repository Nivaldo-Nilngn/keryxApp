import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Converte o Timestamp do Firestore para DateTime do Dart
class TimestampConverter implements JsonConverter<DateTime?, Object?> {
  const TimestampConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json is Timestamp) {
      return json.toDate();
    } else if (json is String) {
      return DateTime.tryParse(json);
    }
    return null;
  }

  @override
  Object? toJson(DateTime? date) {
    if (date == null) return null;
    return Timestamp.fromDate(date);
  }
}

@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    String? uid,
    String? displayName,
    String? email,
    String? photoUrl,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? lastLogin,
    @Default(UserStats()) UserStats stats,
    @Default(UserSubscription()) UserSubscription subscription,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

@freezed
abstract class UserStats with _$UserStats {
  const factory UserStats({
    @Default(0) int currentStreak,
    @Default(0) int longestStreak,
    @Default(0) int totalDays,
    @Default(0) int totalSessions,
    @Default(0) int lessonsCompletedCount,
    @Default(0) int plansStartedCount,
    @Default(0) int plansCompletedCount,
    String? lastReadDate, // Formato "YYYY-MM-DD"
  }) = _UserStats;

  factory UserStats.fromJson(Map<String, dynamic> json) =>
      _$UserStatsFromJson(json);
}

@freezed
abstract class UserSubscription with _$UserSubscription {
  const factory UserSubscription({
    @Default('free') String tier,
    @TimestampConverter() DateTime? expiresAt,
  }) = _UserSubscription;

  factory UserSubscription.fromJson(Map<String, dynamic> json) =>
      _$UserSubscriptionFromJson(json);
}
