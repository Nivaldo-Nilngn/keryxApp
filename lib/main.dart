import 'dart:io';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/state/font_state.dart';
import 'core/state/navigation_state.dart';
import 'core/state/nav_bar_style_provider.dart';
import 'core/state/navbar_route_observer.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_fonts.dart';
import 'features/bible/view_model/bible_state.dart';
import 'core/widgets/main_layout.dart';
import 'core/widgets/mbiblia_top_bar.dart';
import 'features/ai/view/chat_assistant_screen.dart';
import 'features/home/view/devocional_screen.dart';
import 'features/study_plan/presentation/study_plan_window.dart';
import 'features/auth/view/login_screen.dart';
import 'core/services/auth_service.dart';
import 'core/widgets/keryx_splash_screen.dart';
import 'core/services/database_service.dart';
import 'core/services/telegram/telegram_bootstrap.dart';

import 'core/services/custom_font_loader.dart';
import 'core/services/app_update_service.dart';
import 'features/access_control/model/user_access_model.dart';
import 'features/access_control/service/access_control_service.dart';
import 'features/access_control/state/access_control_providers.dart';
import 'features/access_control/view/pending_approval_screen.dart';
import 'features/access_control/view/update_required_screen.dart';
import 'core/services/notification_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/community_notification_listener.dart';
import 'features/home/view_model/notifications_provider.dart';
import 'features/home/service/devocional_service.dart';

/// Handler obrigatório de segundo plano para processar notificações do Firebase
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔔 [FCM Background Handler] Mensagem recebida em segundo plano/minimizado: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  await Firebase.initializeApp(
    options: kIsWeb
        ? FirebaseOptions(
            apiKey: dotenv.env['FIREBASE_API_KEY']!,
            authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN']!,
            projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
            storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET']!,
            messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
            appId: dotenv.env['FIREBASE_APP_ID']!,
          )
        : null,
  );

  // Registra handler de notificações em segundo plano no Android/iOS
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Carrega fontes dinâmicas baixadas da loja
  await CustomFontLoader.loadDownloadedFonts();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const KeryxApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

/// Chave global de navegação da raiz da aplicação para permitir controle seguro
/// por atalhos de hardware e modais globais.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class KeryxApp extends ConsumerStatefulWidget {
  const KeryxApp({super.key});

  @override
  ConsumerState<KeryxApp> createState() => _KeryxAppState();
}

class _KeryxAppState extends ConsumerState<KeryxApp> with WidgetsBindingObserver {
  NavbarRouteObserver? _navbarObserver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(pushNotificationServiceProvider).initialize();
      ref.read(communityNotificationListenerProvider).startListening();

