import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/features/store/repository/store_repository.dart';
import 'package:keryx_app/features/home/view_model/notifications_provider.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';

class StoreState {
  final List<StoreItem> availablePackages;
  final Set<String> downloadedFilenames;
  final Set<String> deletingFilenames;
  final Map<String, double> downloadProgress;
  final bool isLoading;
  final String? error;
  
  const StoreState({
    this.availablePackages = const [],
    this.downloadedFilenames = const {},
    this.deletingFilenames = const {},
    this.downloadProgress = const {},
    this.isLoading = false,
    this.error,
  });
  
  StoreState copyWith({
    List<StoreItem>? availablePackages,
    Set<String>? downloadedFilenames,
    Set<String>? deletingFilenames,
    Map<String, double>? downloadProgress,
    bool? isLoading,
    String? error,
  }) {
    return StoreState(
      availablePackages: availablePackages ?? this.availablePackages,
      downloadedFilenames: downloadedFilenames ?? this.downloadedFilenames,
      deletingFilenames: deletingFilenames ?? this.deletingFilenames,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
  
  bool isDownloaded(String filename) {
    // 1. Match exato
    if (downloadedFilenames.contains(filename)) return true;
    
    // 2. Se for nome base (sem barra), procura se algum path termina com ele
    if (!filename.contains('/')) {
      final suffix = '/$filename';
      if (downloadedFilenames.any((path) => path.endsWith(suffix))) return true;
      
      // Fix para Fontes (arquivo.zip extraído para pasta fonts/)
      if (filename.startsWith('font_') && filename.endsWith('.zip')) {
        final folderName = filename.replaceAll('font_', '').replaceAll('.zip', '');
        return downloadedFilenames.any((path) => path.startsWith('fonts/$folderName/'));
      }
    }
    
    return false;
  }
  
  bool isDeleting(String filename) => deletingFilenames.contains(filename);
}

class StoreNotifier extends StateNotifier<StoreState> {
  final StoreRepository _repository;
  final NotificationService _notificationService;
  
  StoreNotifier(this._repository, this._notificationService) : super(const StoreState()) {
    loadPackages();
  }
  
  Future<void> loadPackages() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final packages = await _repository.getAvailablePackages();
      
      final downloaded = await _repository.getDownloadedFiles();
      
      // Log por categoria
      final categories = <StoreCategory>[];
      for (var item in packages) {
        if (!categories.contains(item.category)) {
          categories.add(item.category);
        }
      }
      
      state = state.copyWith(
        availablePackages: packages,
        downloadedFilenames: downloaded.toSet(),
        isLoading: false,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao carregar loja: $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  final Set<String> _cancelledFilenames = {};

  Future<void> downloadPackage(StoreItem item) async {
    final filename = item.filename;
    _cancelledFilenames.remove(filename);
    
    // Atualiza progresso para 0
    state = state.copyWith(
      downloadProgress: {...state.downloadProgress, filename: 0.0},
    );
    
    try {
      await _repository.downloadPackage(
        item,
        onProgress: (progress) {
          if (_cancelledFilenames.contains(filename)) return;
          state = state.copyWith(
            downloadProgress: {...state.downloadProgress, filename: progress},
          );
        },
      );
      
      if (_cancelledFilenames.contains(filename)) {
        _cancelledFilenames.remove(filename);
        return;
      }
      
      // Marca como baixado
      final newDownloaded = {...state.downloadedFilenames, filename};
      state = state.copyWith(
        downloadedFilenames: newDownloaded,
        downloadProgress: {...state.downloadProgress}..remove(filename),
      );
      
      if (item.category == StoreCategory.fonts) {
         await CustomFontLoader.loadDownloadedFonts();
      }
      
      _notificationService.addNotification(
        title: 'Download Concluído',
        message: 'O pacote "${item.name}" foi baixado com sucesso.',
        type: 'download',
      );
    } catch (e) {
      final isCancelled = _cancelledFilenames.contains(filename);
      _cancelledFilenames.remove(filename);
      
      state = state.copyWith(
        downloadProgress: {...state.downloadProgress}..remove(filename),
        error: isCancelled ? null : e.toString(),
      );
      if (!isCancelled) {
        rethrow;
      }
    }
  }
  
  Future<void> cancelDownload(StoreItem item) async {
    final filename = item.filename;
    _cancelledFilenames.add(filename);
    
    _repository.cancelDownload(filename);
    
    final newProgress = Map<String, double>.from(state.downloadProgress);
    newProgress.remove(filename);
    
    state = state.copyWith(
      downloadProgress: newProgress,
    );
    
    debugPrint('🛑 Download cancelado com sucesso: ${item.name}');
  }
  
  Future<void> deletePackage(StoreItem item) async {
    final filename = item.filename;
    final base = filename.contains('/') ? filename.split('/').last : filename;
    
    // OPTIMISTIC UPDATE: Remove imediatamente do estado local para a UI responder no mesmo frame
    final optimisticDownloaded = {...state.downloadedFilenames};
    optimisticDownloaded.removeWhere((path) =>
        path == filename ||
        path.endsWith('/$filename') ||
        path == base ||
        path.endsWith('/$base'));
    
    if (filename.startsWith('font_') && filename.endsWith('.zip')) {
      final folderName = filename.replaceAll('font_', '').replaceAll('.zip', '');
      optimisticDownloaded.removeWhere((path) => path.startsWith('fonts/$folderName/'));
    }

    state = state.copyWith(
      downloadedFilenames: optimisticDownloaded,
      deletingFilenames: {...state.deletingFilenames, filename},
    );
    
    try {
      await _repository.deletePackage(item);
      final freshDownloaded = await _repository.getDownloadedFiles();
      
      final newDeleting = {...state.deletingFilenames}..remove(filename);
      
      state = state.copyWith(
        downloadedFilenames: freshDownloaded.toSet(),
        deletingFilenames: newDeleting,
      );
    } catch (e) {
      final newDeleting = {...state.deletingFilenames}..remove(filename);
      state = state.copyWith(
        deletingFilenames: newDeleting,
        error: e.toString()
      );
      rethrow;
    }
  }
  
  Future<void> refresh() async {
    await loadPackages();
  }
}

// Providers
final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository();
});

final storeProvider = StateNotifierProvider<StoreNotifier, StoreState>((ref) {
  final repository = ref.watch(storeRepositoryProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return StoreNotifier(repository, notificationService);
});
