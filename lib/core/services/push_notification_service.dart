import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/state/navigation_state.dart';

final pushNotificationServiceProvider = Provider(PushNotificationService.new);

/// Configuração do canal de notificações Android
const _androidChannel = AndroidNotificationChannel(
  'keryx_app_notifications',
  'Notificações Keryx',
  description: 'Notificações de avisos, downloads e novidades do KeryxApp',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

/// Configuração do canal de Devocional Diário no Android
const _devotionalChannel = AndroidNotificationChannel(
  'keryx_devotional_channel',
  'Devocional Diário',
  description: 'Lembretes matinais diários do Devocional e Palavra do Dia',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
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

    // 1. Cria o canal de notificações no Android com importância máxima
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

    // 7. Inscreve no tópico global de atualizações do app
    await subscribeToTopic('keryx_updates');

    // Inscreve no tópico pessoal do usuário para notificações da comunidade e diretas
    final currentUid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (currentUid != null) {
      await subscribeToTopic('user_$currentUid');
    }

    // Monitora login/logout para inscrever/desinscrever automaticamente
    _ref.listen<AsyncValue<dynamic>>(authStateProvider, (prev, next) async {
      final user = next.valueOrNull;
      if (user != null) {
        await saveCurrentToken(user.uid);
        await subscribeToTopic('user_${user.uid}');
      }
    });

    // 8. Notificações FCM em primeiro plano
    _subscriptions.add(FirebaseMessaging.onMessage.listen(_onForegroundMessage));

    // 9. Trata clique na notificação em segundo plano
    _subscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 App aberto via notificação: ${message.data}');
      if (message.data['type'] == 'app_update' || message.data['type'] == 'devocional') {
        _ref.read(navigationProvider.notifier).setIndex(0);
      }
    }));

    // 10. Inicializa fuso horário e agenda notificação nativa diária do Devocional matinal
    if (!kIsWeb) {
      try {
        tz.initializeTimeZones();
        try {
          tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
        } catch (_) {}
      } catch (e) {
        debugPrint('⚠️ Erro ao inicializar timezone: $e');
      }
      await scheduleDailyDevotionalNotification();
    }
  }

  /// Cria os canais no Android 8.0+
  Future<void> _createNotificationChannel() async {
    if (kIsWeb) return;
    try {
      final androidImpl = localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(_androidChannel);
      await androidImpl?.createNotificationChannel(_devotionalChannel);
    } catch (e) {
      debugPrint('⚠️ Erro ao criar canais de notificação: $e');
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
      if (data['type'] == 'app_update' || data['type'] == 'devocional') {
        _ref.read(navigationProvider.notifier).setIndex(0);
      }
    } catch (e) {
      debugPrint('❌ Erro ao processar payload do clique: $e');
    }
  }

  /// Agenda a notificação nativa matinal diária do Devocional (padrão: 07:00 da manhã)
  /// Dispara pontualmente no horário local todos os dias através do AlarmManager nativo.
  Future<void> scheduleDailyDevotionalNotification({
    int hour = 7,
    int minute = 0,
    String? customTitle,
    String? customBody,
  }) async {
    if (kIsWeb) return;

    try {
      try {
        tz.initializeTimeZones();
        try {
          tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
        } catch (_) {}
      } catch (_) {}

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // Se o horário de hoje já passou, agenda a partir de amanhã
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await localNotificationsPlugin.zonedSchedule(
        id: 777,
        title: customTitle ?? '🌅 Devocional Diário • Bom dia!',
        body: customBody ??
            'Comece o seu dia com a Palavra de Deus. Toque para ler o versículo e a reflexão de hoje.',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'keryx_devotional_channel',
            'Devocional Diário',
            channelDescription:
                'Lembretes matinais diários do Devocional e Palavra do Dia',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/launcher_icon',
            ticker: 'Devocional Diário',
            enableVibration: true,
            playSound: true,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode({'type': 'devocional'}),
      );
      debugPrint(
          '⏰ Devocional matinal agendado para às ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} com repetição diária!');
    } catch (e) {
      debugPrint('⚠️ Erro ao agendar notificação diária do devocional: $e');
    }
  }

  /// Dispara uma notificação nativa no sistema (Android, iOS) alertando sobre a nova versão
  Future<void> notifyAppUpdateIfAvailable({
    required int latestVersion,
    required String versionName,
    required String releaseNotes,
    required String downloadUrl,
  }) async {
    final notifId = 'app_update_build_$latestVersion';
    if (checkAndMarkAsNotified(notifId)) return;

    await showLocalNotification(
      id: notifId,
      title: 'Nova Atualização: v$versionName',
      body: releaseNotes.isNotEmpty
          ? releaseNotes
          : 'Uma nova versão do KeryxApp está disponível. Toque para atualizar.',
      payload: {
        'type': 'app_update',
        'url': downloadUrl,
        'version': versionName,
        'build': latestVersion,
      },
    );
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
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/launcher_icon',
            ticker: 'KeryxApp',
            enableVibration: true,
            playSound: true,
            channelShowBadge: true,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.message,
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