      // Dispara notificação nativa no sistema se já houver versão mais recente disponível
      final isAvailable = ref.read(isUpdateAvailableProvider);
      if (isAvailable) {
        final info = ref.read(latestUpdateInfoProvider).valueOrNull;
        if (info != null) {
          ref.read(pushNotificationServiceProvider).notifyAppUpdateIfAvailable(
                latestVersion: info.latestVersion,
                versionName: info.versionName,
                releaseNotes: info.releaseNotes,
                downloadUrl: info.downloadUrl,
              );
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Quando o usuário restaura o app após estar minimizado:
      // Revalida imediatamente as notificações da comunidade e checagem de atualização
      ref.invalidate(notificationsProvider);
      ref.invalidate(latestUpdateInfoProvider);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inicializa o observer apenas uma vez, com o container do ProviderScope
    _navbarObserver ??= NavbarRouteObserver(ProviderScope.containerOf(context, listen: false));
  }

  @override
  Widget build(BuildContext context) {
    // Monitora atualizações para disparar alerta na barra de notificações do Android/iOS
    ref.listen<bool>(isUpdateAvailableProvider, (prev, isAvailable) {
      if (isAvailable) {
        final updateInfo = ref.read(latestUpdateInfoProvider).valueOrNull;
        if (updateInfo != null) {
          ref.read(pushNotificationServiceProvider).notifyAppUpdateIfAvailable(
                latestVersion: updateInfo.latestVersion,
                versionName: updateInfo.versionName,
                releaseNotes: updateInfo.releaseNotes,
                downloadUrl: updateInfo.downloadUrl,
              );
        }
      }
    });

    ref.listen<AsyncValue<AppUpdateInfo?>>(latestUpdateInfoProvider, (prev, next) {
      final info = next.valueOrNull;
      final current = ref.read(currentAppVersionProvider).valueOrNull;
      if (info != null && current != null && info.latestVersion > current.buildNumber) {
        ref.read(pushNotificationServiceProvider).notifyAppUpdateIfAvailable(
              latestVersion: info.latestVersion,
              versionName: info.versionName,
              releaseNotes: info.releaseNotes,
              downloadUrl: info.downloadUrl,
            );
      }
    });

    // Atualiza a notificação diária matinal com o versículo e título do devocional de hoje
    ref.listen<AsyncValue<DevocionalData?>>(devocionalDiarioProvider, (prev, next) {
      final dev = next.valueOrNull;
      if (dev != null && dev.title.isNotEmpty) {
        ref.read(pushNotificationServiceProvider).scheduleDailyDevotionalNotification(
              customTitle: '🌅 Devocional: ${dev.title}',
              customBody: '${dev.verse} — ${dev.verseReference}',
            );
      }
    });

    final appThemeMode = ref.watch(themeModeProvider);
    final fontSettings = ref.watch(fontSettingsProvider);

    // Garante sincronização da fonte global do sistema
    GoogleFonts.setGlobalFontFamilyOverride(fontSettings.fontFamily);

    final themeData = AppTheme.getTheme(
      mode: appThemeMode,
      fontFamily: fontSettings.fontFamily,
    );

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      scrollBehavior: const AppCustomScrollBehavior(),
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
      navigatorObservers: [if (_navbarObserver != null) _navbarObserver!],
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);

        // Tamanho de fonte selecionado nas configurações do sistema:
        // 16.0px é a base padrão (1.0).
        // Se o usuário selecionar 12px -> 0.75
        // Se o usuário selecionar 20px -> 1.25
        // Se o usuário selecionar 24px -> 1.50
        final userFontScale = (fontSettings.fontSize / 16.0).clamp(0.70, 2.2);
        final systemScale = mediaQuery.textScaler.scale(1.0);
        final effectiveScale = (systemScale * userFontScale).clamp(0.70, 2.5);

        final String activeFont = fontSettings.fontFamily;
        final TextStyle dynamicDefaultStyle = CustomFontLoader.loadedFontFamilies.contains(activeFont)
            ? TextStyle(fontFamily: activeFont)
            : GoogleFonts.getFont(activeFont);

        final wrappedChild = MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(effectiveScale),
          ),
          child: DefaultTextStyle.merge(
            style: dynamicDefaultStyle,
            child: child ?? const SizedBox(),
          ),
        );

        final scrollNotificationHandler = NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Se a barra estiver configurada para o estilo Fixo, ela nunca se oculta ao rolar
            if (ref.read(navBarStyleProvider) == NavBarStyle.fixed) {
              return false;
            }

            // Só esconde a navbar se houver realmente espaço para rolar na tela e o scroll for vertical
            if (notification.metrics.axis == Axis.vertical && notification.metrics.maxScrollExtent > 0) {
              if (notification is UserScrollNotification) {
                if (notification.direction == ScrollDirection.reverse) {
                  if (ref.read(navbarVisibleProvider)) {
                    ref.read(navbarVisibleProvider.notifier).state = false;
                  }
                } else if (notification.direction == ScrollDirection.forward) {
                  if (!ref.read(navbarVisibleProvider)) {
                    ref.read(navbarVisibleProvider.notifier).state = true;
                  }
                }
              } else if (notification is ScrollUpdateNotification) {
                // Se chegar no final da tela, a navbar volta a aparecer
                if (notification.metrics.extentAfter < 10) {
                  if (!ref.read(navbarVisibleProvider)) {
                    ref.read(navbarVisibleProvider.notifier).state = true;
                  }
                }
              }
            }
            return false;
          },
          child: wrappedChild,
        );

        return GlobalShortcutsHandler(
          child: scrollNotificationHandler,
        );
      },
      title: 'KeryxApp',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      home: const AppInitializer(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Splash de inicialização que copia o strongV2.db do asset (primeira vez)
/// e depois navega para o [AuthWrapper] com fade transition.
class AppInitializer extends StatelessWidget {
  const AppInitializer({super.key});

  @override
  Widget build(BuildContext context) {
    return KeryxSplashScreen(
      statusMessages: const [
        'Preparando as Escrituras...',
        'Carregando concordância Strong...',
        'Quase lá...',
      ],
      initFuture: () async {
        // No Mobile/Desktop, inicializa o Strong se necessário.
        // No Web, o Strong carrega sob demanda (lazy) para inicialização instantânea da página.
        if (!kIsWeb) {
          await DatabaseService().getStrongDatabase();
        }
      },
      onReady: () {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthWrapper(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isGuest = ref.watch(guestModeProvider);

    if (isGuest) {
      return const MainLayout();
    }

    return authState.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }

        // Se o e-mail for do administrador principal, concede acesso imediato e transparente
        final email = user.email?.trim().toLowerCase();
        if (AccessControlService.isPrimaryAdmin(email)) {
          WidgetsBinding.instance.addPostFrameCallback((_) => TelegramBootstrap.start());
          return const MainLayout();
        }

        // Para os demais usuários, monitora em tempo real o status de aprovação
        final accessState = ref.watch(currentUserAccessProvider);

        return accessState.when(
          data: (accessInfo) {
            if (accessInfo == null) {
              return const KeryxSplashScreen(message: 'Verificando autorização de acesso...');
            }

            if (accessInfo.isBlocked) {
              return PendingApprovalScreen(
                accessInfo: accessInfo,
                isBlocked: true,
              );
            }

            if (accessInfo.isPending) {
              return PendingApprovalScreen(
                accessInfo: accessInfo,
                isBlocked: false,
              );
            }

            // Se o Administrador exigiu a atualização e o usuário ainda está na versão antiga:
            final currentVersion = ref.watch(currentAppVersionProvider).valueOrNull;
            final installedBuild = currentVersion?.buildNumber ?? 1;
            final targetBuild = accessInfo.targetBuildNumber ?? 1;

            if (accessInfo.updateRequired && installedBuild < targetBuild) {
              return UpdateRequiredScreen(accessInfo: accessInfo);
            }

            // Usuário devidamente autorizado
            WidgetsBinding.instance.addPostFrameCallback((_) => TelegramBootstrap.start());
            return const MainLayout();
          },
          loading: () =>
              const KeryxSplashScreen(message: 'Verificando credenciais e acesso...'),
          error: (e, stack) => PendingApprovalScreen(
            accessInfo: UserAccessInfo(
              uid: user.uid,
              email: user.email ?? '',
              displayName: user.displayName,
              status: AccessStatus.pending,
              role: UserRole.user,
            ),
          ),
        );
      },
      loading: () =>
          const KeryxSplashScreen(message: 'Sincronizando com os céus...'),
      error: (e, stack) => const LoginScreen(),
    );
  }
}

class AppCustomScrollBehavior extends MaterialScrollBehavior {
  const AppCustomScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // No mobile touch nativo, mantém visual limpo.
    // No desktop/web, permite a barra de rolagem interativa e responsiva do Material.
    if (kIsWeb) {
      final platform = getPlatform(context);
      if (platform == TargetPlatform.windows ||
          platform == TargetPlatform.macOS ||
          platform == TargetPlatform.linux) {
        return Scrollbar(
          controller: details.controller,
          interactive: true,
          child: child,
        );
      }
      return child;
    }
    return super.buildScrollbar(context, child, details);
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
      };
}

