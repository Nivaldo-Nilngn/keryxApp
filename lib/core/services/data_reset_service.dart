import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/core/services/database_service.dart';
import 'package:keryx_app/core/services/bible_service.dart';
import 'package:keryx_app/core/services/pdf_service.dart';
import 'package:keryx_app/core/utils/bible_text_parser.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/reading/repository/reading_repository.dart';
import 'package:keryx_app/features/study/view_model/note_cards_provider.dart';

/// Opções de limpeza selecionáveis pelo usuário
class ResetDataOptions {
  bool biblesAndStore;
  bool pdfsAndEbooks;
  bool readingProgress;
  bool documentsAndStudies;
  bool favoritesAndHighlights;
  bool verseAnnotations;
  bool cachesAndHistory;

  ResetDataOptions({
    this.biblesAndStore = true,
    this.pdfsAndEbooks = true,
    this.readingProgress = true,
    this.documentsAndStudies = true,
    this.favoritesAndHighlights = true,
    this.verseAnnotations = true,
    this.cachesAndHistory = true,
  });

  bool get isAllSelected =>
      biblesAndStore &&
      pdfsAndEbooks &&
      readingProgress &&
      documentsAndStudies &&
      favoritesAndHighlights &&
      verseAnnotations &&
      cachesAndHistory;

  bool get hasAnySelected =>
      biblesAndStore ||
      pdfsAndEbooks ||
      readingProgress ||
      documentsAndStudies ||
      favoritesAndHighlights ||
      verseAnnotations ||
      cachesAndHistory;

  int get selectedCount {
    int count = 0;
    if (biblesAndStore) count++;
    if (pdfsAndEbooks) count++;
    if (readingProgress) count++;
    if (documentsAndStudies) count++;
    if (favoritesAndHighlights) count++;
    if (verseAnnotations) count++;
    if (cachesAndHistory) count++;
    return count;
  }

  void setAll(bool value) {
    biblesAndStore = value;
    pdfsAndEbooks = value;
    readingProgress = value;
    documentsAndStudies = value;
    favoritesAndHighlights = value;
    verseAnnotations = value;
    cachesAndHistory = value;
  }
}

/// Serviço responsável por coordenar a limpeza e redefinição de dados locais e na nuvem,
/// permitindo que o usuário escolha exatamente o que deseja apagar ou comece do zero.
class DataResetService {
  /// Remove todos os documentos de uma subcoleção usando batch
  static Future<void> _deleteSubcollection(CollectionReference colRef) async {
    try {
      final snap = await colRef.get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Aviso ao apagar subcoleção ${colRef.path}: $e');
    }
  }

