import 'package:flutter_test/flutter_test.dart';
import 'package:keryx_app/features/access_control/model/user_access_model.dart';
import 'package:keryx_app/features/access_control/service/access_control_service.dart';

void main() {
  group('Access Control - Primary Admin Safeguards', () {
    test('Identifica o Administrador Principal de forma case-insensitive e trim', () {
      expect(AccessControlService.isPrimaryAdmin('nivaldo.nilngn@gmail.com'), isTrue);
      expect(AccessControlService.isPrimaryAdmin('NIVALDO.NILNGN@GMAIL.COM'), isTrue);
      expect(AccessControlService.isPrimaryAdmin('  nivaldo.nilngn@gmail.com  '), isTrue);
      expect(AccessControlService.isPrimaryAdmin('Nivaldo.Nilngn@Gmail.Com'), isTrue);

      expect(AccessControlService.isPrimaryAdmin('outro@gmail.com'), isFalse);
      expect(AccessControlService.isPrimaryAdmin(''), isFalse);
      expect(AccessControlService.isPrimaryAdmin(null), isFalse);
    });

    test('Validação de formato de e-mail RFC 5322', () {
      expect(AccessControlService.isValidEmail('usuario@dominio.com'), isTrue);
      expect(AccessControlService.isValidEmail('nome.sobrenome@empresa.com.br'), isTrue);
      expect(AccessControlService.isValidEmail('user+tag@gmail.com'), isTrue);

      expect(AccessControlService.isValidEmail('emailinvalido'), isFalse);
      expect(AccessControlService.isValidEmail('usuario@'), isFalse);
      expect(AccessControlService.isValidEmail('@dominio.com'), isFalse);
      expect(AccessControlService.isValidEmail(''), isFalse);
      expect(AccessControlService.isValidEmail('   '), isFalse);
    });

    test('UserAccessInfo para o Administrador Principal sempre força role=admin e status=authorized', () {
      // Mesmo que o Firestore contenha status pending ou user, para o e-mail do admin principal ele é forçado a admin autorizado
      final adminData = {
        'email': 'nivaldo.nilngn@gmail.com',
        'displayName': 'Nivaldo',
        'role': 'user',
        'status': 'pending',
      };

      final info = UserAccessInfo.fromMap('admin_uid_123', adminData);
      expect(info.isAdmin, isTrue);
      expect(info.isAuthorized, isTrue);
      expect(info.isPending, isFalse);
      expect(info.isBlocked, isFalse);
      expect(info.role, equals(UserRole.admin));
      expect(info.status, equals(AccessStatus.authorized));
    });

    test('UserAccessInfo para usuários comuns respeita status e role do mapa', () {
      final pendingData = {
        'email': 'estudante@gmail.com',
        'displayName': 'João',
        'role': 'user',
        'status': 'pending',
      };

      final pendingInfo = UserAccessInfo.fromMap('uid_joao', pendingData);
      expect(pendingInfo.isAdmin, isFalse);
      expect(pendingInfo.isAuthorized, isFalse);
      expect(pendingInfo.isPending, isTrue);
      expect(pendingInfo.isBlocked, isFalse);

      final blockedData = {
        'email': 'bloqueado@gmail.com',
        'displayName': 'Maria',
        'role': 'user',
        'status': 'blocked',
      };

      final blockedInfo = UserAccessInfo.fromMap('uid_maria', blockedData);
      expect(blockedInfo.isBlocked, isTrue);
      expect(blockedInfo.isAuthorized, isFalse);
      expect(blockedInfo.isPending, isFalse);

      final authorizedData = {
        'email': 'autorizado@gmail.com',
        'displayName': 'Pedro',
        'role': 'user',
        'status': 'authorized',
      };

      final authorizedInfo = UserAccessInfo.fromMap('uid_pedro', authorizedData);
      expect(authorizedInfo.isAuthorized, isTrue);
      expect(authorizedInfo.isPending, isFalse);
      expect(authorizedInfo.isBlocked, isFalse);
    });

    test('Conversão de AccessStatus e UserRole para String e labels em Português', () {
      expect(AccessStatus.authorized.labelPt, equals('Autorizado'));
      expect(AccessStatus.pending.labelPt, equals('Pendente'));
      expect(AccessStatus.blocked.labelPt, equals('Bloqueado'));

      expect(AccessStatus.fromString('approved'), equals(AccessStatus.authorized));
      expect(AccessStatus.fromString('autorizado'), equals(AccessStatus.authorized));
      expect(AccessStatus.fromString('revogado'), equals(AccessStatus.blocked));
      expect(AccessStatus.fromString('bloqueado'), equals(AccessStatus.blocked));
      expect(AccessStatus.fromString('qualquer_coisa'), equals(AccessStatus.pending));

      expect(UserRole.admin.labelPt, equals('Administrador Principal'));
      expect(UserRole.user.labelPt, equals('Usuário'));
      expect(UserRole.fromString('administrador'), equals(UserRole.admin));
      expect(UserRole.fromString('admin'), equals(UserRole.admin));
      expect(UserRole.fromString('outro'), equals(UserRole.user));
    });

    test('PreAuthorizedEmail serializa e deserializa corretamente', () {
      final now = DateTime.now();
      final preAuth = PreAuthorizedEmail(
        email: 'convidado@igreja.com',
        status: AccessStatus.authorized,
        addedAt: now,
        addedBy: 'nivaldo.nilngn@gmail.com',
        note: 'Líder de Jovens',
      );

      final map = preAuth.toMap();
      expect(map['email'], equals('convidado@igreja.com'));
      expect(map['status'], equals('authorized'));
      expect(map['addedBy'], equals('nivaldo.nilngn@gmail.com'));
      expect(map['note'], equals('Líder de Jovens'));
    });
  });
}
