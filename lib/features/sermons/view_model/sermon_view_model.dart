import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/sermon_model.dart';
import '../services/sermon_service.dart';

class SermonListNotifier extends StateNotifier<AsyncValue<List<Sermon>>> {
  final SermonService _service;

  SermonListNotifier(this._service) : super(const AsyncValue.loading()) {
    loadSermons();
  }

  Future<void> loadSermons() async {
    state = const AsyncValue.loading();
    try {
      final sermons = await _service.getSermons();
      state = AsyncValue.data(sermons);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addSermon(Sermon sermon) async {
    try {
      await _service.saveSermon(sermon);
      await loadSermons();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> updateSermon(Sermon sermon) async {
    try {
      await _service.saveSermon(sermon);
      await loadSermons();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> deleteSermon(String id) async {
    try {
      await _service.deleteSermon(id);
      await loadSermons();
    } catch (e) {
      // Handle error
    }
  }
}

final sermonListProvider = StateNotifierProvider<SermonListNotifier, AsyncValue<List<Sermon>>>((ref) {
  final service = ref.watch(sermonServiceProvider);
  return SermonListNotifier(service);
});

// Provider for a single sermon by ID
final sermonProvider = FutureProvider.family<Sermon?, String>((ref, id) async {
  final service = ref.watch(sermonServiceProvider);
  return service.getSermon(id);
});
