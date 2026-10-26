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
import 'dart:convert';
import 'package:keryx_app/features/access_control/service/access_control_service.dart';
import 'package:keryx_app/features/access_control/view/user_management_screen.dart';
import 'reset_data_modal.dart';
import 'edit_profile_modal.dart';

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
                      constraints: const BoxConstraints(maxWidth: double.infinity),
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
                  if (ref.watch(storeProvider.select((s) => s.downloadProgress.isNotEmpty)))
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
            if (value == 'edit_profile') {
              showEditProfileModal(context, ref);
            } else if (value == 'settings') {
              _showSettings(context, ref);
            } else if (value == 'access_management') {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen()));
            } else if (value == 'logout') {
              _handleLogout(context, ref);
            } else if (value == 'login') {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
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
              _buildThemeSelectorItem(context, ref),
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
                value: 'edit_profile',
                child: Row(
                  children: [
                    Icon(Icons.manage_accounts_outlined, color: Theme.of(context).colorScheme.onSurface, size: 20),
                    const SizedBox(width: 12),
                    Text('Editar Perfil', style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onSurface)),
                  ],
                ),
              ),
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
              const PopupMenuDivider(height: 1),
              _buildThemeSelectorItem(context, ref),
              const PopupMenuDivider(height: 1),
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

            final String frameId = data?['avatarFrame'] ?? 'gold';

            List<Color> frameColors;
            switch (frameId) {
              case 'aurora':
                frameColors = const [Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFF3B82F6)];
                break;
              case 'fire':
                frameColors = const [Color(0xFFEF4444), Color(0xFFF97316), Color(0xFFFBBF24)];
                break;
              case 'sapphire':
                frameColors = const [Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFF1D4ED8)];
                break;
              case 'emerald':
                frameColors = const [Color(0xFF10B981), Color(0xFF059669)];
                break;
              case 'royal':
                frameColors = const [Color(0xFF7C3AED), Color(0xFFA855F7), Color(0xFFC026D3)];
                break;
              case 'midnight':
                frameColors = const [Color(0xFF38BDF8), Color(0xFF6366F1)];
                break;
              case 'silver':
                frameColors = const [Color(0xFFF1F5F9), Color(0xFF94A3B8)];
                break;
              case 'none':
                frameColors = const [Colors.transparent, Colors.transparent];
                break;
              case 'gold':
              default:
                frameColors = const [Color(0xFFF59E0B), Color(0xFFD97706)];
                break;
            }

            return Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: frameId != 'none'
                    ? LinearGradient(
                        colors: frameColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: frameId == 'none'
                    ? Border.all(color: Colors.white24, width: 1.2)
                    : null,
              ),
              child: Container(
                padding: const EdgeInsets.all(1.2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: buildAvatarImageWidget(context, photoUrl, initial, size: 28),
              ),
            );
          },
          loading: () => SizedBox(width: 32, height: 32, child: Center(child: CircleAvatar(radius: 16, backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest))),
          error: (_, __) => Icon(Icons.account_circle_outlined, color: Theme.of(context).colorScheme.onSurface, size: 24),
        );
      },
    );
  }

  static Widget buildAvatarImageWidget(BuildContext context, String? photoUrl, String initial, {double? size}) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return buildInitialsWidget(context, initial, size: size);
    }

    // Se for Base64 (data:image/...)
    if (photoUrl.startsWith('data:image') || !photoUrl.startsWith('http')) {
      try {
        final cleanBase64 = photoUrl.contains(',') ? photoUrl.split(',').last : photoUrl;
        final bytes = base64Decode(cleanBase64.trim());
        return ClipOval(
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: size,
            height: size,
            errorBuilder: (context, error, stackTrace) => buildInitialsWidget(context, initial, size: size),
          ),
        );
      } catch (_) {
        return buildInitialsWidget(context, initial, size: size);
      }
    }

    // Se for URL HTTP/HTTPS
    String resolvedUrl = photoUrl;
    if (resolvedUrl.contains('googleusercontent.com')) {
      resolvedUrl = resolvedUrl.replaceAll(RegExp(r'=s\d+(-c)?'), '=s256-c');
    }
    if (kIsWeb && resolvedUrl.startsWith('http') && !resolvedUrl.contains('wsrv.nl')) {
      resolvedUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(resolvedUrl)}';
    }

    return ClipOval(
      child: Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) => buildInitialsWidget(context, initial, size: size),
      ),
    );
  }

  static Widget buildInitialsWidget(BuildContext context, String initial, {double? size}) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.outfit(
          color: Theme.of(context).colorScheme.primary,
          fontSize: size != null ? size * 0.45 : 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildThemeSelectorItem(BuildContext context, WidgetRef ref) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 94,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Consumer(
        builder: (context, ref, _) {
          final currentMode = ref.watch(themeModeProvider);
          return SizedBox(
            width: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        size: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'TEMA VISUAL',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMenuThemeButton(
                      context: context,
                      ref: ref,
                      label: 'Claro',
                      mode: AppThemeMode.light,
                      current: currentMode,
                      bgColor: const Color(0xFFF3F4F6),
                      textColor: Colors.black87,
                      icon: Icons.light_mode_rounded,
                    ),
                    _buildMenuThemeButton(
                      context: context,
                      ref: ref,
                      label: 'Escuro',
                      mode: AppThemeMode.dark,
                      current: currentMode,
                      bgColor: const Color(0xFF1E1E30),
                      textColor: const Color(0xFFE2E0F9),
                      icon: Icons.dark_mode_rounded,
                    ),
                    _buildMenuThemeButton(
                      context: context,
                      ref: ref,
                      label: 'Sépia',
                      mode: AppThemeMode.sepia,
                      current: currentMode,
                      bgColor: const Color(0xFFFDF0D5),
                      textColor: const Color(0xFF5C4033),
                      icon: Icons.auto_stories_rounded,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuThemeButton({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required AppThemeMode mode,
    required AppThemeMode current,
    required Color bgColor,
    required Color textColor,
    required IconData icon,
  }) {
    final isSelected = mode == current;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(themeModeProvider.notifier).setTheme(mode);
        Navigator.of(context).pop();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.kPrimaryGold.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Center(
              child: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: AppTheme.kPrimaryGold, size: 22)
                  : Icon(icon, color: textColor.withValues(alpha: 0.7), size: 18),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: double.infinity),
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


class UnifiedSettingsSheet extends ConsumerStatefulWidget {
  const UnifiedSettingsSheet({super.key});

  @override
  ConsumerState<UnifiedSettingsSheet> createState() => _UnifiedSettingsSheetState();
}

class _UnifiedSettingsSheetState extends ConsumerState<UnifiedSettingsSheet> {
  bool _isSystemSettingsExpanded = true;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(fontSettingsProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), width: 1)),
          ),
          padding: EdgeInsets.fromLTRB(
            isTablet ? 40 : 24,
            16,
            isTablet ? 40 : 24,
            MediaQuery.of(context).viewInsets.bottom + 36,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
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

                  // 1. PERFIL DO USUÁRIO COM OPÇÃO DE EDITAR
                  _buildUserProfileSection(context, user),
                  const SizedBox(height: 24),

                  // 2. CONFIGURAÇÕES DO SISTEMA (FONTE E VOZ TTS - MINIMIZÁVEL)
                  _buildSystemSettingsSection(context, settings),
                  const SizedBox(height: 24),

                  // 3. ARMAZENAMENTO E DADOS
                  Text('ARMAZENAMENTO E DADOS', style: _sectionTitleStyle(context)),
                  const SizedBox(height: 14),
                  _buildDataResetSection(context, ref),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfileSection(BuildContext context, dynamic user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nenhum usuário conectado', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    'Faça login para sincronizar dados e personalizar seu perfil',
                    style: GoogleFonts.manrope(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.kPrimaryGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Entrar'),
            ),
          ],
        ),
      );
    }

    final isPrimaryAdmin = AccessControlService.isPrimaryAdmin(user.email);
    final userData = ref.watch(userDataProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONTA E PERFIL', style: _sectionTitleStyle(context)),
        const SizedBox(height: 12),
        userData.when(
          data: (data) {
            String name = data?['name'] ?? user.displayName ?? '';
            if (name.isEmpty && user.email != null) {
              name = user.email!.split('@').first;
            }
            if (name.isEmpty) name = 'Usuário';

            final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
            String? photoUrl = data?['photoUrl'] ?? user.photoURL ?? (user.providerData.isNotEmpty ? user.providerData.first.photoURL : null);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E1E2E), const Color(0xFF151520)]
                      : [Colors.white, const Color(0xFFF9FAFB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.kPrimaryGold, width: 2),
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: KeryxUserDropdown.buildAvatarImageWidget(context, photoUrl, initial, size: 54),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppTheme.kPrimaryGold,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 11, color: Colors.black),
                        ),
                      ),
                    ],
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
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isPrimaryAdmin) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, size: 15, color: AppTheme.kPrimaryGold),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email ?? '',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isPrimaryAdmin) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      showEditProfileModal(context, ref);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                      foregroundColor: AppTheme.kPrimaryGold,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 15),
                    label: Text('Editar', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSystemSettingsSection(BuildContext context, FontSettings settings) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A28) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Toggle
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              setState(() {
                _isSystemSettingsExpanded = !_isSystemSettingsExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tune_rounded, color: AppTheme.kPrimaryGold, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Configurações do Sistema',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.kPrimaryGold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'FONTE & VOZ',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.kPrimaryGold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fonte: ${settings.fontFamily} • ${settings.fontSize.toInt()}px • Voz TTS',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isSystemSettingsExpanded ? 'Minimizar' : 'Personalizar',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.kPrimaryGold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isSystemSettingsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppTheme.kPrimaryGold,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Se estiver expandido, exibe os controles de Fonte e TTS
          if (_isSystemSettingsExpanded) ...[
            Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TAMANHO DA FONTE (${settings.fontSize.toInt()}px)', style: _sectionTitleStyle(context)),
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
                  const SizedBox(height: 24),

                  Text('ESTILO DE FONTE', style: _sectionTitleStyle(context)),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 24),

                  // Card de Áudio e Voz TTS
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF4ADE80).withValues(alpha: 0.15), const Color(0xFF3B82F6).withValues(alpha: 0.15)],
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
                            constraints: const BoxConstraints(maxWidth: double.infinity),
                            builder: (context) => const keryx_tts.TtsSettingsSheet(),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.record_voice_over_rounded, color: Theme.of(context).colorScheme.onSurface, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Áudio e Leitura (TTS)', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text('Configurar vozes, velocidade e idioma da leitura', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12)),
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
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataResetSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF3F1212),
                  const Color(0xFF220A0A),
                ]
              : [
                  const Color(0xFFFEF2F2),
                  const Color(0xFFFEE2E2),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.pop(context);
            showResetDataModal(context, ref);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.cleaning_services_rounded,
                    color: Color(0xFFEF4444),
                    size: 22,
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
                              'Limpar Dados e Começar do Zero',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'RESET',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Apagar bíblias, livros, notas, favoritos e caches acumulados.',
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
                  color: const Color(0xFFEF4444).withValues(alpha: 0.6),
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
}

