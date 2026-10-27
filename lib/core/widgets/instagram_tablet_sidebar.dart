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

/// Menu Lateral Estilo Instagram para Tablets e Telas Maiores
class InstagramTabletSidebar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onSelectIndex;
  final bool isRoute;

  const InstagramTabletSidebar({
    super.key,
    required this.currentIndex,
    required this.onSelectIndex,
    this.isRoute = false,
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
    final isCompact = screenWidth < 1050; // Recolhe em tablets médios, expande em desktop
    final sidebarWidth = isCompact ? 76.0 : 220.0;

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

    return Container(
      width: sidebarWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            // 1. Logo no Topo
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 14 : 20,
                vertical: 20,
              ),
              child: isCompact
                  ? GestureDetector(
                      onTap: () => _handleNavigate(context, 0),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD97706).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.auto_stories_rounded, color: Colors.black, size: 22),
                      ),
                    )
                  : GestureDetector(
                      onTap: () => _handleNavigate(context, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.auto_stories_rounded, color: Colors.black, size: 19),
                          ),
                          const SizedBox(width: 11),
                          Text(
                            'KeryxApp',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 19.5,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            const SizedBox(height: 10),

            // 2. Itens de Navegação das Outras Telas
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12),
                children: [
                  _buildNavItem(
                    context: context,
                    icon: Icons.home_rounded,
                    inactiveIcon: Icons.home_outlined,
                    label: 'Página inicial',
                    isSelected: currentIndex == 0,
                    isCompact: isCompact,
                    onTap: () => _handleNavigate(context, 0),
                  ),
                  const SizedBox(height: 6),
                  _buildNavItem(
                    context: context,
                    icon: Icons.menu_book_rounded,
                    inactiveIcon: Icons.menu_book_outlined,
                    label: 'Bíblia',
                    isSelected: currentIndex == 1,
                    isCompact: isCompact,
                    onTap: () => _handleNavigate(context, 1),
                  ),
                  const SizedBox(height: 6),
                  _buildNavItem(
                    context: context,
                    icon: Icons.people_alt_rounded,
                    inactiveIcon: Icons.people_alt_outlined,
                    label: 'Comunidade',
                    badgeText: 'Novo',
                    isSelected: currentIndex == 6,
                    isCompact: isCompact,
                    onTap: () => _handleNavigate(context, 6),
                  ),
                  const SizedBox(height: 6),
                  _buildNavItem(
                    context: context,
                    icon: Icons.auto_stories_rounded,
                    inactiveIcon: Icons.auto_stories_outlined,
                    label: 'Estudos',
                    isSelected: currentIndex == 2,
                    isCompact: isCompact,
                    onTap: () => _handleNavigate(context, 2),
                  ),
                  const SizedBox(height: 6),
                  _buildNavItem(
                    context: context,
                    icon: Icons.edit_note_rounded,
                    inactiveIcon: Icons.edit_note_outlined,
                    label: 'Anotações',
                    isSelected: currentIndex == 3,
                    isCompact: isCompact,
                    onTap: () => _handleNavigate(context, 3),
                  ),
                  const SizedBox(height: 6),
                  _buildNavItem(
                    context: context,
                    icon: Icons.bookmark_rounded,
                    inactiveIcon: Icons.bookmark_border_rounded,
                    label: 'Favoritos',
                    isSelected: currentIndex == 4,
                    isCompact: isCompact,
                    onTap: () => _handleNavigate(context, 4),
                  ),
                  const SizedBox(height: 6),
                  _buildNavItem(
                    context: context,
                    icon: Icons.shopping_bag_rounded,
                    inactiveIcon: Icons.shopping_bag_outlined,
                    label: 'Loja',
                    isSelected: currentIndex == 5,
                    isCompact: isCompact,
                    onTap: () => _handleNavigate(context, 5),
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    color: isDark ? Colors.white10 : Colors.black12,
                    height: 1,
                    indent: isCompact ? 8 : 4,
                    endIndent: isCompact ? 8 : 4,
                  ),
                  const SizedBox(height: 14),

                  // Botão Criar (+ Post / Story)
                  _buildNavItem(
                    context: context,
                    icon: Icons.add_box_rounded,
                    inactiveIcon: Icons.add_box_outlined,
                    label: 'Criar',
                    isSelected: false,
                    isCompact: isCompact,
                    highlightGold: true,
                    onTap: () => _showCreateOptions(context),
                  ),
                ],
              ),
            ),

            // 3. Rodapé do Menu Lateral (Perfil + Mais)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: 12),
              child: Column(
                children: [
                  // Item de Perfil
                  Tooltip(
                    message: 'Meu Perfil ($userName)',
                    child: InkWell(
                      onTap: () => showEditProfileModal(context, ref),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 8 : 12,
                          vertical: 9,
                        ),
                        child: Row(
                          mainAxisAlignment: isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
                          children: [
                            CommunityUserAvatar(
                              photoUrl: userPhoto,
                              name: userName,
                              radius: 14,
                              avatarFrame: userFrameId,
                            ),
                            if (!isCompact) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Item Mais (Menu Hambúrguer estilo Instagram)
                  PopupMenuButton<String>(
                    tooltip: 'Mais opções',
                    offset: const Offset(10, -120),
                    onSelected: (val) {
                      if (val == 'theme') {
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
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 8 : 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.menu_rounded,
                            size: 24,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                          if (!isCompact) ...[
                            const SizedBox(width: 12),
                            Text(
                              'Mais',
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData inactiveIcon,
    required String label,
    required bool isSelected,
    required bool isCompact,
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 12,
              vertical: 9.5,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? icon : inactiveIcon,
                      color: itemColor,
                      size: isSelected ? 24 : 22,
                    ),
                    if (badgeText != null && isCompact)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                if (!isCompact) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: itemColor,
                      ),
                    ),
                  ),
                  if (badgeText != null)
                    Container(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
