import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide openDatabase;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  test('strong verses', () async {
    try {
      final db = await openDatabase('assets/database/strongV2.db', password: ';%25lindEN');
      final rows = await db.rawQuery("SELECT VER_TEXTO FROM VERSICULOS WHERE VER_LIV_ID=1 AND VER_CAPITULO=1 LIMIT 5");
      for (final r in rows) {
        print("SAMPLE VERSE: ${r['VER_TEXTO']}");
      }
    } catch (e) {
      print("Error: $e");
    }
  });
}
