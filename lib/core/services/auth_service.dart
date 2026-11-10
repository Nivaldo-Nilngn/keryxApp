import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../features/auth/model/user_model.dart';

class AuthService {
  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _customAuth = auth,
        _customFirestore = firestore;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  
  // Instância do GoogleSignIn configurada para Android/iOS (no Web usamos apenas FirebaseAuth popup)
  final GoogleSignIn? _googleSignIn = kIsWeb
      ? null
      : GoogleSignIn(
          serverClientId: '809342545607-mdbs8b13gdo81et56rf4k9rf75ibkdcs.apps.googleusercontent.com',
        );

  /// Validação rigorosa de formato de e-mail seguro
  static bool isValidEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty || trimmed.length > 254) return false;
    final emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    return emailRegex.hasMatch(trimmed);
  }

  /// Validação de força mínima de senha
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  /// Sanitização contra injeção de tags ou caracteres de controle em nomes de exibição
  static String sanitizeDisplayName(String name) {
    return name.trim().replaceAll(RegExp(r'[<>{}\\/]'), '');
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signUp(String email, String password, String name) async {
    final trimmedEmail = email.trim();
    final sanitizedName = sanitizeDisplayName(name);

    if (!isValidEmail(trimmedEmail)) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'O endereço de e-mail informado é inválido.',
      );
    }
    if (!isValidPassword(password)) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'A senha deve conter no mínimo 6 caracteres.',
      );
    }
    if (sanitizedName.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-name',
        message: 'O nome de exibição não pode estar vazio.',
      );
    }

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      
      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(sanitizedName);
        await userCredential.user!.reload();
        await _updateUserData(userCredential.user!, name: sanitizedName);
      }
      return userCredential;
    } catch (e) {
      debugPrint('Erro no cadastro: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    final trimmedEmail = email.trim();
    if (!isValidEmail(trimmedEmail)) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'O endereço de e-mail informado é inválido.',
      );
    }
    if (password.isEmpty) {
      throw FirebaseAuthException(
        code: 'wrong-password',
        message: 'A senha não pode estar em branco.',
      );
    }

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: trimmedEmail, 
        password: password.trim(),
      );
      if (cred.user != null) {
        await _updateUserData(cred.user!);
      }
      return cred;
    } catch (e) {
      debugPrint('Erro no login: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      debugPrint('Erro no login anônimo: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // No Web, o Firebase resolve o login com Google diretamente com signInWithPopup.
        // Isso remove a dependência do pacote google_sign_in para Web, 
        // permitindo usar QUALQUER botão customizado sem erros de UnimplementedError.
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(googleProvider);
        if (userCredential.user != null) {
          await _updateUserData(userCredential.user!);
        }
        return userCredential;
      } else {
        // No Mobile (Android/iOS), usamos o fluxo nativo do pacote google_sign_in.
        
        final GoogleSignInAccount? googleUser = await _googleSignIn?.signIn();
        if (googleUser == null) return null;
 
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        
        final userCredential = await _auth.signInWithCredential(credential);
        if (userCredential.user != null) {
          await _updateUserData(userCredential.user!);
        }
        return userCredential;
      }
    } catch (e) {
      debugPrint('Erro ao entrar com Google: $e');
      rethrow;
    }
  }

  Future<void> _updateUserData(User user, {String? name}) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      
      final displayName = name != null ? sanitizeDisplayName(name) : user.displayName;
      
      // Tentar pegar a foto do perfil principal ou dos provedores (Google)
      String? photoUrl = user.photoURL;
      if (photoUrl == null && user.providerData.isNotEmpty) {
        photoUrl = user.providerData.first.photoURL;
      }

      // Sanitização para evitar erro 429 no Web (muda o tamanho da imagem solicitada)
      // O Google às vezes bloqueia s96-c se houver muitos pedidos. s192-c ou s320-c costumam funcionar.
      // Sanitização para evitar erro 429 no Web e buscar qualidade estável
      if (photoUrl != null && photoUrl.contains('googleusercontent.com')) {
        // s256-c é um tamanho padrão seguro que evita bloqueios frequentes
        photoUrl = photoUrl.replaceAll(RegExp(r'=s\d+(-c)?'), '=s256-c');
      }
      
      // Usa o novo UserModel para obter dados padronizados com stats e subscription
      final userModel = UserModel(
        uid: user.uid,
        displayName: displayName ?? 'Buscador',
        email: user.email,
        photoUrl: photoUrl,
      );

      final userMap = userModel.toJson();
      userMap['stats'] = userModel.stats.toJson();
      userMap['subscription'] = userModel.subscription.toJson();

      final emailNormalized = (user.email ?? '').trim().toLowerCase();
      final isPrimaryAdmin = emailNormalized == 'nivaldo.nilngn@gmail.com';

      final Map<String, dynamic> updateData = {
        ...userMap,
        'email': emailNormalized,
        'lastLogin': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        if (!doc.exists) 'createdAt': FieldValue.serverTimestamp(),
      };

      if (isPrimaryAdmin) {
        updateData['role'] = 'admin';
        updateData['status'] = 'authorized';
      } else if (!doc.exists || doc.data()?['status'] == null) {
        // Se ainda não tiver status, verifica se foi pré-autorizado
        try {
          final preAuth = await _firestore.collection('authorized_emails').doc(emailNormalized).get();
          if (preAuth.exists && preAuth.data()?['status'] == 'authorized') {
            updateData['status'] = 'authorized';
            updateData['role'] = 'user';
            updateData['isPreAuthorized'] = true;
            updateData['approvedAt'] = FieldValue.serverTimestamp();
          } else {
            updateData['status'] = 'pending';
            updateData['role'] = 'user';
            updateData['requestedAt'] = FieldValue.serverTimestamp();
          }
        } catch (_) {
          updateData['status'] = 'pending';
          updateData['role'] = 'user';
        }
      }

      // Salva os dados unindo o JSON padrão do UserModel, mas preservando o `createdAt` antigo
      await docRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Erro ao atualizar Firestore: $e');
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
    String? avatarFrame,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final trimmedName = displayName != null ? sanitizeDisplayName(displayName) : null;
      final trimmedPhoto = photoUrl?.trim();

      if (trimmedName != null && trimmedName.isNotEmpty) {
        await user.updateDisplayName(trimmedName);
      }
      if (trimmedPhoto != null) {
        await user.updatePhotoURL(trimmedPhoto.isNotEmpty ? trimmedPhoto : null);
      }
      await user.reload();

      final updates = <String, dynamic>{
        'lastActivity': FieldValue.serverTimestamp(),
      };
      if (trimmedName != null && trimmedName.isNotEmpty) {
        updates['displayName'] = trimmedName;
        updates['name'] = trimmedName;
      }
      if (trimmedPhoto != null) {
        updates['photoUrl'] = trimmedPhoto.isNotEmpty ? trimmedPhoto : null;
      }
      if (avatarFrame != null) {
        updates['avatarFrame'] = avatarFrame;
      }

      await _firestore.collection('users').doc(user.uid).set(updates, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Erro ao atualizar perfil: $e');
      rethrow;
    }
  }

  /// Envia e-mail de redefinição de senha (ou criação de senha para quem entrou com Google)
  Future<void> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();
    if (!isValidEmail(trimmed)) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'O endereço de e-mail informado é inválido.',
      );
    }
    try {
      await _auth.sendPasswordResetEmail(email: trimmed);
    } catch (e) {
      debugPrint('Erro ao enviar e-mail de redefinição: $e');
      rethrow;
    }
  }

  /// Verifica se o usuário atual só tem login com Google (sem senha de e-mail cadastrada)
  bool get isGoogleOnlyAccount {
    final user = _auth.currentUser;
    if (user == null) return false;
    final hasGoogle = user.providerData.any((p) => p.providerId == 'google.com');
    final hasPassword = user.providerData.any((p) => p.providerId == 'password');
    return hasGoogle && !hasPassword;
  }

  /// Define ou altera a senha de e-mail para a conta logada atualmente
  Future<void> setPasswordForCurrentUser(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Nenhum usuário logado com e-mail válido.');
    }

    final trimmed = newPassword.trim();
    if (!isValidPassword(trimmed)) {
      throw Exception('A senha deve ter pelo menos 6 caracteres.');
    }

    try {
      final hasPassword = user.providerData.any((p) => p.providerId == 'password');
      if (hasPassword) {
        // Já tem provedor de senha, apenas atualiza
        await user.updatePassword(trimmed);
      } else {
        // Usuário do Google sem senha: vincula credencial de e-mail/senha à mesma conta
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: trimmed,
        );
        await user.linkWithCredential(credential);
      }
      await user.reload();
    } catch (e) {
      debugPrint('Erro ao definir senha: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Revoga token de notificações push e atualiza timestamp de logout antes da desautenticação
        try {
          await _firestore.collection('users').doc(user.uid).update({
            'fcmToken': FieldValue.delete(),
            'lastSignOut': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Aviso: Falha ao revogar fcmToken no Firestore antes do logout: $e');
        }
      }

      // No Web, o signOut do google_sign_in pode travar devido a políticas de CORS/COOP.
      // O Firebase signOut() já é suficiente para limpar a sessão do app no navegador.
      if (!kIsWeb) {
        await _googleSignIn?.signOut();
      }
    } catch (e) {
      debugPrint('Erro ao deslogar Google: $e');
    }
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Erro ao deslogar Firebase: $e');
    }
  }
}

final authServiceProvider = Provider((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Provider para controlar o modo convidado (Offline)
final guestModeProvider = StateProvider<bool>((ref) => false);

// Provider para buscar os dados do usuário no Firestore
final userDataProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snapshot) => snapshot.data());
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});
