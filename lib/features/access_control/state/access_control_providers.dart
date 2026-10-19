import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../model/user_access_model.dart';
import '../service/access_control_service.dart';

final accessControlServiceProvider = Provider<AccessControlService>((ref) {
  return AccessControlService();
});

/// Indica se o usuário autenticado atualmente é o Administrador Principal
final isPrimaryAdminProvider = Provider<bool>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  return AccessControlService.isPrimaryAdmin(authUser?.email);
});

/// Stream do perfil de acesso do usuário atualmente conectado.
/// Quando o usuário loga, automaticamente verifica e sincroniza o documento no Firestore.
final currentUserAccessProvider = StreamProvider<UserAccessInfo?>((ref) {
  final authState = ref.watch(authStateProvider);
  final accessService = ref.watch(accessControlServiceProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }

      // Sincroniza o acesso no Firestore em background se necessário
      accessService.checkAndRegisterAccess(user).catchError((e) {
        print('Erro ao sincronizar acesso do usuário: $e');
        return UserAccessInfo(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          status: AccessControlService.isPrimaryAdmin(user.email)
              ? AccessStatus.authorized
              : AccessStatus.pending,
          role: AccessControlService.isPrimaryAdmin(user.email)
              ? UserRole.admin
              : UserRole.user,
        );
      });

      return accessService.streamCurrentUserAccess(user.uid, user.email);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => Stream.value(null),
  );
});

/// Stream de todos os usuários cadastrados (consumido pela tela de Gerenciamento de Acessos)
final allUsersProvider = StreamProvider<List<UserAccessInfo>>((ref) {
  final isAdmin = ref.watch(isPrimaryAdminProvider);
  if (!isAdmin) {
    return Stream.value([]);
  }
  final service = ref.watch(accessControlServiceProvider);
  return service.streamAllUsers();
});

/// Stream de e-mails pré-autorizados
final preAuthorizedEmailsProvider = StreamProvider<List<PreAuthorizedEmail>>((ref) {
  final isAdmin = ref.watch(isPrimaryAdminProvider);
  if (!isAdmin) {
    return Stream.value([]);
  }
  final service = ref.watch(accessControlServiceProvider);
  return service.streamPreAuthorizedEmails();
});

/// Termo de busca na tela de Gerenciamento
final userSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtro de status selecionado (null = Todos)
final userStatusFilterProvider = StateProvider<AccessStatus?>((ref) => null);

/// Lista de usuários filtrada para a interface
final filteredUsersProvider = Provider<List<UserAccessInfo>>((ref) {
  final usersAsync = ref.watch(allUsersProvider);
  final query = ref.watch(userSearchQueryProvider).trim().toLowerCase();
  final statusFilter = ref.watch(userStatusFilterProvider);
  final authUser = ref.watch(authStateProvider).value;
  final isAdm = AccessControlService.isPrimaryAdmin(authUser?.email);

  final adminFallback = (isAdm && authUser != null)
      ? [
          UserAccessInfo(
            uid: authUser.uid,
            email: AccessControlService.kPrimaryAdminEmail,
            displayName: authUser.displayName ?? 'Nivaldo (Admin)',
            photoUrl: authUser.photoURL,
            role: UserRole.admin,
            status: AccessStatus.authorized,
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
          )
        ]
      : <UserAccessInfo>[];

  final users = (usersAsync.value != null && usersAsync.value!.isNotEmpty)
      ? usersAsync.value!
      : adminFallback;

  return users.where((u) {
    // Filtro por status
    if (statusFilter != null && u.status != statusFilter) {
      return false;
    }

    // Filtro por pesquisa
    if (query.isNotEmpty) {
      final emailMatch = u.email.toLowerCase().contains(query);
      final nameMatch = (u.displayName ?? '').toLowerCase().contains(query);
      return emailMatch || nameMatch;
    }

    return true;
  }).toList();
});
