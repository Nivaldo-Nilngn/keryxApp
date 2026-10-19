import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:keryx_app/features/outlines/model/outline_model.dart';

/// Erro amigável para mostrar ao usuário (nunca vaza chaves/detalhes internos).
class AiException implements Exception {
  final String userMessage;
  final Object? cause;
  AiException(this.userMessage, [this.cause]);
  @override
  String toString() => userMessage;
}

/// Perfil do usuário/igreja: versão da Bíblia e tradição teológica.
/// Salve isso nas configurações do app e atribua em `AiService.profile`.
class AiProfile {
  final String version; // NVI, ARA, ACF...
  final String tradition; // evangelica_geral, reformada, batista, pentecostal, assembleiana
  const AiProfile({this.version = 'NVI', this.tradition = 'evangelica_geral'});

  Map<String, dynamic> toJson() => {
        'version': version.toUpperCase(),
        'tradition': tradition,
      };
}

enum AiTask {
  outline('outline'),
  structuredSermon('structured_sermon'),
  strong('strong'),
  verseAnalysis('verse_analysis'),
  dictionary('dictionary'),
  chat('chat');

  final String wire;
  const AiTask(this.wire);
}

class AiService {
  AiService({this.authTokenProvider});

  /// Ex.: () async => await FirebaseAuth.instance.currentUser?.getIdToken()
  /// O Worker deve validar esse token e aplicar limite por usuário.
  final Future<String?> Function()? authTokenProvider;

  /// Perfil global (versão + tradição). Atualize quando o usuário mudar nas configurações.
  static AiProfile profile = const AiProfile();

  static const String _workerUrl =
      'https://biblia-ia-esboco.nivaldo-nilngn.workers.dev';

  /// Defina no arquivo .env
  static String get _appToken => dotenv.env['APP_TOKEN'] ?? '';

  // Cache LRU em memória (máx. 100 itens). Só para tarefas determinísticas.
  static const int _cacheMax = 100;
  static final LinkedHashMap<String, String> _cache = LinkedHashMap();

  // ---------------------------------------------------------------------------
  // API pública (mesmas assinaturas de antes, para não quebrar o app)
  // ---------------------------------------------------------------------------

  Future<String> generateOutline(BibleOutline outline,
      {String? additionalData, String? verseText}) {
    final context = StringBuffer()
      ..writeln('Título: ${outline.title}')
      ..writeln('Tema central: ${outline.theme}')
      ..writeln('Referência: ${outline.reference}');
    if (additionalData != null && additionalData.trim().isNotEmpty) {
      context.writeln('Observações do pregador: $additionalData');
    }
    return generateSermonDraftFromWorker(
      context.toString(),
      verseText: verseText,
    );
  }

  /// [verseText]: passe o texto REAL do banco local (SQLite). Assim a IA
  /// não cita a Bíblia "de memória" (que erra e mistura versões).
  Future<String> generateSermonDraftFromWorker(
    String text, {
    int? bookId,
    int? chapter,
    int? verse,
    String? version,
    String? verseText,
  }) {
    final input = StringBuffer(text);
    if (verseText != null && verseText.trim().isNotEmpty) {
      input
        ..writeln()
        ..writeln('TEXTO BÍBLICO (use exatamente este texto):')
        ..writeln(verseText);
    }
    return _ask(
      AiTask.outline,
      input.toString(),
      versionOverride: version,
      extra: {'book_id': bookId, 'chapter': chapter, 'verse': verse},
      cache: true,
      timeout: const Duration(seconds: 45),
    );
  }

  /// Sermão estruturado REAL em JSON (antes retornava conteúdo falso).
  Future<String> generateStructuredSermon({
    required String theme,
    required String reference,
    String? verseText,
  }) async {
    final input = 'Tema: $theme\nPassagem: $reference'
        '${verseText != null ? '\nTEXTO BÍBLICO:\n$verseText' : ''}';
    final raw = await _ask(
      AiTask.structuredSermon,
      input,
      cache: true,
      timeout: const Duration(seconds: 60),
    );
    try {
      final cleaned =
          raw.replaceAll(RegExp(r'^```(?:json)?|```$', multiLine: true), '').trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      for (final k in ['title', 'introduction', 'points', 'conclusion']) {
        if (!json.containsKey(k)) throw FormatException('faltou "$k"');
      }
      return jsonEncode(json);
    } catch (e) {
      throw AiException(
          'A IA retornou um formato inválido. Tente gerar novamente.', e);
    }
  }

  Future<String> translateStrong(String entry) async {
    // Sem tradução ainda. Ideal: usar um léxico Strong em PT no SQLite.
    return entry;
  }

  /// [lexiconData]: passe a entrada REAL do léxico Strong (do seu banco) —
  /// a IA só explica/aplica, não inventa etimologia.
  Future<String> getStrongDefinition(String strongTag, String verseContext,
      {String? lexiconData}) async {
    try {
      return await _ask(
        AiTask.strong,
        'Número Strong: $strongTag\n'
        'Contexto do versículo: $verseContext\n'
        '${lexiconData != null ? 'Dados do léxico:\n$lexiconData' : 'Dados do léxico: (não fornecidos)'}',
        cache: true,
      );
    } on AiException catch (e) {
      return e.userMessage;
    }
  }

