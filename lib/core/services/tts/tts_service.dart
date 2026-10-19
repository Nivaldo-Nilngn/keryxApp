import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

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
    await _flutterTts.awaitSpeakCompletion(true); // REQUIRED so speak() awaits on Web/Android

    if (kIsWeb) {
      await _flutterTts.setLanguage("pt-BR");
      await _flutterTts.setSpeechRate(1.0); // 1.0 é o normal na Web
      await _flutterTts.setPitch(1.0);
      return;
    }

    // Check available engines
    try {
      final engines = await _flutterTts.getEngines;
      debugPrint("🗣️ TTS: Motores disponíveis: $engines");
      final defaultEngine = await _flutterTts.getDefaultEngine;
      debugPrint("🗣️ TTS: Motor padrão atual: $defaultEngine");
    } catch (e) {
      debugPrint("🗣️ TTS: Erro ao buscar motores: $e");
    }

    // Try to force Google TTS engine for higher quality voices if available
    try {
      await _flutterTts.setEngine("com.google.android.tts");
    } catch (e) {
      debugPrint("Engine Google TTS não encontrada, usando padrão.");
    }
    
    await _flutterTts.setLanguage("pt-BR");
    // Configurações padrão para uma voz mais realista e serena (leitura bíblica)
    await _flutterTts.setSpeechRate(0.45); // Um pouco mais lento
    await _flutterTts.setPitch(0.9); // Um pouco mais grave/profundo
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Optional: await _flutterTts.setQueueMode(1);
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
          // O locale as vezes vem como pt-BR mas a engine retorna vozes pt-PT, então filtramos pelo nome também
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
    // If no voice was explicitly passed, try to fetch it from SharedPreferences
    if (voice == null) {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('tts_voice_name');
      final locale = prefs.getString('tts_voice_locale');
      if (name != null && locale != null && name.isNotEmpty) {
        voice = {'name': name, 'locale': locale};
      }
    }

    if (voice != null) {
      debugPrint("🗣️ TTS: Configurando voz selecionada -> ${voice['name']} (${voice['locale']})");
      try {
        await _flutterTts.setLanguage(voice['locale']!);
        await _flutterTts.setVoice({"name": voice['name']!, "locale": voice['locale']!});
      } catch (e) {
        debugPrint("🗣️ TTS: Erro ao configurar voz: $e");
      }
    } else {
      debugPrint("🗣️ TTS: Nenhuma voz selecionada, usando pt-BR padrão");
      await _flutterTts.setLanguage("pt-BR");
    }
    
    debugPrint("🗣️ TTS: Texto a ser lido (${text.length} caracteres): ${text.substring(0, text.length > 50 ? 50 : text.length)}...");
    
    // Chunking text if it's too long, as Android TTS fails silently on very long texts.
    if (text.length > 3900) {
      text = text.substring(0, 3900);
    }
    
    await _flutterTts.speak(text);
  }

  bool _isStopped = false;

  Future<void> speakAndWait(String text, {Map<String, String>? voice}) async {
    _isStopped = false;
    
    if (voice == null && !kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('tts_voice_name');
      final locale = prefs.getString('tts_voice_locale');
      if (name != null && locale != null && name.isNotEmpty) {
        voice = {'name': name, 'locale': locale};
      }
    }

    if (voice != null && !kIsWeb) {
      try {
        await _flutterTts.setLanguage(voice['locale']!);
        await _flutterTts.setVoice({"name": voice['name']!, "locale": voice['locale']!});
      } catch (e) {}
    } else {
      await _flutterTts.setLanguage("pt-BR");
    }

    if (text.trim().isEmpty) return;

    if (text.length > 3900) {
      text = text.substring(0, 3900);
    }
    
    try {
      if (kIsWeb) {
        Completer<bool> completer = Completer<bool>();
        _flutterTts.setCompletionHandler(() {
          if (!completer.isCompleted) completer.complete(true);
        });
        _flutterTts.setErrorHandler((msg) {
          if (!completer.isCompleted) completer.complete(false);
        });
        _flutterTts.speak(text);
        bool success = await completer.future;
        if (!success || _isStopped) throw Exception("TTS_FAILED");
      } else {
        final result = await _flutterTts.speak(text);
        if (result == 0 || result == false) {
           throw Exception("TTS_FAILED");
        }
        if (_isStopped) {
           throw Exception("TTS_INTERRUPTED");
        }
      }
    } catch (e) {
      debugPrint("Erro no speakAndWait: $e");
      throw Exception("TTS_INTERRUPTED");
    }
  }

  Future<void> speakVerses(List<String> verses, {Map<String, String>? voice}) async {
    await stop(); // Para qualquer leitura anterior
    _isStopped = false;
    
    if (voice == null && !kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('tts_voice_name');
      final locale = prefs.getString('tts_voice_locale');
      if (name != null && locale != null && name.isNotEmpty) {
        voice = {'name': name, 'locale': locale};
      }
    }

    if (voice != null && !kIsWeb) {
      debugPrint("🗣️ TTS: Configurando voz selecionada -> ${voice['name']} (${voice['locale']})");
      try {
        await _flutterTts.setLanguage(voice['locale']!);
        await _flutterTts.setVoice({"name": voice['name']!, "locale": voice['locale']!});
        // Pequeno delay para garantir que o Android carregue a voz antes de falar
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint("🗣️ TTS: Erro ao configurar voz: $e");
      }
    } else {
      await _flutterTts.setLanguage("pt-BR");
    }

    if (kIsWeb) {
      // Na Web, o motor de TTS tem limite de caracteres e engasga em textos longos.
      // Além disso, ele possui uma fila interna. Portanto, enviamos cada versículo
      // separadamente para a fila do navegador. O stop() limpa a fila.
      for (String verse in verses) {
        if (verse.trim().isNotEmpty) {
          await _flutterTts.speak(verse);
        }
      }
      return;
    }

    String fullText = verses.join(". ");
    
    // Regex para dividir o texto em blocos de no máximo 3500 caracteres,
    // tentando cortar em pontos finais.
    List<String> chunks = [];
    int maxChunkSize = 3500;
    int start = 0;
    
    while (start < fullText.length) {
      int end = start + maxChunkSize;
      if (end >= fullText.length) {
        chunks.add(fullText.substring(start));
        break;
      }
      
      // Procura o último ponto final dentro do limite
      int lastDot = fullText.lastIndexOf('.', end);
      if (lastDot > start) {
        chunks.add(fullText.substring(start, lastDot + 1));
        start = lastDot + 1;
      } else {
        // Se não houver ponto, corta no limite mesmo
        chunks.add(fullText.substring(start, end));
        start = end;
      }
    }

    // Usar Completer para aguardar cada chunk de forma robusta no Android/iOS
    for (int i = 0; i < chunks.length; i++) {
      if (_isStopped) break;
      String chunk = chunks[i].trim();
      if (chunk.isEmpty) continue;
      
      Completer<void> completer = Completer<void>();
      
      _flutterTts.setCompletionHandler(() {
        if (!completer.isCompleted) completer.complete();
      });
      
      _flutterTts.setErrorHandler((msg) {
        debugPrint("🗣️ TTS: Erro no chunk $i: $msg");
        if (!completer.isCompleted) completer.complete();
      });

      await _flutterTts.speak(chunk);
      
      // Aguarda até o chunk terminar (ou erro)
      await completer.future;
    }
  }

  Future<void> stop() async {
    _isStopped = true;
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
