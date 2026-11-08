import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/theme/app_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/edit_profile_modal.dart';
import 'package:keryx_app/features/community/view/widgets/community_user_avatar.dart';
import 'package:keryx_app/features/community/view/widgets/create_post_bottom_sheet.dart';
import 'package:keryx_app/features/community/view/widgets/create_story_bottom_sheet.dart';
import 'package:keryx_app/features/home/view/notifications_bottom_sheet.dart';
import 'package:keryx_app/features/home/view_model/notifications_provider.dart';
import 'package:keryx_app/features/home/view/guide_screen.dart';
import 'package:keryx_app/core/services/release_notes_service.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/study_plan/presentation/study_plan_window.dart';
import 'package:keryx_app/features/study/view/dictionary_screen.dart';
import 'package:keryx_app/features/pdf/view/pdf_books_screen.dart';
import 'package:keryx_app/features/ai/view/chat_assistant_screen.dart';
import 'package:keryx_app/features/home/view/devocional_screen.dart';
import 'package:keryx_app/features/home/service/devocional_service.dart';
import 'package:keryx_app/core/widgets/main_layout.dart';

/// Provider global para controlar a expansão manual do menu lateral em tablets/desktop.
/// null = automático baseado no tamanho da tela (>= 1150px expandido).
final sidebarExpandedProvider = StateProvider<bool?>((ref) => null);

