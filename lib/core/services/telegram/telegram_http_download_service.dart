import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class TelegramHttpDownloadService {
  static final TelegramHttpDownloadService instance = TelegramHttpDownloadService._();
  TelegramHttpDownloadService._();

  // Cloudflare Worker que faz proxy da API Telegram (resolve CORS no Web e esconde o BOT_TOKEN).
  // Rota: GET /download?file_id=<id>
  static const String _proxyBase =
      'https://biblia-ia-esboco.nivaldo-nilngn.workers.dev';
  static const String _defaultAppToken = 'KeryxAppToken2026';

  // Cache em memória para Web (evita re-download e permite abrir diretamente no SfPdfViewer.memory)
  static final Map<String, String> _webDataUrlCache = {};
  static Map<String, String> get webDataUrlCache => _webDataUrlCache;

  static final Map<String, Uint8List> _webBytesCache = {};
  static Map<String, Uint8List> get webBytesCache => _webBytesCache;

  static Uint8List? getWebBytes(String key) {
    if (_webBytesCache.containsKey(key)) return _webBytesCache[key];
    final clean = key.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    if (_webBytesCache.containsKey(clean)) return _webBytesCache[clean];
    if (_webBytesCache.containsKey('$clean.pdf')) return _webBytesCache['$clean.pdf'];
    return null;
  }

  Future<String?> downloadFile(
    String fileId,
    String fileName,
    Function(double) onProgress,
  ) async {
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      fileName = '$fileName.pdf';
    }
    try {
      if (kIsWeb) {
        return await _downloadWeb(fileId, fileName, onProgress);
      } else {
        return await _downloadNative(fileId, fileName, onProgress);
      }
    } catch (e) {
      debugPrint('Telegram HTTP Error: $e');
      rethrow;
    }
  }

  // ── Web: usa o proxy Cloudflare e BytesBuilder para poupar memória ────────────
  Future<String?> _downloadWeb(
    String fileId,
    String fileName,
    Function(double) onProgress,
  ) async {
    // Se já foi baixado na sessão Web, retorna imediatamente
    if (_webBytesCache.containsKey(fileId) || _webDataUrlCache.containsKey(fileId)) {
      onProgress(1.0);
      return _webDataUrlCache[fileId] ?? fileId;
    }
    if (_webBytesCache.containsKey(fileName) || _webDataUrlCache.containsKey(fileName)) {
      onProgress(1.0);
      return _webDataUrlCache[fileName] ?? fileName;
    }

    debugPrint('🌐 [Web] Baixando via proxy Cloudflare: $fileId ($fileName)');

    final downloadUrl = Uri.parse(
      '$_proxyBase/download?file_id=${Uri.encodeComponent(fileId)}',
    );

    final client = http.Client();
    try {
      final appToken = (dotenv.env['APP_TOKEN']?.isNotEmpty == true)
          ? dotenv.env['APP_TOKEN']!
          : _defaultAppToken;
      final request = http.Request('GET', downloadUrl);
      if (appToken.isNotEmpty) {
        request.headers['X-App-Token'] = appToken;
      }
      
      final streamResponse = await client.send(request);

      if (streamResponse.statusCode != 200) {
        throw Exception(
          'Proxy retornou ${streamResponse.statusCode}',
        );
      }

      // No Web não temos sistema de arquivos, acumulamos em memória.
      // O BytesBuilder(copy: false) reduz dramaticamente o uso de RAM no JS.
      final builder = BytesBuilder(copy: false);
      int downloaded = 0;
      final contentLength = streamResponse.contentLength;

      int lastReportedPercent = -1;
      DateTime lastReportTime = DateTime.now();

      await for (final chunk in streamResponse.stream) {
        builder.add(chunk);
        downloaded += chunk.length;
        
        if (contentLength != null && contentLength > 0) {
          final currentPercent = ((downloaded / contentLength) * 100).toInt();
          final now = DateTime.now();
          
          if (currentPercent != lastReportedPercent || now.difference(lastReportTime).inMilliseconds > 100) {
            onProgress(downloaded / contentLength);
            lastReportedPercent = currentPercent;
            lastReportTime = now;
          }
        } else {
          final now = DateTime.now();
          if (now.difference(lastReportTime).inMilliseconds > 200) {
            onProgress(0.0);
            lastReportTime = now;
          }
        }
      }

      onProgress(1.0);

      final bytes = builder.takeBytes();
      final cleanName = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');

      // Armazena bytes brutos (consumidos diretamente pelo SfPdfViewer sem loop nem decodificação JS no build)
      _webBytesCache[fileId] = bytes;
      _webBytesCache[fileName] = bytes;
      _webBytesCache[cleanName] = bytes;

      final base64Str = base64Encode(bytes);
      final dataUrl = 'data:application/pdf;base64,$base64Str';
      _webDataUrlCache[fileId] = dataUrl;
      _webDataUrlCache[fileName] = dataUrl;
      _webDataUrlCache[cleanName] = dataUrl;
      return dataUrl;
    } finally {
      client.close();
    }
  }

  // ── Nativo (Android/iOS/Desktop): Usa o proxy e salva direto no disco (sem RAM leak)
  Future<String?> _downloadNative(
    String fileId,
    String fileName,
    Function(double) onProgress,
  ) async {
    debugPrint('📱 [Native] Baixando via proxy Cloudflare: $fileId');

    final downloadUrl = Uri.parse(
      '$_proxyBase/download?file_id=${Uri.encodeComponent(fileId)}',
    );

    final client = http.Client();
    try {
      final appToken = (dotenv.env['APP_TOKEN']?.isNotEmpty == true)
          ? dotenv.env['APP_TOKEN']!
          : _defaultAppToken;
      final request = http.Request('GET', downloadUrl);
      if (appToken.isNotEmpty) {
        request.headers['X-App-Token'] = appToken;
      }
      
      final streamResponse = await client.send(request);

      if (streamResponse.statusCode != 200) {
        throw Exception('Falha no download via proxy: ${streamResponse.statusCode}');
      }

      final dir = await getApplicationDocumentsDirectory();
      final pdfDir = Directory('${dir.path}/pdfs');
      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
      }

      final finalPath = '${pdfDir.path}/$fileName';
      final partPath = '$finalPath.part';
      final partFile = File(partPath);

      final sink = partFile.openWrite();
      int downloaded = 0;
      final contentLength = streamResponse.contentLength;
      
      int lastReportedPercent = -1;
      DateTime lastReportTime = DateTime.now();

      await for (final chunk in streamResponse.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        
        if (contentLength != null && contentLength > 0) {
          final currentPercent = ((downloaded / contentLength) * 100).toInt();
          final now = DateTime.now();
          
          // Só reporta se mudou pelo menos 1% OU passou mais de 100ms (evita loop e crash WebGL no Web)
          if (currentPercent != lastReportedPercent || now.difference(lastReportTime).inMilliseconds > 100) {
            onProgress(downloaded / contentLength);
            lastReportedPercent = currentPercent;
            lastReportTime = now;
          }
        } else {
          final now = DateTime.now();
          if (now.difference(lastReportTime).inMilliseconds > 200) {
            onProgress(0.0);
            lastReportTime = now;
          }
        }
      }

      await sink.close();
      onProgress(1.0);

      // Renomeia atomicamente quando o download termina
      await partFile.rename(finalPath);

      return finalPath;
    } finally {
      client.close();
    }
  }
}
