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
import 'package:keryx_app/core/widgets/cookie_consent_banner.dart';

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

