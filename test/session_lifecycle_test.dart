import 'package:flutter_test/flutter_test.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'dart:io';

void main() {
  group('Auditoria de Sessão e Controle de Acesso', () {
    test('Validação de sanitização e integridade de credenciais no AuthService', () {
      expect(AuthService.isValidEmail('user@dominio.com'), isTrue);
      expect(AuthService.isValidEmail(''), isFalse);
      expect(AuthService.isValidEmail('invalid-email'), isFalse);
      expect(AuthService.isValidEmail('<script>alert(1)</script>@hack.com'), isFalse);

      expect(AuthService.isValidPassword('123456'), isTrue);
      expect(AuthService.isValidPassword('12345'), isFalse);
      expect(AuthService.isValidPassword('   123456   '), isTrue);

      final cleanName = AuthService.sanitizeDisplayName('<script>Pastor João</script>');
      expect(cleanName.contains('<script>'), isFalse);
      expect(cleanName.contains('<'), isFalse);
      expect(cleanName.contains('>'), isFalse);
      expect(cleanName, contains('Pastor João'));
    });

    test('Validação estrutural de Firestore Security Rules para Isolamento de Dados', () {
      final file = File('firestore.rules');
      expect(file.existsSync(), isTrue, reason: 'firestore.rules deve existir');

      final content = file.readAsStringSync();
      // Regra de subcoleções de usuários
      expect(content.contains('match /study_plan_progress/{docId}'), isTrue);
      expect(content.contains('match /active_plan/{docId}'), isTrue);
      expect(content.contains('match /plans/{planId}'), isTrue);
      expect(content.contains('request.auth.uid == uid'), isTrue);
      expect(content.contains('isPrimaryAdmin()'), isTrue);
    });

    test('Validação estrutural de Storage Security Rules contra IDOR e vazamentos', () {
      final file = File('storage.rules');
      expect(file.existsSync(), isTrue, reason: 'storage.rules deve existir para prevenir buckets públicos');

      final content = file.readAsStringSync();
      expect(content.contains('match /users/{userId}/{allPaths=**}'), isTrue);
      expect(content.contains('request.auth.uid == uid'), isTrue);
      expect(content.contains('allow read, write: if false;'), isTrue, reason: 'Deve haver negação padrão');
    });
  });
}

