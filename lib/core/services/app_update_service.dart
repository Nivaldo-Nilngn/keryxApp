import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'internal_download_service.dart';

/// Valida se a URL de download do APK pertence a fontes oficiais autorizadas
bool isTrustedDownloadUrl(String url) {
  final u = Uri.tryParse(url);
  if (u == null || u.scheme != 'https') return false;
  final isRepo = u.host == 'github.com' &&
      u.path.startsWith('/Nivaldo-Nilngn/keryxApp/');
  final isWorker = u.host == 'keryx-version.nivaldo-nilngn.workers.dev';
  return isRepo || isWorker;
}

/// Modelo de dados da versão retornado pelo Cloudflare Worker / GitHub Releases
class AppUpdateInfo {
  final int latestVersion;
  final String versionName;
  final String downloadUrl;
  final String iosUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final int minVersion;
  final String? releaseDate;
  final String? sha256;

  AppUpdateInfo({
    required this.latestVersion,
    required this.versionName,
    required this.downloadUrl,
    this.iosUrl = '',
    this.releaseNotes = '',
    this.forceUpdate = false,
    this.minVersion = 0,
    this.releaseDate,
    this.sha256,
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
      sha256: json['sha256'] as String?,
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
        if (releaseDate != null) 'release_date': releaseDate,
        if (sha256 != null) 'sha256': sha256,
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

  /// URL padrão para consulta de versões
  static String get defaultVersionUrl {
    final envUrl = dotenv.env['CLOUDFLARE_VERSION_URL']?.trim();
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }
    return 'https://keryx-version.nivaldo-nilngn.workers.dev';
  }

  AppUpdateService({
    http.Client? client,
  }) : _client = client ?? http.Client();

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
          'User-Agent': 'KeryxApp-Updater/2.0',
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
        print('AppUpdateService: Não foi possível obter versão: $e');
      }
      return null;
    }
  }

  /// Dispara a rotina unificada de download e instalação
  Future<void> downloadAndInstallApk(BuildContext context, AppUpdateInfo info) async {
    final downloadService = DownloadService();
    await downloadService.downloadAndInstall(context, info);
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
/// Na Web, o usuário sempre consome a versão mais recente em tempo real servida da nuvem.
final isUpdateAvailableProvider = Provider<bool>((ref) {
  if (kIsWeb) return false;

  final current = ref.watch(currentAppVersionProvider).valueOrNull;
  final latest = ref.watch(latestUpdateInfoProvider).valueOrNull;

  if (current == null || latest == null) return false;
  return latest.latestVersion > current.buildNumber;
});

/// Indica se a atualização é estritamente obrigatória (force_update == true ou minVersion > buildNumber)
final isForceUpdateRequiredProvider = Provider<bool>((ref) {
  if (kIsWeb) return false;

  final current = ref.watch(currentAppVersionProvider).valueOrNull;
  final latest = ref.watch(latestUpdateInfoProvider).valueOrNull;

  if (current == null || latest == null) return false;
  if (latest.latestVersion <= current.buildNumber) return false;

  return latest.forceUpdate || latest.minVersion > current.buildNumber;
});
