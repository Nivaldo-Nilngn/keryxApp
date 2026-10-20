import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/features/store/repository/b2_service.dart';
import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:keryx_app/core/services/database_service.dart';

class StoreRepository {
  static const String _storageDir = 'store';
  static const String _prefsKey = 'downloaded_store_items';
  
  final B2Service _b2Service = B2Service();
  final Map<String, http.Client> _activeDownloads = {};
  
  void cancelDownload(String filename) {
    final client = _activeDownloads.remove(filename);
    if (client != null) {
      try {
        client.close();
      } catch (e) {
        debugPrint('⚠️ Erro ao fechar client: $e');
      }
      debugPrint('🛑 Download cancelado e client abortado para: $filename');
    }
  }
  
  // Lista de categorias de pastas no Backblaze
  static const List<String> _categories = [
    'bibles',
    'books', 
    'commentaries',
    'commentary',
    'dictionaries',
    'fonts',
    'journals',
    'audios',
    'Comentários Expositivos',
    'Cultura e História',
    'Esboços, Homilética e Temas',
  ];
  
  // Mapeamento de prefixos de pasta para categorias
  StoreCategory? _categoryFromPath(String path) {
    for (final category in _categories) {
      if (path.startsWith('$category/')) {
        switch (category) {
          case 'bibles':
            return StoreCategory.bibles;
          case 'books':
            return StoreCategory.books;
          case 'commentaries':
          case 'commentary':
            return StoreCategory.commentaries;
          case 'Comentários Expositivos':
            return StoreCategory.expository;
          case 'Cultura e História':
            return StoreCategory.culture;
          case 'Esboços, Homilética e Temas':
            return StoreCategory.homiletics;
          case 'dictionaries':
            return StoreCategory.dictionaries;
          case 'fonts':
            return StoreCategory.fonts;
          case 'journals':
            return StoreCategory.journals;
          case 'audios':
            return StoreCategory.audios;
        }
      }
    }
    return null;
  }
  
