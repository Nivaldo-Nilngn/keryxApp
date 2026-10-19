import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/user_access_model.dart';

class AccessControlService {
  static const String kPrimaryAdminEmail = 'nivaldo.nilngn@gmail.com';
  static const String kFirebaseConsoleRulesUrl =
      'https://console.firebase.google.com/project/bibliapeniel-nilngn/firestore/rules';

  static const String kRecommendedFirestoreRules = '''rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function signedIn() { return request.auth != null; }

    function counterDelta(field) {
      return request.resource.data.get(field, 0) - resource.data.get(field, 0);
    }
    function likeRef(id) {
      return /databases/\$(db)/documents/annotations/\$(id)/likes/\$(request.auth.uid);
    }
    function likeCountOk(id) {
      let d = counterDelta('likeCount');
      return d == 0
        || (d == 1  && !exists(likeRef(id)) && existsAfter(likeRef(id)))
        || (d == -1 && exists(likeRef(id))  && !existsAfter(likeRef(id)));
    }

    match /annotations/{id} {
      allow read: if resource.data.get('isPublic', false) == true || (signedIn() && resource.data.authorId == request.auth.uid);
      allow create: if signedIn() && request.resource.data.authorId == request.auth.uid
                    && request.resource.data.get('likeCount', 0) == 0
                    && request.resource.data.get('commentCount', 0) == 0
                    && request.resource.data.get('isLocked', false) == false;
      allow delete: if signedIn() && resource.data.authorId == request.auth.uid;
      allow update: if signedIn() && (
        (resource.data.authorId == request.auth.uid 
         && request.resource.data.authorId == resource.data.authorId
         && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['likeCount','commentCount'])) ||
        (resource.data.get('isPublic', false) == true &&
         request.resource.data.diff(resource.data).affectedKeys().hasOnly(['commentCount', 'likeCount', 'lastActivityAt'])
         && likeCountOk(id) 
         && counterDelta('commentCount') >= -1 && counterDelta('commentCount') <= 1)
      );

      match /comments/{cid} {
        allow read: if get(/databases/\$(db)/documents/annotations/\$(id)).data.get('isPublic', false) == true || 
                       (signedIn() && get(/databases/\$(db)/documents/annotations/\$(id)).data.authorId == request.auth.uid);
        
        allow create: if signedIn()
          && request.resource.data.authorId == request.auth.uid
          && request.resource.data.get('isAccepted', false) == false
          && get(/databases/\$(db)/documents/annotations/\$(id)).data.get('isPublic', false) == true
          && get(/databases/\$(db)/documents/annotations/\$(id)).data.get('isLocked', false) == false;
          
        allow update: if signedIn() && (
          (resource.data.authorId == request.auth.uid && 
           !request.resource.data.diff(resource.data).affectedKeys().hasAny(['authorId','isAccepted'])) ||
          (get(/databases/\$(db)/documents/annotations/\$(id)).data.authorId == request.auth.uid &&
           request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isAccepted']))
        );
        
        allow delete: if signedIn() && 
          (resource.data.authorId == request.auth.uid || 
           get(/databases/\$(db)/documents/annotations/\$(id)).data.authorId == request.auth.uid);
      }

      match /likes/{uid} {
        allow read: if signedIn() && 
          (get(/databases/\$(db)/documents/annotations/\$(id)).data.get('isPublic', false) == true || 
           get(/databases/\$(db)/documents/annotations/\$(id)).data.authorId == request.auth.uid);
           
        allow create: if signedIn() && request.auth.uid == uid && 
          get(/databases/\$(db)/documents/annotations/\$(id)).data.get('isPublic', false) == true &&
          request.resource.data.size() <= 5;
          
        allow delete: if signedIn() && request.auth.uid == uid;
      }
    }

    match /store_comments/{docId} {
      allow read: if true;
      allow create: if signedIn() && request.resource.data.authorId == request.auth.uid;
      allow update, delete: if signedIn() && resource.data.authorId == request.auth.uid;
    }

    function isPrimaryAdmin() {
      return signedIn() && (
        ('email' in request.auth.token && request.auth.token.email != null && request.auth.token.email.lower() == 'nivaldo.nilngn@gmail.com') ||
        request.auth.uid == 'I5v6l4CDUQRaliO9upJrE36QEHx1'
      );
    }

    match /authorized_emails/{email} {
      allow read: if signedIn();
      allow write: if isPrimaryAdmin();
    }

    match /access_logs/{logId} {
      allow read, write: if isPrimaryAdmin();
    }

    match /users/{uid} {
      allow read: if signedIn() && (request.auth.uid == uid || isPrimaryAdmin());
      
      allow create: if signedIn() && (
        isPrimaryAdmin() || 
        (request.auth.uid == uid && 
         request.resource.data.get('role', 'user') != 'admin')
      );

      allow update: if signedIn() && (
        (isPrimaryAdmin() && 
         (resource.data.get('email', '').lower() != 'nivaldo.nilngn@gmail.com' || 
          (request.resource.data.get('role', 'admin') == 'admin' && 
           request.resource.data.get('status', 'authorized') == 'authorized'))) ||
        (request.auth.uid == uid && 
         !request.resource.data.diff(resource.data).affectedKeys().hasAny(['role', 'status', 'approvedAt', 'approvedBy']))
      );

      allow delete: if isPrimaryAdmin() && resource.data.get('email', '').lower() != 'nivaldo.nilngn@gmail.com';

      match /annotations/{docId} {
        allow read, write: if signedIn() && request.auth.uid == uid;
      }
      match /highlights/{docId} {
        allow read, write: if signedIn() && request.auth.uid == uid;
      }
      match /favorites/{docId} {
        allow read, write: if signedIn() && request.auth.uid == uid;
      }
      match /reading_history/{docId} {
        allow read, write: if signedIn() && request.auth.uid == uid;
      }
      match /outlines/{docId} {
        allow read, write: if signedIn() && request.auth.uid == uid;
      }
      match /notifications/{nid} {
        allow read, delete: if signedIn() && request.auth.uid == uid;
        allow update: if signedIn() && request.auth.uid == uid && 
          request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isRead']);
        allow create: if signedIn() && (
          (request.resource.data.fromUserId == request.auth.uid && uid != request.auth.uid) ||
          request.auth.uid == uid
        );
      }
    }
  }
}''';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AccessControlService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static bool isPrimaryAdmin(String? email) {
    if (email == null) return false;
    return normalizeEmail(email) == kPrimaryAdminEmail;
  }

