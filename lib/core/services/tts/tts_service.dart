import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'web_tts_helper.dart';

final ttsServiceProvider = Provider<TTSService>((ref) {
  return TTSService();
});

final ttsVoicesProvider = FutureProvider<List<Map<String, String>>>((ref) async {
  final service = ref.read(ttsServiceProvider);
  return await service.getPortugueseVoices();
});

final ttsSelectedVoiceProvider = StateNotifierProvider<TTSVoiceNotifier, Map<String, String>?>((ref) {
  return TTSVoiceNotifier();
});

class TTSVoiceNotifier extends StateNotifier<Map<String, String>?> {
  TTSVoiceNotifier() : super(null) {
    _loadSelectedVoice();
  }

  Future<void> _loadSelectedVoice() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('tts_voice_name');
    final locale = prefs.getString('tts_voice_locale');
    if (name != null && locale != null) {
      state = {'name': name, 'locale': locale};
    }
  }

  Future<void> selectVoice(Map<String, String> voice) async {
    state = voice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tts_voice_name', voice['name'] ?? '');
    await prefs.setString('tts_voice_locale', voice['locale'] ?? '');
  }
}

final ttsRateProvider = StateNotifierProvider<TTSRateNotifier, double>((ref) {
  return TTSRateNotifier(ref);
});

class TTSRateNotifier extends StateNotifier<double> {
  final Ref ref;
  TTSRateNotifier(this.ref) : super(0.45) {
    _loadRate();
  }
  Future<void> _loadRate() async {
    final prefs = await SharedPreferences.getInstance();
    final rate = prefs.getDouble('tts_speech_rate');
    if (rate != null) {
      state = rate;
      ref.read(ttsServiceProvider).setSpeechRate(rate);
    }
  }
  Future<void> setRate(double rate) async {
    state = rate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_speech_rate', rate);
    ref.read(ttsServiceProvider).setSpeechRate(rate);
  }
}

final ttsPitchProvider = StateNotifierProvider<TTSPitchNotifier, double>((ref) {
  return TTSPitchNotifier(ref);
});

