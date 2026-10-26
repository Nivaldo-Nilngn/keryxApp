import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/widgets/release_notes_dialog.dart';
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

  // Controllers para a Janela / Aba Completa de Versão do Aplicativo
  final TextEditingController _versionNameController = TextEditingController();
  final TextEditingController _versionBuildController = TextEditingController();
  final TextEditingController _versionNotesController = TextEditingController();
  final TextEditingController _versionApkUrlController = TextEditingController();
  final TextEditingController _versionIosUrlController = TextEditingController();
  bool _versionForceUpdate = false;
  bool _isSavingVersion = false;
  bool _versionInitialized = false;
  final GlobalKey<FormState> _versionFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _searchController.dispose();
    _versionNameController.dispose();
    _versionBuildController.dispose();
    _versionNotesController.dispose();
    _versionApkUrlController.dispose();
    _versionIosUrlController.dispose();
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

  void _confirmCancelUpdate(UserAccessInfo user) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accessControlServiceProvider).cancelUserUpdateRequest(
            targetUid: user.uid,
            targetEmail: user.email,
          );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Exigência de atualização cancelada para ${user.email}.'),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
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
  }

  void _showNotifyUpdateDialog(UserAccessInfo user, AppUpdateInfo? latestInfo) {
    final targetVersion = latestInfo?.versionName ?? '1.0.1';
    final targetBuild = latestInfo?.latestVersion ?? 2;
    final messageController = TextEditingController(
      text:
          'Olá ${user.displayName ?? 'irmão(ã)'}, o Administrador solicitou que você atualize o KeryxApp para a versão v$targetVersion. Novas melhorias e correções foram publicadas. Por favor, atualize seu aplicativo para manter o acesso liberado ao sistema.',
    );
    bool isSending = false;

    showDialog(
      context: context,
      barrierDismissible: !isSending,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_security_update_warning_rounded,
                    color: Color(0xFFF59E0B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Exigir Atualização',
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'O usuário receberá um aviso obrigatório ao abrir o KeryxApp exigindo a atualização para v$targetVersion (Build $targetBuild) para continuar utilizando o aplicativo.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Versão em uso:',
                          style: GoogleFonts.manrope(fontSize: 12, color: Colors.white60),
                        ),
                        Text(
                          user.versionDisplay,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: user.isOutdated(targetBuild)
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'MENSAGEM DE AVISO AO USUÁRIO',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: messageController,
                    maxLines: 4,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSending ? null : () => Navigator.pop(ctx),
                child: Text('Cancelar', style: GoogleFonts.manrope(color: Colors.white60)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF111223),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isSending
                    ? null
                    : () async {
                        setDialogState(() => isSending = true);
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);

                        try {
                          await ref.read(accessControlServiceProvider).requestUserUpdate(
                                targetUid: user.uid,
                                targetEmail: user.email,
                                targetVersion: targetVersion,
                                targetBuild: targetBuild,
                                customMessage: messageController.text.trim(),
                              );

                          nav.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Exigência de atualização para v$targetVersion enviada para ${user.email}!',
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isSending = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Erro: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                icon: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111223)),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  isSending ? 'Enviando...' : 'Exigir Atualização',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _initVersionControllers(AppUpdateInfo? currentInfo) {
    if (_versionInitialized) return;
    final nextBuild = (currentInfo?.latestVersion ?? 1) + 1;
    _versionBuildController.text = nextBuild.toString();
    _versionNameController.text = currentInfo?.versionName ?? '1.0.1';
    _versionNotesController.text = currentInfo?.releaseNotes ?? '';
    _versionApkUrlController.text = currentInfo?.downloadUrl.isNotEmpty == true
        ? currentInfo!.downloadUrl
        : 'https://keryx-version.nivaldo-nilngn.workers.dev/download';
    _versionIosUrlController.text = currentInfo?.iosUrl.isNotEmpty == true
        ? currentInfo!.iosUrl
        : 'https://keryxapp.pages.dev';
    _versionForceUpdate = currentInfo?.forceUpdate ?? false;
    _versionInitialized = true;
  }

  Future<void> _publishVersionFromTab(AppUpdateInfo? currentInfo) async {
    if (!_versionFormKey.currentState!.validate()) return;
    setState(() => _isSavingVersion = true);

    try {
      final buildNum = int.tryParse(_versionBuildController.text.trim()) ??
          ((currentInfo?.latestVersion ?? 1) + 1);

      final newInfo = AppUpdateInfo(
        latestVersion: buildNum,
        versionName: _versionNameController.text.trim(),
        downloadUrl: _versionApkUrlController.text.trim(),
        iosUrl: _versionIosUrlController.text.trim(),
        releaseNotes: _versionNotesController.text.trim(),
        forceUpdate: _versionForceUpdate,
        minVersion: _versionForceUpdate
            ? buildNum
            : (currentInfo?.minVersion ?? 1),
        releaseDate: DateTime.now().toIso8601String().split('T')[0],
      );

      // Grava no Firestore protegido pelas Security Rules (isPrimaryAdmin)
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .set({
        ...newInfo.toJson(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ref.invalidate(latestUpdateInfoProvider);
      ref.invalidate(isUpdateAvailableProvider);

      if (mounted) {
        setState(() => _isSavingVersion = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.black, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Configuração da versão v${newInfo.versionName} (Build ${newInfo.latestVersion}) salva no Firestore! Para publicar o APK, execute ./scripts/publish_release.sh.',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingVersion = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao publicar versão: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
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

    final allUsers = (usersAsync.value != null && usersAsync.value!.isNotEmpty)
        ? usersAsync.value!
        : (adminFallbackUser != null ? [adminFallbackUser] : <UserAccessInfo>[]);
    final authorizedCount = allUsers.where((u) => u.isAuthorized).length;
    final pendingCount = allUsers.where((u) => u.isPending).length;
    final blockedCount = allUsers.where((u) => u.isBlocked).length;
    final latestUpdateInfo = ref.watch(latestUpdateInfoProvider).valueOrNull;
    final latestBuild = latestUpdateInfo?.latestVersion ?? 1;
    final outdatedCount = allUsers.where((u) => u.isOutdated(latestBuild)).length;
    final onlyOutdated = ref.watch(userOutdatedOnlyFilterProvider);
    final currentVersionAsync = ref.watch(currentAppVersionProvider);

    final unredeemedPreAuth = preAuthorizedEmailsAsync.valueOrNull?.where((pe) {
      return !allUsers.any((u) =>
          AccessControlService.normalizeEmail(u.email) ==
          AccessControlService.normalizeEmail(pe.email));
    }).toList() ?? <PreAuthorizedEmail>[];

    // Inicializa os controllers da aba de versão na primeira carga
    if (latestUpdateInfo != null && !_versionInitialized) {
      _initVersionControllers(latestUpdateInfo);
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          title: Text(
            'Central de Acessos & Versão',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: theme.colorScheme.onSurface,
            ),
          ),
          bottom: TabBar(
            indicatorColor: AppTheme.kPrimaryGold,
            indicatorWeight: 3,
            labelColor: AppTheme.kPrimaryGold,
            unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            labelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            unselectedLabelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            tabs: [
              Tab(
                icon: const Icon(Icons.people_alt_rounded, size: 19),
                text: 'Usuários (${allUsers.length})',
              ),
              const Tab(
                icon: Icon(Icons.rocket_launch_rounded, size: 19),
                text: 'Versão do App',
              ),
              Tab(
                icon: const Icon(Icons.mark_email_read_rounded, size: 19),
                text: 'Pré-Autorizados (${unredeemedPreAuth.length})',
              ),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: TabBarView(
              children: [
                // ── ABA 1: USUÁRIOS ──────────────────────────────────────────
                _buildUsersTab(
                  context,
                  allUsers: allUsers,
                  filteredUsers: filteredUsers,
                  currentFilter: currentFilter,
                  onlyOutdated: onlyOutdated,
                  outdatedCount: outdatedCount,
                  pendingCount: pendingCount,
                  authorizedCount: authorizedCount,
                  blockedCount: blockedCount,
                  usersAsync: usersAsync,
                ),

                // ── ABA 2: VERSÃO DO APP (JANELA COMPLETA E FÁCIL) ────────────
                _buildVersionTab(
                  context,
                  latestInfo: latestUpdateInfo,
                  currentVersionAsync: currentVersionAsync,
                ),

                // ── ABA 3: PRÉ-AUTORIZADOS ───────────────────────────────────
                _buildPreAuthorizedTab(
                  context,
                  unredeemed: unredeemedPreAuth,
                  preAuthorizedEmailsAsync: preAuthorizedEmailsAsync,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ABA 1: USUÁRIOS (Pesquisa, Filtros e Lista Completa)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildUsersTab(
    BuildContext context, {
    required List<UserAccessInfo> allUsers,
    required List<UserAccessInfo> filteredUsers,
    required AccessStatus? currentFilter,
    required bool onlyOutdated,
    required int outdatedCount,
    required int pendingCount,
    required int authorizedCount,
    required int blockedCount,
    required AsyncValue<List<UserAccessInfo>> usersAsync,
  }) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Barra de Pesquisa
        TextField(
          controller: _searchController,
          onChanged: (val) =>
              ref.read(userSearchQueryProvider.notifier).state = val,
          style: GoogleFonts.manrope(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Pesquisar por e-mail ou nome...',
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
        const SizedBox(height: 14),

        // Chips de Filtro por Status
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                context,
                label: 'Todos',
                count: allUsers.length,
                isSelected: currentFilter == null && !onlyOutdated,
                onTap: () {
                  ref.read(userOutdatedOnlyFilterProvider.notifier).state = false;
                  ref.read(userStatusFilterProvider.notifier).state = null;
                },
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: 'Desatualizados',
                count: outdatedCount,
                color: const Color(0xFFF59E0B),
                isSelected: onlyOutdated,
                onTap: () {
                  ref.read(userOutdatedOnlyFilterProvider.notifier).state = !onlyOutdated;
                },
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: 'Pendentes',
                count: pendingCount,
                color: const Color(0xFFF59E0B),
                isSelected: currentFilter == AccessStatus.pending && !onlyOutdated,
                onTap: () {
                  ref.read(userOutdatedOnlyFilterProvider.notifier).state = false;
                  ref.read(userStatusFilterProvider.notifier).state = AccessStatus.pending;
                },
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: 'Autorizados',
                count: authorizedCount,
                color: const Color(0xFF10B981),
                isSelected: currentFilter == AccessStatus.authorized && !onlyOutdated,
                onTap: () {
                  ref.read(userOutdatedOnlyFilterProvider.notifier).state = false;
                  ref.read(userStatusFilterProvider.notifier).state = AccessStatus.authorized;
                },
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: 'Bloqueados',
                count: blockedCount,
                color: const Color(0xFFFF5252),
                isSelected: currentFilter == AccessStatus.blocked && !onlyOutdated,
                onTap: () {
                  ref.read(userOutdatedOnlyFilterProvider.notifier).state = false;
                  ref.read(userStatusFilterProvider.notifier).state = AccessStatus.blocked;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Lista de Usuários
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ABA 2: VERSÃO DO APP (Janela Completa, Rápida e Fácil para Leigos)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildVersionTab(
    BuildContext context, {
    required AppUpdateInfo? latestInfo,
    required AsyncValue<AppCurrentVersion?> currentVersionAsync,
  }) {
    final theme = Theme.of(context);
    final latestBuild = latestInfo?.latestVersion ?? 1;
    final latestName = latestInfo?.versionName ?? '1.0.0';
    final notes = latestInfo?.releaseNotes.isNotEmpty == true
        ? latestInfo!.releaseNotes
        : 'Nenhuma nota informada.';
    final iosUrl = latestInfo?.iosUrl.isNotEmpty == true
        ? latestInfo!.iosUrl
        : 'https://keryxapp.pages.dev';

    return Form(
      key: _versionFormKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Banner de Apresentação
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                  theme.colorScheme.surfaceContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.kPrimaryGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.kPrimaryGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Color(0xFF111223),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Publicar Versão do Aplicativo',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mude a versão aqui para que os celulares dos membros recebam o aviso de atualização imediatamente.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cards de Status em tempo real
          Row(
            children: [
              Expanded(
                child: _buildVersionStatItem(
                  context,
                  title: 'CLOUDFLARE (NO AR)',
                  value: 'v$latestName (Build $latestBuild)',
                  icon: Icons.cloud_done_rounded,
                  color: AppTheme.kPrimaryGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildVersionStatItem(
                  context,
                  title: 'SEU APP ATUAL',
                  value: currentVersionAsync.when(
                    data: (v) => v != null ? 'v${v.versionName} (${v.buildNumber})' : '1.0.0',
                    loading: () => '...',
                    error: (_, __) => '1.0.0',
                  ),
                  icon: Icons.phone_android_rounded,
                  color: const Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Card com as Notas Atuais
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'NOTAS DA VERSÃO ATIVA NO AR:',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      tooltip: 'Atualizar dados do Cloudflare',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        ref.invalidate(latestUpdateInfoProvider);
                        ref.invalidate(currentAppVersionProvider);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
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
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── FORMULÁRIO SIMPLES PARA LEIGOS ───────────────────────
          Text(
            'NOVA ATUALIZAÇÃO',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppTheme.kPrimaryGold,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Campo 1: Número da Versão
                Text(
                  'Número da Versão',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Coloque o número que os membros verão na tela (ex: 1.0.2).',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _versionNameController,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ex: 1.0.2',
                    prefixIcon: const Icon(Icons.tag_rounded, size: 20),
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
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe o número da versão'
                      : null,
                ),
                const SizedBox(height: 18),

                // Campo 2: O que há de novo? (Notas da Versão)
                Text(
                  'O que há de novo nesta versão?',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Explique de forma simples o que mudou ou melhorou.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _versionNotesController,
                  maxLines: 3,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ex: Correção de áudio da Bíblia, melhorias de velocidade e novas funções de estudo.',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 36),
                      child: Icon(Icons.edit_note_rounded, size: 22),
                    ),
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
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      ReleaseNotesDialog.show(
                        context,
                        adminReleaseNotes: _versionNotesController.text,
                        isAfterUpdate: true,
                      );
                    },
                    icon: const Icon(Icons.preview_rounded, size: 16, color: AppTheme.kPrimaryGold),
                    label: Text(
                      'Pré-visualizar Tela de Novidades ✨',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.kPrimaryGold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Campo 3: Switch de Atualização Obrigatória
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Obrigar membros a atualizar?',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'Se ativado, impede o uso do app em versões antigas até o membro atualizar.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    activeThumbColor: AppTheme.kPrimaryGold,
                    value: _versionForceUpdate,
                    onChanged: (val) => setState(() => _versionForceUpdate = val),
                  ),
                ),
                const SizedBox(height: 14),

                // ── SEÇÃO AVANÇADA (EXPANSÍVEL, OCULTA PARA LEIGOS) ──────
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    iconColor: AppTheme.kPrimaryGold,
                    collapsedIconColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    title: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Configurações Técnicas de Servidor (Opcional)',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      const SizedBox(height: 8),
                      // Build Incremental
                      Text(
                        'Nº DE BUILD INCREMENTAL',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _versionBuildController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.manrope(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ex: 3',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Informe o build';
                          if (int.tryParse(v.trim()) == null) return 'Apenas números inteiros';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Link APK Android
                      Text(
                        'URL DE DOWNLOAD DO APK (ANDROID)',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _versionApkUrlController,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'https://keryx-version.nivaldo-nilngn.workers.dev/download',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Link PWA Web / iPhone
                      Text(
                        'URL DO PWA (IPHONE / WEB)',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _versionIosUrlController,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface,
                        ),
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
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── BOTÃO PRINCIPAL DE LANÇAMENTO ────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.kPrimaryGold,
                      foregroundColor: const Color(0xFF111223),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
                    ),
                    onPressed: _isSavingVersion
                        ? null
                        : () => _publishVersionFromTab(latestInfo),
                    icon: _isSavingVersion
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF111223),
                            ),
                          )
                        : const Icon(Icons.rocket_launch_rounded, size: 22),
                    label: Text(
                      _isSavingVersion
                          ? 'Publicando no Cloudflare...'
                          : 'Salvar e Publicar Nova Versão 🚀',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ABA 3: PRÉ-AUTORIZADOS (Convites antecipados e gerenciamento)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPreAuthorizedTab(
    BuildContext context, {
    required List<PreAuthorizedEmail> unredeemed,
    required AsyncValue<List<PreAuthorizedEmail>> preAuthorizedEmailsAsync,
  }) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Card de Apresentação e Botão Novo
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.kPrimaryGold.withValues(alpha: 0.25),
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
                      color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      color: AppTheme.kPrimaryGold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'E-mails Pré-Autorizados',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Libere acessos antes mesmo do membro baixar o app.',
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
              const SizedBox(height: 12),
              Text(
                'Cadastre o e-mail previamente. Quando a pessoa realizar o login pela primeira vez com o Google, o acesso será liberado automaticamente sem precisar de autorização manual.',
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.kPrimaryGold,
                    foregroundColor: const Color(0xFF111223),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _showAddEmailDialog,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(
                    'Autorizar Novo E-mail',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'AGUARDANDO PRIMEIRO LOGIN (${unredeemed.length})',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 10),

        if (unredeemed.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhum e-mail pré-autorizado pendente',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Todos os membros autorizados já fizeram o primeiro login.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: unredeemed
                  .map((pe) => _buildPreAuthorizedTile(context, pe))
                  .toList(),
            ),
          ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
            ),
          ),
        ],
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
    final latestUpdateInfo = ref.watch(latestUpdateInfoProvider).valueOrNull;
    final latestBuild = latestUpdateInfo?.latestVersion ?? 1;

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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.15),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Informações do Usuário + Status Badge alinhado no topo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  user.displayName ?? 'Usuário',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPrimary) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, size: 15, color: AppTheme.kPrimaryGold),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                user.status.labelPt.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // E-mail em largura total, sem quebrar com '.c om'!
                    Text(
                      user.email,
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Badges de Versão, Plataforma e Status de Atualização
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Badge de Versão Instalada
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: user.isOutdated(latestBuild)
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : (user.buildNumber != null
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: user.isOutdated(latestBuild)
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                                  : (user.buildNumber != null
                                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.1)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                user.isOutdated(latestBuild)
                                    ? Icons.warning_amber_rounded
                                    : (user.buildNumber != null
                                        ? Icons.verified_rounded
                                        : Icons.help_outline_rounded),
                                size: 12,
                                color: user.isOutdated(latestBuild)
                                    ? const Color(0xFFF59E0B)
                                    : (user.buildNumber != null
                                        ? const Color(0xFF10B981)
                                        : Colors.white60),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.buildNumber != null
                                    ? (user.isOutdated(latestBuild)
                                        ? '${user.versionDisplay} (Desatualizado)'
                                        : '${user.versionDisplay} (Atualizado)')
                                    : 'Versão: ${user.versionDisplay}',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: user.isOutdated(latestBuild)
                                      ? const Color(0xFFF59E0B)
                                      : (user.buildNumber != null
                                          ? const Color(0xFF10B981)
                                          : Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badge de Plataforma (Android / iOS / Web)
                        if (user.platform != null && user.platform!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  user.platform!.toLowerCase().contains('ios') ||
                                          user.platform!.toLowerCase().contains('apple')
                                      ? Icons.apple_rounded
                                      : (user.platform!.toLowerCase().contains('web')
                                          ? Icons.language_rounded
                                          : Icons.android_rounded),
                                  size: 11,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  user.platformDisplay,
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Badge de Exigência Ativa
                        if (user.updateRequired)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 11, color: Color(0xFFEF4444)),
                                const SizedBox(width: 3),
                                Text(
                                  'ATUALIZAÇÃO EXIGIDA',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFEF4444),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isPrimary)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Administrador Principal Protegido',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.kPrimaryGold,
                      ),
                    ),
                  )
                else ...[
                  // Botão de Exigência / Notificação de Atualização
                  if (user.updateRequired)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF59E0B),
                        side: BorderSide(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: () => _confirmCancelUpdate(user),
                      icon: const Icon(Icons.close_rounded, size: 15),
                      label: Text(
                        'Cancelar Exigência',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: user.isOutdated(latestBuild)
                            ? const Color(0xFFF59E0B)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        side: BorderSide(
                          color: user.isOutdated(latestBuild)
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: () => _showNotifyUpdateDialog(user, latestUpdateInfo),
                      icon: Icon(
                        Icons.system_security_update_warning_rounded,
                        size: 15,
                        color: user.isOutdated(latestBuild)
                            ? const Color(0xFFF59E0B)
                            : AppTheme.kPrimaryGold,
                      ),
                      label: Text(
                        user.isOutdated(latestBuild) ? 'Exigir Atualização' : 'Notificar Versão',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: user.isOutdated(latestBuild)
                              ? const Color(0xFFF59E0B)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),

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
