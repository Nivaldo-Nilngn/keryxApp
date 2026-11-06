import 'dart:async';
import 'dart:io' as io;
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/platform_utils.dart';
import 'app_update_service.dart';

/// Status do download da atualização
enum UpdateDownloadStatus {
  idle,
  downloading,
  completed,
  error,
}

/// Estado reativo do download de atualização do aplicativo
class UpdateDownloadState {
  final UpdateDownloadStatus status;
  final double progress; // 0.0 a 1.0 (-1.0 para indeterminado)
  final int receivedBytes;
  final int totalBytes;
  final String? progressText; // Ex: "13% (30.0 MB / 224.4 MB)"
  final String? downloadedFilePath;
  final String? errorMessage;
  final String? targetVersion;

  const UpdateDownloadState({
    this.status = UpdateDownloadStatus.idle,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = -1,
    this.progressText,
    this.downloadedFilePath,
    this.errorMessage,
    this.targetVersion,
  });

  bool get isDownloading => status == UpdateDownloadStatus.downloading;
  bool get isCompleted => status == UpdateDownloadStatus.completed;
  bool get hasError => status == UpdateDownloadStatus.error;
  bool get isIdle => status == UpdateDownloadStatus.idle;

  UpdateDownloadState copyWith({
    UpdateDownloadStatus? status,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    String? progressText,
    String? downloadedFilePath,
    String? errorMessage,
    String? targetVersion,
  }) {
    return UpdateDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      progressText: progressText ?? this.progressText,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
      errorMessage: errorMessage ?? this.errorMessage,
      targetVersion: targetVersion ?? this.targetVersion,
    );
  }
}

/// Gerenciador de estado do download da atualização em segundo plano
class UpdateDownloadNotifier extends StateNotifier<UpdateDownloadState> {
  static UpdateDownloadNotifier? instance;

  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  UpdateDownloadNotifier() : super(const UpdateDownloadState()) {
    instance = this;
  }