  // Extrai nome limpo do filename
  String _extractName(String filename, String category) {
    String rawName = filename.replaceFirst('$category/', '').split('/').last;
    
    // Tratamento especial para Bíblias usando nosso mapeamento
    if (category == 'bibles') {
      String acronym = rawName
          .replaceAll('.sqlite', '')
          .replaceAll('.bbl.mybible', '')
          .replaceAll('.mybible', '')
          .replaceAll('.db', '')
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .replaceAll('.', ' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim()
          .toUpperCase();
          
      if (BibleMetadata.versionNames.containsKey(acronym)) {
        return BibleMetadata.versionNames[acronym]!;
      }
    }

    String name = rawName
               .replaceAll('.cmt.mybible', '')
               .replaceAll('.dct.mybible', '')
               .replaceAll('.bbl.mybible', '')
               .replaceAll('.bok.mybible', '')
               .replaceAll('.sqlite', '')
               .replaceAll('.pdf', '')
               .replaceAll('.ttf', '')
               .replaceAll('.otf', '')
               .replaceAll('.css', '')
               .replaceAll('LICENSE', '')
               .replaceAll('_', ' ');
               
    // Substituir pontos e hífens por espaço para melhor legibilidade
    name = name.replaceAll('.', ' ').replaceAll('-', ' ');
    
    // Remover espaços múltiplos e retornar com trim
    return name.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }
  
  // Para fonts e journals: agrupa por subpasta
  Map<String, List<Map<String, dynamic>>> _groupBySubfolder(
      List<Map<String, dynamic>> files, String category) {
    final groups = <String, List<Map<String, dynamic>>>{};
    
    for (final file in files) {
      final fileName = file['fileName'] as String;
      final parts = fileName.split('/');
      if (parts.length >= 2) {
        final subfolder = parts[1]; // nome da subpasta (ex: "DejaVu")
        groups.putIfAbsent(subfolder, () => []).add(file);
      }
    }
    
    return groups;
  }
  
  Future<List<StoreItem>> getAvailablePackages() async {
    
    try {
      final items = <StoreItem>[];
      
      if (kIsWeb) {
        final String jsonStr = await rootBundle.loadString('assets/data/loja_keryx.json');
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        for (var row in jsonList) {
          try {
            items.add(StoreItem.fromJson(row));
          } catch (e) {
            debugPrint('⚠️ Erro ao parsear item da loja (json): $e');
          }
        }
      } else {
        // Abre (e copia se necessário) o banco da loja
        final dbLoja = await _initAssetDatabase('loja_keryx.db');
        
        // 1. Puxa os dados da Loja (Bíblias, Comentários, Dicionários, etc)
        final List<Map<String, dynamic>> lojaData = await dbLoja.query('loja');
        for (var row in lojaData) {
          try {
            items.add(StoreItem.fromJson(row));
          } catch (e) {
            debugPrint('⚠️ Erro ao parsear item da loja: $e');
          }
        }
      }
      
      // Ordena por categoria e nome
      items.sort((a, b) {
        final catCompare = a.category.name.compareTo(b.category.name);
        if (catCompare != 0) return catCompare;
        return a.name.compareTo(b.name);
      });
      
      return items;
    } catch (e) {
      debugPrint('❌ Erro ao ler SQLite/JSON da loja: $e');
      return [];
    }
  }

  // Função mágica que copia o banco dos assets pro celular se ele não existir
  Future<Database> _initAssetDatabase(String dbName) async {
    // Requer: import 'package:sqflite/sqflite.dart';
    // O flutter precisa copiar o asset pro diretório interno pra ler via sqflite
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, dbName);
    
    final prefs = await SharedPreferences.getInstance();
    const int currentStoreDbVersion = 3;
    final installedStoreDbVersion = prefs.getInt('loja_keryx_version') ?? 0;
    
    // MUDADO: só sobrepõe o banco se o app estiver em modo de desenvolvimento (Debug) ou atualizar versão
    bool overwrite = kDebugMode || installedStoreDbVersion < currentStoreDbVersion; 
    
    if (overwrite || !await File(path).exists()) {
      debugPrint("Copiando $dbName dos assets para o sistema (Versão $currentStoreDbVersion)...");
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}
        
      ByteData data = await rootBundle.load('assets/data/$dbName');
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
      await prefs.setInt('loja_keryx_version', currentStoreDbVersion);
    }
    
