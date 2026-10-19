import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:tdlib/td_client.dart';
import 'package:tdlib/src/tdclient/platform_interfaces/td_native_plugin.dart' as td_native;

enum DownloadState { idle, resolving, downloading, completed, failed, canceled }

class DownloadProgress {
  final String fileId;
  final DownloadState state;
  final int downloadedBytes;
  final int totalBytes;
  final String? localPath;
  final String? error;

  const DownloadProgress({
    required this.fileId,
    required this.state,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.localPath,
    this.error,
  });

  /// 0.0 a 1.0
  double get fraction =>
      totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
}

class TelegramException implements Exception {
  final String message;
  final int? code;
  TelegramException(this.message, [this.code]);
  @override
  String toString() => 'TelegramException($code): $message';
}

/// Ponto de entrada do isolate que faz o tdReceive (chamada BLOQUEANTE).
void _receiveLoop(SendPort out) {
  try {
    td_native.TdNativePlugin.registerWith();
    TdPlugin.initialize('libtdjson.so');
    while (true) {
      final event = tdReceive(1.0);        // espera até 1s; retorna null se nada chegou
      if (event != null) out.send(event);
    }
  } catch (e, stack) {
    print("ISOLATE ERROR: $e\n$stack");
    out.send(e.toString());
  }
}

class TelegramDownloadService {
  TelegramDownloadService._();
  static final instance = TelegramDownloadService._();

  late String _apiHash;
  late String _botToken;
  late int _apiIdValue;

  int? _clientId;
  Isolate? _isolate;
  Completer<void> _ready = Completer<void>();
  bool _initStarted = false;

  // remoteFileId -> controller de progresso
  final Map<String, StreamController<DownloadProgress>> _controllers = {};
  // remoteFileId -> id local do TDLib
  final Map<String, int> _tdFileIds = {};
  // remoteFileId -> aguardando resolução do getRemoteFile
  final Map<String, Completer<td.File>> _resolvers = {};
  final Map<String, DateTime> _lastEmit = {};
  final Map<String, double> _lastFraction = {};
  final Map<String, String> _fileNames = {};

  final List<Completer<td.Messages>> _searchQueue = [];
  final List<String> _fileResolveQueue = [];
  final Map<String, String> _remoteIdToAlias = {};

  Future<void> ensureReady() async {
    if (!_initStarted) {
      throw TelegramException('TDLib não inicializado.');
    }
    await _ready.future;
  }