  static bool isValidEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    );
    return emailRegex.hasMatch(trimmed);
  }

  /// Verifica e sincroniza o acesso de um usuário autenticado.
  /// Chamado automaticamente na inicialização da sessão.
  Future<UserAccessInfo> checkAndRegisterAccess(User authUser) async {
    final email = normalizeEmail(authUser.email ?? '');
    final uid = authUser.uid;
    final docRef = _firestore.collection('users').doc(uid);

    // 1. Administrador Principal: Garantia absoluta de autorização e papel de admin
    if (isPrimaryAdmin(email)) {
      final doc = await docRef.get();
      final existingData = doc.data() ?? {};

      final adminData = <String, dynamic>{
        'uid': uid,
        'email': kPrimaryAdminEmail,
        'name': authUser.displayName ?? existingData['name'] ?? 'Nivaldo (Admin)',
        'displayName': authUser.displayName ?? existingData['displayName'] ?? 'Nivaldo (Admin)',
        'photoUrl': authUser.photoURL ?? existingData['photoUrl'],
        'role': UserRole.admin.toDbString(),
        'status': AccessStatus.authorized.toDbString(),
        'lastLogin': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        if (!doc.exists) 'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(adminData, SetOptions(merge: true));
      return UserAccessInfo.fromMap(uid, {
        ...existingData,
        ...adminData,
        'createdAt': (doc.exists && existingData['createdAt'] != null)
            ? existingData['createdAt']
            : DateTime.now(),
        'lastLogin': DateTime.now(),
      });
    }

    // 2. Usuário normal: buscar documento existente
    final doc = await docRef.get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      final currentStatusStr = data['status'] as String?;

      // Se já possui status definido no documento
      if (currentStatusStr != null && currentStatusStr.isNotEmpty) {
        // Atualiza última atividade
        await docRef.set({
          'lastLogin': FieldValue.serverTimestamp(),
          'lastActivity': FieldValue.serverTimestamp(),
          if (authUser.displayName != null && authUser.displayName!.isNotEmpty)
            'displayName': authUser.displayName,
          if (authUser.photoURL != null) 'photoUrl': authUser.photoURL,
        }, SetOptions(merge: true));

        return UserAccessInfo.fromFirestore(doc);
      }
    }

    // 3. Novo usuário ou sem status: verificar se já está na lista de pré-autorizados
    bool preAuthorized = false;
    if (email.isNotEmpty) {
      final preAuthDoc = await _firestore.collection('authorized_emails').doc(email).get();
      if (preAuthDoc.exists) {
        final preAuthData = preAuthDoc.data() ?? {};
        final status = AccessStatus.fromString(preAuthData['status'] as String?);
        if (status == AccessStatus.authorized) {
          preAuthorized = true;
        }
      }
    }

    final initialStatus = preAuthorized ? AccessStatus.authorized : AccessStatus.pending;
    final now = DateTime.now();

    final newUserData = <String, dynamic>{
      'uid': uid,
      'email': email,
      'name': authUser.displayName ?? (email.isNotEmpty ? email.split('@').first : 'Usuário'),
      'displayName': authUser.displayName ?? (email.isNotEmpty ? email.split('@').first : 'Usuário'),
      'photoUrl': authUser.photoURL,
      'role': UserRole.user.toDbString(),
      'status': initialStatus.toDbString(),
      'isPreAuthorized': preAuthorized,
      'createdAt': FieldValue.serverTimestamp(),
      'requestedAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
      'lastActivity': FieldValue.serverTimestamp(),
      if (preAuthorized) 'approvedAt': FieldValue.serverTimestamp(),
      if (preAuthorized) 'approvedBy': 'system:pre_authorized',
    };

    await docRef.set(newUserData, SetOptions(merge: true));

    // Log de auditoria
    if (!preAuthorized) {
      await _logAudit(
        action: 'access_requested',
        targetEmail: email,
        targetUid: uid,
        details: 'Nova solicitação de acesso registrada com status pendente.',
      );
    } else {
      await _logAudit(
        action: 'pre_authorized_registered',
        targetEmail: email,
        targetUid: uid,
        details: 'Usuário pré-autorizado realizou seu primeiro acesso com sucesso.',
      );
    }

    return UserAccessInfo.fromMap(uid, {
      ...newUserData,
      'createdAt': now,
      'requestedAt': now,
      'lastLogin': now,
    });
  }

  /// Stream em tempo real do status de acesso do usuário logado
  Stream<UserAccessInfo?> streamCurrentUserAccess(String? uid, String? email) {
    if (uid == null || uid.isEmpty) {
      return Stream.value(null);
    }

    final normalized = normalizeEmail(email ?? '');
    final isAdm = isPrimaryAdmin(normalized);

    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        // Se ainda não existir no firestore, se for o admin, já retorna autorizado
        if (isAdm) {
          return UserAccessInfo(
            uid: uid,
            email: kPrimaryAdminEmail,
            displayName: 'Nivaldo (Admin)',
            status: AccessStatus.authorized,
            role: UserRole.admin,
          );
        }
        return null;
      }

      final info = UserAccessInfo.fromFirestore(snapshot);
      if (isAdm) {
        return info.copyWith(
          role: UserRole.admin,
          status: AccessStatus.authorized,
        );
      }
      return info;
    });
  }

  /// Stream com todos os usuários cadastrados (apenas admin pode consumir)
  Stream<List<UserAccessInfo>> streamAllUsers() {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => UserAccessInfo.fromFirestore(doc))
          .toList();

      // Ordenar: primeiro pendentes (mais urgentes), depois autorizados, depois bloqueados
      list.sort((a, b) {
        if (a.isPending && !b.isPending) return -1;
        if (!a.isPending && b.isPending) return 1;
        // Depois por data mais recente
        final dateA = a.requestedAt ?? a.createdAt ?? DateTime(2000);
        final dateB = b.requestedAt ?? b.createdAt ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      return list;
    });
  }

  /// Stream da lista de e-mails pré-autorizados
  Stream<List<PreAuthorizedEmail>> streamPreAuthorizedEmails() {
    return _firestore
        .collection('authorized_emails')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PreAuthorizedEmail.fromFirestore(doc))
          .toList();
    });
  }

  /// Aprovar usuário pendente
  Future<void> approveUser(String targetUid, String targetEmail) async {
    _ensureIsAdmin();
    final docRef = _firestore.collection('users').doc(targetUid);
    final adminUser = _auth.currentUser;

    await docRef.update({
      'status': AccessStatus.authorized.toDbString(),
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': adminUser?.email ?? kPrimaryAdminEmail,
      'lastActivity': FieldValue.serverTimestamp(),
    });

    await _logAudit(
      action: 'approve_user',
      targetEmail: targetEmail,
      targetUid: targetUid,
      details: 'Acesso aprovado pelo Administrador Principal.',
    );
  }

  /// Bloquear / revogar acesso de um usuário
  Future<void> blockUser(String targetUid, String targetEmail) async {
    _ensureIsAdmin();

    if (isPrimaryAdmin(targetEmail)) {
      throw Exception('Operação inválida: O Administrador Principal não pode ser bloqueado.');
    }

    final docRef = _firestore.collection('users').doc(targetUid);
    final adminUser = _auth.currentUser;

    await docRef.update({
      'status': AccessStatus.blocked.toDbString(),
      'blockedAt': FieldValue.serverTimestamp(),
      'blockedBy': adminUser?.email ?? kPrimaryAdminEmail,
      'lastActivity': FieldValue.serverTimestamp(),
    });

    await _logAudit(
      action: 'block_user',
      targetEmail: targetEmail,
      targetUid: targetUid,
      details: 'Acesso revogado/bloqueado pelo Administrador Principal.',
    );
  }

  /// Reativar usuário bloqueado
  Future<void> unblockUser(String targetUid, String targetEmail) async {
    _ensureIsAdmin();
    final docRef = _firestore.collection('users').doc(targetUid);
    final adminUser = _auth.currentUser;

    await docRef.update({
      'status': AccessStatus.authorized.toDbString(),
      'unblockedAt': FieldValue.serverTimestamp(),
      'unblockedBy': adminUser?.email ?? kPrimaryAdminEmail,
      'lastActivity': FieldValue.serverTimestamp(),
    });

    await _logAudit(
      action: 'unblock_user',
      targetEmail: targetEmail,
      targetUid: targetUid,
      details: 'Acesso reativado pelo Administrador Principal.',
    );
  }

  /// Pré-autorizar e-mail manualmente
  Future<void> preAuthorizeEmail(String rawEmail, {String? note}) async {
    _ensureIsAdmin();
    final email = normalizeEmail(rawEmail);

    if (!isValidEmail(email)) {
      throw Exception('Por favor, informe um endereço de e-mail válido.');
    }

    if (isPrimaryAdmin(email)) {
      throw Exception('O e-mail informado já é o Administrador Principal.');
    }

    final adminUser = _auth.currentUser;

    // 1. Salvar na coleção de authorized_emails
    final preAuthDoc = _firestore.collection('authorized_emails').doc(email);
    final exists = (await preAuthDoc.get()).exists;
    if (exists) {
      throw Exception('Este e-mail já está cadastrado na lista de autorizados.');
    }

    await preAuthDoc.set({
      'email': email,
      'status': AccessStatus.authorized.toDbString(),
      'addedAt': FieldValue.serverTimestamp(),
      'addedBy': adminUser?.email ?? kPrimaryAdminEmail,
      if (note != null && note.isNotEmpty) 'note': note,
    });

    // 2. Se o usuário já se cadastrou antes e estava com status pendente, liberar imediatamente!
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final existingDoc = userQuery.docs.first;
        await existingDoc.reference.update({
          'status': AccessStatus.authorized.toDbString(),
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': adminUser?.email ?? kPrimaryAdminEmail,
          'isPreAuthorized': true,
        });
      }
    } catch (e) {
      print('Aviso ao sincronizar usuário pré-existente: $e');
    }

    await _logAudit(
      action: 'pre_authorize_email',
      targetEmail: email,
      details: 'E-mail adicionado manualmente à lista de usuários autorizados.',
    );
  }

  /// Remover e-mail pré-autorizado
  Future<void> removePreAuthorization(String rawEmail) async {
    _ensureIsAdmin();
    final email = normalizeEmail(rawEmail);

    await _firestore.collection('authorized_emails').doc(email).delete();

    await _logAudit(
      action: 'remove_pre_authorization',
      targetEmail: email,
      details: 'E-mail removido da lista de pré-autorizados pelo administrador.',
    );
  }

  /// Gravar log de auditoria
  Future<void> _logAudit({
    required String action,
    required String targetEmail,
    String? targetUid,
    String? details,
  }) async {
    try {
      final adminUser = _auth.currentUser;
      await _firestore.collection('access_logs').add({
        'adminUid': adminUser?.uid ?? 'system',
        'adminEmail': adminUser?.email ?? kPrimaryAdminEmail,
        'targetEmail': targetEmail,
        if (targetUid != null) 'targetUid': targetUid,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
        if (details != null) 'details': details,
      });
    } catch (e) {
      print('Aviso ao gravar log de auditoria: $e');
    }
  }

  void _ensureIsAdmin() {
    final currentEmail = _auth.currentUser?.email;
    if (!isPrimaryAdmin(currentEmail)) {
      throw Exception('Acesso negado: Apenas o Administrador Principal tem permissão para esta ação.');
    }
  }
}
