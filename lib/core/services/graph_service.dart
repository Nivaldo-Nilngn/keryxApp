import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GraphService {
  static final GraphService _instance = GraphService._internal();
  factory GraphService() => _instance;
  GraphService._internal();

  static String get _tenantId => dotenv.env['AZURE_TENANT_ID']!;
  static String get _clientId => dotenv.env['AZURE_CLIENT_ID']!;
  static String get _clientSecret => dotenv.env['AZURE_CLIENT_SECRET']!;
  static String get _userId => dotenv.env['AZURE_USER_ID']!;
  static String get _folderPath => dotenv.env['AZURE_FOLDER_PATH']!;

  String? _cachedToken;
  DateTime? _tokenExpiry;

  Future<String> getToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken!;
    }
    final response = await http.post(
      Uri.parse('https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/token'),
      body: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'scope': 'https://graph.microsoft.com/.default',
        'grant_type': 'client_credentials',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Falha ao autenticar: ${response.body}');
    }
    final data = json.decode(response.body);
    _cachedToken = data['access_token'] as String;
    _tokenExpiry = DateTime.now()
        .add(Duration(seconds: (data['expires_in'] as int) - 60));
    return _cachedToken!;
  }

  String getDirectContentUrl(String itemId) =>
      'https://graph.microsoft.com/v1.0/users/$_userId/drive/items/$itemId/content';

  Future<Map<String, String>> getDirectAccessData(String fileId) async {
    final token = await getToken();
    return {
      'url': getDirectContentUrl(fileId),
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getPdfPage({String? nextLink, int pageSize = 20}) async {
    final token = await getToken();
    final url = nextLink ??
        'https://graph.microsoft.com/v1.0/users/$_userId/drive/root:/$_folderPath:/children'
        '?\$top=$pageSize&\$orderby=name&\$select=id,name,size';

    final response = await http
        .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar PDFs: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final items = (data['value'] as List<dynamic>? ?? [])
        .where((i) => (i['name'] as String? ?? '').toLowerCase().endsWith('.pdf'))
        .cast<Map<String, dynamic>>()
        .toList();

    return {
      'items': items,
      'nextLink': data['@odata.nextLink'] as String?,
    };
  }

  Future<Map<String, dynamic>> searchPdfsRemote({
    required String query,
    String? nextLink,
  }) async {
    final token = await getToken();
    final q = Uri.encodeComponent(query.trim().replaceAll("'", "''"));
    final url = nextLink ??
        'https://graph.microsoft.com/v1.0/users/$_userId/drive/root:/$_folderPath:'
        '/search(q=\'$q\')?\$top=50&\$select=id,name,size';

    final response = await http
        .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Erro na busca: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final items = (data['value'] as List<dynamic>? ?? [])
        .where((i) => (i['name'] as String? ?? '').toLowerCase().endsWith('.pdf'))
        .cast<Map<String, dynamic>>()
        .toList();

    return {'items': items, 'nextLink': data['@odata.nextLink'] as String?};
  }

  Future<void> deleteDriveItem(String itemId) async {
    final token = await getToken();
    final url = 'https://graph.microsoft.com/v1.0/users/$_userId/drive/items/$itemId';

    final response = await http
        .delete(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Erro ao excluir no OneDrive (${response.statusCode}): ${response.body}');
    }
  }

  Future<void> clearLegacyCache() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      'pdf_index_v3', 'pdf_index_ts_v3',
      'pdf_index_v4', 'pdf_index_ts_v4',
    ]) {
      await prefs.remove(k);
    }
  }
}
