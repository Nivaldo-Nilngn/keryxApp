import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/core/state/font_state.dart';

/// Notifier que gerencia a visibilidade da barra de controle de áudio (TTS)
/// na tela de leitura bíblica, persistindo a preferência do usuário.
class ReadingAudioBarNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  ReadingAudioBarNotifier(this._prefs) : super(_loadInitial(_prefs));

  static const String _prefKey = 'keryx_show_reading_audio_bar';

  static bool _loadInitial(SharedPreferences? prefs) {
    // Por padrão a barra de áudio é exibida (true), a menos que o usuário
    // decida ocultá-la para uma leitura bíblica imersiva.
    return prefs?.getBool(_prefKey) ?? true;
  }

  /// Alterna entre mostrar e ocultar a barra de áudio.
  Future<void> toggle() async {
    await setVisible(!state);
  }

  /// Define explicitamente se a barra de áudio deve ser exibida ou ocultada.
  Future<void> setVisible(bool visible) async {
    state = visible;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, visible);
    } catch (_) {}
  }
}

/// Provider para controlar a visibilidade da barra de áudio na leitura da Bíblia.
final showReadingAudioBarProvider =
    StateNotifierProvider<ReadingAudioBarNotifier, bool>((ref) {
  try {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ReadingAudioBarNotifier(prefs);
  } catch (_) {
    return ReadingAudioBarNotifier(null);
  }
});

