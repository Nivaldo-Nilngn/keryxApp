import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/edit_profile_modal.dart';
import 'package:keryx_app/features/community/view/widgets/community_user_avatar.dart';
import 'package:keryx_app/features/community/view/widgets/create_post_bottom_sheet.dart';
import 'package:keryx_app/features/community/view/widgets/create_story_bottom_sheet.dart';
import 'package:keryx_app/features/home/view/notifications_bottom_sheet.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
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
    if (isRoute && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    onSelectIndex(index);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final manualExpanded = ref.watch(sidebarExpandedProvider);
    final isExpanded = manualExpanded ?? (screenWidth >= 1150);
    final sidebarWidth = isExpanded ? 230.0 : 76.0;

    final currentUser = FirebaseAuth.instance.currentUser;
    final userData = ref.watch(userDataProvider).valueOrNull;
    final userPhoto = (userData?['photoUrl'] as String?)?.trim() ??
        currentUser?.photoURL?.trim();
    final userName = (userData?['name'] as String?)?.trim() ??
        currentUser?.displayName ??
        'Perfil';
    final userFrameId = (userData?['avatarFrame'] as String?) ?? 'gold';

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
                        padding: const EdgeInsets.fromLTRB(19, 16, 14, 16),
                        child: SizedBox(
                          height: 38,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _handleNavigate(context, 0),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.asset(
                                      'assets/img/logo.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ClipRect(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 160),
                                    curve: Curves.easeInOut,
                                    opacity: isExpanded ? 1.0 : 0.0,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics: const NeverScrollableScrollPhysics(),
                                      child: SizedBox(
                                        width: 150,
                                        child: Row(
                                          children: [
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'KeryxApp',
                                                maxLines: 1,
                                                overflow: TextOverflow.clip,
                                                softWrap: false,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 18.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  letterSpacing: -0.4,
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
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // 2. Itens de Navegação das Telas
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          children: [
                            _buildNavItem(
                              context: context,
                              icon: Icons.home_rounded,
                              inactiveIcon: Icons.home_outlined,
                              label: 'Página inicial',
                              isSelected: currentIndex == 0,
                              isExpanded: isExpanded,
                              onTap: () => _handleNavigate(context, 0),
                            ),
                            const SizedBox(height: 4),
                            _buildNavItem(
                              context: context,
                              icon: Icons.menu_book_rounded,
                              inactiveIcon: Icons.menu_book_outlined,
                              label: 'Bíblia',
                              isSelected: currentIndex == 1,
                              isExpanded: isExpanded,
                              onTap: () => _handleNavigate(context, 1),
                            ),
                            const SizedBox(height: 4),
                            _buildNavItem(
                              context: context,
                              icon: Icons.people_alt_rounded,
                              inactiveIcon: Icons.people_alt_outlined,
                              label: 'Comunidade',
                              badgeText: 'Novo',
                              isSelected: currentIndex == 6,
                              isExpanded: isExpanded,
                              onTap: () => _handleNavigate(context, 6),
                            ),
                            const SizedBox(height: 4),
                            _buildNavItem(
                              context: context,
                              icon: Icons.auto_stories_rounded,
                              inactiveIcon: Icons.auto_stories_outlined,
                              label: 'Estudos',
                              isSelected: currentIndex == 2,
                              isExpanded: isExpanded,
                              onTap: () => _handleNavigate(context, 2),
                            ),
                            const SizedBox(height: 4),
                            _buildNavItem(
                              context: context,
                              icon: Icons.edit_note_rounded,
                              inactiveIcon: Icons.edit_note_outlined,
                              label: 'Anotações',
                              isSelected: currentIndex == 3,
                              isExpanded: isExpanded,
                              onTap: () => _handleNavigate(context, 3),
                            ),
                            const SizedBox(height: 4),
                            _buildNavItem(
                              context: context,
                              icon: Icons.bookmark_rounded,
                              inactiveIcon: Icons.bookmark_border_rounded,
                              label: 'Favoritos',
                              isSelected: currentIndex == 4,
                              isExpanded: isExpanded,
                              onTap: () => _handleNavigate(context, 4),
                            ),
                            const SizedBox(height: 4),
                            _buildNavItem(
                              context: context,
                              icon: Icons.shopping_bag_rounded,
                              inactiveIcon: Icons.shopping_bag_outlined,
                              label: 'Loja',
                              isSelected: currentIndex == 5,
                              isExpanded: isExpanded,
                              onTap: () => _handleNavigate(context, 5),
                            ),
                            const SizedBox(height: 12),
                            Divider(
                              color: isDark ? Colors.white10 : Colors.black12,
                              height: 1,
                              indent: 4,
                              endIndent: 4,
                            ),
                            const SizedBox(height: 12),

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

                      // 3. Rodapé do Menu Lateral (Tema + Perfil + Mais)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        child: Column(
                          children: [
                            // Botão Direto de Tema (Alternar Exibição / Tema)
                            Tooltip(
                              message: 'Alternar Exibição / Tema',
                              child: InkWell(
                                onTap: () => _showThemeDialog(context, ref),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Icon(
                                          Icons.palette_outlined,
                                          size: 24,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                        ),
                                      ),
                                      Expanded(
                                        child: ClipRect(
                                          child: AnimatedOpacity(
                                            duration: const Duration(milliseconds: 160),
                                            curve: Curves.easeInOut,
                                            opacity: isExpanded ? 1.0 : 0.0,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              physics: const NeverScrollableScrollPhysics(),
                                              child: SizedBox(
                                                width: 150,
                                                child: Row(
                                                  children: [
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      'Tema',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.clip,
                                                      softWrap: false,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 14.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: Theme.of(context).colorScheme.onSurface,
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
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Item de Perfil
                            Tooltip(
                              message: 'Meu Perfil ($userName)',
                              child: InkWell(
                                onTap: () {
                                  if (onProfileTap != null) {
                                    onProfileTap!();
                                  } else {
                                    _handleNavigate(context, 6);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Center(
                                          child: CommunityUserAvatar(
                                            photoUrl: userPhoto,
                                            name: userName,
                                            radius: 12,
                                            avatarFrame: userFrameId,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: ClipRect(
                                          child: AnimatedOpacity(
                                            duration: const Duration(milliseconds: 160),
                                            curve: Curves.easeInOut,
                                            opacity: isExpanded ? 1.0 : 0.0,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              physics: const NeverScrollableScrollPhysics(),
                                              child: SizedBox(
                                                width: 150,
                                                child: Row(
                                                  children: [
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        userName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        softWrap: false,
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600,
                                                          color: Theme.of(context).colorScheme.onSurface,
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
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 4),

                            PopupMenuButton<String>(
                              tooltip: 'Mais opções',
                              offset: const Offset(10, -120),
                              onSelected: (val) {
                                if (val == 'toggle_sidebar') {
                                  final current = ref.read(sidebarExpandedProvider) ?? (screenWidth >= 1150);
                                  ref.read(sidebarExpandedProvider.notifier).state = !current;
                                } else if (val == 'theme') {
                                  _showThemeDialog(context, ref);
                                } else if (val == 'notifications') {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => const NotificationsBottomSheet(),
                                  );
                                } else if (val == 'profile') {
                                  showEditProfileModal(context, ref);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'toggle_sidebar',
                                  child: Row(
                                    children: [
                                      Icon(
                                        isExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
                                        size: 20,
                                        color: AppTheme.kPrimaryGold,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        isExpanded ? 'Recolher menu lateral' : 'Abrir menu lateral',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'theme',
                                  child: Row(
                                    children: [
                                      Icon(Icons.palette_outlined, size: 20),
                                      SizedBox(width: 12),
                                      Text('Alternar Exibição / Tema'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'notifications',
                                  child: Row(
                                    children: [
                                      Icon(Icons.notifications_none_rounded, size: 20),
                                      SizedBox(width: 12),
                                      Text('Notificações'),
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
                              ],
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Icon(
                                        Icons.menu_rounded,
                                        size: 24,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    Expanded(
                                      child: ClipRect(
                                        child: AnimatedOpacity(
                                          duration: const Duration(milliseconds: 160),
                                          curve: Curves.easeInOut,
                                          opacity: isExpanded ? 1.0 : 0.0,
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            physics: const NeverScrollableScrollPhysics(),
                                            child: SizedBox(
                                              width: 150,
                                              child: Row(
                                                children: [
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Mais',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.clip,
                                                    softWrap: false,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 14.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: Theme.of(context).colorScheme.onSurface,
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
                                ),
                              ),
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
            Expanded(child: body!),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        isSelected ? icon : inactiveIcon,
                        color: itemColor,
                        size: isSelected ? 24 : 22,
                      ),
                      if (badgeText != null && !isExpanded)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeInOut,
                      opacity: isExpanded ? 1.0 : 0.0,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          width: 148,
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: itemColor,
                                  ),
                                ),
                              ),
                              if (badgeText != null)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
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
            ),
          ),
        ),
      ),
    );
  }
}
