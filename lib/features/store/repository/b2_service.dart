import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class B2Service {
  static String get _keyId => dotenv.env['B2_KEY_ID'] ?? '';
  static String get _applicationKey => dotenv.env['B2_APPLICATION_KEY'] ?? '';
  static String get _bucketName => dotenv.env['B2_BUCKET_NAME'] ?? 'igreja-imagens';
  
  String? _authorizationToken;
  String? _accountId;
  String? _apiUrl;
  String? _bucketId;
  DateTime? _tokenExpiry;
  
  // Remove BOM (Byte Order Mark) se presente
  String _removeBOM(String str) {
    if (str.startsWith('\uFEFF')) {
      debugPrint('⚠️ BOM detectado e removido');
      return str.substring(1);
    }
    return str;
  }
  
  // Converte bytes para string tratando BOM
  String _bytesToString(Uint8List bytes) {
    String str = utf8.decode(bytes);
    return _removeBOM(str);
  }
  
  // Autentica no B2 e obtém token de autorização
  Future<void> _authenticate() async {
    debugPrint('🔐 Autenticando no Backblaze B2...');
    debugPrint('   KeyID: ${_keyId.isNotEmpty ? "✅ configurado" : "❌ vazio"}');
    debugPrint('   AppKey: ${_applicationKey.isNotEmpty ? "✅ configurado" : "❌ vazio"}');
    debugPrint('   Bucket (esperado): $_bucketName');
    debugPrint('   Using BucketName: $_bucketName');
    
    if (_keyId.isEmpty || _applicationKey.isEmpty) {
      throw Exception('B2 credentials not configured. Set B2_KEY_ID and B2_APPLICATION_KEY in .env');
    }
    
    if (_authorizationToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      debugPrint('✅ Token ainda válido, reutilizando');
      return;
    }
    
    debugPrint('📡 Solicitando novo token...');
    
    final response = await http.get(
      Uri.parse('https://api.backblaze.com/b2api/v2/b2_authorize_account'),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$_keyId:$_applicationKey'))}',
      },
    );
    
    debugPrint('   Status: ${response.statusCode}');
    
    if (response.statusCode != 200) {
      debugPrint('❌ Erro completo: ${response.body}');
      try {
        String cleanBody = _bytesToString(response.bodyBytes);
        final errorData = json.decode(cleanBody);
        final message = errorData['message'] ?? 'Sem mensagem';
        throw Exception('Falha ao autenticar no B2: ${response.statusCode} - $message');
      } catch (e) {
        throw Exception('Falha ao autenticar no B2: ${response.statusCode}');
      }
    }
    
    try {
      String body = _bytesToString(response.bodyBytes);
      final data = json.decode(body);
      _authorizationToken = data['authorizationToken'];
      _accountId = data['accountId'];
      _apiUrl = data['apiUrl'];
      // Extrair bucketId das permissões
      final allowed = data['allowed'];
      if (allowed != null && allowed['bucketId'] != null) {
        _bucketId = allowed['bucketId'];
        debugPrint('✅ BucketId extraído das permissões: $_bucketId');
      }
      final minimumTTL = data['minimumTTL'] ?? 86400;
      _tokenExpiry = DateTime.now().add(Duration(seconds: minimumTTL - 60));
      debugPrint('✅ Autenticado com sucesso! Token válido por ~${minimumTTL ~/ 60} minutos');
    } catch (e) {
      debugPrint('❌ Erro ao decodificar JSON: $e');
      rethrow;
    }
  }
  
  // Gera URL de download para um arquivo
  Future<String> getDownloadUrl(String fileName) async {
    if (_keyId.isEmpty || _applicationKey.isEmpty) {
      return 'https://example.com/commentaries/$fileName';
    }
    
    await _authenticate();
    
    // Transformar api00X.backblazeb2.com em f00X.backblazeb2.com/file
    String downloadUrl = _apiUrl ?? 'https://f000.backblazeb2.com';
    downloadUrl = downloadUrl.replaceAll('api00', 'f00');
    if (!downloadUrl.contains('/file')) {
      downloadUrl = '$downloadUrl/file';
    }
    
    // Codifica corretamente cada parte do caminho (para suportar espaços, '+' e outros)
    final encodedFileName = fileName.split('/').map((part) => Uri.encodeComponent(part)).join('/');
    
    final url = '$downloadUrl/$_bucketName/$encodedFileName';
    debugPrint('🔗 URL de download: $url');
    return url;
  }

  /// Retorna os headers necessários para download (incluindo token)
  Future<Map<String, String>> getDownloadHeaders() async {
    await _authenticate();
    return {
      'Authorization': _authorizationToken ?? '',
    };
  }
  
  // Lista arquivos no bucket COM PAGINAÇÃO
  Future<List<Map<String, dynamic>>> listFiles({String? prefix}) async {
    debugPrint('🔍 listFiles() chamado com prefix: $prefix');
    await _authenticate();
    
    final bucketId = await _getBucketId();
    final baseUrl = _apiUrl ?? 'https://api.backblaze.com';
    
    final allFiles = <Map<String, dynamic>>[];
    String? nextFileId;
    int page = 1;
    
    do {
      debugPrint('📄 Buscando página $page...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/b2api/v2/b2_list_file_names'),
        headers: {
          'Authorization': _authorizationToken!,
        },
        body: json.encode({
          'bucketId': bucketId,
          'prefix': prefix,
          if (nextFileId != null) 'startFileId': nextFileId,
          'maxFileCount': 1000,
        }),
      );
      
      debugPrint('   Status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        debugPrint('❌ Erro: ${response.body}');
        throw Exception('Falha ao listar arquivos: ${response.statusCode}');
      }
      
      try {
        String body = _bytesToString(response.bodyBytes);
        final data = json.decode(body);
        final files = List<Map<String, dynamic>>.from(data['files']);
        allFiles.addAll(files);
        
        debugPrint('   Página $page: ${files.length} arquivos');
        nextFileId = data['nextFileId'] as String?;
        
        // Log dos primeiros arquivos desta página
        if (files.isNotEmpty && page == 1) {
          debugPrint('   Primeiros arquivos da primeira página:');
          for (int i = 0; i < files.length.clamp(0, 5); i++) {
            final file = files[i];
            debugPrint('     - ${file['fileName']} (${file['size']} bytes)');
          }
        }
        
        page++;
      } catch (e) {
        debugPrint('❌ Erro ao decodificar JSON: $e');
        rethrow;
      }
    } while (nextFileId != null);
    
    debugPrint('✅ Total de arquivos encontrados (todas as páginas): ${allFiles.length}');
    return allFiles;
  }
  
  // Obtém bucketId a partir do nome
  Future<String> _getBucketId() async {
    if (_bucketId != null) {
      debugPrint('✅ Usando bucketId da autenticação: $_bucketId');
      return _bucketId!;
    }
    
    // Fallback: buscar o bucketId pelo nome usando b2_list_buckets
    final baseUrl = _apiUrl ?? 'https://api.backblaze.com';
    try {
      debugPrint('🔍 BucketId não veio na autenticação, buscando por nome: $_bucketName no $baseUrl...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/b2api/v2/b2_list_buckets'),
        headers: {
          'Authorization': _authorizationToken!,
        },
        body: json.encode({
          'accountId': _accountId,
          'bucketName': _bucketName,
        }),
      );

      if (response.statusCode == 200) {
        final body = _bytesToString(response.bodyBytes);
        final data = json.decode(body);
        final buckets = data['buckets'] as List;
        if (buckets.isNotEmpty) {
          _bucketId = buckets.first['bucketId'];
          debugPrint('🎯 BucketId encontrado pelo nome: $_bucketId');
          return _bucketId!;
        }
      } else {
        debugPrint('❌ Erro ao listar buckets: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('⚠️ Exceção ao buscar bucketId por nome: $e');
    }
    
    throw Exception('BucketId não disponível. Verifique se o bucket "$_bucketName" existe e se as credenciais estão corretas.');
  }
}
