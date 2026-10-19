// Refresh compiler summary
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/study_plan_model.dart';
import '../../../core/services/auth_service.dart';

import '../../achievements/repository/achievement_repository.dart';
import '../../auth/model/user_model.dart';

class StudyPlanRepository {
  final FirebaseFirestore _firestore;
  final AchievementRepository _achievementRepo;

  StudyPlanRepository(this._firestore, this._achievementRepo);

  /// --- GLOBAL CATALOG ---

  /// Obtém todos os planos do catálogo global
  Stream<List<StudyPlan>> watchCatalog() {
    return _firestore.collection('plans').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => StudyPlan.fromJson(doc.data()..['id'] = doc.id)).toList();
    });
  }

  /// Obtém as lições de um plano específico
  Stream<List<StudyLesson>> watchLessons(String planId) {
    return _firestore
        .collection('plans')
        .doc(planId)
        .collection('lessons')
        .orderBy('lessonIndex')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => StudyLesson.fromJson(doc.data()..['id'] = doc.id)).toList();
    });
  }

  /// --- USER PROGRESS ---

  /// Escuta o plano ativo do usuário
  Stream<UserPlanProgress?> watchActivePlan(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('active_plan')
        .doc('current')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UserPlanProgress.fromJson(doc.data()!);
    });
  }

  /// Inscreve o usuário em um plano
  Future<void> enrollInPlan(String uid, StudyPlan plan) async {
    final progressRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('active_plan')
        .doc('current');
    
    final progress = UserPlanProgress(
      planId: plan.id,
      planTitle: plan.title,
      startedAt: DateTime.now(),
      currentLessonIndex: 1,
      completedLessons: [],
      status: 'active',
      progress: 0.0,
    );

    await progressRef.set(progress.toJson());

    // Atualiza estatísticas do usuário
    final userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final stats = UserStats.fromJson(userData['stats'] ?? {});
        final newStats = stats.copyWith(
          plansStartedCount: stats.plansStartedCount + 1,
        );
        transaction.update(userRef, {'stats': newStats.toJson()});
        
        // Verifica conquistas
        await _achievementRepo.checkAndUnlockAchievements(uid, newStats);
      }
    });
  }

  /// Marca uma lição como concluída
  Future<void> completeLesson({
    required String uid,
    required String planId,
    required int lessonIndex,
    required int totalLessons,
  }) async {
    final progressRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('active_plan')
        .doc('current');

    final doc = await progressRef.get();
    if (!doc.exists) return;

    final currentProgress = UserPlanProgress.fromJson(doc.data()!);
    
    // Evita duplicatas em completedLessons
    final completed = Set<int>.from(currentProgress.completedLessons)..add(lessonIndex);
    
    final nextLessonIndex = (lessonIndex < totalLessons) ? lessonIndex + 1 : lessonIndex;
    final progressPercent = completed.length / totalLessons;
    final isFinished = completed.length == totalLessons;

    await progressRef.update({
      'completedLessons': completed.toList(),
      'currentLessonIndex': isFinished ? lessonIndex : nextLessonIndex,
      'progress': progressPercent,
      'status': isFinished ? 'completed' : 'active',
    });

    // Atualiza estatísticas do usuário
    final userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final stats = UserStats.fromJson(userData['stats'] ?? {});
        final newStats = stats.copyWith(
          lessonsCompletedCount: stats.lessonsCompletedCount + 1,
          plansCompletedCount: isFinished ? stats.plansCompletedCount + 1 : stats.plansCompletedCount,
        );
        transaction.update(userRef, {'stats': newStats.toJson()});
        
        // Verifica conquistas
        await _achievementRepo.checkAndUnlockAchievements(uid, newStats);
      }
    });
  }
}

final studyPlanRepositoryProvider = Provider((ref) {
  final achievementRepo = ref.watch(achievementRepositoryProvider);
  return StudyPlanRepository(FirebaseFirestore.instance, achievementRepo);
});

final studyCatalogStreamProvider = StreamProvider<List<StudyPlan>>((ref) {
  return ref.watch(studyPlanRepositoryProvider).watchCatalog();
});

final activePlanProgressProvider = StreamProvider<UserPlanProgress?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value(null);
  return ref.watch(studyPlanRepositoryProvider).watchActivePlan(authUser.uid);
});

final planLessonsProvider = StreamProvider.family<List<StudyLesson>, String>((ref, planId) {
  return ref.watch(studyPlanRepositoryProvider).watchLessons(planId);
});
