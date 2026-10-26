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
  /// Executa a limpeza com base nas opções personalizadas selecionadas pelo usuário
  static Future<void> resetData(
    WidgetRef ref, {
    required ResetDataOptions options,
    void Function(String stepMessage)? onProgress,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

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
      }

      // 3. Progresso de Leitura Bíblica ("LENDO", capítulos concluídos, streaks)
      if (options.readingProgress) {
        onProgress?.call('Redefinindo progresso e histórico de leitura...');
        if (uid != null) {
          try {
            await ref.read(readingRepositoryProvider).clearAllReadingHistory(uid);
          } catch (e) {
            debugPrint('Erro ao limpar histórico de leitura: $e');
          }
        }
        await ref.read(lastReadProvider.notifier).clear();
        await ref.read(lastCommentaryReadProvider.notifier).clear();

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_read_session');
        await prefs.remove('recent_books');
        await prefs.remove('recent_devotionals');
      }

      // 4. Documentos, Sermões e Estudos (NoteCards)
      if (options.documentsAndStudies) {
        onProgress?.call('Removendo documentos e sermões criados...');
        await ref.read(noteCardsProvider.notifier).clearAll();
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
