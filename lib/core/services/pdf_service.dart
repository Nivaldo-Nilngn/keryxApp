import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'telegram/telegram_http_download_service.dart';

typedef AccessRefresher = Future<Map<String, String>> Function();

class PdfService {
  static const String _webDownloadedKey = 'web_downloaded_pdf_books';

  Future<Directory> get _pdfDir async {
    final dir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${dir.path}/pdfs');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }

  Future<String> getBookPath(String fileName) async {
    if (kIsWeb) {
      final clean = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      if (TelegramHttpDownloadService.webBytesCache.containsKey(fileName) ||
          TelegramHttpDownloadService.webBytesCache.containsKey(clean)) {
        return 'memory://$fileName';
      }
      final cached = TelegramHttpDownloadService.webDataUrlCache[fileName] ??
          TelegramHttpDownloadService.webDataUrlCache[clean];
      if (cached != null) return cached;
      return fileName;
    }
    final dir = await _pdfDir;
    return '${dir.path}/$fileName';
  }

  Future<bool> isBookDownloaded(String fileName) async {
    if (kIsWeb) {
      final clean = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      if (TelegramHttpDownloadService.webBytesCache.containsKey(fileName) ||
          TelegramHttpDownloadService.webBytesCache.containsKey(clean) ||
          TelegramHttpDownloadService.webDataUrlCache.containsKey(fileName) ||
          TelegramHttpDownloadService.webDataUrlCache.containsKey(clean)) {
        return true;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList(_webDownloadedKey) ?? [];
        return list.contains(fileName) || list.contains(clean);
      } catch (_) {
        return false;
      }
    }
    try {
      final path = await getBookPath(fileName);
      final file = File(path);
      if (await file.exists()) return true;
      final fallback = File('$path.pdf');
      return await fallback.exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> saveWebDownloadedBook(String fileName, String? dataUrl, {String? fileId}) async {
    if (!kIsWeb) return;
    final clean = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    if (dataUrl != null && dataUrl.isNotEmpty) {
      TelegramHttpDownloadService.webDataUrlCache[fileName] = dataUrl;
      TelegramHttpDownloadService.webDataUrlCache[clean] = dataUrl;
      if (fileId != null && fileId.isNotEmpty) {
        TelegramHttpDownloadService.webDataUrlCache[fileId] = dataUrl;
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_webDownloadedKey) ?? [];
      if (!list.contains(fileName)) {
        list.add(fileName);
        await prefs.setStringList(_webDownloadedKey, list);
      }
      if (fileId != null && fileId.isNotEmpty) {
        await prefs.setString('web_pdf_file_id_$fileName', fileId);
        await prefs.setString('web_pdf_file_id_$clean', fileId);
      }
    } catch (_) {}
  }

  Future<String?> getWebFileId(String fileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clean = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      return prefs.getString('web_pdf_file_id_$fileName') ?? prefs.getString('web_pdf_file_id_$clean');
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, String>>> listDownloadedBooks() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList(_webDownloadedKey) ?? [];
        return list.map((name) {
          final clean = name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
          final path = TelegramHttpDownloadService.webBytesCache.containsKey(name) ||
                  TelegramHttpDownloadService.webBytesCache.containsKey(clean)
              ? 'memory://$name'
              : (TelegramHttpDownloadService.webDataUrlCache[name] ??
                  TelegramHttpDownloadService.webDataUrlCache[clean] ??
                  name);
          return {'name': name, 'path': path};
        }).toList();
      } catch (e) {
        return [];
      }
    }

    try {
      final dir = await _pdfDir;
      final files = dir.listSync().whereType<File>().toList();

      // Só apaga .tmp antigos: os recentes podem ser downloads em andamento
      // ou interrompidos que ainda podem ser retomados.
      final now = DateTime.now();
      for (final f in files.where((f) => f.path.endsWith('.tmp'))) {
        try {
          if (now.difference(f.lastModifiedSync()) > const Duration(days: 3)) {
            f.deleteSync();
          }
        } catch (_) {}
      }

      return files.where((f) => !f.path.endsWith('.tmp')).map((f) {
        String path = f.path;
        String name = path.split('/').last;
        
        // Auto-fix para arquivos antigos baixados sem extensão .pdf
        if (!name.toLowerCase().endsWith('.pdf') && !name.toLowerCase().endsWith('.mybible')) {
          final newPath = '$path.pdf';
          try {
            f.renameSync(newPath);
            path = newPath;
            name = '$name.pdf';
          } catch (_) {}
        }
        
        return {'name': name, 'path': path};
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Stream<double?> downloadBook(
    String url,
    String fileName, {
    Map<String, String>? headers,
    int expectedSize = 0,
    AccessRefresher? refreshAccess,
    int maxAttempts = 5,
  }) async* {
    final dir = await _pdfDir;
    final tempFile = File('${dir.path}/$fileName.tmp');
    final finalPath = '${dir.path}/$fileName';
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 20)));

    var currentUrl = url;
    var currentHeaders = Map<String, String>.from(headers ?? {});
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        if (attempt > 1) {
          await Future.delayed(Duration(seconds: 2 * attempt));
          if (refreshAccess != null) {
            final fresh = await refreshAccess();
            currentUrl = fresh['url']!;
            currentHeaders = {'Authorization': fresh['Authorization']!};
          }
        }

        var offset = await tempFile.exists() ? await tempFile.length() : 0;

        // .tmp maior que o esperado: está estragado, recomeça
        if (expectedSize > 0 && offset > expectedSize) {
          await tempFile.delete();
          offset = 0;
        }
        // .tmp já completo (ex.: o app fechou antes do rename)
        if (expectedSize > 0 && offset == expectedSize) {
          final dest = File(finalPath);
          if (await dest.exists()) {
            await dest.delete();
          }
          await tempFile.rename(finalPath);
          yield 1.0;
          return;
        }

        final resp = await dio.get<ResponseBody>(
          currentUrl,
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              ...currentHeaders,
              if (offset > 0) 'Range': 'bytes=$offset-',
            },
            validateStatus: (s) => s == 200 || s == 206 || s == 416,
          ),
        );

        if (resp.statusCode == 416) {
          await tempFile.delete();
          throw Exception('Servidor recusou a retomada (416)');
        }

        final resumed = resp.statusCode == 206 && offset > 0;
        if (!resumed) offset = 0;

        final contentLength =
            int.tryParse(resp.headers.value(Headers.contentLengthHeader) ?? '') ?? -1;
        final total = expectedSize > 0
            ? expectedSize
            : (contentLength > 0 ? offset + contentLength : -1);

        final sink = tempFile.openWrite(
          mode: resumed ? FileMode.append : FileMode.write,
        );
        var received = offset;
        var lastPct = -1;
        try {
          await for (final chunk
              in resp.data!.stream.timeout(const Duration(seconds: 45))) {
            sink.add(chunk);
            received += chunk.length;
            if (total > 0) {
              final pct = (received * 100) ~/ total;
              if (pct != lastPct) {
                lastPct = pct;
                yield received / total;
              }
            }
          }
          await sink.flush();
        } finally {
          await sink.close();
        }

        final actual = await tempFile.length();
        if (expectedSize > 0 && actual != expectedSize) {
          if (actual > expectedSize) await tempFile.delete();
          throw Exception('Incompleto: $actual de $expectedSize bytes');
        }

        final dest = File(finalPath);
        if (await dest.exists()) {
          await dest.delete();
        }
        await tempFile.rename(finalPath);
        yield 1.0;
        return;
      } catch (e) {
        lastError = e;
        if (e is DioException && e.response?.statusCode == 404) rethrow;
      }
    }

    throw Exception('Falha após $maxAttempts tentativas: $lastError');
  }

  Future<void> deleteBook(String fileName) async {
    if (kIsWeb) {
      final clean = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      TelegramHttpDownloadService.webBytesCache.remove(fileName);
      TelegramHttpDownloadService.webBytesCache.remove(clean);
      TelegramHttpDownloadService.webDataUrlCache.remove(fileName);
      TelegramHttpDownloadService.webDataUrlCache.remove(clean);
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList(_webDownloadedKey) ?? [];
        list.remove(fileName);
        list.remove(clean);
        await prefs.setStringList(_webDownloadedKey, list);
        await prefs.remove('web_pdf_file_id_$fileName');
        await prefs.remove('web_pdf_file_id_$clean');
      } catch (_) {}
      return;
    }

    try {
      final dir = await _pdfDir;
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) {
        await file.delete();
      }
      final tmpFile = File('${dir.path}/$fileName.tmp');
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
    } catch (_) {}
  }
}