  Future<void> init({
    required int apiId,
    required String apiHash,
    required String botToken,
  }) async {
    if (_initStarted) return _ready.future;
    if (_ready.isCompleted) _ready = Completer<void>();
    _initStarted = true;

    try {
      _apiIdValue = apiId;
      _apiHash = apiHash;
      _botToken = botToken;

      try {
        final support = await getApplicationSupportDirectory();
        final tdlibDir = Directory('${support.path}/tdlib');
        if (tdlibDir.existsSync()) {
          tdlibDir.deleteSync(recursive: true);
        }
      } catch (_) {}

      await TdPlugin.initialize('libtdjson.so');
      _clientId = tdCreate();

      final rx = ReceivePort();
      _isolate = await Isolate.spawn(_receiveLoop, rx.sendPort);
      rx.listen(_onEvent);

      _send(const td.SetLogVerbosityLevel(newVerbosityLevel: 1));
      return await _ready.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          if (!_ready.isCompleted) {
            _ready.completeError(TelegramException('Timeout na autenticação MTProto'));
          }
          _isolate?.kill(priority: Isolate.immediate);
          _isolate = null;
          throw TelegramException('Timeout na autenticação MTProto');
        },
      );
    } catch (e) {
      if (!_ready.isCompleted) {
        _ready.completeError(TelegramException('Falha ao iniciar TDLib: $e'));
      }
      _initStarted = false;
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      throw TelegramException('Falha ao iniciar TDLib: $e');
    }
  }

  void _send(td.TdFunction f) => tdSend(_clientId!, f);

  // ---------------------------------------------------------------- eventos
  void _onEvent(dynamic event) {
    try {
      if (event is td.TdObject) {
         print("TDLib Raw: ${event.toJson()}");
      }
    } catch (_) {}

    if (event is td.UpdateAuthorizationState) {
      _onAuthState(event.authorizationState);
    } else if (event is td.UpdateFile) {
      _onFile(event.file, isDirectResponse: false);
    } else if (event is td.File) {
      _onFile(event, isDirectResponse: true);
    } else if (event is td.Messages) {
      if (_searchQueue.isNotEmpty) {
        _searchQueue.removeAt(0).complete(event);
      }
    } else if (event is td.TdError) {
      _onError(event);
    }
  }

  Future<void> _onAuthState(td.AuthorizationState s) async {
    print("onAuthState called with: $s");
    if (s is td.AuthorizationStateWaitTdlibParameters) {
      print("Getting support directory...");
      final support = await getApplicationSupportDirectory();
      print("Got support directory: ${support.path}");
      final sessionToken = DateTime.now().millisecondsSinceEpoch;
      
      final request = td.SetTdlibParameters(
        useTestDc: false,
        databaseDirectory: '${support.path}/tdlib_session_$sessionToken/db',
        filesDirectory: '${support.path}/tdlib_session_$sessionToken/files',
        databaseEncryptionKey: '',
        useFileDatabase: true,       // necessário p/ retomar downloads
        useChatInfoDatabase: true,
        useMessageDatabase: true,
        useSecretChats: false,
        apiId: _apiIdValue,
        apiHash: _apiHash,
        systemLanguageCode: 'pt-BR',
        deviceModel: 'Flutter',
        systemVersion: 'Android',
        applicationVersion: '1.0.0',
        enableStorageOptimizer: true,
        ignoreFileNames: false,
      );
      print("Sending SetTdlibParameters...");
      _send(request);
      print("SetTdlibParameters sent!");
    } else if (s is td.AuthorizationStateWaitPhoneNumber) {
      // Em vez de setAuthenticationPhoneNumber, o equivalente p/ bot:
      _send(td.CheckAuthenticationBotToken(token: _botToken));
    } else if (s is td.AuthorizationStateReady) {
      _send(const td.SetOption(
          name: 'use_storage_optimizer',
          value: td.OptionValueBoolean(value: true)));
      if (!_ready.isCompleted) _ready.complete();
    } else if (s is td.AuthorizationStateClosed) {
      if (!_ready.isCompleted) {
        _ready.completeError(TelegramException('Cliente TDLib fechado'));
      }
    }
  }

  void _onError(td.TdError e) {
    final err = TelegramException(e.message, e.code);
    if (!_ready.isCompleted) {
      _ready.completeError(err);       // ex.: 401 token inválido, API_ID errado
      return;
    }
    
    // Libera quem estiver aguardando busca
    for (final s in _searchQueue) {
      if (!s.isCompleted) s.completeError(err);
    }
    _searchQueue.clear();

    // Erro sem correlação: propaga a quem está aguardando resolução ou baixando
    for (final r in _resolvers.values) {
      if (!r.isCompleted) r.completeError(err);
    }
    _resolvers.clear();
    // Removido a emissão de falha global aqui para permitir que o catch() no _run() tente o fallback HTTP.
  }

  void _onFile(td.File file, {bool isDirectResponse = false}) async {
    final remoteId = file.remote.id;
    if (remoteId.isEmpty) return;
    
    // 1) resolução do getRemoteFile (apenas se for resposta direta)
    if (isDirectResponse && _fileResolveQueue.isNotEmpty) {
      final requestedId = _fileResolveQueue.removeAt(0);
      final resolver = _resolvers.remove(requestedId);
      if (resolver != null && !resolver.isCompleted) {
        resolver.complete(file);
      }
      // Se o remoteId retornado for diferente, atualizamos o mapeamento para os Updates futuros acharem!
      if (requestedId != remoteId) {
        _remoteIdToAlias[remoteId] = requestedId;
      }
    }

    // 2) só nos interessam arquivos que estamos acompanhando
    final aliasId = _remoteIdToAlias[remoteId] ?? remoteId;
    if (!_controllers.containsKey(aliasId)) return;
    _tdFileIds[aliasId] = file.id;

    final local = file.local;
    final total = file.size > 0 ? file.size : file.expectedSize;

    if (local.isDownloadingCompleted) {
      final fileName = _fileNames[aliasId] ?? 'Telegram_$aliasId.pdf';
      final docs = await getApplicationDocumentsDirectory();
      final pdfDir = Directory('${docs.path}/pdfs');
      if (!await pdfDir.exists()) await pdfDir.create(recursive: true);
      
      final finalFile = File('${pdfDir.path}/$fileName');
      if (!await finalFile.exists()) {
        try {
          await File(local.path).copy(finalFile.path);
        } catch (_) {}
      }

      _emit(aliasId, DownloadProgress(
        fileId: aliasId,
        state: DownloadState.completed,
        downloadedBytes: total,
        totalBytes: total,
        localPath: finalFile.path,
      ), force: true);
      return;
    }
    if (!local.isDownloadingActive && local.canBeDownloaded == false) {
      _emit(aliasId, DownloadProgress(
        fileId: aliasId, state: DownloadState.failed,
        error: 'Arquivo indisponível para download'), force: true);
      return;
    }
    _emit(aliasId, DownloadProgress(
      fileId: aliasId,
      state: DownloadState.downloading,
      downloadedBytes: local.downloadedSize,
      totalBytes: total,
    ));
  }

  /// Limita a taxa de emissão: evita rebuilds excessivos da UI em arquivos de 2GB.
  void _emit(String id, DownloadProgress p, {bool force = false}) {
    final c = _controllers[id];
    if (c == null || c.isClosed) return;
    final now = DateTime.now();
    final last = _lastEmit[id];
    final lastFrac = _lastFraction[id] ?? -1;
    final mustEmit = force ||
        p.state != DownloadState.downloading ||
        last == null ||
        now.difference(last).inMilliseconds >= 200 ||
        (p.fraction - lastFrac) >= 0.005;
    if (!mustEmit) return;
    _lastEmit[id] = now;
    _lastFraction[id] = p.fraction;
    c.add(p);
  }

  // ------------------------------------------------------------------- API
  /// Inicia o download e devolve o stream de progresso desse arquivo.
  Stream<DownloadProgress> startPdfDownload(String fileId, String fileName) {
    if (!_ready.isCompleted) {
      throw TelegramException('TDLib não autenticado. Chame init() antes.');
    }
    final existing = _controllers[fileId];
    if (existing != null && !existing.isClosed) return existing.stream;

    final controller = StreamController<DownloadProgress>.broadcast();
    _controllers[fileId] = controller;
    _run(fileId, fileName);
    return controller.stream;
  }



  Future<void> _run(String fileId, String fileName, {String? aliasId}) async {
    final emitId = aliasId ?? fileId;
    _fileNames[emitId] = fileName;
    try {
      if (aliasId == null) {
        _emit(emitId, DownloadProgress(
          fileId: emitId, state: DownloadState.resolving), force: true);
      }

      final resolver = Completer<td.File>();
      print("TDLib _run: Enviando GetRemoteFile com fileId = '$fileId'");
      _fileResolveQueue.add(fileId);
      _resolvers[fileId] = resolver;
      _send(td.GetRemoteFile(remoteFileId: fileId, fileType: const td.FileTypeDocument()));
      final file = await resolver.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TelegramException(
            'Timeout ao resolver file_id (bot errado ou sem rede?)'),
      );

      _tdFileIds[fileId] = file.id;
      _send(td.DownloadFile(
        fileId: file.id,
        priority: 32,       // 1..32; maior = prioridade
        offset: 0,
        limit: 0,           // 0 = arquivo inteiro
        synchronous: false, // retorna já; o progresso vem via UpdateFile
      ));
    } catch (e) {
      // FALBACK: HTTP Bot API (limite 20MB)
      try {
        print("TDLib falhou, tentando fallback HTTP: $e");
        final apiUrl = Uri.parse('https://api.telegram.org/bot$_botToken/getFile?file_id=$fileId');
        final res = await http.get(apiUrl);
        final jsonResponse = jsonDecode(res.body);
        if (jsonResponse['ok'] == true) {
           final filePath = jsonResponse['result']['file_path'];
           final downloadUrl = Uri.parse('https://api.telegram.org/file/bot$_botToken/$filePath');
           
           final expectedSize = jsonResponse['result']['file_size'] ?? 1;
           _emit(emitId, DownloadProgress(
             fileId: emitId, state: DownloadState.downloading, downloadedBytes: 0, totalBytes: expectedSize), force: true);
             
           final request = http.Request('GET', downloadUrl);
           final streamedResponse = await http.Client().send(request);
           
           if (streamedResponse.statusCode == 200) {
             final contentLength = streamedResponse.contentLength ?? expectedSize;
             int downloadedBytes = 0;
             
             final docs = await getApplicationDocumentsDirectory();
             final dir = Directory('${docs.path}/pdfs');
             if (!await dir.exists()) await dir.create(recursive: true);
             final localFile = File('${dir.path}/$fileName');
             final sink = localFile.openWrite();
             
             await for (final chunk in streamedResponse.stream) {
               sink.add(chunk);
               downloadedBytes += chunk.length;
               
               _emit(emitId, DownloadProgress(
                 fileId: emitId, 
                 state: DownloadState.downloading, 
                 downloadedBytes: downloadedBytes, 
                 totalBytes: contentLength,
               ));
             }
             
             await sink.flush();
             await sink.close();
             
             _emit(emitId, DownloadProgress(
               fileId: emitId, 
               state: DownloadState.completed, 
               downloadedBytes: downloadedBytes, 
               totalBytes: downloadedBytes,
               localPath: localFile.path
             ), force: true);
             return;
           } else {
             throw Exception('Erro HTTP: ${streamedResponse.statusCode}');
           }
        } else {
           throw Exception(jsonResponse['description'] ?? 'Erro desconhecido da API');
        }
      } catch (httpError) {
        _emit(emitId, DownloadProgress(
          fileId: emitId, state: DownloadState.failed, error: 'TDLib: $e | HTTP: $httpError'),
          force: true);
      }
    }
  }

  void cancel(String fileId) {
    final id = _tdFileIds[fileId];
    if (id != null) {
      _send(td.CancelDownloadFile(fileId: id, onlyIfPending: false));
    }
    _emit(fileId, DownloadProgress(
        fileId: fileId, state: DownloadState.canceled), force: true);
  }

  /// Libera o espaço da cópia interna do TDLib (após copiar para Downloads).
  void deleteInternalCopy(String fileId) {
    final id = _tdFileIds[fileId];
    if (id != null) _send(td.DeleteFile(fileId: id));
  }

  void release(String fileId) {
    _controllers.remove(fileId)?.close();
    _tdFileIds.remove(fileId);
    _lastEmit.remove(fileId);
    _lastFraction.remove(fileId);
  }

  Future<void> dispose() async {
    _isolate?.kill(priority: Isolate.immediate);
    for (final c in _controllers.values) {
      await c.close();
    }
  }
}
