import 'package:flutter_test/flutter_test.dart';
import 'package:keryx_app/core/services/app_update_service.dart';

void main() {
  group('Security & Download Integrity Tests (OWASP AppSec)', () {
    test('isTrustedDownloadUrl accepts official GitHub release binaries', () {
      expect(
        isTrustedDownloadUrl('https://github.com/Nivaldo-Nilngn/keryxApp/releases/download/v2.1.0/keryx_app.apk'),
        isTrue,
      );
      expect(
        isTrustedDownloadUrl('https://github.com/Nivaldo-Nilngn/keryxApp/archive/refs/tags/v2.1.0.tar.gz'),
        isTrue,
      );
    });

    test('isTrustedDownloadUrl accepts official Cloudflare Workers backend', () {
      expect(
        isTrustedDownloadUrl('https://keryx-version.nivaldo-nilngn.workers.dev/api/latest'),
        isTrue,
      );
    });

    test('isTrustedDownloadUrl rejects unencrypted HTTP URLs (MitM Protection)', () {
      expect(
        isTrustedDownloadUrl('http://github.com/Nivaldo-Nilngn/keryxApp/releases/download/v2.1.0/app.apk'),
        isFalse,
      );
      expect(
        isTrustedDownloadUrl('http://keryx-version.nivaldo-nilngn.workers.dev/'),
        isFalse,
      );
    });

    test('isTrustedDownloadUrl blocks domain spoofing and phishing attempts', () {
      // Subdomain spoofing
      expect(
        isTrustedDownloadUrl('https://github.com.attacker.com/Nivaldo-Nilngn/keryxApp/app.apk'),
        isFalse,
      );
      // Malicious repository path on GitHub
      expect(
        isTrustedDownloadUrl('https://github.com/MaliciousUser/keryxApp/releases/download/v1.0/app.apk'),
        isFalse,
      );
      // Arbitrary external domain
      expect(
        isTrustedDownloadUrl('https://malware-drop.com/update.apk'),
        isFalse,
      );
      // File / data / blob schemes
      expect(
        isTrustedDownloadUrl('file:///sdcard/Download/fake.apk'),
        isFalse,
      );
      expect(
        isTrustedDownloadUrl('javascript:alert(1)'),
        isFalse,
      );
    });

    test('AppUpdateInfo validates SHA-256 integrity field parsing', () {
      final json = {
        'latest_version': 210,
        'version_name': '2.1.0',
        'download_url': 'https://github.com/Nivaldo-Nilngn/keryxApp/releases/download/v2.1.0/app.apk',
        'sha256': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'force_update': false,
        'min_version': 200,
      };

      final info = AppUpdateInfo.fromJson(json);
      expect(info.latestVersion, equals(210));
      expect(info.versionName, equals('2.1.0'));
      expect(info.sha256, equals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'));
      expect(isTrustedDownloadUrl(info.downloadUrl), isTrue);
    });
  });
}