  /// Executa a limpeza com base nas opções personalizadas selecionadas pelo usuário
  static Future<void> resetData(
    WidgetRef ref, {
    required ResetDataOptions options,
    void Function(String stepMessage)? onProgress,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final firestore = FirebaseFirestore.instance;

      // 1. Bíblias e Módulos da Loja (IndexedDB / SQLite local)
      if (options.biblesAndStore) {
        onProgress?.call('Removendo bíblias e módulos da loja...');
        await ref.read(storeProvider.notifier).clearAllDownloadedAndCloud();
        await DatabaseService().closeAll();
        BibleService.clearAllCaches();
        BibleService.notifyDatabaseDownloaded(null);
        BibleTextParser.clearCache();
        await ref.read(selectedVersionProvider.notifier).setVersion(BibleService.defaultVersion);
      }

      // 2. PDFs e E-books Baixados
      if (options.pdfsAndEbooks) {
        onProgress?.call('Limpando PDFs e e-books baixados...');
        await PdfService().clearAllDownloadedPdfs();

        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getKeys();
        for (final k in keys) {
          if (k.contains('_page') || k.contains('_bookmarks') || k.startsWith('pdf_')) {
            await prefs.remove(k);
          }
        }

        if (uid != null) {
          try {
            // Limpa marcações e páginas de PDF salvas na subcoleção users/$uid/highlights
            final highlightsSnap = await firestore
                .collection('users')
                .doc(uid)
                .collection('highlights')
                .get();
            final batch = firestore.batch();
            bool hadPdfHighlights = false;
            for (final doc in highlightsSnap.docs) {
              final data = doc.data();
              if (data.containsKey('currentPage') ||
                  data.containsKey('totalPages') ||
                  data.containsKey('bookmarks') ||
                  data.containsKey('highlights')) {
                batch.delete(doc.reference);
                hadPdfHighlights = true;
              }
            }
            if (hadPdfHighlights) {
              await batch.commit();
            }
          } catch (e) {
            debugPrint('Aviso ao limpar destaques de PDF na nuvem: $e');
          }
        }
      }

      // 3. Progresso de Leitura Bíblica ("LENDO", capítulos concluídos, streaks) e de Livros
      if (options.readingProgress) {
        onProgress?.call('Redefinindo progresso e histórico de leitura...');
        if (uid != null) {
          try {
            await ref.read(readingRepositoryProvider).clearAllReadingHistory(uid);
          } catch (e) {
            debugPrint('Erro ao limpar histórico de leitura: $e');
          }

          // Limpa conquistas (achievements) desbloqueadas
          try {
            await _deleteSubcollection(
              firestore.collection('users').doc(uid).collection('achievements'),
            );
          } catch (e) {
            debugPrint('Erro ao limpar conquistas: $e');
          }

          // Limpa plano ativo (active_plan)
          try {
            await _deleteSubcollection(
              firestore.collection('users').doc(uid).collection('active_plan'),
            );
          } catch (e) {
            debugPrint('Erro ao limpar plano ativo: $e');
          }
        }
        await ref.read(lastReadProvider.notifier).clear();
        await ref.read(lastCommentaryReadProvider.notifier).clear();

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_read_session');
        await prefs.remove('recent_books');
        await prefs.remove('recent_devotionals');

        // Limpa marcadores de livros HTML locais (bkm_*)
        final keys = prefs.getKeys();
        for (final k in keys) {
          if (k.startsWith('bkm_')) {
            await prefs.remove(k);
          }
        }
      }

      // 4. Documentos, Sermões e Estudos (NoteCards, Sermons, Outlines)
      if (options.documentsAndStudies) {
        onProgress?.call('Removendo documentos e sermões criados...');
        await ref.read(noteCardsProvider.notifier).clearAll();
        if (uid != null) {
          try {
            await _deleteSubcollection(
              firestore.collection('users').doc(uid).collection('sermons'),
            );
            await _deleteSubcollection(
              firestore.collection('users').doc(uid).collection('outlines'),
            );
          } catch (e) {
            debugPrint('Erro ao limpar sermões/esboços: $e');
          }
        }
      }

      // 5. Favoritos e Marcações com Cores
      if (options.favoritesAndHighlights) {
        onProgress?.call('Limpando favoritos e marcações de versículos...');
        await ref.read(favoritesProvider.notifier).clearAll();
        await ref.read(highlightsProvider.notifier).clearAll();
      }

      // 6. Anotações de Versículos
      if (options.verseAnnotations) {
        onProgress?.call('Removendo anotações nos versículos...');
        await ref.read(annotationsProvider.notifier).clearAll();
      }

      // 7. Caches e Histórico Temporário
      if (options.cachesAndHistory) {
        onProgress?.call('Limpando caches e preferências temporárias...');
        BibleService.clearAllCaches();
        BibleTextParser.clearCache();
        final prefs = await SharedPreferences.getInstance();
        final cacheKeys = [
          'reader_font_size',
          'verse_of_day_data',
          'verse_of_day_date',
          'last_read_session',
        ];
        for (final k in cacheKeys) {
          await prefs.remove(k);
        }
      }

      // 8. LIMPEZA PROFUNDA DE RESÍDUOS NO DOCUMENTO users/{uid}
      // Remove definitivamente os campos no Firestore para não deixar nenhum resíduo
      if (uid != null) {
        onProgress?.call('Eliminando resíduos no Firebase...');
        final Map<String, dynamic> firestoreDeletions = {};

        if (options.readingProgress) {
          firestoreDeletions['book_progress'] = FieldValue.delete();
          firestoreDeletions['stats'] = FieldValue.delete();
        }
        if (options.biblesAndStore) {
          firestoreDeletions['cloudLibrary'] = FieldValue.delete();
        }
        if (options.pdfsAndEbooks) {
          firestoreDeletions['cloudPdfs'] = FieldValue.delete();
        }

        if (firestoreDeletions.isNotEmpty) {
          try {
            await firestore.collection('users').doc(uid).update(firestoreDeletions);
            debugPrint('🧹 [DataResetService] Resíduos eliminados em users/$uid: ${firestoreDeletions.keys.toList()}');
          } catch (e) {
            debugPrint('⚠️ Erro ao atualizar documento users/$uid com FieldValue.delete: $e');
          }
        }
      }

      onProgress?.call('Concluído!');
      debugPrint('🧹 Limpeza selecionada de dados concluída com sucesso!');
    } catch (e, st) {
      debugPrint('❌ Erro durante resetData: $e\n$st');
      rethrow;
    }
  }

  /// Atalho para limpar tudo
  static Future<void> resetAllData(
    WidgetRef ref, {
    void Function(String stepMessage)? onProgress,
  }) =>
      resetData(
        ref,
        options: ResetDataOptions(),
        onProgress: onProgress,
      );
}