  Future<String> analyzeVerseTheology(String reference, String text) async {
    try {
      return await _ask(
        AiTask.verseAnalysis,
        'Referência: $reference\nTexto: $text',
        cache: true,
      );
    } on AiException catch (e) {
      return e.userMessage;
    }
  }

  Future<String?> getDictionarySummary(String word) async {
    try {
      return await _ask(AiTask.dictionary, word, cache: true);
    } on AiException catch (e) {
      if (kDebugMode) debugPrint('AI Dictionary: ${e.cause ?? e}');
      return null;
    }
  }

  Future<String> askAssistant(String message,
      {List<Map<String, String>>? history}) async {
    try {
      return await _ask(
        AiTask.chat,
        message,
        history: _trimHistory(history),
      );
    } on AiException catch (e) {
      return e.userMessage;
    }
  }

  Stream<String> askAssistantStream(String message,
      {List<Map<String, String>>? history}) async* {
    try {
      yield* _askStream(
        AiTask.chat,
        message,
        history: _trimHistory(history),
      );
    } on AiException catch (e) {
      yield e.userMessage;
    } catch (e) {
      yield 'Ocorreu um erro ao processar sua pergunta.';
    }
  }

  // ---------------------------------------------------------------------------
  // Núcleo: uma única função que fala com o Worker
  // ---------------------------------------------------------------------------

  List<Map<String, String>> _trimHistory(List<Map<String, String>>? h) {
    if (h == null) return const [];
    final last = h.length > 10 ? h.sublist(h.length - 10) : h;
    return last
        .map((m) => {
              'role': m['role'] == 'assistant' ? 'assistant' : 'user',
              'content': (m['content'] ?? '').length > 2000
                  ? m['content']!.substring(0, 2000)
                  : (m['content'] ?? ''),
            })
        .toList();
  }

  Stream<String> _askStream(
    AiTask task,
    String input, {
    List<Map<String, String>>? history,
    Map<String, dynamic>? extra,
  }) async* {
    final p = profile;

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_appToken.isNotEmpty) headers['X-App-Token'] = _appToken;
    final token = await authTokenProvider?.call();
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final body = jsonEncode({
      'action': 'ai',
      'task': task.wire,
      'input': input,
      'history': history ?? const [],
      'profile': p.toJson(),
      'stream': true,
      if (extra != null) ...extra,
    });

    final req = http.Request('POST', Uri.parse(_workerUrl));
    req.headers.addAll(headers);
    req.body = body;

    final res = await http.Client().send(req).timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw AiException('Falha ao conectar com a IA (HTTP ${res.statusCode}).');
    }

    final stream = res.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in stream) {
      if (line.startsWith('data: ')) {
        final data = line.substring(6).trim();
        if (data == '[DONE]') break;
        if (data.isEmpty) continue;
        try {
          final json = jsonDecode(data);
          final content = json['choices']?[0]?['delta']?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } catch (_) {}
      }
    }
  }

  Future<String> _ask(
    AiTask task,
    String input, {
    List<Map<String, String>>? history,
    Map<String, dynamic>? extra,
    String? versionOverride,
    bool cache = false,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final p = versionOverride == null
        ? profile
        : AiProfile(version: versionOverride, tradition: profile.tradition);

    final cacheKey = cache
        ? '${task.wire}|${p.version}|${p.tradition}|${input.hashCode}|${input.length}'
        : null;
    if (cacheKey != null && _cache.containsKey(cacheKey)) {
      final v = _cache.remove(cacheKey)!; // move para o fim (LRU)
      _cache[cacheKey] = v;
      return v;
    }

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_appToken.isNotEmpty) headers['X-App-Token'] = _appToken;
    final token = await authTokenProvider?.call();
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final body = jsonEncode({
      'action': 'ai',
      'task': task.wire,
      'input': input,
      'history': history ?? const [],
      'profile': p.toJson(),
      if (extra != null) ...extra,
    });

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .post(Uri.parse(_workerUrl), headers: headers, body: body)
            .timeout(timeout);

        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          final text = (data['response'] as String?)?.trim() ?? '';
          if (text.isEmpty) {
            throw AiException('A IA não retornou resposta. Tente novamente.');
          }
          if (cacheKey != null) {
            _cache[cacheKey] = text;
            if (_cache.length > _cacheMax) _cache.remove(_cache.keys.first);
          }
          return text;
        }
        if (res.statusCode == 429) {
          throw AiException(
              'Você fez muitas solicitações. Aguarde um pouco e tente de novo.');
        }
        if (res.statusCode >= 500 && attempt == 0) {
          lastError = 'HTTP ${res.statusCode}';
          await Future.delayed(const Duration(milliseconds: 800));
          continue;
        }
        throw AiException(
            'Não foi possível consultar a IA agora. Tente novamente mais tarde.',
            'HTTP ${res.statusCode}');
      } on AiException {
        rethrow;
      } on TimeoutException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e;
        if (attempt == 0) await Future.delayed(const Duration(milliseconds: 800));
      }
    }
    if (kDebugMode) debugPrint('AiService falhou: $lastError');
    throw AiException(
        'Sem conexão ou tempo esgotado. Verifique sua internet e tente novamente.',
        lastError);
  }
}