    return await openDatabase(path);
  }
  
  String _getFolderForCategory(StoreCategory category) {
    switch (category) {
      case StoreCategory.bibles: return 'bibles';
      case StoreCategory.commentaries: return 'commentaries';
      case StoreCategory.expository: return 'Comentários Expositivos';
      case StoreCategory.culture: return 'Cultura e História';
      case StoreCategory.homiletics: return 'Esboços, Homilética e Temas';
      case StoreCategory.dictionaries: return 'dictionaries';
      case StoreCategory.fonts: return 'fonts';
      case StoreCategory.books: return 'books';
      case StoreCategory.journals: return 'journals';
      case StoreCategory.audios: return 'audios';
      case StoreCategory.outros: return 'Outros';
    }
  }

  // Download de um pacote (descompacta fontes)
  Future<void> downloadPackage(StoreItem item, 
      {Function(double progress)? onProgress}) async {
    if (item.category == StoreCategory.fonts) {
      await _downloadAndUnzip(item, onProgress: onProgress);
    } else {
      await _downloadSinglePackage(item, onProgress: onProgress);
    }
  }
  
  Future<void> _downloadSinglePackage(StoreItem item, 
      {Function(double progress)? onProgress}) async {
    final client = http.Client();
    _activeDownloads[item.filename] = client;
    try {
      final url = item.downloadUrl ?? '';
      if (url.isEmpty) throw Exception('URL de download vazia');
      
      final folderName = _getFolderForCategory(item.category);
      final filename = '$folderName/${item.filename}';
      
      String finalUrl = url;
      if (kIsWeb && finalUrl.startsWith('https://github.com/')) {
        finalUrl = 'https://biblia-ia-esboco.nivaldo-nilngn.workers.dev/github-proxy?url=${Uri.encodeComponent(url)}';
      }
      final request = http.Request('GET', Uri.parse(finalUrl));
      
      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        throw Exception('Falha ao baixar: status ${response.statusCode}');
      }
      
      final contentLength = response.contentLength ?? item.sizeBytes;
      
      if (kIsWeb) {
        if (contentLength != null && contentLength > 100 * 1024 * 1024) {
          throw Exception('Arquivo muito grande para ser salvo no navegador (max: 100MB).');
        }
        if (!item.filename.endsWith('.sqlite') && !item.filename.endsWith('.db') && !item.filename.endsWith('.mybible')) {
          throw Exception('A versão Web atualmente só suporta download de Bíblias e Módulos. Arquivos estáticos não são suportados.');
        }

        // No Web, baixamos tudo para a memória com BytesBuilder (mais eficiente)
        final builder = BytesBuilder(copy: false);
        int lastProgressMs = 0;
        await for (final chunk in response.stream) {
          builder.add(chunk);
          if (contentLength != null && contentLength > 0 && onProgress != null) {
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - lastProgressMs >= 150 || builder.length == contentLength) {
              lastProgressMs = now;
              onProgress(builder.length / contentLength);
            }
          }
        }
        final bytes = builder.takeBytes();
        
        final factory = databaseFactoryFfiWeb;
        final dbPath = await factory.getDatabasesPath();
        final path = join(dbPath, item.filename);
        await factory.writeDatabaseBytes(path, bytes);
        debugPrint('✅ Banco salvo no IndexedDB (Web): $path');
      } else {
        // Lógica original para Mobile/Desktop com download parcial seguro
        final dir = await _localStorageDir;
        final file = File('${dir.path}/$filename');
        final tmp = File('${file.path}.part');
        
        await tmp.parent.create(recursive: true);
        
        final sink = tmp.openWrite();
        int bytesReceived = 0;
        int lastProgressMs = 0;
        
        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            bytesReceived += chunk.length;
            
            if (contentLength != null && contentLength > 0 && onProgress != null) {
              final now = DateTime.now().millisecondsSinceEpoch;
              if (now - lastProgressMs >= 150 || bytesReceived == contentLength) {
                lastProgressMs = now;
                onProgress(bytesReceived / contentLength);
              }
            }
          }
          await sink.close();
          await tmp.rename(file.path);
        } catch (e) {
          await sink.close();
          if (await tmp.exists()) await tmp.delete();
          rethrow;
        }
      }
      
      await DatabaseService().closeDatabase(item.filename);
      await setDownloaded(filename, true);
      debugPrint('✅ Download concluído: ${item.name}');
    } catch (e) {
      rethrow;
    } finally {
      _activeDownloads.remove(item.filename);
      client.close();
    }
  }
  
  Future<void> _downloadAndUnzip(StoreItem item, 
      {Function(double progress)? onProgress}) async {
    final client = http.Client();
    _activeDownloads[item.filename] = client;
    try {
      final url = item.downloadUrl ?? '';
      if (url.isEmpty) throw Exception('URL de download vazia');
      
      String finalUrl = url;
      if (kIsWeb && finalUrl.startsWith('https://github.com/')) {
        finalUrl = 'https://biblia-ia-esboco.nivaldo-nilngn.workers.dev/github-proxy?url=${Uri.encodeComponent(url)}';
      }
      final request = http.Request('GET', Uri.parse(finalUrl));
      
      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        throw Exception('Falha ao baixar zip: status ${response.statusCode}');
      }
      
      final contentLength = response.contentLength ?? item.sizeBytes;
      
      if (kIsWeb) {
        throw Exception('O download de fontes (zip) não é suportado na versão Web.');
      } else {
        final dir = await _localStorageDir;
        final zipFile = File('${dir.path}/temp_${item.filename}');
        
        final sink = zipFile.openWrite();
        int bytesReceived = 0;
        int lastProgressMs = 0;
        
        await for (final chunk in response.stream) {
          sink.add(chunk);
          bytesReceived += chunk.length;
          if (contentLength != null && contentLength > 0 && onProgress != null) {
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - lastProgressMs >= 150 || bytesReceived == contentLength) {
              lastProgressMs = now;
              onProgress((bytesReceived / contentLength) * 0.9); // 90% para o download
            }
          }
        }
        await sink.close();
        
        // Unzip
        final bytes = await zipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        
        final folderName = _getFolderForCategory(item.category);
        
        for (final file in archive) {
          final filename = file.name;
          if (file.isFile) {
            final data = file.content as List<int>;
            final extractedFile = File('${dir.path}/$folderName/$filename');
            
            if (!isWithin(dir.path, normalize(extractedFile.path))) {
              debugPrint('⚠️ Ignorando arquivo fora do destino (Path Traversal): $filename');
              continue;
            }
            
            await extractedFile.parent.create(recursive: true);
            await extractedFile.writeAsBytes(data);
            
            await setDownloaded('$folderName/$filename', true);
          }
        }
        
        // Marca o próprio zip como baixado para que o StoreState saiba que o pacote inteiro foi concluído
        await setDownloaded('$folderName/${item.filename}', true);
        
        await zipFile.delete();
        if (onProgress != null) onProgress(1.0);
        
        debugPrint('✅ Zip descompactado: ${item.name}');
      }
    } catch (e) {
      rethrow;
    } finally {
      _activeDownloads.remove(item.filename);
      client.close();
    }
  }
  
  Future<String> getDownloadUrl(String filename) async {
    return await _b2Service.getDownloadUrl(filename);
  }
  
  // Retorna diretório de armazenamento local
  Future<Directory> get _localStorageDir async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocDir.path}/$_storageDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
  
  // Verifica se um item está baixado localmente (Suporta nome completo ou apenas o nome base)
  Future<bool> isDownloaded(String filename) async {
    final prefs = await SharedPreferences.getInstance();
    final downloaded = prefs.getStringList(_prefsKey) ?? [];
    
    // 1. Tenta match exato primeiro
    if (downloaded.contains(filename)) return true;
    
    // 2. Se for apenas o nome base (ex: 'BEACON.cmt.mybible'), procura nas subpastas
    if (!filename.contains('/')) {
      return downloaded.any((path) => path.endsWith('/$filename'));
    }
    
    return false;
  }
  
  // Retorna lista de arquivos baixados (Sincroniza SharedPreferences com Arquivos Físicos)
  Future<List<String>> getDownloadedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getStringList(_prefsKey) ?? []).toSet();
    
    // Scan físico no diretório da loja
    if (kIsWeb) return saved.toList();

    final dir = await _localStorageDir;
    final Set<String> discovered = {};
    
    try {
      if (await dir.exists()) {
        final List<FileSystemEntity> entities = await dir.list(recursive: true).toList();
        for (final entity in entities) {
          if (entity is File && !entity.path.endsWith('.part')) {
            // Pegar o caminho relativo para bater com o padrão do Backblaze (ex: commentaries/file.cmt.mybible)
            final relativePath = entity.path.replaceFirst('${dir.path}/', '');
            discovered.add(relativePath);
          }
        }
      }

      // Adicionalmente, verifica pastas no raiz do appDocDir se especificado pelo usuário (commentary e commentaries)
      final appDocDir = await getApplicationDocumentsDirectory();
      final List<String> extraFolders = ['commentary', 'commentaries'];
      for (final rawFolder in extraFolders) {
        final folder = Directory(join(appDocDir.path, rawFolder));
        if (await folder.exists()) {
          final List<FileSystemEntity> entities = await folder.list().toList();
          for (final entity in entities) {
            if (entity is File && !entity.path.endsWith('.part')) {
               // Armazena com o prefixo da pasta para consistência
               discovered.add('$rawFolder/${basename(entity.path)}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao escanear diretórios: $e');
    }

    final total = saved.union(discovered).toList();
    if (total.length > saved.length) {
      // Sincroniza de volta para o Prefs para persistência rápida no futuro
      await prefs.setStringList(_prefsKey, total);
    }
    
    return total;
  }
  
  // Marca/desmarca arquivo como baixado
  Future<void> setDownloaded(String filename, bool downloaded) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    
    if (downloaded && !list.contains(filename)) {
      list.add(filename);
    } else if (!downloaded && list.contains(filename)) {
      list.remove(filename);
    }
    
    await prefs.setStringList(_prefsKey, list);
  }
  
  // Caminho local do arquivo baixado (Resolve caminhos relativos ou nomes base)
  Future<String> localPath(String filename) async {
    if (kIsWeb) return filename;
    
    final dir = await _localStorageDir;
    
    // Se o arquivo existe no caminho direto, retorna ele
    final directFile = File('${dir.path}/$filename');
    if (await directFile.exists()) return directFile.path;

    // Se o arquivo não tem barra, ele é um nome base. Vamos procurar nas subpastas conhecidas.
    if (!filename.contains('/')) {
      for (final cat in _categories) {
        final path = '${dir.path}/$cat/$filename';
        if (await File(path).exists()) return path;
      }
    }

    return '${dir.path}/$filename';
  }
  
  // Verifica se arquivo existe fisicamente
  Future<bool> fileExists(String filename) async {
    if (kIsWeb) {
      if (filename.endsWith('.sqlite') || filename.endsWith('.db') || filename.endsWith('.mybible')) {
        try {
          final factory = databaseFactoryFfiWeb;
          final dbPath = await factory.getDatabasesPath();
          final base = filename.contains('/') ? filename.split('/').last : filename;
          return await factory.databaseExists(join(dbPath, base));
        } catch (_) {}
      }
      return isDownloaded(filename);
    }
    
    final path = await localPath(filename);
    return File(path).exists();
  }
  
  // Exclui um item baixado (pacote ou arquivo único)
  Future<void> deletePackage(StoreItem item) async {
    await DatabaseService().closeDatabase(item.filename);
    
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? [];
      
      if (item.category == StoreCategory.fonts) {
        final subfolderName = item.name.replaceAll(' ', '_');
        await setDownloaded('fonts/${item.filename}', false);
        await setDownloaded(item.filename, false);
        list.removeWhere((p) => p.contains(item.filename) || (subfolderName.isNotEmpty && p.contains(subfolderName)));
      } else {
        final folderName = _getFolderForCategory(item.category);
        final filename = '$folderName/${item.filename}';
        await setDownloaded(filename, false);
        await setDownloaded(item.filename, false);
        final base = item.filename.contains('/') ? item.filename.split('/').last : item.filename;
        list.removeWhere((p) => p == filename || p == item.filename || p.endsWith('/$base'));
        
        if (item.filename.endsWith('.sqlite') || item.filename.endsWith('.db') || item.filename.endsWith('.mybible')) {
          try {
            final factory = databaseFactoryFfiWeb;
            final dbPath = await factory.getDatabasesPath();
            await factory.deleteDatabase(join(dbPath, item.filename)).timeout(const Duration(seconds: 3));
          } catch (e) {
            debugPrint('Erro/Timeout ao excluir IndexedDB: \$e');
          }
        }
      }
      await prefs.setStringList(_prefsKey, list);
      debugPrint('🗑️ Download excluído da sessão web: ${item.name}');
      return;
    }
    
    if (item.category == StoreCategory.fonts) {
      final dir = await _localStorageDir;
      final subfolderName = item.name.replaceAll(' ', '_');
      final folder = Directory('${dir.path}/fonts/$subfolderName');
      
      if (await folder.exists()) {
        final files = await folder.list().toList();
        for (var f in files) {
          final fileName = basename(f.path);
          await setDownloaded('fonts/$subfolderName/$fileName', false);
        }
        await folder.delete(recursive: true);
      }
      
      // Remove o próprio zip do estado para que a UI reflita
      await setDownloaded('fonts/${item.filename}', false);
      await setDownloaded(item.filename, false);
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? [];
      list.removeWhere((p) => p.contains(item.filename) || (subfolderName.isNotEmpty && p.contains(subfolderName)));
      await prefs.setStringList(_prefsKey, list);
      
      debugPrint('🗑️ Pacote de fonte ${item.name} excluído');
    } else {
      // Excluir arquivo único
      final folderName = _getFolderForCategory(item.category);
      final filename = '$folderName/${item.filename}';
      
      final path = await localPath(filename);
      final file = File(path);
      
      if (await file.exists()) {
        await file.delete();
      }
      await setDownloaded(filename, false);
      await setDownloaded(item.filename, false);
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? [];
      final base = item.filename.contains('/') ? item.filename.split('/').last : item.filename;
      list.removeWhere((p) => p == filename || p == item.filename || p.endsWith('/$base'));
      await prefs.setStringList(_prefsKey, list);
      debugPrint('🗑️ Download excluído: ${item.name}');
    }
  }
  
  // Lê conteúdo do arquivo local
  Future<String> readLocalItem(String filename) async {
    if (kIsWeb) return ''; // Retorno vazio na Web já que não podemos ler filesystem
    
    final path = await localPath(filename);
    final file = File(path);
    
    if (!await file.exists()) {
      throw Exception('Arquivo não encontrado: $filename resolvido como $path');
    }
    
    return await file.readAsString();
  }
  
  // Lista todos os arquivos locais com seus metadados
  Future<List<StoreItem>> getLocalPackages() async {
    if (kIsWeb) return []; // Na Web o state já gerencia os virtuais
    
    final downloadedFilenames = await getDownloadedFiles();
    final dir = await _localStorageDir;
    
    final items = <StoreItem>[];
    
    for (final filename in downloadedFilenames) {
      final file = File('${dir.path}/$filename');
      if (await file.exists()) {
        final stat = await file.stat();
        final category = _categoryFromPath(filename) ?? StoreCategory.commentaries;
        final name = _extractName(filename, category.name);
        
        items.add(StoreItem(
          id: filename,
          name: name,
          filename: filename,
          category: category,
          downloadUrl: file.path,
          sizeBytes: stat.size,
        ));
      }
    }
    
    return items;
  }
  
  // Limpa todos os downloads
  Future<void> clearAll() async {
    await DatabaseService().closeAll();
    final prefs = await SharedPreferences.getInstance();
    
    if (!kIsWeb) {
      final dir = await _localStorageDir;
      final files = await dir.list(recursive: true).toList();
      
      for (final file in files) {
        if (file is File) {
          await file.delete();
        }
      }
    } else {
      final downloaded = prefs.getStringList(_prefsKey) ?? [];
      final factory = databaseFactoryFfiWeb;
      final dbPath = await factory.getDatabasesPath();
      for (final item in downloaded) {
        if (item.endsWith('.sqlite') || item.endsWith('.db') || item.endsWith('.mybible')) {
          try {
            final base = item.contains('/') ? item.split('/').last : item;
            await factory.deleteDatabase(join(dbPath, base));
          } catch (_) {}
        }
      }
    }
    
    await prefs.remove(_prefsKey);
    
    debugPrint('🗑️ Todos os downloads foram limpos');
  }
  
  // Calcula espaço total usado
  Future<int> getTotalStorageUsed() async {
    if (kIsWeb) return 0;
    
    final dir = await _localStorageDir;
    int total = 0;
    
    try {
      final files = await dir.list(recursive: true).toList();
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          total += stat.size;
        }
      }
    } catch (e) {
      debugPrint('Erro ao calcular armazenamento: $e');
    }
    
    return total;
  }
}
