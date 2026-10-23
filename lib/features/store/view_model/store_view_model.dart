import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/features/store/repository/store_repository.dart';
import 'package:keryx_app/features/home/view_model/notifications_provider.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';
import 'package:keryx_app/core/services/auth_service.dart';

class StoreState {
  final List<StoreItem> availablePackages;
  final Set<String> downloadedFilenames;
  final Set<String> cloudLibrary;
  final Set<String> deletingFilenames;
  final Map<String, double> downloadProgress;
  final bool isLoading;
  final bool isSyncingCloud;
  final String? error;
  
  const StoreState({
    this.availablePackages = const [],
    this.downloadedFilenames = const {},
    this.cloudLibrary = const {},
    this.deletingFilenames = const {},
    this.downloadProgress = const {},
    this.isLoading = false,
    this.isSyncingCloud = false,
    this.error,
  });
  
  StoreState copyWith({
    List<StoreItem>? availablePackages,
    Set<String>? downloadedFilenames,
    Set<String>? cloudLibrary,
    Set<String>? deletingFilenames,
    Map<String, double>? downloadProgress,
    bool? isLoading,
    bool? isSyncingCloud,
    String? error,
  }) {
    return StoreState(
      availablePackages: availablePackages ?? this.availablePackages,
      downloadedFilenames: downloadedFilenames ?? this.downloadedFilenames,
      cloudLibrary: cloudLibrary ?? this.cloudLibrary,
      deletingFilenames: deletingFilenames ?? this.deletingFilenames,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isLoading: isLoading ?? this.isLoading,
      isSyncingCloud: isSyncingCloud ?? this.isSyncingCloud,
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

  bool isInCloudLibrary(String filename) {
    if (cloudLibrary.contains(filename)) return true;
    if (!filename.contains('/')) {
      final suffix = '/$filename';
      if (cloudLibrary.any((path) => path.endsWith(suffix))) return true;
    }
    final base = filename.contains('/') ? filename.split('/').last : filename;
    if (cloudLibrary.any((c) => c == base || c.endsWith('/$base'))) return true;
    return false;
  }

  List<StoreItem> get missingCloudPackages {
    return availablePackages.where((item) {
      final inCloud = isInCloudLibrary(item.filename);
      final downloaded = isDownloaded(item.filename);
      return inCloud && !downloaded;
    }).toList();
  }
  
  bool isDeleting(String filename) => deletingFilenames.contains(filename);
}

class StoreNotifier extends StateNotifier<StoreState> {
  final StoreRepository _repository;
  final NotificationService _notificationService;
  final String? userId;
  
  StoreNotifier(this._repository, this._notificationService, {this.userId}) : super(const StoreState()) {
    loadPackages();
  }
  
  Future<void> loadPackages() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final packages = await _repository.getAvailablePackages();
      final downloaded = await _repository.getDownloadedFiles();
      
      Set<String> cloudSet = {};
      if (userId != null) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final rawCloud = userDoc.data()?['cloudLibrary'];
            if (rawCloud is List) {
              cloudSet = rawCloud.map((e) => e.toString()).toSet();
            }
          }

          // Se este dispositivo tem itens baixados que ainda não constam na nuvem, adiciona automaticamente
          final missingInCloud = downloaded.where((f) => !cloudSet.contains(f)).toList();
          if (missingInCloud.isNotEmpty) {
            await FirebaseFirestore.instance.collection('users').doc(userId).set({
              'cloudLibrary': FieldValue.arrayUnion(missingInCloud),
            }, SetOptions(merge: true));
            cloudSet.addAll(missingInCloud);
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao sincronizar cloudLibrary com Firestore: $e');
        }
      }
      
      state = state.copyWith(
        availablePackages: packages,
        downloadedFilenames: downloaded.toSet(),
        cloudLibrary: cloudSet,
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
    
    int lastProgressUpdateMs = 0;
    double lastProgressValue = 0.0;

    try {
      await _repository.downloadPackage(
        item,
        onProgress: (progress) {
          if (_cancelledFilenames.contains(filename)) return;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (progress >= 0.99 || (now - lastProgressUpdateMs >= 150 && (progress - lastProgressValue).abs() >= 0.01)) {
            lastProgressUpdateMs = now;
            lastProgressValue = progress;
            state = state.copyWith(
              downloadProgress: {...state.downloadProgress, filename: progress},
            );
          }
        },
      );
      
      if (_cancelledFilenames.contains(filename)) {
        _cancelledFilenames.remove(filename);
        return;
      }
      
      // Marca como baixado localmente e na nuvem
      final newDownloaded = {...state.downloadedFilenames, filename};
      final newCloud = {...state.cloudLibrary, filename};
      state = state.copyWith(
        downloadedFilenames: newDownloaded,
        cloudLibrary: newCloud,
        downloadProgress: {...state.downloadProgress}..remove(filename),
      );

      // Persiste na nuvem do usuário no Firestore
      if (userId != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'cloudLibrary': FieldValue.arrayUnion([filename]),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('⚠️ Erro ao salvar cloudLibrary no Firebase: $e');
        }
      }
      
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
  
  Future<void> deletePackage(StoreItem item, {bool removeFromCloud = false}) async {
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

    Set<String> updatedCloud = state.cloudLibrary;
    if (removeFromCloud) {
      updatedCloud = Set<String>.from(state.cloudLibrary)..remove(filename)..remove(base);
      if (userId != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'cloudLibrary': FieldValue.arrayRemove([filename, base]),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('⚠️ Erro ao remover do cloudLibrary: $e');
        }
      }
    }

    state = state.copyWith(
      downloadedFilenames: optimisticDownloaded,
      cloudLibrary: updatedCloud,
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

  Future<void> syncCloudLibrary() async {
    final missing = state.missingCloudPackages;
    if (missing.isEmpty) return;
    state = state.copyWith(isSyncingCloud: true);
    try {
      for (final item in missing) {
        await downloadPackage(item);
      }
    } catch (e) {
      debugPrint('⚠️ Erro durante sincronização em lote da nuvem: $e');
    } finally {
      state = state.copyWith(isSyncingCloud: false);
    }
  }

  Future<void> removeFromCloud(StoreItem item) async {
    final filename = item.filename;
    final base = filename.contains('/') ? filename.split('/').last : filename;
    final updatedCloud = Set<String>.from(state.cloudLibrary)..remove(filename)..remove(base);
    state = state.copyWith(cloudLibrary: updatedCloud);

    if (userId != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'cloudLibrary': FieldValue.arrayRemove([filename, base]),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('⚠️ Erro ao remover item da nuvem: $e');
      }
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
  final authAsync = ref.watch(authStateProvider);
  final userId = authAsync.value?.uid;
  return StoreNotifier(repository, notificationService, userId: userId);
});

/// Provider otimizado para telas que apenas precisam saber se pacotes foram baixados ou estão disponíveis,
/// evitando rebuilds desnecessários durante o progresso contínuo de downloads (downloadProgress).
final downloadedStorePackagesProvider = Provider<StoreState>((ref) {
  ref.watch(storeProvider.select((s) => s.downloadedFilenames));
  ref.watch(storeProvider.select((s) => s.availablePackages));
  ref.watch(storeProvider.select((s) => s.cloudLibrary));
  return ref.read(storeProvider);
});

