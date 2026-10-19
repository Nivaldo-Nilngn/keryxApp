import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadService {
  final Dio _dio = Dio();

  Future<void> downloadAndInstall(
    BuildContext context,
    String url,
  ) async {
    // Mostra o Diálogo de Progresso
    showDialog(
      context: context,
      barrierDismissible: false, // Bloqueia fechar durante o download
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

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      // Usar getTemporaryDirectory costuma ser mais compatível para o FileProvider
      // em muitos dispositivos Android para instalação de APKs
      final directory = await getTemporaryDirectory();
      final filePath = "${directory.path}/keryx_update.apk";

      // Limpa arquivo antigo se existir
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
                _progress = received / total;
              }
            });
          }
        },
      );

      if (mounted) Navigator.pop(context); // Fecha o diálogo

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao abrir APK: ${result.message}")),
          );
        }
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
    final downloadedMB = (_receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMB = _totalBytes != -1 ? (_totalBytes / (1024 * 1024)).toStringAsFixed(1) : null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(_error != null ? 'Erro no Download' : 'Baixando Atualização'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              )
            else ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: _totalBytes != -1 ? _progress : null,
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 20),
              if (_totalBytes != -1)
                Text("${(_progress * 100).toInt()}% completo ($downloadedMB MB de $totalMB MB)")
              else
                Text("$downloadedMB MB baixados (calculando...)"),
            ],
          ],
        ),
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('FECHAR'),
          ),
      ],
    );
  }
}

final downloadServiceProvider = Provider((ref) => DownloadService());
