import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CloudflarePdfService {
  CloudflarePdfService._();
  static final instance = CloudflarePdfService._();

  // Substitua pela URL final do seu Worker da Cloudflare quando criar
  final String _workerUrl = 'https://biblia-ia-esboco.nivaldo-nilngn.workers.dev/pdfs';

  Future<List<Map<String, dynamic>>> fetchPdfs() async {
    try {
      if (kIsWeb) {
        debugPrint('🌐 Lendo banco_telegram.json dos assets para web...');
        final String jsonStr = await rootBundle.loadString('assets/data/banco_telegram.json');
        return await compute(_decodeAndMapPdfs, jsonStr);
      }

      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'banco_telegram.db');
      
      final prefs = await SharedPreferences.getInstance();
      const int currentDbVersion = 2; // Incremente isso toda vez que atualizar o banco nos assets
      final installedDbVersion = prefs.getInt('banco_telegram_version') ?? 0;
      
      bool overwrite = kDebugMode || installedDbVersion < currentDbVersion;
      
      if (overwrite || !await File(path).exists()) {
        debugPrint("Copiando banco_telegram.db dos assets (Versão $currentDbVersion)...");
        try {
          await Directory(dirname(path)).create(recursive: true);
        } catch (_) {}
          
        ByteData data = await rootBundle.load('assets/data/banco_telegram.db');
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
        await prefs.setInt('banco_telegram_version', currentDbVersion);
      }
      
      final db = await openDatabase(path);
      
      // Busca todos os livros
      final List<Map<String, dynamic>> livrosData = await db.query('livros');
      
      // Mapeamento usando Isolate (desafoga a UI)
      return await compute(_mapPdfs, livrosData);
    } catch (e) {
      debugPrint('Erro SQLite Telegram: $e');
      throw Exception('Falha ao ler banco_telegram.db local');
    }
  }

  // Função para decodificar e processar a lista no background para a Web
  static List<Map<String, dynamic>> _decodeAndMapPdfs(String jsonStr) {
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    final List<Map<String, dynamic>> livrosData = jsonList.cast<Map<String, dynamic>>();
    return _mapPdfs(livrosData);
  }

  // Função isolada que roda no fundo sem travar a tela
  static List<Map<String, dynamic>> _mapPdfs(List<Map<String, dynamic>> livrosData) {
    return livrosData.map((pdf) => {
      'id': pdf['file_id'], 
      'name': pdf['titulo'] ?? pdf['nome_arquivo'],
      'size': ((pdf['tamanho_mb'] ?? 0.0) * 1024 * 1024).toInt(),
      'download_url': pdf['download_url'], 
    }).toList();
  }

  Future<void> deletePdf(String fileName) async {
    // Esse método provavelmente apagava do KV, mas no SQLite local que vem do Backblaze/Assets
    // a gente não precisa apagar (quem apaga é o script de varredura). 
    debugPrint('Exclusão não aplicável ao banco SQLite lido dos assets.');
  }
}
