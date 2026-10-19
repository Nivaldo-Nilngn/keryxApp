import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// Modelo de dados da versão retornado pelo Cloudflare Worker / R2 / Pages
class AppUpdateInfo {
  final int latestVersion;
  final String versionName;
  final String downloadUrl;
  final String iosUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final int minVersion;
  final String? releaseDate;

  AppUpdateInfo({
    required this.latestVersion,
    required this.versionName,
    required this.downloadUrl,
    this.iosUrl = '',
    this.releaseNotes = '',
    this.forceUpdate = false,
    this.minVersion = 0,
    this.releaseDate,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: (json['latest_version'] as num?)?.toInt() ?? 0,
      versionName: json['version_name'] as String? ?? '1.0.0',
      downloadUrl: json['download_url'] as String? ?? '',
      iosUrl: json['ios_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
      forceUpdate: json['force_update'] as bool? ?? false,
      minVersion: (json['min_version'] as num?)?.toInt() ?? 0,
      releaseDate: json['release_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'latest_version': latestVersion,
        'version_name': versionName,
        'download_url': downloadUrl,
        'ios_url': iosUrl,
        'release_notes': releaseNotes,
        'force_update': forceUpdate,
        'min_version': minVersion,
        'release_date': releaseDate,
      };
}

class AppCurrentVersion {
  final int buildNumber;
  final String versionName;

  const AppCurrentVersion({
    required this.buildNumber,
    required this.versionName,
  });
}

class AppUpdateService {
  final http.Client _client;
  final Dio _dio;

  /// URL padrão ou definida no arquivo .env
  static String get defaultVersionUrl {
    final envUrl = dotenv.env['CLOUDFLARE_VERSION_URL']?.trim();
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }
    // Fallback padrão configurável pelo Cloudflare
    return 'https://keryx-version.pages.dev/version.json';
  }

  AppUpdateService({
    http.Client? client,
    Dio? dio,
  })  : _client = client ?? http.Client(),
        _dio = dio ?? Dio();

  /// Obtém a versão e build atuais do aplicativo instalado
  Future<AppCurrentVersion> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber) ?? 1;
      return AppCurrentVersion(
        buildNumber: build,
        versionName: info.version.isNotEmpty ? info.version : '1.0.0',
      );
    } catch (_) {
      return const AppCurrentVersion(buildNumber: 1, versionName: '1.0.0');
    }
  }

  /// Consulta o endpoint do Cloudflare para verificar a última versão lançada
  Future<AppUpdateInfo?> checkLatestVersion({String? customUrl}) async {
    final baseUrl = customUrl ?? defaultVersionUrl;
    if (baseUrl.isEmpty) return null;

    try {
      // Adiciona timestamp para ignorar caches intermediários do navegador/CDN
      final separator = baseUrl.contains('?') ? '&' : '?';
      final cacheBustUrl = '$baseUrl${separator}t=${DateTime.now().millisecondsSinceEpoch}';

      final response = await _client.get(
        Uri.parse(cacheBustUrl),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'KeryxApp-Updater/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          return AppUpdateInfo.fromJson(decoded);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('AppUpdateService: Não foi possível obter versão do Cloudflare: $e');
      }
      return null;
    }
  }

  /// Baixa o APK no Android e abre o instalador nativo, ou abre a URL no navegador
  Future<void> downloadAndInstallApk(BuildContext context, String url) async {
    if (kIsWeb) {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ApkDownloadDialog(url: url, dio: _dio),
      );
    } else {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ApkDownloadDialog extends StatefulWidget {
  final String url;
  final Dio dio;

  const _ApkDownloadDialog({required this.url, required this.dio});

  @override
  State<_ApkDownloadDialog> createState() => _ApkDownloadDialogState();
}

class _ApkDownloadDialogState extends State<_ApkDownloadDialog> {
  double _progress = 0.0;
  int _received = 0;
  int _total = -1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/keryx_update.apk';

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
            'user-agent': 'KeryxApp-Updater',
            'Accept': '*/*',
          },
        ),
        onReceiveProgress: (received, total) {
          if (mounted) {
            setState(() {
              _received = received;
              _total = total;
              if (total > 0) {
                _progress = received / total;
              }
            });
          }
        },
      );

      if (mounted) {
        Navigator.pop(context); // Fecha diálogo
      }

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível iniciar o instalador: ${result.message}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      String msg = 'Erro no download: $e';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          msg = 'Tempo de conexão esgotado ao contatar o servidor.';
        } else if (e.response?.statusCode == 404) {
          msg = 'Arquivo APK não encontrado no GitHub / servidor (404).';
        }
      }
      if (mounted) {
        setState(() => _error = msg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloadedMb = (_received / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = _total > 0 ? (_total / (1024 * 1024)).toStringAsFixed(1) : null;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _error != null ? Icons.error_outline_rounded : Icons.downloading_rounded,
              color: _error != null ? Colors.redAccent : AppTheme.kPrimaryGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error != null ? 'Erro no Download' : 'Baixando Atualização',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Text(
              _error!,
              style: GoogleFonts.manrope(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            )
          else ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _total > 0 ? _progress : null,
                minHeight: 10,
                backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                color: AppTheme.kPrimaryGold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _total > 0
                  ? '${(_progress * 100).toInt()}% concluído ($downloadedMb MB de $totalMb MB)'
                  : '$downloadedMb MB baixados...',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
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

// ── Providers Riverpod ──────────────────────────────────────────────────────

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

/// Versão atual do aplicativo instalado
final currentAppVersionProvider = FutureProvider<AppCurrentVersion>((ref) {
  final service = ref.watch(appUpdateServiceProvider);
  return service.getCurrentVersion();
});

/// Última versão obtida do Cloudflare
final latestUpdateInfoProvider = FutureProvider<AppUpdateInfo?>((ref) {
  final service = ref.watch(appUpdateServiceProvider);
  return service.checkLatestVersion();
});

/// Indica se há nova versão disponível (latestVersion > buildNumber)
final isUpdateAvailableProvider = Provider<bool>((ref) {
  final current = ref.watch(currentAppVersionProvider).valueOrNull;
  final latest = ref.watch(latestUpdateInfoProvider).valueOrNull;

  if (current == null || latest == null) return false;
  return latest.latestVersion > current.buildNumber;
});

/// Armazena qual versão já foi dispensada pelo usuário nesta sessão
final dismissedUpdateVersionProvider = StateProvider<int?>((ref) => null);
