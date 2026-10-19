import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/features/home/view/home_screen.dart';
import 'package:keryx_app/features/bible/navigation/view/book_selection_screen.dart';
import 'package:keryx_app/features/bible/navigation/view/commentary_selection_screen.dart';
import 'package:keryx_app/features/study/view/annotations_screen.dart';
import 'package:keryx_app/features/study/view/favorites_screen.dart';
import 'package:keryx_app/features/store/view/store_screen.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/access_control/service/access_control_service.dart';
import 'package:keryx_app/features/access_control/view/user_management_screen.dart';
import 'pwa_install_guide_modal.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  double? _dragStartX;

  String _getTitle(int index) {
    return 'KeryxApp';
  }

  bool _showLogo(int index) {
    return true;
  }

  @override
  Widget build(BuildContext context) {
    var currentIndex = ref.watch(navigationProvider);
    final canPop = ref.watch(navigationProvider.notifier).canPop;

    ref.listen<int>(navigationProvider, (previous, next) {
      if (next == 5 && previous != 5) {
        // Ao ir para a Loja via navegação, sempre garante que abre na aba Downloads
        ref.read(isLibraryModeProvider.notifier).state = false;
        ref.read(searchQueryProvider.notifier).state = '';
      }
    });
    


    final screens = [
      const HomeScreen(), // 0
      const BookSelectionScreen(), // 1
      const CommentarySelectionScreen(), // 2
      const AnnotationsScreen(), // 3
      const FavoritesScreen(showTopBar: false), // 4
      const StoreScreen(), // 5
    ];

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, dynamic result) {
        if (didPop) return;
        ref.read(navigationProvider.notifier).goBack();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: _buildDrawer(context),
        appBar: currentIndex == 5 
          ? null
          : MBibliaTopBar(
              title: _getTitle(currentIndex),
              showLogo: _showLogo(currentIndex),
              showBackButton: false,
            ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (details) {
            _dragStartX = details.globalPosition.dx;
          },
          onHorizontalDragEnd: (details) {
            final startX = _dragStartX;
            _dragStartX = null;
            // Gesto de voltar da borda esquerda (< 50px de margem)
            if (startX != null && startX < 50 && (details.primaryVelocity ?? 0) > 250) {
              if (ref.read(navigationProvider.notifier).canGoBack) {
                ref.read(navigationProvider.notifier).goBack();
              }
            }
          },
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Stack(
              children: [
                IndexedStack(
                  index: currentIndex,
                  children: screens,
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildBottomNav(currentIndex),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(int currentIndex) {
    if (currentIndex == 1) {
      return BookDetailBottomNav(
        currentIndex: currentIndex,
        onTap: (index) => ref.read(navigationProvider.notifier).setIndex(index),
        onBack: () => ref.read(navigationProvider.notifier).goBack(),
      );
    } else if (currentIndex == 2) {
      return CommentaryBottomNav(
        currentIndex: 2, // Sempre 2 para estar ativo
        onTap: (index) => ref.read(navigationProvider.notifier).setIndex(index),
        onBack: () => ref.read(navigationProvider.notifier).goBack(),
      );
    } else {
      return CustomBottomNav(
        currentIndex: currentIndex,
        onTap: (index) => ref.read(navigationProvider.notifier).setIndex(index),
        onBack: () => ref.read(navigationProvider.notifier).goBack(),
      );
    }
  }

  Widget _buildDrawer(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final authUser = ref.watch(authStateProvider).value;
    final isPrimaryAdmin = AccessControlService.isPrimaryAdmin(authUser?.email);
    final userName = authUser?.displayName ?? (authUser?.email != null ? authUser!.email!.split('@').first : 'Usuário');

    return Drawer(
      backgroundColor: Theme.of(context).cardColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isPrimaryAdmin ? AppTheme.kPrimaryGold : const Color(0xFF6B21A8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPrimaryAdmin ? Icons.shield_rounded : Icons.person,
                      color: isPrimaryAdmin ? const Color(0xFF111223) : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                userName,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: onSurface,
                                ),
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
                          isPrimaryAdmin ? 'Administrador Principal' : 'Usuário Autorizado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isPrimaryAdmin ? AppTheme.kPrimaryGold : onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: onSurface.withValues(alpha: 0.1)),
            if (isPrimaryAdmin)
              _buildDrawerItem(
                Icons.admin_panel_settings_outlined,
                'Gerenciamento de Acessos',
                AppTheme.kPrimaryGold,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                  );
                },
              ),
            _buildDrawerItem(Icons.star_outline, 'Seja Premium', Colors.orange),
            _buildDrawerItem(Icons.bookmark_border, 'Meus Favoritos', onSurface),
            _buildDrawerItem(Icons.history, 'Histórico', onSurface),
            _buildDrawerItem(
              Icons.install_mobile_rounded,
              'Instalar App (iPhone / Android)',
              AppTheme.kPrimaryGold,
              onTap: () {
                Navigator.pop(context);
                showPwaInstallGuide(context);
              },
            ),
            _buildDrawerItem(
              Icons.settings_outlined,
              'Configurações',
              onSurface,
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const UnifiedSettingsSheet(),
                );
              },
            ),
            const Spacer(),
            Divider(color: onSurface.withValues(alpha: 0.1)),
            _buildDrawerItem(
              Icons.logout,
              'Sair',
              Colors.redAccent,
              onTap: () {
                Navigator.pop(context);
                ref.read(authServiceProvider).signOut();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, Color color, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

