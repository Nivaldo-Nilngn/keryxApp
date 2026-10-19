import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/app_update_service.dart';
import '../model/user_access_model.dart';
import '../service/access_control_service.dart';
import '../state/access_control_providers.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEmailDialog() {
    final emailController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: AppTheme.kPrimaryGold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Autorizar Novo E-mail',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cadastre um e-mail previamente. Quando a pessoa realizar o login pela primeira vez, o acesso será liberado automaticamente.',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'ENDEREÇO DE E-MAIL',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      style: GoogleFonts.manrope(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'exemplo@gmail.com',
                        hintStyle: GoogleFonts.manrope(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                        prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppTheme.kPrimaryGold,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe o e-mail.';
                        }
                        if (!AccessControlService.isValidEmail(value)) {
                          return 'Insira um formato de e-mail válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'OBSERVAÇÃO OU NOME (OPCIONAL)',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: noteController,
                      style: GoogleFonts.manrope(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Ex: Membro do grupo de estudos',
                        hintStyle: GoogleFonts.manrope(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                        prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.manrope(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.kPrimaryGold,
                  foregroundColor: const Color(0xFF111223),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSubmitting = true);

                        final email = emailController.text.trim();
                        final note = noteController.text.trim();
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(dialogCtx);

                        try {
                          await ref
                              .read(accessControlServiceProvider)
                              .preAuthorizeEmail(email, note: note);

                          if (mounted) {
                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('E-mail "$email" autorizado com sucesso!'),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (mounted) {
                            final isPerm = e.toString().contains('permission-denied') ||
                                e.toString().contains('insufficient permissions');
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  isPerm
                                      ? 'As regras do Firestore precisam ser publicadas no Firebase Console para autorizar gravações.'
                                      : 'Erro: ${e.toString().replaceAll('Exception: ', '')}',
                                ),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF111223),
                        ),
                      )
                    : Text(
                        'Autorizar E-mail',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmRevokeAccess(UserAccessInfo user) {
    if (user.isAdmin || AccessControlService.isPrimaryAdmin(user.email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O Administrador Principal não pode ser bloqueado.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 24),
            const SizedBox(width: 10),
            Text(
              'Revogar Acesso',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Deseja realmente revogar o acesso de ${user.displayName ?? user.email}? O usuário será imediatamente impedido de acessar os recursos protegidos do aplicativo.',
          style: GoogleFonts.manrope(
            color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.8),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.manrope(
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(accessControlServiceProvider)
                    .blockUser(user.uid, user.email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Acesso de ${user.email} revogado.'),
                      backgroundColor: const Color(0xFF1E293B),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Revogar Acesso',
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveUser(UserAccessInfo user) async {
    try {
      await ref
          .read(accessControlServiceProvider)
          .approveUser(user.uid, user.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Acesso de ${user.displayName ?? user.email} aprovado com sucesso!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aprovar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _unblockUser(UserAccessInfo user) async {
    try {
      await ref
          .read(accessControlServiceProvider)
          .unblockUser(user.uid, user.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Acesso de ${user.displayName ?? user.email} reativado com sucesso!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reativar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usersAsync = ref.watch(allUsersProvider);
    final filteredUsers = ref.watch(filteredUsersProvider);
    final currentFilter = ref.watch(userStatusFilterProvider);
    final preAuthorizedEmailsAsync = ref.watch(preAuthorizedEmailsProvider);

    final authUser = ref.watch(authStateProvider).value;
    final isAdm = AccessControlService.isPrimaryAdmin(authUser?.email);

    final adminFallbackUser = isAdm && authUser != null
        ? UserAccessInfo(
            uid: authUser.uid,
            email: AccessControlService.kPrimaryAdminEmail,
            displayName: authUser.displayName ?? 'Nivaldo (Admin)',
            photoUrl: authUser.photoURL,
            role: UserRole.admin,
            status: AccessStatus.authorized,
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
          )
        : null;

    // Contadores para as tabs de filtros
    final allUsers = (usersAsync.value != null && usersAsync.value!.isNotEmpty)
        ? usersAsync.value!
        : (adminFallbackUser != null ? [adminFallbackUser] : <UserAccessInfo>[]);
    final authorizedCount = allUsers.where((u) => u.isAuthorized).length;
    final pendingCount = allUsers.where((u) => u.isPending).length;
    final blockedCount = allUsers.where((u) => u.isBlocked).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Gerenciamento de Acessos',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.kPrimaryGold,
                foregroundColor: const Color(0xFF111223),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: _showAddEmailDialog,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Novo E-mail',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // ── 1. Meu Usuário Administrador (Card em destaque) ──────────────────
              _buildAdminProfileCard(context),
              const SizedBox(height: 16),

              // ── 1.1 Gerenciador de Versão do App (Cloudflare KV & PWA) ─────────────
              _buildVersionControlCard(context),
              const SizedBox(height: 20),

              // ── 2. Barra de Pesquisa ──────────────────────────────────────────────
              TextField(
                controller: _searchController,
                onChanged: (val) =>
                    ref.read(userSearchQueryProvider.notifier).state = val,
                style: GoogleFonts.manrope(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Pesquisar usuário por e-mail ou nome...',
                  hintStyle: GoogleFonts.manrope(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(userSearchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppTheme.kPrimaryGold,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── 3. Chips de Filtro por Status ────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      context,
                      label: 'Todos',
                      count: allUsers.length,
                      isSelected: currentFilter == null,
                      onTap: () =>
                          ref.read(userStatusFilterProvider.notifier).state = null,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      context,
                      label: 'Pendentes',
                      count: pendingCount,
                      color: const Color(0xFFF59E0B),
                      isSelected: currentFilter == AccessStatus.pending,
                      onTap: () => ref
                          .read(userStatusFilterProvider.notifier)
                          .state = AccessStatus.pending,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      context,
                      label: 'Autorizados',
                      count: authorizedCount,
                      color: const Color(0xFF10B981),
                      isSelected: currentFilter == AccessStatus.authorized,
                      onTap: () => ref
                          .read(userStatusFilterProvider.notifier)
                          .state = AccessStatus.authorized,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      context,
                      label: 'Bloqueados',
                      count: blockedCount,
                      color: const Color(0xFFFF5252),
                      isSelected: currentFilter == AccessStatus.blocked,
                      onTap: () => ref
                          .read(userStatusFilterProvider.notifier)
                          .state = AccessStatus.blocked,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── 4. E-mails Pré-Autorizados Aguardando Primeiro Login ──────────────
              preAuthorizedEmailsAsync.when(
                data: (preEmails) {
                  // Filtra apenas aqueles que ainda não têm conta criada
                  final unredeemed = preEmails.where((pe) {
                    return !allUsers.any((u) =>
                        AccessControlService.normalizeEmail(u.email) ==
                        AccessControlService.normalizeEmail(pe.email));
                  }).toList();

                  if (unredeemed.isEmpty) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.kPrimaryGold.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.forward_to_inbox_rounded,
                                  color: AppTheme.kPrimaryGold, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'E-mails pré-autorizados (${unredeemed.length})',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Usuários autorizados manualmente que ainda não fizeram o primeiro login.',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...unredeemed.map((pe) => _buildPreAuthorizedTile(context, pe)),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // ── 5. Lista de Usuários ─────────────────────────────────────────────
              usersAsync.when(
                data: (users) {
                  if (filteredUsers.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return Column(
                    children: filteredUsers
                        .map((u) => _buildUserCard(context, u))
                        .toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.kPrimaryGold),
                  ),
                ),
                error: (e, st) {
                  final isPermissionDenied = e.toString().contains('permission-denied') ||
                      e.toString().contains('insufficient permissions');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isPermissionDenied)
                        _buildFirestoreRulesPendingCard(context)
                      else
                        Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Colors.redAccent, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                'Erro ao carregar lista de usuários:\n$e',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  ref.invalidate(allUsersProvider);
                                  ref.invalidate(preAuthorizedEmailsProvider);
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Tentar Novamente'),
                              ),
                            ],
                          ),
                        ),
                      // Lista de usuários (com fallback do administrador)
                      if (filteredUsers.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, left: 4),
                          child: Text(
                            'USUÁRIOS (${filteredUsers.length})',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        ...filteredUsers.map((u) => _buildUserCard(context, u)),
                      ] else
                        _buildEmptyState(context),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.kPrimaryGold.withValues(alpha: 0.15),
            theme.colorScheme.surfaceContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.kPrimaryGold.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.kPrimaryGold,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.kPrimaryGold.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFF111223),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Minha Conta',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.kPrimaryGold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ADMIN PRINCIPAL',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF111223),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AccessControlService.kPrimaryAdminEmail,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0x22F2CA50)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.verified_user_rounded,
                  size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Acesso total e permanente ao sistema de gerenciamento. Autorização automática.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVersionControlCard(BuildContext context) {
    final theme = Theme.of(context);
    final latestUpdateAsync = ref.watch(latestUpdateInfoProvider);
    final currentVersionAsync = ref.watch(currentAppVersionProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.kPrimaryGold.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
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
                        Text(
                          'Controle de Versão',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'CLOUDFLARE KV',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gerencie a versão distribuída para Android e iPhone',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 14),
          latestUpdateAsync.when(
            data: (info) {
              final latestBuild = info?.latestVersion ?? 1;
              final latestName = info?.versionName ?? '1.0.0';
              final notes = info?.releaseNotes.isNotEmpty == true
                  ? info!.releaseNotes
                  : 'Nenhuma nota informada.';
              final iosUrl = info?.iosUrl.isNotEmpty == true
                  ? info!.iosUrl
                  : 'https://keryxapp.pages.dev';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildVersionStatItem(
                          context,
                          title: 'VERSÃO NO CLOUDFLARE',
                          value: 'v$latestName (Build $latestBuild)',
                          icon: Icons.cloud_done_rounded,
                          color: AppTheme.kPrimaryGold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildVersionStatItem(
                          context,
                          title: 'MEU APP INSTALADO',
                          value: currentVersionAsync.when(
                            data: (v) => 'v${v.versionName} (${v.buildNumber})',
                            loading: () => '...',
                            error: (_, __) => '1.0.0',
                          ),
                          icon: Icons.phone_android_rounded,
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NOTAS DA VERSÃO:',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notes,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.apple_rounded, size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              'PWA iOS: ',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                iosUrl,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: AppTheme.kPrimaryGold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.kPrimaryGold,
                        foregroundColor: const Color(0xFF111223),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _showEditVersionDialog(context, info),
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: Text(
                        'Alterar Versão do Aplicativo',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppTheme.kPrimaryGold),
              ),
            ),
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Não foi possível consultar a versão no Cloudflare ($e).',
                  style: GoogleFonts.manrope(color: Colors.redAccent, fontSize: 12),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(latestUpdateInfoProvider),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Recarregar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionStatItem(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditVersionDialog(BuildContext context, AppUpdateInfo? currentInfo) {
    final formKey = GlobalKey<FormState>();
    final buildController = TextEditingController(
      text: ((currentInfo?.latestVersion ?? 1) + 1).toString(),
    );
    final versionNameController = TextEditingController(
      text: currentInfo?.versionName ?? '1.0.1',
    );
    final apkUrlController = TextEditingController(
      text: currentInfo?.downloadUrl.isNotEmpty == true
          ? currentInfo!.downloadUrl
          : 'https://github.com/Nivaldo-Nilngn/keryxApp/releases/latest/download/keryxApp.apk',
    );
    final iosUrlController = TextEditingController(
      text: currentInfo?.iosUrl.isNotEmpty == true
          ? currentInfo!.iosUrl
          : 'https://keryxapp.pages.dev',
    );
    final notesController = TextEditingController(
      text: currentInfo?.releaseNotes ?? '',
    );
    bool forceUpdate = currentInfo?.forceUpdate ?? false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: AppTheme.kPrimaryGold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Lançar Nova Versão',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Altere o número de versão para que os celulares dos membros recebam o alerta de atualização imediatamente.',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nº DE BUILD (INCREMENTAL)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: buildController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.manrope(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Ex: 2',
                                    filled: true,
                                    fillColor: theme.scaffoldBackgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Informe o build';
                                    if (int.tryParse(v.trim()) == null) return 'Apenas números';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NOME DA VERSÃO',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: versionNameController,
                                  style: GoogleFonts.manrope(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Ex: 1.0.1',
                                    filled: true,
                                    fillColor: theme.scaffoldBackgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Informe o nome'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'URL DE DOWNLOAD DO APK (ANDROID)',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: apkUrlController,
                        style: GoogleFonts.manrope(fontSize: 12, color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'https://github.com/.../keryxApp.apk',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'URL DO PWA (IPHONE / WEB)',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: iosUrlController,
                        style: GoogleFonts.manrope(fontSize: 12, color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'https://keryxapp.pages.dev',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'NOTAS DA VERSÃO / O QUE MUDOU',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: notesController,
                        maxLines: 3,
                        style: GoogleFonts.manrope(fontSize: 13, color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Descreva as novidades desta versão...',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Forçar Atualização?',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Exige que os usuários atualizem para continuar usando o app.',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        activeColor: AppTheme.kPrimaryGold,
                        value: forceUpdate,
                        onChanged: (val) => setDialogState(() => forceUpdate = val),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.manrope(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.kPrimaryGold,
                  foregroundColor: const Color(0xFF111223),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);

                        final newInfo = AppUpdateInfo(
                          latestVersion: int.parse(buildController.text.trim()),
                          versionName: versionNameController.text.trim(),
                          downloadUrl: apkUrlController.text.trim(),
                          iosUrl: iosUrlController.text.trim(),
                          releaseNotes: notesController.text.trim(),
                          forceUpdate: forceUpdate,
                          minVersion: forceUpdate
                              ? int.parse(buildController.text.trim())
                              : (currentInfo?.minVersion ?? 1),
                          releaseDate: DateTime.now().toIso8601String().split('T')[0],
                        );

                        final success = await ref
                            .read(appUpdateServiceProvider)
                            .publishNewVersion(newInfo);

                        ref.invalidate(latestUpdateInfoProvider);
                        ref.invalidate(isUpdateAvailableProvider);

                        if (context.mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Versão v${newInfo.versionName} divulgada com sucesso no Cloudflare!'
                                    : 'A versão foi salva no Firestore (verifique a conexão com o Cloudflare).',
                              ),
                              backgroundColor: success
                                  ? const Color(0xFF10B981)
                                  : Colors.orangeAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF111223),
                        ),
                      )
                    : Text(
                        'Salvar e Divulgar',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required int count,
    Color? color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final chipColor = color ?? AppTheme.kPrimaryGold;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.2)
              : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? chipColor
                : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? chipColor : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? chipColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (color != null ? Colors.white : const Color(0xFF111223))
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, UserAccessInfo user) {
    final theme = Theme.of(context);
    final isPrimary = AccessControlService.isPrimaryAdmin(user.email);

    Color statusColor;
    IconData statusIcon;
    switch (user.status) {
      case AccessStatus.authorized:
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case AccessStatus.pending:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case AccessStatus.blocked:
        statusColor = const Color(0xFFFF5252);
        statusIcon = Icons.block_rounded;
        break;
    }

    final String initial = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName![0].toUpperCase()
        : (user.email.isNotEmpty ? user.email[0].toUpperCase() : 'U');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: user.isPending
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: user.isPending ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.15),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Informações do Usuário
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName ?? 'Usuário',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPrimary) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, size: 16, color: AppTheme.kPrimaryGold),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      user.status.labelPt.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Metadados de Data
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (user.requestedAt != null || user.createdAt != null)
                _buildDateMeta(
                  theme,
                  label: user.isPending ? 'Solicitado em' : 'Primeiro acesso',
                  date: user.requestedAt ?? user.createdAt!,
                ),
              if (user.lastLogin != null)
                _buildDateMeta(
                  theme,
                  label: 'Última atividade',
                  date: user.lastLogin!,
                ),
              if (user.approvedAt != null)
                _buildDateMeta(
                  theme,
                  label: 'Aprovado em',
                  date: user.approvedAt!,
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Botões de Ação
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isPrimary)
                Text(
                  'Administrador Principal Protegido',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.kPrimaryGold,
                  ),
                )
              else ...[
                if (user.isPending) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF5252),
                      side: BorderSide(
                        color: const Color(0xFFFF5252).withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _confirmRevokeAccess(user),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text(
                      'Rejeitar',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _approveUser(user),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      'Aprovar Acesso',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else if (user.isAuthorized) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF5252),
                      side: BorderSide(
                        color: const Color(0xFFFF5252).withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _confirmRevokeAccess(user),
                    icon: const Icon(Icons.block_rounded, size: 16),
                    label: Text(
                      'Revogar Acesso',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else if (user.isBlocked) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.kPrimaryGold,
                      foregroundColor: const Color(0xFF111223),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _unblockUser(user),
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: Text(
                      'Reativar Usuário',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateMeta(ThemeData theme, {required String label, required DateTime date}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.calendar_today_rounded,
          size: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ${_dateFormat.format(date)}',
          style: GoogleFonts.manrope(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildPreAuthorizedTile(BuildContext context, PreAuthorizedEmail preAuth) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.mark_email_read_rounded,
              color: Color(0xFF10B981), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preAuth.email,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (preAuth.note != null && preAuth.note!.isNotEmpty)
                  Text(
                    preAuth.note!,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFFF5252), size: 18),
            tooltip: 'Remover pré-autorização',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(accessControlServiceProvider)
                    .removePreAuthorization(preAuth.email);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Pré-autorização de ${preAuth.email} removida.'),
                      backgroundColor: const Color(0xFF1E293B),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Erro: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 56,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum usuário encontrado',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tente ajustar o termo de pesquisa ou o filtro selecionado.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirestoreRulesPendingCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFF59E0B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Regras do Firestore Aguardando Ativação',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFDE68A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Seu acesso de Admin Principal está 100% ativo.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Para que o Firestore libere a listagem e controle em tempo real dos demais usuários nesta tela, publique as regras no Console do Firebase (projeto bibliapeniel-nilngn).',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.kPrimaryGold,
                  foregroundColor: const Color(0xFF111223),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
                onPressed: () {
                  Clipboard.setData(
                    const ClipboardData(
                      text: AccessControlService.kRecommendedFirestoreRules,
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Regras copiadas! Cole na aba "Regras" do Firestore no Firebase Console.',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppTheme.kPrimaryGold,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 4),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 17),
                label: Text(
                  'Copiar firestore.rules',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFDE68A),
                  side: BorderSide(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
                onPressed: () async {
                  final uri = Uri.parse(AccessControlService.kFirebaseConsoleRulesUrl);
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link: https://console.firebase.google.com/project/bibliapeniel-nilngn/firestore/rules'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: Text(
                  'Abrir Firebase Console',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.9),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
                onPressed: () => _showPublishRulesGuideDialog(context),
                icon: const Icon(Icons.help_outline_rounded, size: 17),
                label: Text(
                  'Passo a Passo',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFDE68A),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                ),
                onPressed: () {
                  ref.invalidate(allUsersProvider);
                  ref.invalidate(preAuthorizedEmailsProvider);
                },
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(
                  'Tentar Novamente',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPublishRulesGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppTheme.kPrimaryGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Como Publicar as Regras',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGuideStep(
                  '1',
                  'Copie as regras',
                  'Clique no botão "Copiar firestore.rules" nesta tela.',
                ),
                const SizedBox(height: 12),
                _buildGuideStep(
                  '2',
                  'Acesse o Firebase Console',
                  'Abra console.firebase.google.com no projeto bibliapeniel-nilngn e vá em "Firestore Database" > aba "Regras" (Rules).',
                ),
                const SizedBox(height: 12),
                _buildGuideStep(
                  '3',
                  'Cole e Clique em Publicar',
                  'Selecione todo o texto existente, cole o conteúdo copiado e clique no botão azul "Publicar" (Publish).',
                ),
                const SizedBox(height: 12),
                _buildGuideStep(
                  '4',
                  'Pronto!',
                  'Retorne ao aplicativo e clique em "Tentar Novamente". A lista completa de usuários será sincronizada instantaneamente.',
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.kPrimaryGold,
                foregroundColor: const Color(0xFF111223),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Entendi',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideStep(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppTheme.kPrimaryGold,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: const Color(0xFF111223),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
