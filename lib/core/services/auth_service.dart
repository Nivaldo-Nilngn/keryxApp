import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../features/auth/model/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Instância do GoogleSignIn configurada para Android/iOS (no Web usamos apenas FirebaseAuth popup)
  final GoogleSignIn? _googleSignIn = kIsWeb
      ? null
      : GoogleSignIn(
          serverClientId: '809342545607-mdbs8b13gdo81et56rf4k9rf75ibkdcs.apps.googleusercontent.com',
        );
  // Removido _isInitialized pois o plugin oficial não necessita/possui initialize()

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signUp(String email, String password, String name) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      if (userCredential.user != null) {
        final displayName = name.trim();
        await userCredential.user!.updateDisplayName(displayName);
        await userCredential.user!.reload();
        await _updateUserData(userCredential.user!, name: displayName);
      }
      return userCredential;
    } catch (e) {
      print('Erro no cadastro: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), 
        password: password.trim(),
      );
      if (cred.user != null) {
        await _updateUserData(cred.user!);
      }
      return cred;
    } catch (e) {
      print('Erro no login: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      print('Erro no login anônimo: $e');
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
      print('Erro ao entrar com Google: $e');
      rethrow;
    }
  }

  Future<void> _updateUserData(User user, {String? name}) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      
      final displayName = name ?? user.displayName;
      
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

      print('DEBUG: Atualizando Firestore para ${user.uid}');
      print('DEBUG: Nome: $displayName');
      print('DEBUG: Foto: $photoUrl');
      
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
      
      print('DEBUG: Firestore atualizado com sucesso.');
    } catch (e) {
      print('DEBUG: Erro ao atualizar Firestore: $e');
    }
  }

  Future<void> signOut() async {
    try {
      // No Web, o signOut do google_sign_in pode travar devido a políticas de CORS/COOP.
      // O Firebase signOut() já é suficiente para limpar a sessão do app no navegador.
      if (!kIsWeb) {
        await _googleSignIn?.signOut();
      }
    } catch (e) {
      print('Erro ao deslogar Google: $e');
    }
    try {
      await _auth.signOut();
    } catch (e) {
      print('Erro ao deslogar Firebase: $e');
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
