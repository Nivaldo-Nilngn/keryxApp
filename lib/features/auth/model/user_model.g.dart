// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserModel _$UserModelFromJson(Map<String, dynamic> json) => _UserModel(
  uid: json['uid'] as String?,
  displayName: json['displayName'] as String?,
  email: json['email'] as String?,
  photoUrl: json['photoUrl'] as String?,
  createdAt: const TimestampConverter().fromJson(json['createdAt']),
  lastLogin: const TimestampConverter().fromJson(json['lastLogin']),
  stats: json['stats'] == null
      ? const UserStats()
      : UserStats.fromJson(json['stats'] as Map<String, dynamic>),
  subscription: json['subscription'] == null
      ? const UserSubscription()
      : UserSubscription.fromJson(json['subscription'] as Map<String, dynamic>),
);

Map<String, dynamic> _$UserModelToJson(_UserModel instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'displayName': instance.displayName,
      'email': instance.email,
      'photoUrl': instance.photoUrl,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'lastLogin': const TimestampConverter().toJson(instance.lastLogin),
      'stats': instance.stats,
      'subscription': instance.subscription,
    };

_UserStats _$UserStatsFromJson(Map<String, dynamic> json) => _UserStats(
  currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
  longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
  totalDays: (json['totalDays'] as num?)?.toInt() ?? 0,
  totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
  lessonsCompletedCount: (json['lessonsCompletedCount'] as num?)?.toInt() ?? 0,
  plansStartedCount: (json['plansStartedCount'] as num?)?.toInt() ?? 0,
  plansCompletedCount: (json['plansCompletedCount'] as num?)?.toInt() ?? 0,
  lastReadDate: json['lastReadDate'] as String?,
);

Map<String, dynamic> _$UserStatsToJson(_UserStats instance) =>
    <String, dynamic>{
      'currentStreak': instance.currentStreak,
      'longestStreak': instance.longestStreak,
      'totalDays': instance.totalDays,
      'totalSessions': instance.totalSessions,
      'lessonsCompletedCount': instance.lessonsCompletedCount,
      'plansStartedCount': instance.plansStartedCount,
      'plansCompletedCount': instance.plansCompletedCount,
      'lastReadDate': instance.lastReadDate,
    };

_UserSubscription _$UserSubscriptionFromJson(Map<String, dynamic> json) =>
    _UserSubscription(
      tier: json['tier'] as String? ?? 'free',
      expiresAt: const TimestampConverter().fromJson(json['expiresAt']),
    );

Map<String, dynamic> _$UserSubscriptionToJson(_UserSubscription instance) =>
    <String, dynamic>{
      'tier': instance.tier,
      'expiresAt': const TimestampConverter().toJson(instance.expiresAt),
    };
