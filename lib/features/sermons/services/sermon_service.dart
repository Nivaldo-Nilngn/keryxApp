import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/sermon_model.dart';

abstract class SermonService {
  Future<List<Sermon>> getSermons();
  Future<Sermon?> getSermon(String id);
  Future<void> saveSermon(Sermon sermon);
  Future<void> deleteSermon(String id);
}

class FirestoreSermonService implements SermonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _uid;

  FirestoreSermonService(this._uid);

  CollectionReference get _collection => 
      _firestore.collection('users').doc(_uid).collection('sermons');

  @override
  Future<List<Sermon>> getSermons() async {
    final snapshot = await _collection.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => Sermon.fromFirestore(doc)).toList();
  }

  @override
  Future<Sermon?> getSermon(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) {
      return Sermon.fromFirestore(doc);
    }
    return null;
  }

  @override
  Future<void> saveSermon(Sermon sermon) async {
    final data = sermon.toMap();
    if (sermon.id.isNotEmpty) {
      await _collection.doc(sermon.id).set(data, SetOptions(merge: true));
    } else {
      await _collection.add(data);
    }
  }

  @override
  Future<void> deleteSermon(String id) async {
    await _collection.doc(id).delete();
  }
}

final sermonServiceProvider = Provider<SermonService>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    return FirestoreSermonService(user.uid);
  }
  // Fallback ou erro pode ser tratado aqui, 
  // mas idealmente as telas de sermão têm AuthGuard
  throw Exception("Usuário não autenticado");
});