/// Menu Lateral Estilo Instagram para Tablets e Telas Maiores
class InstagramTabletSidebar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onSelectIndex;
  final bool isRoute;
  final Widget? body;
  final VoidCallback? onProfileTap;

  const InstagramTabletSidebar({
    super.key,
    required this.currentIndex,
    required this.onSelectIndex,
    this.isRoute = false,
    this.body,
    this.onProfileTap,
  });

  void _handleNavigate(BuildContext context, int index) {
    if (isRoute) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainLayout()),
        );
      }
    }
    onSelectIndex(index);
  }

  void _openSpecialScreen(BuildContext context, int targetIndex, {WidgetRef? ref}) {
    if (currentIndex == targetIndex) return;

    if (targetIndex == 11 && ref != null) {
      _openDevocional(context, ref);
      return;
    }

    Widget page;
    switch (targetIndex) {
      case 7:
        page = const StudyPlanWindow();
        break;
      case 8:
        page = const DictionaryScreen();
        break;
      case 9:
        page = const PdfBooksScreen();
        break;
      case 10:
        page = const ChatAssistantScreen();
        break;
      default:
        return;
    }

    if (isRoute) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: Duration.zero,
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    }
  }

  Future<void> _openDevocional(BuildContext context, WidgetRef ref) async {
    if (currentIndex == 11) return;

    final devocionalAsync = ref.read(devocionalDiarioProvider);
    DevocionalData? devocional = devocionalAsync.valueOrNull;

    if (devocional == null) {
      try {
        devocional = await ref.read(devocionalDiarioProvider.future);
      } catch (e) {
        debugPrint('Erro ao buscar devocional na sidebar: $e');
      }
    }

    if (devocional != null && context.mounted) {
      final route = MaterialPageRoute(
        builder: (_) => DevocionalScreen(devocional: devocional!),
      );
      if (isRoute) {
        Navigator.pushReplacement(context, route);
      } else {
        Navigator.push(context, route);
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível carregar o devocional de hoje.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Criar na Comunidade',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF4F46E5), size: 22),
                ),
                title: Text(
                  'Publicação no Feed',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  'Compartilhe uma oração, versículo ou bênção',
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const CreatePostBottomSheet(),
                  );
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: Color(0xFFD97706), size: 22),
                ),
                title: Text(
                  'Novo Story Bíblico',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  'Publique uma meditação com fundo e versículo',
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const CreateStoryBottomSheet(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.read(themeModeProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Alternar Exibição',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                currentTheme == AppThemeMode.dark ? Icons.radio_button_checked : Icons.radio_button_off,
                color: currentTheme == AppThemeMode.dark ? AppTheme.kPrimaryGold : null,
              ),
              title: const Text('Modo Escuro (Padrão)'),
              subtitle: const Text('Design moderno e confortável'),
              onTap: () {
                ref.read(themeModeProvider.notifier).setTheme(AppThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                currentTheme == AppThemeMode.light ? Icons.radio_button_checked : Icons.radio_button_off,
                color: currentTheme == AppThemeMode.light ? AppTheme.kPrimaryGold : null,
              ),
              title: const Text('Modo Claro'),
              subtitle: const Text('Fundo suave e brilhante'),
              onTap: () {
                ref.read(themeModeProvider.notifier).setTheme(AppThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                currentTheme == AppThemeMode.sepia ? Icons.radio_button_checked : Icons.radio_button_off,
                color: currentTheme == AppThemeMode.sepia ? AppTheme.kPrimaryGold : null,
              ),
              title: const Text('Modo Sépia'),
              subtitle: const Text('Pergaminho nobre para leitura'),
              onTap: () {
                ref.read(themeModeProvider.notifier).setTheme(AppThemeMode.sepia);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
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
                    color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFFF5252), size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sair da Conta',
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tem certeza que deseja sair da sua conta?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(authServiceProvider).signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5252),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Sair',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final manualExpanded = ref.watch(sidebarExpandedProvider);
    final isExpanded = manualExpanded ?? (screenWidth >= 1150);
    final sidebarWidth = isExpanded ? 245.0 : 72.0;

    final currentUser = FirebaseAuth.instance.currentUser;
    final userName = ref.watch(
          userDataProvider.select(
            (v) => (v.valueOrNull?['name'] as String?)?.trim(),
          ),
        ) ??
        currentUser?.displayName ??
        'Perfil';
    final userPhoto = ref.watch(
          userDataProvider.select(
            (v) => (v.valueOrNull?['photoUrl'] as String?)?.trim(),
          ),
        ) ??
        currentUser?.photoURL?.trim();
    final userFrameId = ref.watch(
      userDataProvider.select(
        (v) => (v.valueOrNull?['avatarFrame'] as String?) ?? 'gold',
      ),
    );

    final bgColor = isDark ? const Color(0xFF101018) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    final sidebarWidget = SizedBox(
      width: sidebarWidth + 14.0,
      height: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Barra lateral com animação de largura suave
          RepaintBoundary(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: sidebarWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  right: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: ClipRect(
                child: SafeArea(
                  right: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Topo: Logo + Nome do App com transição suave de opacidade
                      Padding(
                        padding: EdgeInsets.fromLTRB(isExpanded ? 16 : 7, 12, isExpanded ? 12 : 7, 8),
                        child: SizedBox(
                          height: 34,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _handleNavigate(context, 0),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: isExpanded
                                  ? Row(
                                      children: [
                                        _buildLogoWidget(),
                                        Expanded(
                                          child: ClipRect(
                                            child: AnimatedOpacity(
                                              duration: const Duration(milliseconds: 160),
                                              curve: Curves.easeInOut,
                                              opacity: 1.0,
                                              child: SingleChildScrollView(
                                                scrollDirection: Axis.horizontal,
                                                physics: const NeverScrollableScrollPhysics(),
                                                child: SizedBox(
                                                  width: 175,
                                                  child: Row(
                                                    children: [
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          'KeryxApp',
                                                          maxLines: 1,
                                                          overflow: TextOverflow.clip,
                                                          softWrap: false,
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 17.5,
                                                            fontWeight: FontWeight.w800,
                                                            color: Theme.of(context).colorScheme.onSurface,
                                                            letterSpacing: -0.3,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Center(child: _buildLogoWidget()),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 2),

                      // 2. Itens de Navegação das Telas (Ultra-compacto e sem barra de rolagem visível)
                      Expanded(
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                          child: ListView(
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            children: [
                              _buildNavItem(
                                context: context,
                                icon: Icons.home_rounded,
                                inactiveIcon: Icons.home_outlined,
                                label: 'Início',
                                isSelected: currentIndex == 0,
                                isExpanded: isExpanded,
                                onTap: () => _handleNavigate(context, 0),
                              ),
                              const SizedBox(height: 2),
                              _buildNavItem(
                                context: context,
                                icon: Icons.menu_book_rounded,
                                inactiveIcon: Icons.menu_book_outlined,
                                label: 'Bíblia',
                                isSelected: currentIndex == 1,
                                isExpanded: isExpanded,
                                onTap: () => _handleNavigate(context, 1),
                              ),
                              const SizedBox(height: 2),
                              _buildNavItem(
                                context: context,
                                icon: Icons.auto_stories_rounded,
                                inactiveIcon: Icons.auto_stories_outlined,
                                label: 'Devocional Diário',
                                isSelected: currentIndex == 11,
                                isExpanded: isExpanded,
                                onTap: () => _openDevocional(context, ref),
                              ),
                              const SizedBox(height: 2),
                              _buildNavItem(
                                context: context,
                                icon: Icons.calendar_month_rounded,
                                inactiveIcon: Icons.calendar_month_outlined,
                                label: 'Plano de Estudo',
                                badgeText: 'Novo',
                                isSelected: currentIndex == 7,
                                isExpanded: isExpanded,
                                onTap: () => _openSpecialScreen(context, 7),
                              ),
                              const SizedBox(height: 2),
                              _buildNavItem(
                                context: context,
                                icon: Icons.comment_bank_rounded,
                                inactiveIcon: Icons.comment_bank_outlined,
                                label: 'Comentários',
                                isSelected: currentIndex == 2,
                                isExpanded: isExpanded,
                                onTap: () => _handleNavigate(context, 2),
                              ),
                              const SizedBox(height: 2),
                              _buildNavItem(
                                context: context,
                                icon: Icons.translate_rounded,
                                inactiveIcon: Icons.translate_outlined,
                                label: 'Dicionário',
                                isSelected: currentIndex == 8,
                                isExpanded: isExpanded,
                                onTap: () => _openSpecialScreen(context, 8),
                              ),
                              const SizedBox(height: 2),
                              _buildNavItem(
                                context: context,
                                icon: Icons.folder_shared_rounded,
                                inactiveIcon: Icons.folder_shared_outlined,
                                label: 'Biblioteca',
                                isSelected: currentIndex == 9,
                                isExpanded: isExpanded,
                                onTap: () => _openSpecialScreen(context, 9),
                              ),
                              const SizedBox(height: 2),
                              _buildNavItem(
                                context: context,
                                icon: Icons.auto_awesome_rounded,
                                inactiveIcon: Icons.auto_awesome_outlined,
                                label: 'IATheos',
                                badgeText: 'IA',
                                isSelected: currentIndex == 10,
                                isExpanded: isExpanded,
                                onTap: () => _openSpecialScreen(context, 10),
                              ),
                              const SizedBox(height: 2),
                              _buildNavItem(
                                context: context,
                                icon: Icons.people_alt_rounded,
                                inactiveIcon: Icons.people_alt_outlined,
                                label: 'Comunidade',
                                isSelected: currentIndex == 6,
                                isExpanded: isExpanded,
                                onTap: () => _handleNavigate(context, 6),
                              ),
                              const SizedBox(height: 2),
                              _buildNavItem(
                                context: context,
                                icon: Icons.edit_note_rounded,
                                inactiveIcon: Icons.edit_note_outlined,
                                label: 'Anotações',
                                isSelected: currentIndex == 3,
                                isExpanded: isExpanded,
                                onTap: () => _handleNavigate(context, 3),
                              ),
                              const SizedBox(height: 2),
                              _buildNavItem(
                                context: context,
                                icon: Icons.bookmark_rounded,
                                inactiveIcon: Icons.bookmark_border_rounded,
                                label: 'Favoritos',
                                isSelected: currentIndex == 4,
                                isExpanded: isExpanded,
                                onTap: () => _handleNavigate(context, 4),
                              ),
                              const SizedBox(height: 2),
                              _buildNavItem(
                                context: context,
                                icon: Icons.shopping_bag_rounded,
                                inactiveIcon: Icons.shopping_bag_outlined,
                                label: 'Loja',
                                isSelected: currentIndex == 5,
                                isExpanded: isExpanded,
                                onTap: () => _handleNavigate(context, 5),
                              ),
                              const SizedBox(height: 2),
                              // Botão Criar (+ Post / Story)
                              _buildNavItem(
                                context: context,
                                icon: Icons.add_box_rounded,
                                inactiveIcon: Icons.add_box_outlined,
                                label: 'Criar',
                                isSelected: false,
                                isExpanded: isExpanded,
                                highlightGold: true,
                                onTap: () => _showCreateOptions(context),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 3. Rodapé do Menu Lateral Compacto (Perfil + Ações Rápidas: Tema, Notificações, Mais)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(7, 3, 7, 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Divider(
                              color: isDark ? Colors.white10 : Colors.black12,
                              height: 1,
                              indent: 4,
                              endIndent: 4,
                            ),
                            const SizedBox(height: 4),

                            // Item de Perfil
                            _buildProfileItem(
                              context: context,
                              ref: ref,
                              isExpanded: isExpanded,
                              userName: userName,
                              userPhoto: userPhoto,
                              userFrameId: userFrameId,
                              isDark: isDark,
                            ),

                            const SizedBox(height: 3),

                            // Barra de Ações Rápidas (Tema, Notificações, Mais)
                            _buildFooterActionBar(
                              context: context,
                              ref: ref,
                              isExpanded: isExpanded,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Botão flutuante na borda lateral direita (pill / tab com chevron)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            top: 22,
            left: sidebarWidth - 12.0,
            child: _buildEdgeToggleButton(context, ref, isExpanded, isDark),
          ),
        ],
      ),
    );

    if (body == null) {
      return sidebarWidget;
    }

    return Stack(
      children: [
        // 1. Área de layout com reserva de espaço para a barra lateral + corpo
        Row(
          children: [
            RepaintBoundary(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: sidebarWidth,
              ),
            ),
            Expanded(
              child: SafeArea(
                top: true,
                bottom: false,
                left: false,
                right: false,
                child: body!,
              ),
            ),
          ],
        ),

        // 2. Barra lateral sobreposta (garante que a aba saliente na borda fique com z-index superior)
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          child: sidebarWidget,
        ),
      ],
    );
  }

  Widget _buildLogoWidget() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(
          'assets/img/logo.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildEdgeToggleButton(
    BuildContext context,
    WidgetRef ref,
    bool isExpanded,
    bool isDark,
  ) {
    final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.14);
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.black.withValues(alpha: 0.75);

    return Tooltip(
      message: isExpanded ? 'Recolher menu lateral' : 'Abrir menu lateral',
      preferBelow: false,
      verticalOffset: 16,
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(sidebarExpandedProvider.notifier).state = !isExpanded;
          },
          borderRadius: BorderRadius.circular(7),
          hoverColor: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          child: Container(
            width: 24,
            height: 26,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.09),
                  blurRadius: 4,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                isExpanded
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                key: ValueKey<bool>(isExpanded),
                size: 16,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem({
    required BuildContext context,
    required WidgetRef ref,
    required bool isExpanded,
    required String userName,
    required String? userPhoto,
    required String userFrameId,
    required bool isDark,
  }) {
    final avatarWidget = SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: CommunityUserAvatar(
          photoUrl: userPhoto,
          name: userName,
          radius: 11.0,
          avatarFrame: userFrameId,
        ),
      ),
    );

    return Tooltip(
      message: 'Meu Perfil ($userName)',
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            if (onProfileTap != null) {
              onProfileTap!();
            } else {
              _handleNavigate(context, 6);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 35,
            padding: EdgeInsets.symmetric(horizontal: isExpanded ? 10 : 0),
            child: isExpanded
                ? Row(
                    children: [
                      avatarWidget,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(child: avatarWidget),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActionBar({
    required BuildContext context,
    required WidgetRef ref,
    required bool isExpanded,
    required bool isDark,
  }) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (!isExpanded) {
      return _buildMoreMenuButton(
        context,
        ref,
        isDark,
        onSurface,
        isExpanded: false,
        unreadCount: unreadCount,
      );
    }

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          // 1. Tema
          Expanded(
            child: Tooltip(
              message: 'Alternar Tema',
              preferBelow: false,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                child: InkWell(
                  onTap: () => _showThemeDialog(context, ref),
                  borderRadius: BorderRadius.circular(7),
                  child: Center(
                    child: Icon(
                      Icons.palette_outlined,
                      size: 17,
                      color: onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 14,
            color: isDark ? Colors.white10 : Colors.black12,
          ),
          // 2. Notificações
          Expanded(
            child: Tooltip(
              message: unreadCount > 0
                  ? 'Notificações ($unreadCount)'
                  : 'Notificações',
              preferBelow: false,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                child: InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      constraints: const BoxConstraints(maxWidth: double.infinity),
                      builder: (_) => const NotificationsBottomSheet(),
                    );
                  },
                  borderRadius: BorderRadius.circular(7),
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          unreadCount > 0
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_none_rounded,
                          size: 17,
                          color: unreadCount > 0 ? AppTheme.kPrimaryGold : onSurface.withValues(alpha: 0.75),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: -1,
                            right: -1,
                            child: Container(
                              width: 5.5,
                              height: 5.5,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 14,
            color: isDark ? Colors.white10 : Colors.black12,
          ),
          // 3. Mais Opções (PopupMenu)
          Expanded(
            child: _buildMoreMenuButton(
              context,
              ref,
              isDark,
              onSurface,
              isExpanded: true,
              unreadCount: unreadCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreMenuButton(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    Color onSurface, {
    required bool isExpanded,
    required int unreadCount,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Mais opções',
      offset: const Offset(10, -220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
      elevation: 12,
      onSelected: (val) {
        if (val == 'settings') {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            constraints: const BoxConstraints(maxWidth: double.infinity),
            builder: (context) => const UnifiedSettingsSheet(),
          );
        } else if (val == 'profile') {
          showEditProfileModal(context, ref);
        } else if (val == 'whats_new') {
          ref.read(releaseNotesServiceProvider).showReleaseNotes(context);
        } else if (val == 'guide') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GuideScreen()),
          );
        } else if (val == 'logout') {
          _handleLogout(context, ref);
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 20),
              SizedBox(width: 12),
              Text('Configurações'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.account_circle_outlined, size: 20),
              SizedBox(width: 12),
              Text('Editar Perfil'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'whats_new',
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 20, color: Color(0xFFFFD56B)),
              SizedBox(width: 12),
              Text('Novidades da Versão'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'guide',
          child: Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 20),
              SizedBox(width: 12),
              Text('Guia do Usuário'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: Color(0xFFFF5252)),
              SizedBox(width: 12),
              Text('Sair da Conta', style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      child: isExpanded
          ? Center(
              child: Icon(
                Icons.more_horiz_rounded,
                size: 19,
                color: onSurface.withValues(alpha: 0.75),
              ),
            )
          : Container(
              height: 35,
              alignment: Alignment.center,
              child: SizedBox(
                width: 22,
                height: 22,
                child: Center(
                  child: Icon(
                    Icons.menu_rounded,
                    size: 20,
                    color: onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData inactiveIcon,
    required String label,
    required bool isSelected,
    required bool isExpanded,
    required VoidCallback onTap,
    String? badgeText,
    bool highlightGold = false,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    const activeColor = AppTheme.kPrimaryGold;

    final itemColor = isSelected
        ? activeColor
        : (highlightGold ? const Color(0xFFD97706) : onSurface.withValues(alpha: 0.8));

    return Tooltip(
      message: label,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 35,
            padding: EdgeInsets.symmetric(horizontal: isExpanded ? 10 : 0),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: isExpanded
                ? Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              isSelected ? icon : inactiveIcon,
                              color: itemColor,
                              size: isSelected ? 20.5 : 19.0,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ClipRect(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeInOut,
                            opacity: 1.0,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: SizedBox(
                                width: 175,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.5,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: itemColor,
                                        ),
                                      ),
                                    ),
                                    if (badgeText != null)
                                      Container(
                                        margin: const EdgeInsets.only(left: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          badgeText,
                                          style: GoogleFonts.outfit(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            isSelected ? icon : inactiveIcon,
                            color: itemColor,
                            size: isSelected ? 20.5 : 19.0,
                          ),
                          if (badgeText != null)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
