import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/features/bible/view/tts_settings_sheet.dart' as keryx_tts;
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/services/custom_font_loader.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/features/auth/view/login_screen.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/home/view/notifications_bottom_sheet.dart';
import 'package:keryx_app/features/home/view_model/notifications_provider.dart';
// Import necessário para o AuthWrapper
import 'package:keryx_app/features/store/view/store_screen.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/access_control/service/access_control_service.dart';
import 'package:keryx_app/features/access_control/view/user_management_screen.dart';
import 'pwa_install_guide_modal.dart';

class KeryxTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final List<Widget>? additionalActions;
  final bool showBackButton;
  final bool showLogo;
  final double height;
  final PreferredSizeWidget? bottom;
  final bool isScrolled;

  const KeryxTopBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.additionalActions,
    this.showBackButton = false,
    this.showLogo = true,
    this.height = 85.0,
    this.bottom,
    this.onBack,
    this.onTitleTap,
    this.isScrolled = false,
  });

  final VoidCallback? onBack;
  final VoidCallback? onTitleTap;

  @override
  Size get preferredSize => Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isScrolled
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)
                : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: height,
          automaticallyImplyLeading: showBackButton,
          centerTitle: false,
          titleSpacing: showBackButton ? 0 : 24.0,
          leadingWidth: leading != null ? 80 : 56,
          leading: leading ?? (showBackButton ? IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface, size: 20),
            onPressed: onBack ?? () => Navigator.pop(context),
          ) : null),
          title: GestureDetector(
            onTap: onTitleTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showLogo) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/img/logoHome.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF2C3243),
                            child: Center(
                              child: Text(
                                'K',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    title == 'KeryxApp' || title == 'Bíblia' || title == 'mBíblia' ? 'KeryxApp' : title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (onTitleTap != null)
                  const Icon(Icons.arrow_drop_down, color: AppTheme.kPrimaryGold),
              ],
            ),
          ),
          actions: actions ?? [
            if (additionalActions != null) ...additionalActions!,
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    size: 26,
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const NotificationsBottomSheet(),
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final unreadCount = ref.watch(unreadNotificationsCountProvider);
                    if (unreadCount == 0) return const SizedBox.shrink();
                    return Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.storefront_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    size: 24,
                  ),
                  if (ref.watch(storeProvider).downloadProgress.isNotEmpty)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.kPrimaryGold,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                ref.read(isLibraryModeProvider.notifier).state = false;
                ref.read(searchQueryProvider.notifier).state = '';
                ref.read(selectedCategoryProvider.notifier).state = null;
                if (Navigator.canPop(context)) {
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
                ref.read(navigationProvider.notifier).setIndex(5);
              },
            ),

            const KeryxUserDropdown(),
            const SizedBox(width: 8),
          ],
          bottom: bottom,
        ),
      ),
    );
  }
}

typedef MBibliaTopBar = KeryxTopBar;
typedef MBibliaUserDropdown = KeryxUserDropdown;

