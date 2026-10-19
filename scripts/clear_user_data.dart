#!/usr/bin/env dart
// Limpa as coleções antigas de anotações e favoritos no Firestore
// para o usuário logado.
//
// USO: dart run scripts/clear_user_data.dart <userId>
// Exemplo: dart run scripts/clear_user_data.dart abc123def456

import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('❌  Informe o userId como argumento.');
    print('   Exemplo: dart run scripts/clear_user_data.dart SEU_UID');
    exit(1);
  }

  final userId = args[0];
  print('🔥 Limpando dados do usuário: $userId');
  print('   Usando Firebase CLI (firestore:delete)...\n');

  // Coleções a apagar
  final collections = [
    'users/$userId/annotations',
    'users/$userId/favorites',
    'users/$userId/note_cards',
  ];

  for (final col in collections) {
    print('🗑️  Apagando: $col');
    final result = await Process.run(
      'npx',
      [
        '-y',
        'firebase-tools@latest',
        'firestore:delete',
        '--recursive',
        '--yes',
        col,
      ],
      workingDirectory: Directory.current.path,
    );
    if (result.exitCode == 0) {
      print('   ✅ OK\n');
    } else {
      print('   ⚠️  Erro: ${result.stderr}\n');
    }
  }

  print('🎉 Concluído! O app agora vai começar sem anotações e sem favoritos.');
}
