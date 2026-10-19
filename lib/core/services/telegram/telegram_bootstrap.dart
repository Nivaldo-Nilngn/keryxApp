import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'telegram_download_service.dart';

class TelegramBootstrap {
  static Future<void>? _startFuture;

  static Future<void> start() {
    if (_startFuture != null) return _startFuture!;
    if (kIsWeb || FirebaseAuth.instance.currentUser == null) {
      _startFuture = Future.value();
      return _startFuture!;
    }
    
    _startFuture = () async {
      try {
        final apiIdStr = dotenv.env['TELEGRAM_API_ID'];
        final apiHash = dotenv.env['TELEGRAM_API_HASH'];
        final token = dotenv.env['TELEGRAM_BOT_TOKEN'];

        if (apiIdStr != null && apiHash != null && token != null) {
          final apiId = int.tryParse(apiIdStr);
          if (apiId != null) {
            await TelegramDownloadService.instance
                .init(apiId: apiId, apiHash: apiHash, botToken: token);
          }
        }
      } catch (e) {
        _startFuture = null;
        debugPrint('Telegram: $e');
      }
    }();
    return _startFuture!;
  }
}