/// Gerenciador Global de Downloads desacoplado da vida útil de qualquer tela
class PdfDownloadManager {
  static final PdfDownloadManager _instance = PdfDownloadManager._internal();
  factory PdfDownloadManager() => _instance;
  PdfDownloadManager._internal();

  final PdfService _pdfService = PdfService();
  final Map<String, double> _activeDownloads = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  final ValueNotifier<Map<String, double>> activeDownloadsNotifier =
      ValueNotifier<Map<String, double>>({});

  bool isDownloading(String fileName) => _activeDownloads.containsKey(fileName);

  double? getProgress(String fileName) => _activeDownloads[fileName];

  void startDownload({
    required String url,
    required String fileName,
    Map<String, String>? headers,
    int expectedSize = 0,
    AccessRefresher? refreshAccess,
    VoidCallback? onCompleted,
    void Function(Object error)? onError,
  }) {
    if (isDownloading(fileName)) return;

    _activeDownloads[fileName] = 0.0;
    activeDownloadsNotifier.value = Map.from(_activeDownloads);

    final stream = _pdfService.downloadBook(
      url,
      fileName,
      headers: headers,
      expectedSize: expectedSize,
      refreshAccess: refreshAccess,
    );

    _subscriptions[fileName] = stream.listen(
      (progress) {
        if (progress != null) {
          _activeDownloads[fileName] = progress;
          activeDownloadsNotifier.value = Map.from(_activeDownloads);
        }
      },
      onError: (err) {
        _activeDownloads.remove(fileName);
        _subscriptions.remove(fileName);
        activeDownloadsNotifier.value = Map.from(_activeDownloads);
        onError?.call(err);
      },
      onDone: () {
        _activeDownloads.remove(fileName);
        _subscriptions.remove(fileName);
        activeDownloadsNotifier.value = Map.from(_activeDownloads);
        onCompleted?.call();
      },
      cancelOnError: true,
    );
  }

  void cancelDownload(String fileName) {
    _subscriptions[fileName]?.cancel();
    _subscriptions.remove(fileName);
    _activeDownloads.remove(fileName);
    activeDownloadsNotifier.value = Map.from(_activeDownloads);
  }
}