/// Manipulador global de atalhos de teclado para toda a aplicação.
/// Permite navegação rápida, zoom de fonte, comandos e abertura do guia de atalhos.
class GlobalShortcutsHandler extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalShortcutsHandler({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<GlobalShortcutsHandler> createState() => _GlobalShortcutsHandlerState();
}

class _GlobalShortcutsHandlerState extends ConsumerState<GlobalShortcutsHandler> {
  bool _isModalOpen = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.dispose();
  }

  bool _isEditingText() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final context = focus.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  BuildContext? get _navContext => appNavigatorKey.currentContext;

  Future<void> _openShortcutsModal() async {
    final ctx = _navContext;
    if (ctx == null || _isModalOpen) return;
    _isModalOpen = true;
    try {
      await showKeyboardShortcutsModal(ctx);
    } finally {
      _isModalOpen = false;
    }
  }

  void _adjustFontSize(double delta) {
    final current = ref.read(fontSettingsProvider).fontSize;
    final newSize = (current + delta).clamp(12.0, 32.0);
    ref.read(fontSettingsProvider.notifier).setFontSize(newSize);

    // Feedback visual sutil
    final messenger = ref.read(scaffoldMessengerKeyProvider).currentState;
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Tamanho da Fonte: ${newSize.toInt()}px'),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        width: 220,
      ),
    );
  }

  void _resetFontSize() {
    ref.read(fontSettingsProvider.notifier).setFontSize(16.0);
    final messenger = ref.read(scaffoldMessengerKeyProvider).currentState;
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Tamanho da Fonte restaurado: 16px'),
        duration: Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        width: 280,
      ),
    );
  }

  void _navigateToTab(int tabIndex) {
    final navState = appNavigatorKey.currentState;
    if (navState != null && navState.canPop()) {
      navState.popUntil((route) => route.isFirst);
    }
    ref.read(navigationProvider.notifier).setIndex(tabIndex);
  }

  Future<void> _openDevocional() async {
    final navState = appNavigatorKey.currentState;
    if (navState != null && navState.canPop()) {
      navState.popUntil((route) => route.isFirst);
    }

    final devocionalAsync = ref.read(devocionalDiarioProvider);
    final devocional = devocionalAsync.valueOrNull ??
        await ref.read(devocionalDiarioProvider.future).catchError((_) => null);

    if (devocional != null) {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => DevocionalScreen(devocional: devocional)),
      );
    }
  }

  void _openStudyPlan() {
    final navState = appNavigatorKey.currentState;
    if (navState != null && navState.canPop()) {
      navState.popUntil((route) => route.isFirst);
    }
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const StudyPlanWindow()),
    );
  }

  void _openAI() {
    final navState = appNavigatorKey.currentState;
    if (navState != null && navState.canPop()) {
      navState.popUntil((route) => route.isFirst);
    }
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ChatAssistantScreen()),
    );
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    final isControl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isEditing = _isEditingText();

    // 1. Abrir modal de atalhos de teclado:
    // Suporta '?' (LogicalKeyboardKey.question), 'Shift + /', 'Ctrl + /' (padrão universal Web),
    // ou 'Alt + A' (Atalhos) / 'Alt + H' (Help).
    final isQuestion = key == LogicalKeyboardKey.question ||
        (isShift && key == LogicalKeyboardKey.slash) ||
        (key.keyLabel == '?');
    final isCommandSlash = isControl &&
        (key == LogicalKeyboardKey.slash || key == LogicalKeyboardKey.question);
    final isAltHelp = isAlt &&
        (key == LogicalKeyboardKey.keyA || key == LogicalKeyboardKey.keyH);

    if (!isEditing && (isQuestion || isCommandSlash || isAltHelp)) {
      _openShortcutsModal();
      return true;
    }

    // Se estiver em campo de texto, não interceptar os demais comandos comuns
    if (isEditing && !isControl && !isAlt) {
      return false;
    }

    // 2. Zoom de Fonte: Ctrl + '+' / '=' e Ctrl + '-'
    if (isControl && (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add)) {
      _adjustFontSize(1.0);
      return true;
    }
    if (isControl && (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract)) {
      _adjustFontSize(-1.0);
      return true;
    }
    if (isControl && (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0)) {
      _resetFontSize();
      return true;
    }

    // 3. Navegação rápida entre abas: Alt + 1..5
    if (isAlt && key == LogicalKeyboardKey.digit1) {
      _navigateToTab(0);
      return true;
    }
    if (isAlt && key == LogicalKeyboardKey.digit2) {
      _navigateToTab(1);
      return true;
    }
    if (isAlt && key == LogicalKeyboardKey.digit3) {
      _openDevocional();
      return true;
    }
    if (isAlt && key == LogicalKeyboardKey.digit4) {
      _openStudyPlan();
      return true;
    }
    if (isAlt && key == LogicalKeyboardKey.digit5) {
      _openAI();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

