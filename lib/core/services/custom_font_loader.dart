import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

class CustomFontLoader {
  static final List<String> loadedFontFamilies = [];

  static Future<void> loadDownloadedFonts() async {
    if (kIsWeb) return;
    loadedFontFamilies.clear();
    
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      // A pasta onde o StoreRepository salva as fontes é "store/fonts" ou "store" dependendo de como as pastas vêm do B2.
      // O StoreRepository usa `file.parent.create()` passando `${dir.path}/${item.filename}`,
      // o que significa que o path é "store/fonts/SubPasta/Arquivo.ttf".
      final fontsDir = Directory(p.join(appDocDir.path, 'store', 'fonts'));
      
      if (!await fontsDir.exists()) {
        debugPrint('ℹ️ Diretório de fontes customizadas não existe ainda.');
        return;
      }
      
      final entities = await fontsDir.list(recursive: true).toList();
      final fontFiles = entities.whereType<File>().where((f) {
        final ext = p.extension(f.path).toLowerCase();
        return ext == '.ttf' || ext == '.otf';
      });
      
      if (fontFiles.isEmpty) {
        debugPrint('ℹ️ Nenhuma fonte customizada encontrada.');
        return;
      }
      
      for (final file in fontFiles) {
        await _loadFontFile(file);
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar fontes dinâmicas: $e');
    }
  }

  static Future<bool> _loadFontFile(File file) async {
    try {
      final familyName = p.basenameWithoutExtension(file.path);
      final fontData = await file.readAsBytes();
      
      final loader = FontLoader(familyName);
      loader.addFont(Future.value(ByteData.view(fontData.buffer)));
      await loader.load();
      
      // Formata o nome para a UI (ex: FreeSansBold -> FreeSans) se for uma variação
      String uiName = familyName;
      if (familyName.contains('Bold') || familyName.contains('Oblique') || familyName.contains('Regular')) {
         uiName = familyName.replaceAll('Bold', '').replaceAll('Oblique', '').replaceAll('_Regular', '').replaceAll('_', '');
      }
      
      if (!loadedFontFamilies.contains(uiName)) {
         loadedFontFamilies.add(uiName);
      }
      
      debugPrint('✅ Fonte carregada dinamicamente: $familyName');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao carregar arquivo de fonte dinâmico: $e');
      return false;
    }
  }

  static Future<String?> importCustomFont() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
      );

      if (result != null && result.files.single.path != null) {
        File sourceFile = File(result.files.single.path!);
        
        // Copia a fonte para o diretório seguro do app
        final appDocDir = await getApplicationDocumentsDirectory();
        final fontsDir = Directory(p.join(appDocDir.path, 'store', 'fonts', 'Importadas'));
        if (!await fontsDir.exists()) {
          await fontsDir.create(recursive: true);
        }
        
        final fileName = p.basename(sourceFile.path);
        final destFile = File(p.join(fontsDir.path, fileName));
        await sourceFile.copy(destFile.path);
        
        // Carrega a fonte imediatamente
        final success = await _loadFontFile(destFile);
        if (success) {
          // Retorna o UI Name
          String familyName = p.basenameWithoutExtension(fileName);
          if (familyName.contains('Bold') || familyName.contains('Oblique') || familyName.contains('Regular')) {
             familyName = familyName.replaceAll('Bold', '').replaceAll('Oblique', '').replaceAll('_Regular', '').replaceAll('_', '');
          }
          return familyName;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erro ao importar fonte: $e');
      return null;
    }
  }

  // Uma seleção premium de Google Fonts disponíveis online!
  static const List<String> googleFonts = [
    'Outfit', 'Inter', 'Roboto', 'Playfair Display', 'Montserrat',
    'Lora', 'Merriweather', 'Nunito', 'Poppins', 'Raleway',
    'Ubuntu', 'Oswald', 'Lato', 'Open Sans', 'Caveat',
    'Dancing Script', 'Pacifico', 'Cinzel', 'Josefin Sans',
    'Quicksand', 'Bebas Neue', 'Anton', 'Satisfy', 'Lobster'
  ];

}
