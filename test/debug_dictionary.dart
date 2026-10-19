import 'package:flutter_test/flutter_test.dart';
import 'package:keryx_app/core/services/database_service.dart';

void main() {
  test('test strong', () async {
    final db = DatabaseService();
    final words = await db.getDictionaryWordsByLetter('strongV2.db', 'A');
    print('Words: ${words.length}');
  });
}
