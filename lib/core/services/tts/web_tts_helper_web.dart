// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class WebTtsHelper {
  static bool get isSupported => html.window.speechSynthesis != null;
  static Timer? _keepAliveTimer;

  static void speakQueue({
    required List<String> texts,
    required VoidCallback onStart,
    required VoidCallback onFinished,
    required VoidCallback onError,
  }) {
    final synth = html.window.speechSynthesis;
    if (synth == null) {
      onError();
      return;
    }

    // Limpa reprodução anterior antes de iniciar a nova fila
    stop();

    final validTexts = texts
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (validTexts.isEmpty) {
      onFinished();
      return;
    }

    try {
      synth.resume();

      // Procura a melhor voz em português disponível no navegador
      final voices = synth.getVoices();
      html.SpeechSynthesisVoice? ptVoice;
      if (voices.isNotEmpty) {
        for (final v in voices) {
          final lang = (v.lang ?? '').toLowerCase();
          if (lang.contains('pt-br') || lang.contains('pt_br')) {
            ptVoice = v;
            break;
          }
        }
        if (ptVoice == null) {
          for (final v in voices) {
            final lang = (v.lang ?? '').toLowerCase();
            if (lang.startsWith('pt')) {
              ptVoice = v;
              break;
            }
          }
        }
      }

      onStart();

      for (int i = 0; i < validTexts.length; i++) {
        final text = validTexts[i];
        final isLast = (i == validTexts.length - 1);
        final utterance = html.SpeechSynthesisUtterance(text);
        utterance.lang = ptVoice?.lang ?? 'pt-BR';
        utterance.rate = 1.0;
        utterance.pitch = 1.0;
        utterance.volume = 1.0;
        if (ptVoice != null) {
          utterance.voice = ptVoice;
        }

        if (isLast) {
          utterance.onEnd.listen((_) {
            _keepAliveTimer?.cancel();
            onFinished();
          });
        }

        utterance.onError.listen((e) {
          final errStr = (e as dynamic).error?.toString() ?? '';
          debugPrint("🗣️ Web TTS Error evento no bloco $i: $errStr");
          // Cancelamentos intencionais ou interrupções de stop() não são falhas
          if (errStr != 'canceled' && errStr != 'interrupted') {
            _keepAliveTimer?.cancel();
            onError();
          }
        });

        synth.speak(utterance);
      }

      // Keep-alive a cada 10s para o Chromium não pausar áudios com mais de 15 segundos
      _keepAliveTimer?.cancel();
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (synth.speaking == true) {
          synth.pause();
          synth.resume();
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      debugPrint("🗣️ Erro ao disparar Web TTS queue: $e");
      onError();
    }
  }

  static void stop() {
    _keepAliveTimer?.cancel();
    try {
      final synth = html.window.speechSynthesis;
      synth?.cancel();
    } catch (_) {}
  }
}
