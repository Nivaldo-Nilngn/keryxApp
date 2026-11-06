import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CloudflarePdfService {
  CloudflarePdfService._();
  static final instance = CloudflarePdfService._();

  List<Map<String, dynamic>>? _cachedPdfs;

  Future<List<Map<String, dynamic>>> fetchPdfs() async {
    if (_cachedPdfs != null && _cachedPdfs!.isNotEmpty) {
      return _cachedPdfs!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      const int currentDbVersion = 3; // v3: banco_telegram com índices em titulo e categoria e remoção do json duplicado
      final installedDbVersion = prefs.getInt('banco_telegram_version') ?? 0;
      
      bool overwrite = installedDbVersion < currentDbVersion;

      Database db;
      if (kIsWeb) {
        final factory = databaseFactoryFfiWeb;
        final dbPath = await factory.getDatabasesPath();
        final path = join(dbPath, 'banco_telegram.db');
        final exists = await factory.databaseExists(path);
        if (overwrite || !exists) {
          debugPrint("🌐 Copiando banco_telegram.db dos assets para IndexedDB...");
          ByteData data = await rootBundle.load('assets/data/banco_telegram.db');
          Uint8List bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await factory.writeDatabaseBytes(path, bytes);
          await prefs.setInt('banco_telegram_version', currentDbVersion);
        }
        db = await factory.openDatabase(
          path,
          options: OpenDatabaseOptions(readOnly: true),
        );
      } else {
        final databasesPath = await getDatabasesPath();
        final path = join(databasesPath, 'banco_telegram.db');
        
        if (overwrite || !await io.File(path).exists()) {
          debugPrint("Copiando banco_telegram.db dos assets (Versão $currentDbVersion)...");
          try {
            await io.Directory(dirname(path)).create(recursive: true);
          } catch (_) {}
            
          ByteData data = await rootBundle.load('assets/data/banco_telegram.db');
          List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await io.File(path).writeAsBytes(bytes, flush: true);
          await prefs.setInt('banco_telegram_version', currentDbVersion);
        }
        
        db = await openDatabase(path, readOnly: true);
      }
      
      // Busca todos os livros
      final List<Map<String, dynamic>> livrosData = await db.query('livros');
      
      // Mapeamento usando Isolate (desafoga a UI)
      final result = await compute(_mapPdfs, livrosData);
      _cachedPdfs = result;
      return result;
    } catch (e) {
      debugPrint('Erro SQLite Telegram: $e');
      throw Exception('Falha ao ler banco_telegram.db local');
    }
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
