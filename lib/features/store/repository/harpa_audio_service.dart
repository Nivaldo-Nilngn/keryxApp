import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'b2_service.dart';

class HarpaAudioService {
  HarpaAudioService._();
  static final instance = HarpaAudioService._();

  static const String _telegramProxyBase =
      'https://biblia-ia-esboco.nivaldo-nilngn.workers.dev/download';
  static const String _defaultAppToken = 'KeryxAppToken2026';

  Map<String, dynamic>? _hymnsIndex;
  bool _isLoading = false;

  // Cache em memória para streaming instantâneo (evita re-downloads na mesma sessão)
  final Map<String, Uint8List> _audioBytesCache = {};

  /// Garante que o índice JSON dos hinos foi lido dos assets
  Future<void> ensureLoaded() async {
    if (_hymnsIndex != null && _hymnsIndex!.isNotEmpty) return;
    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }
    _isLoading = true;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/harpa_telegram_index.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      _hymnsIndex = (data['hymns'] as Map<String, dynamic>?) ?? {};
    } catch (e) {
      debugPrint('HarpaAudioService: Não foi possível carregar índice dos assets ($e).');
      _hymnsIndex = _hymnsIndex ?? {};
    } finally {
      _isLoading = false;
    }
  }

  /// Retorna o file_id do Telegram para um número de hino (ex: "001" ou "1")
  String? getTelegramFileId(String hymnNumber) {
    if (_hymnsIndex == null) return null;
    final cleanNum = int.tryParse(hymnNumber.trim())?.toString();
    if (cleanNum == null) return null;
    final item = _hymnsIndex![cleanNum] as Map<String, dynamic>?;
    return item?['file_id'] as String?;
  }

  /// Retorna a URL de streaming. Prioriza Telegram (via Cloudflare Proxy) e cai para B2 se indisponível.
  Future<String> getStreamUrl(String hymnNumber) async {
    await ensureLoaded();
    final numStr = hymnNumber.padLeft(3, '0');
    final fileId = getTelegramFileId(hymnNumber);

    if (fileId != null && fileId.isNotEmpty) {
      return '$_telegramProxyBase?file_id=${Uri.encodeComponent(fileId)}&title=Harpa_$numStr.mp3';
    }

    // Fallback transparente para Backblaze B2
    final b2 = B2Service();
    return await b2.getAuthorizedStreamUrl('audios/Harpa_Crista/$numStr.mp3');
  }

  /// Retorna os headers de autenticação para download/stream do arquivo
  Map<String, String> getDownloadHeaders(String url) {
    if (url.contains('workers.dev')) {
      final appToken = dotenv.isInitialized && (dotenv.env['APP_TOKEN']?.isNotEmpty == true)
          ? dotenv.env['APP_TOKEN']!
          : _defaultAppToken;
      return {'X-App-Token': appToken};
    }
    return {};
  }

  /// Retorna bytes em cache na memória (se já tiver sido baixado/tocado nesta sessão)
  Uint8List? getCachedAudioBytes(String hymnNumber) {
    final cleanNum = int.tryParse(hymnNumber.trim())?.toString() ?? hymnNumber;
    return _audioBytesCache[cleanNum];
  }

  /// Baixa os bytes do hino com headers de autorização e suporte a progresso
  Future<Uint8List> fetchAudioBytes(
    String hymnNumber, {
    Function(double progress)? onProgress,
  }) async {
    final cleanNum = int.tryParse(hymnNumber.trim())?.toString() ?? hymnNumber;
    if (_audioBytesCache.containsKey(cleanNum)) {
      onProgress?.call(1.0);
      return _audioBytesCache[cleanNum]!;
    }

    final streamUrl = await getStreamUrl(hymnNumber);
    final headers = getDownloadHeaders(streamUrl);
    if (headers.isEmpty && !streamUrl.contains('workers.dev')) {
      final b2 = B2Service();
      headers.addAll(await b2.getDownloadHeaders());
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(streamUrl));
      request.headers.addAll(headers);

      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final builder = BytesBuilder(copy: false);
      int loaded = 0;

      await for (final chunk in response.stream) {
        builder.add(chunk);
        loaded += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          onProgress(loaded / contentLength);
        }
      }

      onProgress?.call(1.0);
      final bytes = builder.takeBytes();
      _audioBytesCache[cleanNum] = bytes;
      return bytes;
    } finally {
      client.close();
    }
  }

  /// Retorna o caminho do arquivo no dispositivo se já existir baixado no app
  Future<String?> getLocalAudioPath(String hymnNumber) async {
    if (kIsWeb) return null;
    final numStr = hymnNumber.padLeft(3, '0');

    try {
      final dir = await getApplicationDocumentsDirectory();
      final storePath = p.join(dir.path, 'store', 'audios', 'Harpa_Crista', '$numStr.mp3');
      if (await File(storePath).exists()) return storePath;
    } catch (_) {}

    return null;
  }
}
