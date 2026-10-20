import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/platform_utils.dart';
import '../theme/app_theme.dart';

class DownloadService {
  final Dio _dio = Dio();

  Future<void> downloadAndInstall(
    BuildContext context,
    String url,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadProgressDialog(url: url, dio: _dio),
    );
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  final String url;
  final Dio dio;
  const _DownloadProgressDialog({required this.url, required this.dio});

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
  int _receivedBytes = 0;
  int _totalBytes = -1;
  String? _error;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() {
    setState(() {
      _progress = 0;
      _receivedBytes = 0;
      _totalBytes = -1;
      _error = null;
      _isCompleted = false;
    });

    if (kIsWeb) {
      _startWebDownload();
    } else {
      _startNativeDownload();
    }
  }

  void _startWebDownload() {
    downloadFileWithProgress(
      widget.url,
      onProgress: (received, total) {
        if (mounted) {
          setState(() {
            _receivedBytes = received;
            _totalBytes = total;
            if (total > 0) {
              _progress = (received / total).clamp(0.0, 1.0);
            }
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isCompleted = true;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _error = err;
          });
        }
      },
    );
  }

  Future<void> _startNativeDownload() async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = "${directory.path}/keryx_update.apk";

      final file = io.File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      await widget.dio.download(
        widget.url,
        filePath,
        options: Options(
          followRedirects: true,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'user-agent': 'Mozilla/5.0 (Linux; Android 10) KeryxApp/1.0',
            'Accept': '*/*',
          },
        ),
        onReceiveProgress: (received, total) {
          if (mounted) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
              if (total != -1) {
                _progress = (received / total).clamp(0.0, 1.0);
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isCompleted = true;
        });
      }

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao abrir APK: ${result.message}")),
        );
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage = "Tempo de conexão esgotado";
        } else if (e.type == DioExceptionType.receiveTimeout) {
          errorMessage = "Tempo de download esgotado";
        } else if (e.response?.statusCode == 404) {
          errorMessage = "Arquivo não encontrado no servidor (404)";
        } else {
          errorMessage = "Erro de rede: ${e.message ?? e.type.toString()}";
        }
      }
      if (mounted) setState(() => _error = errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final downloadedMB = (_receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMB = _totalBytes > 0 ? (_totalBytes / (1024 * 1024)).toStringAsFixed(1) : null;

    final primaryColor = _error != null
        ? Colors.redAccent
        : (_isCompleted ? const Color(0xFF10B981) : AppTheme.kPrimaryGold);

    final title = _error != null
        ? 'Erro no Download'
        : (_isCompleted ? 'Download Concluído!' : 'Baixando Aplicativo (APK)');

    final icon = _error != null
        ? Icons.error_outline_rounded
        : (_isCompleted ? Icons.check_circle_rounded : Icons.downloading_rounded);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
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
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  downloadFile(widget.url);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.file_download_rounded, size: 18),
                label: const Text('Baixar pelo Navegador em 2º Plano'),
              ),
            ] else if (_isCompleted) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 40),
                    const SizedBox(height: 10),
                    Text(
                      'Arquivo keryxApp.apk pronto!',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      kIsWeb
                          ? 'O instalador foi salvo no seu aparelho. Toque no arquivo na barra de notificações ou acesse a pasta Downloads para instalar.'
                          : 'O instalador nativo foi iniciado. Siga as instruções na tela do aparelho.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _totalBytes > 0 ? _progress : null,
                  minHeight: 12,
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.kPrimaryGold),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _totalBytes > 0
                        ? '${(_progress * 100).toInt()}% concluído'
                        : 'Baixando arquivo...',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    _totalBytes > 0
                        ? '$downloadedMB / $totalMB MB'
                        : '$downloadedMB MB',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Aguarde enquanto o arquivo oficial é transferido para o seu dispositivo.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      downloadFile(widget.url);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Download em segundo plano iniciado nas notificações!'),
                          backgroundColor: Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_active_outlined, size: 16),
                    label: const Text(
                      'Baixar direto pelas notificações',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (_error != null) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: _startDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.kPrimaryGold,
              foregroundColor: const Color(0xFF111223),
            ),
            child: const Text('TENTAR NOVAMENTE'),
          ),
        ] else if (_isCompleted) ...[
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('CONCLUIR'),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('MINIMIZAR'),
          ),
        ],
      ],
    );
  }
}

final downloadServiceProvider = Provider((ref) => DownloadService());
