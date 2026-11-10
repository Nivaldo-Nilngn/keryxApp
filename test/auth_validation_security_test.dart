import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keryx_app/core/services/auth_service.dart';

void main() {
  group('AuthService AppSec & Input Validation Tests', () {
    test('isValidEmail accepts well-formed RFC 5322 emails', () {
      expect(AuthService.isValidEmail('user@keryxapp.com'), isTrue);
      expect(AuthService.isValidEmail('pastor.estudo@igreja.org.br'), isTrue);
      expect(AuthService.isValidEmail('nivaldo.nilngn@gmail.com'), isTrue);
      expect(AuthService.isValidEmail('  spaced@keryx.com  '), isTrue);
    });

    test('isValidEmail rejects malicious or malformed emails', () {
      expect(AuthService.isValidEmail(''), isFalse);
      expect(AuthService.isValidEmail('   '), isFalse);
      expect(AuthService.isValidEmail('invalid-email'), isFalse);
      expect(AuthService.isValidEmail('user@'), isFalse);
      expect(AuthService.isValidEmail('@domain.com'), isFalse);
      expect(AuthService.isValidEmail('user@domain'), isFalse);
      expect(AuthService.isValidEmail("user'--@domain.com"), isFalse);
      expect(AuthService.isValidEmail('user<script>@domain.com'), isFalse);
      // Exceeds 254 RFC characters limit
      final superLong = '${'a' * 250}@keryx.com';
      expect(AuthService.isValidEmail(superLong), isFalse);
    });

    test('isValidPassword enforces minimum security length of 6 characters', () {
      expect(AuthService.isValidPassword('123456'), isTrue);
      expect(AuthService.isValidPassword('SenhaForte#2026'), isTrue);
      expect(AuthService.isValidPassword('12345'), isFalse);
      expect(AuthService.isValidPassword(''), isFalse);
    });

    test('sanitizeDisplayName strips script and HTML tags to prevent XSS', () {
      expect(
        AuthService.sanitizeDisplayName('<script>alert("hack")</script>Pastor João'),
        equals('scriptalert("hack")scriptPastor João'),
      );
      expect(
        AuthService.sanitizeDisplayName('  <b>Maria Silva</b>  '),
        equals('bMaria Silvab'),
      );
      expect(
        AuthService.sanitizeDisplayName('Nivaldo G Neto {Admin}'),
        equals('Nivaldo G Neto Admin'),
      );
      expect(
        AuthService.sanitizeDisplayName(r'Pastor\Líder'),
        equals('PastorLíder'),
      );
      expect(
        AuthService.sanitizeDisplayName('  Nome Normal  '),
        equals('Nome Normal'),
      );
    });

    test('signUp fails fast on invalid input without network call', () {
      final auth = AuthService();
      expect(
        () => auth.signUp('invalid-email', '123456', 'Teste'),
        throwsA(isA<FirebaseAuthException>().having(
          (e) => e.code,
          'code',
          'invalid-email',
        )),
      );

      expect(
        () => auth.signUp('valid@email.com', '123', 'Teste'),
        throwsA(isA<FirebaseAuthException>().having(
          (e) => e.code,
          'code',
          'weak-password',
        )),
      );

      expect(
        () => auth.signUp('valid@email.com', '123456', '   '),
        throwsA(isA<FirebaseAuthException>().having(
          (e) => e.code,
          'code',
          'invalid-name',
        )),
      );
    });

    test('signIn fails fast on invalid email or empty password', () {
      final auth = AuthService();
      expect(
        () => auth.signIn('not-an-email', 'senha'),
        throwsA(isA<FirebaseAuthException>().having(
          (e) => e.code,
          'code',
          'invalid-email',
        )),
      );

      expect(
        () => auth.signIn('valid@email.com', ''),
        throwsA(isA<FirebaseAuthException>().having(
          (e) => e.code,
          'code',
          'wrong-password',
        )),
      );
    });

    test('sendPasswordResetEmail fails fast on invalid email', () {
      final auth = AuthService();
      expect(
        () => auth.sendPasswordResetEmail(''),
        throwsA(isA<FirebaseAuthException>().having(
          (e) => e.code,
          'code',
          'invalid-email',
        )),
      );
    });
  });
}
