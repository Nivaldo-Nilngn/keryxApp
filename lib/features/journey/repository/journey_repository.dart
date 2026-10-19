import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/model/user_model.dart';
import '../../../core/services/auth_service.dart';

class JourneyRepository {
  final FirebaseFirestore _firestore;

  JourneyRepository(this._firestore);

  /// Escutar as atualizações em tempo real do UserModel, 
  /// que já inclui os "stats" (Streak, Sessões, etc.)
  Stream<UserModel?> watchUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          // Injeta o uid no JSON antes de converter
          final data = doc.data()!..['uid'] = doc.id;
          return UserModel.fromJson(data);
        });
  }

  /// Método utilitário para pegar uma única foto do Firestore atual do usuário logado
  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!..['uid'] = doc.id;
    return UserModel.fromJson(data);
  }
}

final journeyRepositoryProvider = Provider((ref) {
  return JourneyRepository(FirebaseFirestore.instance);
});

final currentUserStreamProvider = StreamProvider<UserModel?>((ref) {
  // Pega o usuário autenticado do firebase auth
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return const Stream.empty();

  // Escuta os dados do Firestore correspondentes a ele
  return ref.watch(journeyRepositoryProvider).watchUser(authUser.uid);
});
