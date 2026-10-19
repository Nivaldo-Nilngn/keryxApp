import 'package:flutter_test/flutter_test.dart';
import 'package:keryx_app/core/services/app_update_service.dart';

void main() {
  group('AppUpdateService & AppUpdateInfo Model', () {
    test('Deserializa JSON retornado pelo Cloudflare corretamente', () {
      final json = {
        'latest_version': 5,
        'version_name': '1.0.5',
        'download_url': 'https://github.com/nivaldo/keryx/releases/download/v1.0.5/app-release.apk',
        'ios_url': 'https://bibliapeniel-nilngn.firebaseapp.com',
        'release_notes': 'Novo sistema de notas e suporte a PWA no iPhone.',
        'force_update': true,
        'min_version': 2,
        'release_date': '2026-10-19',
      };

      final info = AppUpdateInfo.fromJson(json);

      expect(info.latestVersion, 5);
      expect(info.versionName, '1.0.5');
      expect(info.downloadUrl, 'https://github.com/nivaldo/keryx/releases/download/v1.0.5/app-release.apk');
      expect(info.iosUrl, 'https://bibliapeniel-nilngn.firebaseapp.com');
      expect(info.releaseNotes, 'Novo sistema de notas e suporte a PWA no iPhone.');
      expect(info.forceUpdate, isTrue);
      expect(info.minVersion, 2);
      expect(info.releaseDate, '2026-10-19');
    });

    test('Lida com JSON com campos ausentes ou nulos com valores padrão seguros', () {
      final json = <String, dynamic>{};

      final info = AppUpdateInfo.fromJson(json);

      expect(info.latestVersion, 0);
      expect(info.versionName, '1.0.0');
      expect(info.downloadUrl, isEmpty);
      expect(info.iosUrl, isEmpty);
      expect(info.releaseNotes, isEmpty);
      expect(info.forceUpdate, isFalse);
      expect(info.minVersion, 0);
      expect(info.releaseDate, isNull);
    });

    test('Serializa AppUpdateInfo para Map corretamente', () {
      final info = AppUpdateInfo(
        latestVersion: 3,
        versionName: '1.0.2',
        downloadUrl: 'https://exemplo.com/app.apk',
        iosUrl: 'https://exemplo.com',
        releaseNotes: 'Correções gerais',
        forceUpdate: false,
        minVersion: 1,
        releaseDate: '2026-10-19',
      );

      final map = info.toJson();

      expect(map['latest_version'], 3);
      expect(map['version_name'], '1.0.2');
      expect(map['download_url'], 'https://exemplo.com/app.apk');
      expect(map['ios_url'], 'https://exemplo.com');
      expect(map['release_notes'], 'Correções gerais');
      expect(map['force_update'], isFalse);
      expect(map['min_version'], 1);
      expect(map['release_date'], '2026-10-19');
    });
  });
}