class TTSPitchNotifier extends StateNotifier<double> {
  final Ref ref;
  TTSPitchNotifier(this.ref) : super(0.9) {
    _loadPitch();
  }
  Future<void> _loadPitch() async {
    final prefs = await SharedPreferences.getInstance();
    final pitch = prefs.getDouble('tts_pitch');
    if (pitch != null) {
      state = pitch;
      ref.read(ttsServiceProvider).setPitch(pitch);
    }
  }
  Future<void> setPitch(double pitch) async {
    state = pitch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_pitch', pitch);
    ref.read(ttsServiceProvider).setPitch(pitch);
  }
}

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();

  TTSService() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (_) {}

    if (kIsWeb) {
      try {
        await _flutterTts.setLanguage("pt-BR");
        await _flutterTts.setSpeechRate(1.0);
        await _flutterTts.setPitch(1.0);
      } catch (_) {}
      return;
    }

    try {
      final defaultEngine = await _flutterTts.getDefaultEngine;
      debugPrint("🗣️ TTS: Motor padrão: $defaultEngine");
    } catch (e) {
      debugPrint("🗣️ TTS: Erro ao consultar motor padrão: $e");
    }

    try {
      await _flutterTts.setLanguage("pt-BR");
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint("🗣️ TTS: Erro ao inicializar parâmetros básicos: $e");
    }
  }

  Future<List<Map<String, String>>> getPortugueseVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      List<Map<String, String>> ptVoices = [];
      
      if (voices != null) {
        for (var voice in voices) {
          final locale = voice["locale"] as String? ?? "";
          final name = voice["name"] as String? ?? "";
          if (locale.toLowerCase().contains("pt-br") && !name.toLowerCase().contains("pt-pt")) {
            ptVoices.add({
              "name": name,
              "locale": locale,
            });
          }
        }
      }
      // Sort: Offline voices first, then Online
      ptVoices.sort((a, b) {
        final aName = a['name']!.toLowerCase();
        final bName = b['name']!.toLowerCase();
        final aIsNetwork = aName.contains('network') || aName.contains('online');
        final bIsNetwork = bName.contains('network') || bName.contains('online');
        if (aIsNetwork && !bIsNetwork) return 1;
        if (!aIsNetwork && bIsNetwork) return -1;
        return aName.compareTo(bName);
      });
      return ptVoices;
    } catch (e) {
      debugPrint("Erro ao carregar vozes: $e");
      return [];
    }
  }

  Future<void> speak(String text, {Map<String, String>? voice}) async {
    await speakAndWait(text, voice: voice);
  }

  bool _isStopped = false;

  Future<void> speakAndWait(String text, {Map<String, String>? voice}) async {
    _isStopped = false;
    final clean = text.trim();
    if (clean.isEmpty) return;

    if (voice == null && !kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final name = prefs.getString('tts_voice_name');
        final locale = prefs.getString('tts_voice_locale');
        if (name != null && locale != null && name.isNotEmpty) {
          voice = {'name': name, 'locale': locale};
        }
      } catch (_) {}
    }

    try {
      if (voice != null && !kIsWeb) {
        await _flutterTts.setLanguage(voice['locale'] ?? 'pt-BR');
        if (voice['name'] != null && voice['locale'] != null) {
          await _flutterTts.setVoice({"name": voice['name']!, "locale": voice['locale']!});
        }
      } else {
        final langResult = await _flutterTts.setLanguage("pt-BR");
        if (langResult == 0) {
          await _flutterTts.setLanguage("pt");
        }
      }
      await _flutterTts.setVolume(1.0);

      // Aplica taxa de fala e pitch salvos
      final prefs = await SharedPreferences.getInstance();
      final rate = prefs.getDouble('tts_speech_rate');
      if (rate != null) {
        await _flutterTts.setSpeechRate(rate);
      }
      final pitch = prefs.getDouble('tts_pitch');
      if (pitch != null) {
        await _flutterTts.setPitch(pitch);
      }
    } catch (e) {
      debugPrint("🗣️ TTS: Erro ao aplicar voz/taxa: $e");
      try {
        await _flutterTts.setLanguage("pt-BR");
        await _flutterTts.setVolume(1.0);
      } catch (_) {}
    }

    var speechText = clean;
    if (speechText.length > 3900) {
      speechText = speechText.substring(0, 3900);
    }

    try {
      if (kIsWeb) {
        final completer = Completer<bool>();
        WebTtsHelper.speakQueue(
          texts: [speechText],
          onStart: () {},
          onFinished: () {
            if (!completer.isCompleted) completer.complete(true);
          },
          onError: () {
            if (!completer.isCompleted) completer.complete(false);
          },
        );
        bool success = await completer.future.timeout(
          const Duration(seconds: 45),
          onTimeout: () => false,
        );
        if (!success || _isStopped) throw Exception("TTS_FAILED");
      } else {
        final completer = Completer<void>();

        _flutterTts.setCompletionHandler(() {
          if (!completer.isCompleted) completer.complete();
        });
        _flutterTts.setCancelHandler(() {
          if (!completer.isCompleted) completer.complete();
        });
        _flutterTts.setErrorHandler((msg) {
          debugPrint("🗣️ TTS Erro retornado: $msg");
          if (!completer.isCompleted) completer.complete();
        });

        final result = await _flutterTts.speak(speechText, focus: true);
        if (result == 0 || result == false) {
          // Se falhou por estado interno, reseta e tenta mais uma vez
          await _flutterTts.stop();
          await Future.delayed(const Duration(milliseconds: 120));
          final retryResult = await _flutterTts.speak(speechText, focus: true);
          if (retryResult == 0 || retryResult == false) {
            throw Exception("TTS_FAILED");
          }
        }

        // Se o speak já retornou esperando a finalização, completer.isCompleted pode já ser true.
        // Se ainda não completou, aguarda com timeout de segurança.
        if (!completer.isCompleted) {
          final timeoutSeconds = (speechText.length / 5).clamp(5, 120).toInt();
          await completer.future.timeout(
            Duration(seconds: timeoutSeconds),
            onTimeout: () {
              debugPrint("🗣️ TTS: Timeout de fala atingido.");
            },
          );
        }

        if (_isStopped) {
          throw Exception("TTS_INTERRUPTED");
        }
      }
    } catch (e) {
      debugPrint("Erro no speakAndWait: $e");
      rethrow;
    }
  }

  Future<void> speakVerses(List<String> verses, {Map<String, String>? voice}) async {
    await stop();
    _isStopped = false;

    if (kIsWeb) {
      final completer = Completer<void>();
      WebTtsHelper.speakQueue(
        texts: verses,
        onStart: () {},
        onFinished: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: () {
          if (!completer.isCompleted) completer.complete();
        },
      );
      await completer.future;
      return;
    }

    for (final verse in verses) {
      if (_isStopped) break;
      final clean = verse.trim();
      if (clean.isEmpty) continue;

      try {
        await speakAndWait(clean, voice: voice);
      } catch (e) {
        if (_isStopped) break;
        debugPrint("🗣️ TTS: Erro no verso/parágrafo: $e");
      }

      if (_isStopped) break;
      // Pausa natural e agradável entre blocos/parágrafos
      await Future.delayed(const Duration(milliseconds: 260));
    }
  }

  Future<void> stop() async {
    _isStopped = true;
    if (kIsWeb) {
      WebTtsHelper.stop();
      return;
    }
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint("Erro no TTS stop: $e");
    }
  }

  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }
}
