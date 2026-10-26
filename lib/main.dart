import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/state/font_state.dart';
import 'core/state/navigation_state.dart';
import 'core/state/navbar_route_observer.dart';

import 'core/theme/app_theme.dart';
import 'features/bible/view_model/bible_state.dart';
import 'core/widgets/main_layout.dart';
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

class KeryxApp extends ConsumerStatefulWidget {
  const KeryxApp({super.key});

  @override
  ConsumerState<KeryxApp> createState() => _KeryxAppState();
}

class _KeryxAppState extends ConsumerState<KeryxApp> {
  NavbarRouteObserver? _navbarObserver;

  @override
  void initState() {
    super.initState();
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

    final appThemeMode = ref.watch(themeModeProvider);

    ThemeData themeData;
    switch (appThemeMode) {
      case AppThemeMode.light:
        themeData = AppTheme.lightTheme;
        break;
      case AppThemeMode.dark:
        themeData = AppTheme.darkTheme;
        break;
      case AppThemeMode.sepia:
        themeData = AppTheme.sepiaTheme;
        break;
      case AppThemeMode.paper:
        themeData = AppTheme.paperTheme;
        break;
    }

    return MaterialApp(
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
      navigatorObservers: [if (_navbarObserver != null) _navbarObserver!],
      builder: (context, child) {
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
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
          child: child ?? const SizedBox(),
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

