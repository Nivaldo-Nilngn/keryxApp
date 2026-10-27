import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
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
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);

    final Color navBgColor;
    final Color borderColor;
    final List<BoxShadow> shadows;
    final Color activeColor;
    final Color inactiveColor;

    switch (themeMode) {
      case AppThemeMode.dark:
        navBgColor = const Color(0xFF131825).withValues(alpha: 0.90);
        borderColor = const Color(0xFFFFB95F).withValues(alpha: 0.45);
        activeColor = const Color(0xFFFFB95F);
        inactiveColor = theme.colorScheme.onSurface.withValues(alpha: 0.55);
        shadows = [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.70),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFFFFB95F).withValues(alpha: 0.16),
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ];
        break;

      case AppThemeMode.sepia:
        // Sepia: pergaminho nobre e acolhedor (não branco!), em perfeita harmonia com o tema
        navBgColor = const Color(0xFFEBE0C7).withValues(alpha: 0.96);
        borderColor = const Color(0xFF8B5E3C).withValues(alpha: 0.40);
        activeColor = const Color(0xFF8B5E3C);
        inactiveColor = const Color(0xFF6B533E);
        shadows = [
          BoxShadow(
            color: const Color(0xFF4A3420).withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF8B5E3C).withValues(alpha: 0.12),
            blurRadius: 14,
            spreadRadius: 0.5,
          ),
        ];
        break;

      case AppThemeMode.paper:
        navBgColor = Colors.white.withValues(alpha: 0.94);
        borderColor = const Color(0xFFE2E8F0);
        activeColor = const Color(0xFF2C2C2C);
        inactiveColor = Colors.grey.shade600;
        shadows = [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ];
        break;

      case AppThemeMode.light:
        navBgColor = Colors.white.withValues(alpha: 0.94);
        borderColor = const Color(0xFFD97706).withValues(alpha: 0.40);
        activeColor = const Color(0xFFD97706);
        inactiveColor = const Color(0xFF475569);
        shadows = [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.16),
            blurRadius: 26,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: 0.5,
          ),
        ];
        break;
    }

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
                    borderRadius: BorderRadius.circular(34),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        decoration: BoxDecoration(
                          color: navBgColor,
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: borderColor,
                            width: 1.5,
                          ),
                          boxShadow: shadows,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            if (!isHome && onBack != null)
                              _buildItem(
                                context,
                                Icons.arrow_back_ios_new_rounded,
                                'Voltar',
                                activeColor: activeColor,
                                inactiveColor: inactiveColor,
                                onTap: onBack,
                              ),
                            if (!isHome)
                              _buildItem(
                                context,
                                Icons.home_filled,
                                'Início',
                                activeColor: activeColor,
                                inactiveColor: inactiveColor,
                                isActive: currentIndex == 0,
                                onTap: () => onTap(0),
                              ),
                            _buildItem(
                              context,
                              Icons.auto_stories_rounded,
                              'Bíblia',
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              isActive: currentIndex == 1,
                              onTap: () => onTap(1),
                            ),
                            _buildItem(
                              context,
                              Icons.edit_note_rounded,
                              'Anotações',
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              isActive: currentIndex == 3,
                              onTap: () => onTap(3),
                            ),
                            _buildItem(
                              context,
                              Icons.favorite_rounded,
                              'Favoritos',
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              isActive: currentIndex == 4,
                              onTap: () => onTap(4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    IconData icon,
    String label, {
    required Color activeColor,
    required Color inactiveColor,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      selected: isActive,
      button: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (onTap != null) onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isActive ? 16 : 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              border: isActive
                  ? Border.all(
                      color: activeColor.withValues(alpha: 0.35),
                      width: 1.2,
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isActive ? activeColor : inactiveColor,
                  size: isActive ? 21 : 20,
                  shadows: isActive
                      ? [
                          Shadow(
                            color: activeColor.withValues(alpha: 0.40),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0.2,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
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