class KeryxUserDropdown extends ConsumerWidget {
  const KeryxUserDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) {
        return PopupMenuButton<String>(
          offset: const Offset(0, 56),
          color: Theme.of(context).cardColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          ),
          elevation: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildUserAvatar(context, user, ref),
          ),
          onSelected: (value) {
            if (value == 'settings') {
              _showSettings(context, ref);
            } else if (value == 'access_management') {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen()));
            } else if (value == 'logout') {
              _handleLogout(context, ref);
            } else if (value == 'login') {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            } else if (value == 'theme') {
              final currentMode = ref.read(themeModeProvider);
              final newMode = currentMode == AppThemeMode.dark ? AppThemeMode.light : AppThemeMode.dark;
              ref.read(themeModeProvider.notifier).setTheme(newMode);
            }
          },
          itemBuilder: (context) {
            final isPrimaryAdmin = user != null && AccessControlService.isPrimaryAdmin(user.email);
            return [
            if (user == null) ...[
              PopupMenuItem(
                value: 'login',
                child: Row(
                  children: [
                    const Icon(Icons.login, color: AppTheme.kPrimaryGold, size: 20),
                    const SizedBox(width: 12),
                    Text('Entrar', style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'theme',
                child: Consumer(
                  builder: (context, ref, _) {
                    final isDark = ref.watch(themeModeProvider) == AppThemeMode.dark;
                    return Row(
                      children: [
                        Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: Theme.of(context).colorScheme.onSurface, size: 20),
                        const SizedBox(width: 12),
                        Text(isDark ? 'Tema Claro' : 'Tema Escuro', style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onSurface)),
                      ],
                    );
                  },
                ),
              ),
            ] else ...[
              PopupMenuItem(
                enabled: false,
                child: Consumer(
                  builder: (context, ref, _) {
                    final userData = ref.watch(userDataProvider);
                    return userData.when(
                      data: (data) {
                        final name = data?['name'] ?? user.displayName ?? 'Usuário';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isPrimaryAdmin) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, size: 14, color: AppTheme.kPrimaryGold),
                                ],
                              ],
                            ),
                            Text(
                              user.email ?? '',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            if (isPrimaryAdmin)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ADMINISTRADOR PRINCIPAL',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.kPrimaryGold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const Text('...'),
                      error: (_, __) => Text(user.displayName ?? 'Usuário'),
                    );
                  },
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurface, size: 20),
                    const SizedBox(width: 12),
                    Text('Configurações', style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onSurface)),
                  ],
                ),
              ),
              if (isPrimaryAdmin)
                PopupMenuItem(
                  value: 'access_management',
                  child: Row(
                    children: [
                      const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.kPrimaryGold, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Gerenciamento de Acessos',
                        style: GoogleFonts.manrope(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'theme',
                child: Consumer(
                  builder: (context, ref, _) {
                    final isDark = ref.watch(themeModeProvider) == AppThemeMode.dark;
                    return Row(
                      children: [
                        Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: Theme.of(context).colorScheme.onSurface, size: 20),
                        const SizedBox(width: 12),
                        Text(isDark ? 'Tema Claro' : 'Tema Escuro', style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onSurface)),
                      ],
                    );
                  },
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, color: Color(0xFFFF5252), size: 20),
                    const SizedBox(width: 12),
                    Text('Sair', style: GoogleFonts.manrope(color: const Color(0xFFFF5252), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ];
          },
        );
      },
      loading: () => const SizedBox(width: 48),
      error: (_, __) => const SizedBox(width: 48),
    );
  }

  Widget _buildUserAvatar(BuildContext context, dynamic user, WidgetRef ref) {
    if (user == null) {
      return Icon(Icons.account_circle_outlined, color: Theme.of(context).colorScheme.onSurface, size: 24);
    }

    return Consumer(
      builder: (context, ref, _) {
        final userData = ref.watch(userDataProvider);
        return userData.when(
          data: (data) {
            String name = data?['name'] ?? user.displayName ?? '';
            if (name.isEmpty && user.email != null) {
              name = user.email!.split('@').first;
            }
            if (name.isEmpty) name = 'Usuário';
            
            final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
            
            // Busca profunda da foto (Firestore -> Firebase Auth -> Provedores)
            String? photoUrl = data?['photoUrl'] ?? 
                                     user.photoURL ?? 
                                     (user.providerData.isNotEmpty ? user.providerData.first.photoURL : null);

            // Sanitização para evitar erro 429 (Too Many Requests) do Google no Web
            if (photoUrl != null && photoUrl.contains('googleusercontent.com')) {
              photoUrl = photoUrl.replaceAll(RegExp(r'=s\d+(-c)?'), '=s256-c');
            }

            if (kIsWeb && photoUrl != null && photoUrl.startsWith('http') && !photoUrl.contains('wsrv.nl')) {
              photoUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(photoUrl)}';
            }

            return Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5), width: 1.5),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: (photoUrl != null)
                ? ClipOval(
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildInitials(context, initial),
                    ),
                  )
                : _buildInitials(context, initial),
            );
          },
          loading: () => SizedBox(width: 32, height: 32, child: Center(child: CircleAvatar(radius: 16, backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest))),
          error: (_, __) => Icon(Icons.account_circle_outlined, color: Theme.of(context).colorScheme.onSurface, size: 24),
        );
      },
    );
  }

  Widget _buildInitials(BuildContext context, String initial) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.outfit(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const UnifiedSettingsSheet(),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFFF5252), size: 32),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sair da Conta',
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tem certeza que deseja sair da sua conta?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.manrope(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(authServiceProvider).signOut();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5252),
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Sair',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class UnifiedSettingsSheet extends ConsumerWidget {
  const UnifiedSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(fontSettingsProvider);
    final appThemeMode = ref.watch(themeModeProvider);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), width: 1)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 36),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.settings_suggest_rounded, color: AppTheme.kPrimaryGold, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'CONFIGURAÇÕES',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Seção Minha Conta e Gerenciamento de Acessos ──
                  _buildAccountAccessSection(context, ref),
                  const SizedBox(height: 24),

                  // ── Seção Instalar no iPhone / Celular (PWA) ──
                  _buildPwaInstallSection(context),
                  const SizedBox(height: 28),

                  Text('TEMA VISUAL', style: _sectionTitleStyle(context)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildThemeCard(context, ref, 'Claro', AppThemeMode.light, appThemeMode, const Color(0xFFF3F4F6), Colors.black87),
                      _buildThemeCard(context, ref, 'Escuro', AppThemeMode.dark, appThemeMode, const Color(0xFF1E293B), Theme.of(context).colorScheme.onSurface),
                      _buildThemeCard(context, ref, 'Sépia', AppThemeMode.sepia, appThemeMode, const Color(0xFFFDF0D5), const Color(0xFF5C4033)),
                      _buildThemeCard(context, ref, 'Papel', AppThemeMode.paper, appThemeMode, const Color(0xFFF4ECD8), Colors.black87),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  Text('TAMANHO DA FONTE', style: _sectionTitleStyle(context)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.text_decrease_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), size: 20),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 6,
                            activeTrackColor: AppTheme.kPrimaryGold,
                            inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                            thumbColor: AppTheme.kPrimaryGold,
                            overlayColor: AppTheme.kPrimaryGold.withValues(alpha: 0.2),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                          ),
                          child: Slider(
                            value: settings.fontSize,
                            min: 12,
                            max: 36,
                            onChanged: (val) => ref.read(fontSettingsProvider.notifier).setFontSize(val),
                          ),
                        ),
                      ),
                      Icon(Icons.text_increase_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), size: 28),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  Text('ESTILO DE FONTE', style: _sectionTitleStyle(context)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        ...CustomFontLoader.googleFonts,
                        ...CustomFontLoader.loadedFontFamilies.where((f) => !CustomFontLoader.googleFonts.contains(f)),
                        '+ Importar'
                      ].map((f) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: f == '+ Importar'
                            ? InkWell(
                                onTap: () async {
                                  final newFont = await CustomFontLoader.importCustomFont();
                                  if (newFont != null) {
                                    ref.read(fontSettingsProvider.notifier).setFontFamily(newFont);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.kPrimaryGold.withValues(alpha: 0.5), width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.add_circle_outline_rounded, color: AppTheme.kPrimaryGold, size: 18),
                                      const SizedBox(width: 8),
                                      Text('Importar', style: GoogleFonts.outfit(color: AppTheme.kPrimaryGold, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: () => ref.read(fontSettingsProvider.notifier).setFontFamily(f),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: settings.fontFamily == f ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: settings.fontFamily == f ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                                    ),
                                    boxShadow: settings.fontFamily == f
                                        ? [BoxShadow(color: AppTheme.kPrimaryGold.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                                        : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    f,
                                    style: CustomFontLoader.loadedFontFamilies.contains(f)
                                        ? TextStyle(
                                            fontFamily: f,
                                            color: settings.fontFamily == f ? Colors.black : Theme.of(context).colorScheme.onSurface,
                                            fontWeight: settings.fontFamily == f ? FontWeight.bold : FontWeight.w500,
                                            fontSize: 16,
                                          )
                                        : GoogleFonts.getFont(
                                            f,
                                            color: settings.fontFamily == f ? Colors.black : Theme.of(context).colorScheme.onSurface,
                                            fontWeight: settings.fontFamily == f ? FontWeight.bold : FontWeight.w500,
                                            fontSize: 16,
                                          ),
                                  ),
                                ),
                              ),
                      )).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF4ADE80).withValues(alpha: 0.2), const Color(0xFF3B82F6).withValues(alpha: 0.2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const keryx_tts.TtsSettingsSheet(),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.record_voice_over_rounded, color: Theme.of(context).colorScheme.onSurface, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Áudio e Leitura (TTS)', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('Configurar vozes e idioma da leitura', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountAccessSection(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    final isAdm = AccessControlService.isPrimaryAdmin(authUser?.email);

    if (isAdm) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.kPrimaryGold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.kPrimaryGold.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_rounded, color: AppTheme.kPrimaryGold, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Administrador Principal',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, size: 14, color: AppTheme.kPrimaryGold),
                        ],
                      ),
                      Text(
                        AccessControlService.kPrimaryAdminEmail,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'AUTORIZADO',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Permissões: Acesso completo ao sistema de gerenciamento de usuários. Autorização automática permanente.',
              style: GoogleFonts.manrope(
                fontSize: 11,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 14),
            // Botão Gerenciamento de Acessos
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.manage_accounts_rounded, color: AppTheme.kPrimaryGold, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gerenciamento de Acessos',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Visualizar, aprovar e revogar acessos de usuários',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (authUser != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline_rounded, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authUser.displayName ?? 'Usuário',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    authUser.email ?? '',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'AUTORIZADO',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF10B981),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPwaInstallSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1B1B32),
                  const Color(0xFF141426),
                ]
              : [
                  const Color(0xFFF8F9FE),
                  const Color(0xFFFFFFFF),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.kPrimaryGold.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.pop(context);
            showPwaInstallGuide(context);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.install_mobile_rounded,
                    color: AppTheme.kPrimaryGold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Instalar App no iPhone / Celular',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.kPrimaryGold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PWA',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.kPrimaryGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Adicione à Tela de Início para usar em tela cheia sem barras de navegador.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _sectionTitleStyle(BuildContext context) {
    return GoogleFonts.outfit(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    );
  }

  Widget _buildThemeCard(BuildContext context, WidgetRef ref, String label, AppThemeMode mode, AppThemeMode current, Color bgColor, Color textColor) {
    final isSelected = mode == current;
    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).setTheme(mode),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.kPrimaryGold : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: AppTheme.kPrimaryGold.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]
                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: isSelected ? const Center(child: Icon(Icons.check_circle_rounded, color: AppTheme.kPrimaryGold, size: 28)) : null,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

}

