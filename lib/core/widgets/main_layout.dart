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
import 'package:keryx_app/features/community/view/community_feed_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/features/community/view/community_user_profile_screen.dart';
import 'package:keryx_app/core/widgets/instagram_tablet_sidebar.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/core/widgets/cookie_consent_banner.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  double? _dragStartX;
  final Set<int> _loadedTabs = <int>{};

  @override
  void initState() {
    super.initState();
    // Registra a aba inicial como ativa para carregamento sob demanda
    _loadedTabs.add(ref.read(navigationProvider));
  }

  String _getTitle(int index) {
    return 'KeryxApp';
  }

  bool _showLogo(int index) {
    return true;
  }

  Widget _buildTab(int index) {
    // Se a aba ainda não foi acessada nesta sessão, não a instancia
    // Evita inicializar conexões ao Firestore/SQLite de telas não visitadas
    if (!_loadedTabs.contains(index)) {
      return SizedBox.shrink(key: ValueKey('tab_placeholder_$index'));
    }

    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const BookSelectionScreen();
      case 2:
        return const CommentarySelectionScreen();
      case 3:
        return const AnnotationsScreen();
      case 4:
        return const FavoritesScreen(showTopBar: false);
      case 5:
        return const StoreScreen();
      case 6:
        return const CommunityFeedScreen(isEmbedded: true);
      default:
        return SizedBox.shrink(key: ValueKey('tab_placeholder_$index'));
    }
  }

  @override
  Widget build(BuildContext context) {
    var currentIndex = ref.watch(navigationProvider);
    final canPop = ref.watch(navigationProvider.notifier).canPop;
    final isTablet = MediaQuery.of(context).size.width >= 720;

    // Registra a aba atual como visitada para montar o widget sob demanda
    _loadedTabs.add(currentIndex);

    ref.listen<int>(navigationProvider, (previous, next) {
      if (next == 5 && previous != 5) {
        // Ao ir para a Loja via navegação, sempre garante que abre na aba Downloads
        ref.read(isLibraryModeProvider.notifier).state = false;
        ref.read(searchQueryProvider.notifier).state = '';
      }
    });

    final tabChildren = List.generate(7, _buildTab);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, dynamic result) {
        if (didPop) return;
        ref.read(navigationProvider.notifier).goBack();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: (isTablet || currentIndex == 5 || currentIndex == 6)
          ? null
          : MBibliaTopBar(
              title: _getTitle(currentIndex),
              showLogo: _showLogo(currentIndex),
              showBackButton: false,
            ),
        body: isTablet
          ? InstagramTabletSidebar(
              currentIndex: currentIndex,
              body: Stack(
                children: [
                  IndexedStack(
                    index: currentIndex,
                    children: tabChildren,
                  ),
                  const CookieConsentBanner(),
                ],
              ),
              onSelectIndex: (index) {
                ref.read(navigationProvider.notifier).setIndex(index);
              },
              onProfileTap: () {
                final user = FirebaseAuth.instance.currentUser;
                final userData = ref.read(userDataProvider).valueOrNull;
                final userPhoto = (userData?['photoUrl'] as String?)?.trim() ?? user?.photoURL?.trim();
                final userName = (userData?['name'] as String?)?.trim() ?? user?.displayName ?? 'Perfil';
                final userFrameId = (userData?['avatarFrame'] as String?) ?? 'gold';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityUserProfileScreen(
                      userId: user?.uid ?? '',
                      userName: userName,
                      userAvatar: userPhoto,
                      avatarFrame: userFrameId,
                    ),
                  ),
                );
              },
            )
          : GestureDetector(
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
                      children: tabChildren,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildBottomNav(currentIndex),
                    ),
                    const CookieConsentBanner(),
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
}

