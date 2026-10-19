import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/state/navigation_state.dart';

/// Barra de navegação unificada para todo o aplicativo, 
/// garantindo consistência no design.
class KeryxBottomNav extends ConsumerWidget {
  final bool isHome;
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onBack;
  final bool forceHide;

  const KeryxBottomNav({
    super.key,
    required this.isHome,
    required this.currentIndex,
    required this.onTap,
    this.onBack,
    this.forceHide = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(navbarVisibleProvider) && !forceHide;

    return AnimatedSlide(
      offset: isVisible ? Offset.zero : const Offset(0, 1.5),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              margin: EdgeInsets.only(
                bottom: 24 + MediaQuery.of(context).padding.bottom, 
                left: 16, 
                right: 16
              ),
              height: 72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: const Color(0xFF4D4635).withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE9C349).withValues(alpha: 0.06),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (!isHome && onBack != null)
                  _buildItem(context, Icons.arrow_back_ios_new_rounded, 'Voltar', onTap: onBack),
                
                if (!isHome)
                  _buildItem(context, Icons.home_filled, 'Início', isActive: currentIndex == 0, onTap: () => onTap(0)),
                
                _buildItem(context, Icons.auto_stories_rounded, 'Bíblia', isActive: currentIndex == 1, onTap: () => onTap(1)),
                _buildItem(context, Icons.edit_note_rounded, 'Anotações', isActive: currentIndex == 3, onTap: () => onTap(3)),
                _buildItem(context, Icons.favorite_rounded, 'Favoritos', isActive: currentIndex == 4, onTap: () => onTap(4)),
              ],
            ),
          ),
        ),
      ),
              ), // closes Container
            ), // closes ConstrainedBox
            ), // closes Flexible
          ], // closes children of Row
        ), // closes Row
      ), // closes SafeArea
    ); // closes AnimatedSlide
  }

  Widget _buildItem(BuildContext context, IconData icon, String label, {bool isActive = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isActive ? 1.25 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                size: 20,
                shadows: isActive ? [
                  Shadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4), 
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ] : null,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Wrappers para compatibilidade com o resto do código ─────────────────────────
// Estes wrappers garantem que qualquer tela que chame os componentes antigos
// receberá o novo design unificado automaticamente.

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onBack;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return KeryxBottomNav(
      isHome: currentIndex == 0,
      currentIndex: currentIndex,
      onTap: onTap,
      onBack: onBack,
    );
  }
}

class BookDetailBottomNav extends StatelessWidget {
  final VoidCallback onBack;
  final int currentIndex;
  final Function(int) onTap;
  final bool forceHide;

  const BookDetailBottomNav({
    super.key,
    required this.onBack,
    required this.currentIndex,
    required this.onTap,
    this.forceHide = false,
  });

  @override
  Widget build(BuildContext context) {
    return KeryxBottomNav(
      isHome: false,
      currentIndex: currentIndex,
      onTap: onTap,
      onBack: onBack,
      forceHide: forceHide,
    );
  }
}

class DictionaryBottomNav extends StatelessWidget {
  final VoidCallback onBack;
  final int currentIndex;
  final Function(int) onTap;

  const DictionaryBottomNav({
    super.key,
    required this.onBack,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KeryxBottomNav(
      isHome: false,
      currentIndex: currentIndex,
      onTap: onTap,
      onBack: onBack,
    );
  }
}

class StudyBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const StudyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KeryxBottomNav(
      isHome: false,
      currentIndex: currentIndex,
      onTap: onTap,
      onBack: () => onTap(0), // O voltar do Study vai para a home
    );
  }
}

class StoreBottomNav extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onBible;
  final VoidCallback? onHome;
  final VoidCallback? onCommentary;
  final VoidCallback? onStore;

  const StoreBottomNav({
    super.key,
    required this.onBack,
    required this.onBible,
    this.onHome,
    this.onCommentary,
    this.onStore,
  });

  @override
  Widget build(BuildContext context) {
    return KeryxBottomNav(
      isHome: false,
      currentIndex: 5, // 5 = Store/Other
      onTap: (index) {
        if (index == 0 && onHome != null) onHome!();
        if (index == 1) onBible();
        if (index == 2 && onCommentary != null) onCommentary!(); // mapeava pra plano/comentário
      },
      onBack: onBack,
    );
  }
}

class CommentaryBottomNav extends StatelessWidget {
  final VoidCallback onBack;
  final int currentIndex;
  final Function(int) onTap;

  const CommentaryBottomNav({
    super.key,
    required this.onBack,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KeryxBottomNav(
      isHome: false,
      currentIndex: currentIndex,
      onTap: onTap,
      onBack: onBack,
    );
  }
}
