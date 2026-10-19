import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/achievement_model.dart';
import '../../auth/model/user_model.dart';
import '../../../core/services/auth_service.dart';

class AchievementRepository {
  final FirebaseFirestore _firestore;

  AchievementRepository(this._firestore);

  /// Lista de conquistas estáticas do sistema
  final List<Achievement> _allAchievements = [
    const Achievement(
      id: 'streak_3',
      title: 'Fogo Inicial',
      description: 'Mantenha um streak de 3 dias',
      icon: '🔥',
      type: 'streak',
      requirement: 3,
    ),
    const Achievement(
      id: 'streak_7',
      title: 'Hábito Sagrado',
      description: 'Mantenha um streak de 7 dias',
      icon: '📅',
      type: 'streak',
      requirement: 7,
    ),
    const Achievement(
      id: 'sessions_10',
      title: 'Leitor Fiel',
      description: 'Complete 10 sessões de leitura',
      icon: '📖',
      type: 'sessions',
      requirement: 10,
    ),
    const Achievement(
      id: 'total_days_30',
      title: 'Um Mês com a Palavra',
      description: 'Leia a bíblia em 30 dias diferentes',
      icon: '🏆',
      type: 'total_days',
      requirement: 30,
    ),
    const Achievement(
      id: 'plan_started',
      title: 'Primeiro Passo',
      description: 'Inicie seu primeiro plano de estudo',
      icon: '🚀',
      type: 'study_plan',
      requirement: 1,
    ),
    const Achievement(
      id: 'lesson_completed',
      title: 'Aprendiz Dedicado',
      description: 'Conclua sua primeira aula em um plano',
      icon: '✍️',
      type: 'study_lesson',
      requirement: 1,
    ),
    const Achievement(
      id: 'lessons_7',
      title: 'Consistência no Estudo',
      description: 'Conclua 7 aulas de planos de estudo',
      icon: '🌟',
      type: 'study_lesson',
      requirement: 7,
    ),
    const Achievement(
      id: 'plan_completed',
      title: 'Missão Cumprida',
      description: 'Conclua um plano de estudo por completo',
      icon: '🎓',
      type: 'study_plan_complete',
      requirement: 1,
    ),
  ];

  /// Escuta as conquistas do usuário e mescla com as definições globais
  Stream<List<Achievement>> watchUserAchievements(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .snapshots()
        .map((snapshot) {
      final unlockedData = {for (var doc in snapshot.docs) doc.id: doc.data()};

      return _allAchievements.map((def) {
        if (unlockedData.containsKey(def.id)) {
          final data = unlockedData[def.id]!;
          return def.copyWith(
            isUnlocked: true,
            unlockedAt: (data['unlockedAt'] as Timestamp?)?.toDate(),
          );
        }
        return def;
      }).toList();
    });
  }

  /// Verifica se novas conquistas devem ser desbloqueadas com base nas estatísticas
  Future<void> checkAndUnlockAchievements(String uid, UserStats stats) async {
    final userAchievementsRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements');

    final snapshot = await userAchievementsRef.get();
    final unlockedIds = snapshot.docs.map((doc) => doc.id).toSet();

    final batch = _firestore.batch();
    bool updated = false;

    for (var ach in _allAchievements) {
      if (unlockedIds.contains(ach.id)) continue;

      bool shouldUnlock = false;
      if (ach.type == 'streak' && stats.currentStreak >= ach.requirement) {
        shouldUnlock = true;
      } else if (ach.type == 'sessions' && stats.totalSessions >= ach.requirement) {
        shouldUnlock = true;
      } else if (ach.type == 'total_days' && stats.totalDays >= ach.requirement) {
        shouldUnlock = true;
      } else if (ach.type == 'study_plan' && stats.plansStartedCount >= ach.requirement) {
        shouldUnlock = true;
      } else if (ach.type == 'study_lesson' && stats.lessonsCompletedCount >= ach.requirement) {
        shouldUnlock = true;
      } else if (ach.type == 'study_plan_complete' && stats.plansCompletedCount >= ach.requirement) {
        shouldUnlock = true;
      }

      if (shouldUnlock) {
        batch.set(userAchievementsRef.doc(ach.id), {
          'unlockedAt': FieldValue.serverTimestamp(),
          'type': ach.type,
          'requirement': ach.requirement,
        });
        updated = true;
      }
    }

    if (updated) {
      await batch.commit();
    }
  }
}

final achievementRepositoryProvider = Provider((ref) {
  return AchievementRepository(FirebaseFirestore.instance);
});

final userAchievementsProvider = StreamProvider<List<Achievement>>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value([]);
  
  return ref.watch(achievementRepositoryProvider).watchUserAchievements(authUser.uid);
});
