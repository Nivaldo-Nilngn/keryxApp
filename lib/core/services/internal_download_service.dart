import 'dart:io' as io;
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/platform_utils.dart';
import '../theme/app_theme.dart';
import 'app_update_service.dart';

class DownloadService {
  final Dio _dio = Dio();

  Future<void> downloadAndInstall(
    BuildContext context,
    dynamic target, {
    String? iosUrl,
    String? sha256Expected,
  }) async {
    final String downloadUrl = target is AppUpdateInfo
        ? target.downloadUrl
        : (target is String ? target : target.toString());
    final String resolvedIosUrl = (target is AppUpdateInfo && target.iosUrl.isNotEmpty)
        ? target.iosUrl
        : (iosUrl ?? '');
    final String? resolvedSha256 = target is AppUpdateInfo
        ? target.sha256
        : sha256Expected;

    // ── 1. Web: usa o gerenciador de downloads nativo do navegador
    if (kIsWeb) {
      downloadFile(downloadUrl, fileName: 'keryxApp.apk');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download do keryxApp.apk iniciado no navegador!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ── 2. iOS Nativo: direciona para a App Store / TestFlight ou URL do PWA
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final targetUrl = resolvedIosUrl.isNotEmpty ? resolvedIosUrl : 'https://keryxapp.pages.dev';
      final uri = Uri.tryParse(targetUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // ── 3. Android Nativo: validação de segurança e download com progresso
    if (!isTrustedDownloadUrl(downloadUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A URL de atualização não foi reconhecida como uma fonte oficial confiável.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadProgressDialog(
        downloadUrl: downloadUrl,
        sha256Expected: resolvedSha256,
        dio: _dio,
      ),
    );
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  final String downloadUrl;
  final String? sha256Expected;
  final Dio dio;

  const _DownloadProgressDialog({
    required this.downloadUrl,
    this.sha256Expected,
    required this.dio,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  final ValueNotifier<double?> _progressNotifier = ValueNotifier<double?>(0);
  final ValueNotifier<int> _receivedNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _totalNotifier = ValueNotifier<int>(-1);
  final CancelToken _cancelToken = CancelToken();

  int _lastPct = -1;
  String? _error;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _startNativeDownload();
  }

  @override
  void dispose() {
    _progressNotifier.dispose();
    _receivedNotifier.dispose();
    _totalNotifier.dispose();
    super.dispose();
  }

  void _cancelDownload() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel('Cancelado pelo usuário.');
    }
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _startNativeDownload() async {
    setState(() {
      _error = null;
      _isCompleted = false;
      _lastPct = -1;
    });
    _progressNotifier.value = 0;
    _receivedNotifier.value = 0;
    _totalNotifier.value = -1;

    try {
      final directory = await getTemporaryDirectory();
      final filePath = "${directory.path}/keryx_update.apk";

      final file = io.File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Download com Dio com validação estrita de status 2xx (detectando 404 e erros de servidor)
      await widget.dio.download(
        widget.downloadUrl,
        filePath,
        cancelToken: _cancelToken,
        options: Options(
          followRedirects: true,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 8),
          validateStatus: (status) => status != null && status >= 200 && status < 300,
          headers: {
            'user-agent': 'KeryxApp-Updater/2.0 (Android)',
            'Accept': '*/*',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            _receivedNotifier.value = received;
            return;
          }
          final pct = (received * 100 ~/ total);
          // Otimização: atualiza a UI apenas quando o percentual inteiro mudar
          if (pct != _lastPct) {
            _lastPct = pct;
            _progressNotifier.value = received / total;
            _receivedNotifier.value = received;
            _totalNotifier.value = total;
          }
        },
      );

      // Verificação opcional de integridade SHA-256 se fornecido
      if (widget.sha256Expected != null && widget.sha256Expected!.isNotEmpty) {
        final expectedHash = widget.sha256Expected!.trim().toLowerCase();
        final digest = await crypto.sha256.bind(file.openRead()).first;
        final actualHash = digest.toString().toLowerCase();

        if (actualHash != expectedHash) {
          if (await file.exists()) {
            await file.delete();
          }
          throw Exception('A integridade do arquivo APK baixado divergiu do hash oficial esperado.');
        }
      }

      if (mounted) {
        setState(() => _isCompleted = true);
        Navigator.of(context, rootNavigator: true).pop(); // Fecha o diálogo
      }

      // Abre o instalador do pacote Android
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível iniciar o instalador: ${result.message}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (_cancelToken.isCancelled) return;

      String errorMessage = 'Erro ao baixar atualização.';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage = 'Tempo de conexão esgotado.';
        } else if (e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Tempo de resposta esgotado durante a transferência.';
        } else if (e.response?.statusCode == 404) {
          errorMessage = 'Arquivo de atualização não encontrado no servidor oficial (404).';
        } else if (e.type == DioExceptionType.cancel) {
          return;
        } else {
          errorMessage = 'Falha de rede: ${e.message ?? e.type.toString()}';
        }
      } else {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }

      if (mounted) {
        setState(() => _error = errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = _error != null
        ? Colors.redAccent
        : (_isCompleted ? const Color(0xFF10B981) : AppTheme.kPrimaryGold);

    final title = _error != null
        ? 'Falha no Download'
        : (_isCompleted ? 'Download Concluído!' : 'Baixando Atualização');

    final icon = _error != null
        ? Icons.error_outline_rounded
        : (_isCompleted ? Icons.check_circle_rounded : Icons.downloading_rounded);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              ValueListenableBuilder<double?>(
                valueListenable: _progressNotifier,
                builder: (context, progress, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.kPrimaryGold),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: Listenable.merge([_progressNotifier, _receivedNotifier, _totalNotifier]),
                builder: (context, _) {
                  final progress = _progressNotifier.value ?? 0;
                  final received = _receivedNotifier.value;
                  final total = _totalNotifier.value;
                  final downloadedMB = (received / (1024 * 1024)).toStringAsFixed(1);
                  final totalMB = total > 0 ? (total / (1024 * 1024)).toStringAsFixed(1) : null;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        total > 0 ? '${(progress * 100).toInt()}% concluído' : 'Transferindo...',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        totalMB != null ? '$downloadedMB / $totalMB MB' : '$downloadedMB MB',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Baixando o pacote oficial do KeryxApp. Aguarde a conclusão.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_error != null) ...[
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('FECHAR'),
          ),
          ElevatedButton(
            onPressed: _startNativeDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.kPrimaryGold,
              foregroundColor: const Color(0xFF111223),
            ),
            child: const Text('TENTAR NOVAMENTE'),
          ),
        ] else ...[
          TextButton(
            onPressed: _cancelDownload,
            child: const Text('CANCELAR'),
          ),
        ],
      ],
    );
  }
}

final downloadServiceProvider = Provider((ref) => DownloadService());