  /// Cancela o download em andamento
  void cancel() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('Cancelado pelo usuário.');
    }
    _cancelToken = null;
    state = const UpdateDownloadState(status: UpdateDownloadStatus.idle);
  }

  /// Redefine o estado para ocioso
  void reset() {
    cancel();
    state = const UpdateDownloadState(status: UpdateDownloadStatus.idle);
  }

  /// Inicia o download e instalação em segundo plano (estilo card moderno sem diálogos bloqueantes)
  Future<void> startDownload({
    required String downloadUrl,
    String? iosUrl,
    String? expectedSha256,
    String? versionName,
    BuildContext? context,
  }) async {
    // Se já estiver baixando, evita disparos duplicados
    if (state.isDownloading) return;

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    state = UpdateDownloadState(
      status: UpdateDownloadStatus.downloading,
      progress: 0.0,
      progressText: 'Iniciando download...',
      targetVersion: versionName,
    );

    int lastPct = -1;

    try {
      // ── 1. Web: usa o gerenciador de downloads via Blob com progresso ──────
      if (kIsWeb) {
        final ok = await downloadFile(
          downloadUrl,
          fileName: 'keryxApp.apk',
          onProgress: (progress, loaded, total) {
            final pct = (progress * 100).toInt();
            String pText;
            if (progress >= 0 && total > 0) {
              final loadedMb = (loaded / (1024 * 1024)).toStringAsFixed(1);
              final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
              pText = '$pct% ($loadedMb MB / $totalMb MB)';
            } else {
              final loadedMb = (loaded / (1024 * 1024)).toStringAsFixed(1);
              pText = '$loadedMb MB baixados...';
            }

            state = UpdateDownloadState(
              status: UpdateDownloadStatus.downloading,
              progress: progress,
              receivedBytes: loaded,
              totalBytes: total,
              progressText: pText,
              targetVersion: versionName,
            );
          },
        );

        if (ok) {
          state = UpdateDownloadState(
            status: UpdateDownloadStatus.completed,
            progress: 1.0,
            progressText: 'Download concluído!',
            targetVersion: versionName,
          );

          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Download concluído com sucesso! Verifique sua pasta de downloads.'),
                backgroundColor: Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          state = UpdateDownloadState(
            status: UpdateDownloadStatus.error,
            errorMessage: 'Falha ao baixar pelo navegador.',
            targetVersion: versionName,
          );
        }
        return;
      }

      // ── 2. iOS Nativo: direciona para a App Store ou tela de PWA ──────────
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final targetUrl = (iosUrl != null && iosUrl.isNotEmpty)
            ? iosUrl
            : 'https://keryxapp.pages.dev';
        final uri = Uri.tryParse(targetUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        state = const UpdateDownloadState(status: UpdateDownloadStatus.idle);
        return;
      }

      // ── 3. Android Nativo: validação de segurança e download com Dio ──────
      if (!isTrustedDownloadUrl(downloadUrl)) {
        state = UpdateDownloadState(
          status: UpdateDownloadStatus.error,
          errorMessage: 'URL de atualização não autorizada ou insegura.',
          targetVersion: versionName,
        );
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A URL de atualização não pertence a uma fonte oficial autorizada.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final directory = await getTemporaryDirectory();
      final filePath = "${directory.path}/keryx_update.apk";
      final file = io.File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _dio.download(
        downloadUrl,
        filePath,
        cancelToken: _cancelToken,
        options: Options(
          followRedirects: true,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 10),
          validateStatus: (status) => status != null && status >= 200 && status < 300,
          headers: {
            'user-agent': 'KeryxApp-Updater/2.0 (Android)',
            'Accept': '*/*',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            final loadedMb = (received / (1024 * 1024)).toStringAsFixed(1);
            state = UpdateDownloadState(
              status: UpdateDownloadStatus.downloading,
              progress: -1.0,
              receivedBytes: received,
              totalBytes: total,
              progressText: '$loadedMb MB baixados...',
              targetVersion: versionName,
            );
            return;
          }

          final pct = (received * 100 ~/ total);
          if (pct != lastPct) {
            lastPct = pct;
            final progress = (received / total).clamp(0.0, 1.0);
            final loadedMb = (received / (1024 * 1024)).toStringAsFixed(1);
            final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
            final pText = '$pct% ($loadedMb MB / $totalMb MB)';

            state = UpdateDownloadState(
              status: UpdateDownloadStatus.downloading,
              progress: progress,
              receivedBytes: received,
              totalBytes: total,
              progressText: pText,
              targetVersion: versionName,
            );
          }
        },
      );

      // Verificação de integridade SHA-256 se fornecido
      if (expectedSha256 != null && expectedSha256.trim().isNotEmpty) {
        final expectedHash = expectedSha256.trim().toLowerCase();
        final digest = await crypto.sha256.bind(file.openRead()).first;
        final actualHash = digest.toString().toLowerCase();

        if (actualHash != expectedHash) {
          if (await file.exists()) {
            await file.delete();
          }
          throw Exception('A integridade do arquivo APK divergiu do hash oficial esperado.');
        }
      }

      // Download concluído com sucesso
      state = UpdateDownloadState(
        status: UpdateDownloadStatus.completed,
        progress: 1.0,
        progressText: 'Download concluído!',
        downloadedFilePath: filePath,
        targetVersion: versionName,
      );

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download concluído com sucesso! Abrindo instalador...'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Dispara automaticamente o instalador do pacote Android
      await openInstaller(filePath);
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        state = const UpdateDownloadState(status: UpdateDownloadStatus.idle);
        return;
      }

      String errorMessage = 'Erro ao baixar atualização.';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage = 'Tempo de conexão esgotado.';
        } else if (e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Tempo de resposta esgotado durante a transferência.';
        } else if (e.response?.statusCode == 404) {
          errorMessage = 'Arquivo não encontrado no servidor oficial (404).';
        } else if (e.type == DioExceptionType.cancel) {
          state = const UpdateDownloadState(status: UpdateDownloadStatus.idle);
          return;
        } else {
          errorMessage = 'Falha de rede: ${e.message ?? e.type.toString()}';
        }
      } else {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }

      state = UpdateDownloadState(
        status: UpdateDownloadStatus.error,
        errorMessage: errorMessage,
        targetVersion: versionName,
      );

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no download: $errorMessage'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Abre o instalador do APK baixado no Android
  Future<void> openInstaller(String filePath, {BuildContext? context}) async {
    try {
      final file = io.File(filePath);
      if (!await file.exists()) {
        state = state.copyWith(
          status: UpdateDownloadStatus.error,
          errorMessage: 'Arquivo do instalador não encontrado.',
        );
        return;
      }

      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível iniciar o instalador: ${result.message}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir instalador: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// Provider reativo global para o estado do download de atualizações
final updateDownloadProvider =
    StateNotifierProvider<UpdateDownloadNotifier, UpdateDownloadState>((ref) {
  return UpdateDownloadNotifier();
});

/// Serviço de download do aplicativo com interface simplificada
class DownloadService {
  final Ref? _ref;

  DownloadService([this._ref]);

  /// Dispara o download sem bloquear a tela do usuário com diálogos modais
  Future<void> downloadAndInstall(
    BuildContext context,
    dynamic target, {
    String? iosUrl,
    String? sha256Expected,
  }) async {
    final String downloadUrl = target is AppUpdateInfo
        ? target.downloadUrl
        : (target is String ? target : target.toString());
    final String resolvedIosUrl =
        (target is AppUpdateInfo && target.iosUrl.isNotEmpty)
            ? target.iosUrl
            : (iosUrl ?? '');
    final String? resolvedSha256 =
        target is AppUpdateInfo ? target.sha256 : sha256Expected;
    final String? versionName =
        target is AppUpdateInfo ? target.versionName : null;

    final notifier = _ref != null
        ? _ref.read(updateDownloadProvider.notifier)
        : UpdateDownloadNotifier.instance;

    if (notifier != null) {
      await notifier.startDownload(
        downloadUrl: downloadUrl,
        iosUrl: resolvedIosUrl,
        expectedSha256: resolvedSha256,
        versionName: versionName,
        context: context,
      );
    }
  }

  /// Abre o instalador do pacote Android caso já esteja baixado
  Future<void> openInstaller(String filePath, {BuildContext? context}) async {
    final notifier = _ref != null
        ? _ref.read(updateDownloadProvider.notifier)
        : UpdateDownloadNotifier.instance;
    await notifier?.openInstaller(filePath, context: context);
  }

  /// Cancela o download atual
  void cancelDownload() {
    final notifier = _ref != null
        ? _ref.read(updateDownloadProvider.notifier)
        : UpdateDownloadNotifier.instance;
    notifier?.cancel();
  }
}

final downloadServiceProvider = Provider<DownloadService>((ref) => DownloadService(ref));
