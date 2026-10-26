import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/state/font_state.dart';

final pushNotificationServiceProvider = Provider(PushNotificationService.new);

/// Configuração do canal de notificações Android
const _androidChannel = AndroidNotificationChannel(
  'keryx_app_notifications',
  'Notificações Keryx',
  description: 'Notificações de avisos, downloads e novidades do KeryxApp',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

/// Instância do plugin de notificações locais
final FlutterLocalNotificationsPlugin localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class PushNotificationService {
  PushNotificationService(this._ref);
  final Ref _ref;

  static const String _notifiedPrefsKey = 'notified_keryx_notification_ids';
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;
  final List<StreamSubscription> _subscriptions = [];

  /// Reseta a flag de inicialização e cancela inscrições (ex: no logout)
  void reset() {
    _initialized = false;
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Cria o canal de notificações no Android
    await _createNotificationChannel();

    // 2. Inicializa o plugin de notificações locais
    await _initLocalNotifications();

    // 3. Solicita permissões (iOS + Android 13+)
    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('⚠️ Erro ao solicitar permissão do FCM: $e');
    }

    // 4. Solicita permissão no Android 13+
    if (!kIsWeb) {
      try {
        await localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (e) {
        debugPrint('⚠️ Erro ao solicitar permissão local no Android: $e');
      }
    }

    // 5. Salva o token FCM
    await _updateToken();

    // 6. Monitora atualizações de token
    _subscriptions.add(_fcm.onTokenRefresh.listen((newToken) async {
      final uid = _ref.read(authStateProvider).valueOrNull?.uid;
      await _saveTokenToDatabase(newToken, uid);
    }));

    // 7. Notificações FCM em primeiro plano
    _subscriptions.add(FirebaseMessaging.onMessage.listen(_onForegroundMessage));

    // 8. Trata clique na notificação em segundo plano
    _subscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 App aberto via notificação: ${message.data}');
    }));
  }

  /// Cria o canal no Android 8.0+
  Future<void> _createNotificationChannel() async {
    if (kIsWeb) return;
    try {
      await localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    } catch (e) {
      debugPrint('⚠️ Erro ao criar canal de notificação: $e');
    }
  }

  /// Inicializa Flutter Local Notifications
  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotificationsPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _handlePayloadClick(response.payload!);
        }
      },
    );

    // Trata inicialização a partir do clique
    final launchDetails = await localNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null) {
        _handlePayloadClick(payload);
      }
    }
  }

  void _handlePayloadClick(String payload) {
    try {
      final data = jsonDecode(payload);
      final id = data['id'] ?? data['notificationId'];
      if (id != null) {
        checkAndMarkAsNotified(id.toString());
      }
    } catch (e) {
      debugPrint('❌ Erro ao processar payload do clique: $e');
    }
  }

  /// Verifica e marca um ID como já notificado para prevenir duplicações.
  /// Retorna `true` se já foi notificado anteriormente (evita notificar de novo).
  bool checkAndMarkAsNotified(String? id) {
    if (id == null || id.isEmpty) return false;

    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final list = prefs.getStringList(_notifiedPrefsKey) ?? [];
      final notifiedSet = list.toSet();

      if (notifiedSet.contains(id)) return true;

      notifiedSet.add(id);
      final listToSave = notifiedSet.toList();
      if (listToSave.length > 100) {
        listToSave.removeRange(0, listToSave.length - 100);
      }

      prefs.setStringList(_notifiedPrefsKey, listToSave);
      return false;
    } catch (e) {
      debugPrint('⚠️ Erro ao acessar SharedPreferences no tracker de notificações: $e');
      return false;
    }
  }

  /// Limpa o rastreamento de IDs notificados (útil ao limpar tudo)
  Future<void> clearNotifiedTracker() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.remove(_notifiedPrefsKey);
    } catch (e) {
      debugPrint('⚠️ Erro ao limpar tracker de notificações: $e');
    }
  }

  /// Exibe notificação local quando uma mensagem FCM chega em primeiro plano.
  void _onForegroundMessage(RemoteMessage message) {
    final messageId = message.data['notificationId'] ?? message.messageId;
    if (checkAndMarkAsNotified(messageId)) return;

    final title = message.notification?.title ?? message.data['title'] as String?;
    final body = message.notification?.body ?? message.data['body'] as String?;

    if (title == null || body == null) return;

    showLocalNotification(
      id: messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      payload: message.data,
    );
  }

  /// Dispara uma notificação nativa no sistema (Android, iOS)
  Future<void> showLocalNotification({
    required String id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    if (kIsWeb) return;

    try {
      await localNotificationsPlugin.show(
        id: id.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'keryx_app_notifications',
            'Notificações Keryx',
            channelDescription: 'Notificações de avisos, downloads e novidades do KeryxApp',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload != null ? jsonEncode(payload) : null,
      );
    } catch (e) {
      debugPrint('❌ Erro ao exibir notificação local: $e');
    }
  }

  Future<void> _updateToken() async {
    if (kIsWeb) return;
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        final uid = _ref.read(authStateProvider).valueOrNull?.uid;
        await _saveTokenToDatabase(token, uid);
      }
    } catch (e) {
      debugPrint('❌ Erro ao obter token FCM: $e');
    }
  }

  Future<void> _saveTokenToDatabase(String token, [String? explicitUid]) async {
    final uid = explicitUid ?? _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ Token FCM salvo com sucesso para o usuário $uid');
      } catch (e) {
        debugPrint('❌ Erro ao salvar token FCM no Firestore: $e');
      }
    }
  }

  Future<void> saveCurrentToken([String? uid]) async {
    if (kIsWeb) return;
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token, uid);
      }
    } catch (e) {
      debugPrint('❌ Erro em saveCurrentToken: $e');
    }
  }

  Future<void> clearToken([String? uid]) async {
    final targetUid = uid ?? _ref.read(authStateProvider).valueOrNull?.uid;
    if (targetUid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
          'fcmToken': FieldValue.delete(),
        });
        debugPrint('✅ Token FCM removido com sucesso para o usuário $targetUid');
      } catch (e) {
        debugPrint('❌ Erro ao limpar token FCM: $e');
      }
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb || topic.isEmpty) return;
    try {
      final clean = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      await _fcm.subscribeToTopic(clean);
    } catch (e) {
      debugPrint('❌ Erro ao assinar tópico $topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb || topic.isEmpty) return;
    try {
      final clean = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      await _fcm.unsubscribeFromTopic(clean);
    } catch (e) {
      debugPrint('❌ Erro ao desinscrever do tópico $topic: $e');
    }
  }
}
