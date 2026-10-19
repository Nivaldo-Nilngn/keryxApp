import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import '../model/reading_history_model.dart';

import '../../achievements/repository/achievement_repository.dart';
import '../../auth/model/user_model.dart';

final readingRepositoryProvider = Provider((ref) {
  return ReadingRepository(
    FirebaseFirestore.instance,
    ref.read(achievementRepositoryProvider),
  );
});

final weeklyProgressProvider = StreamProvider<Set<int>>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value({});
  
  return ref.watch(readingRepositoryProvider).watchWeeklyHistory(authUser.uid);
});

final allReadingProgressProvider = StreamProvider<Map<String, Set<int>>>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value({});
  
  return ref.watch(readingRepositoryProvider).watchAllChaptersRead(authUser.uid);
});

class ReadingRepository {
  final FirebaseFirestore _firestore;
  final AchievementRepository _achievementRepository;

  ReadingRepository(this._firestore, this._achievementRepository);

  /// Retorna o histórico da semana atual (domingo a sábado)
  Stream<Set<int>> watchWeeklyHistory(String uid) {
    final now = DateTime.now();
    // Encontrar o domingo passado
    final sunday = now.subtract(Duration(days: now.weekday % 7));
    final startOfNextWeek = sunday.add(const Duration(days: 7));
    
    final startStr = "${sunday.year}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')}";
    final endStr = "${startOfNextWeek.year}-${startOfNextWeek.month.toString().padLeft(2, '0')}-${startOfNextWeek.day.toString().padLeft(2, '0')}";

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('reading_history')
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThan: endStr)
        .snapshots()
        .map((snapshot) {
      final Set<int> doneDays = {};
      for (var doc in snapshot.docs) {
        final dateStr = doc.id; // YYYY-MM-DD
        try {
          final date = DateTime.parse(dateStr);
          doneDays.add(date.weekday % 7); // 0 = Dom, 6 = Sáb
        } catch (_) {}
      }
      return doneDays;
    }).handleError((e) {
      if (!e.toString().contains('permission-denied')) {
        debugPrint("Erro ao observar histórico semanal: $e");
      }
      return <int>{};
    });
  }

  /// Retorna o conjunto de capítulos lidos por livro (Geral)
  Stream<Map<String, Set<int>>> watchAllChaptersRead(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('reading_history')
        .snapshots()
        .map((snapshot) {
      final Map<String, Set<int>> bookProgress = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List<dynamic> chapters = data['chapters'] ?? [];
        for (var c in chapters) {
          final abbrev = c['book'] as String;
          final chapter = c['chapter'] as int;
          if (!bookProgress.containsKey(abbrev)) {
            bookProgress[abbrev] = {};
          }
          bookProgress[abbrev]!.add(chapter);
        }
      }
      return bookProgress;
    }).handleError((e) {
      if (!e.toString().contains('permission-denied')) {
        debugPrint("Erro ao observar capítulos lidos: $e");
      }
      return <String, Set<int>>{};
    });
  }

  /// Salva uma sessão de leitura calculando o streak automaticamente usando Batch!
  Future<void> endReadingSession({
    required String uid,
    required String todayDateString, // Ex: "2026-03-16"
    required String yesterdayDateString, // Ex: "2026-03-15"
    required int durationSeconds,
    required List<ChapterRead> chaptersRead,
  }) async {
    final batch = _firestore.batch();
    
    final userRef = _firestore.collection('users').doc(uid);
    final historyRef = userRef.collection('reading_history').doc(todayDateString);

    // 1. Ler o state atual do usuário (precisamos do lastReadDate e stats)
    final userDoc = await userRef.get();
    if (!userDoc.exists) return; // Segurança, não deveria acontecer

    final userData = userDoc.data()!;
    final statsData = Map<String, dynamic>.from(userData['stats'] ?? {});
    
    int currentStreak = statsData['currentStreak'] ?? 0;
    int longestStreak = statsData['longestStreak'] ?? 0;
    int totalDays = statsData['totalDays'] ?? 0;
    int totalSessions = statsData['totalSessions'] ?? 0;
    String? lastReadDate = statsData['lastReadDate'];

    // 2. Calcular o Streak
    if (lastReadDate == yesterdayDateString) {
      // Leu ontem, mantem a sequência crescendo!
      currentStreak++;
      totalDays++; // Mais um dia de leitura
    } else if (lastReadDate == todayDateString) {
      // Já leu hoje antes, o streak continua o mesmo, só soma a sessão
    } else {
      // Pulou algum dia, perdeu a sequência :(
      currentStreak = 1;
      totalDays++; // Um novo dia pra conta total
    }

    // Atualiza o recorde
    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    // 3. Atualizar o Documento de Usuário (Stats)
    batch.update(userRef, {
      'stats': {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'totalDays': totalDays,
        'totalSessions': totalSessions + 1,
        'lastReadDate': todayDateString,
      }
    });

    // 4. Salvar os detalhes de Hoje no Histórico (Merge na data atual)
    // Se o usuário já leu, agrupamos os capítulos e somamos o tempo
    final historyDoc = await historyRef.get();
    List<dynamic> existingChapters = [];
    int existingDuration = 0;
    
    if (historyDoc.exists) {
      existingChapters = historyDoc.data()?['chapters'] ?? [];
      existingDuration = historyDoc.data()?['durationSeconds'] ?? 0;
    }

    // Juntar os capítulos antigos com os novos, removendo duplicados se quiser (simplificando por agora)
    for (var novoCap in chaptersRead) {
      existingChapters.add(novoCap.toJson());
    }

    batch.set(historyRef, {
      'date': todayDateString,
      'durationSeconds': existingDuration + durationSeconds,
      'chapters': existingChapters,
    }, SetOptions(merge: true));

    // 5. Commit de tudo no Firestore!
    await batch.commit();

    // 6. Verificar conquistas (Desencadeado pelo fim da sessão)
    final newStats = UserStats(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalDays: totalDays,
      totalSessions: totalSessions + 1,
      lastReadDate: todayDateString,
    );
    await _achievementRepository.checkAndUnlockAchievements(uid, newStats);
  }

  /// Remove o progresso de leitura de um livro específico
  Future<void> clearBookProgress(String uid, String abbrev) async {
    final historyRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('reading_history');

    final snapshot = await historyRef.get();
    final batch = _firestore.batch();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final chapters = List<dynamic>.from(data['chapters'] ?? []);
      
      bool changed = false;
      chapters.removeWhere((c) {
        if (c['book'] == abbrev) {
          changed = true;
          return true;
        }
        return false;
      });

      if (changed) {
        batch.update(doc.reference, {'chapters': chapters});
      }
    }

    await batch.commit();
  }
}
