import 'package:flutter/material.dart';
import '../models/release_notes_model.dart';

class ReleaseNotesCatalog {
  /// Lista de notas de versão ordenadas da mais recente para a mais antiga
  static const List<ReleaseNoteVersion> allVersions = [
    ReleaseNoteVersion(
      versionName: '2.0.0',
      buildNumber: 9,
      title: 'Comunidade Renovada, Avatares & Acesso Aprimorado',
      releaseDate: 'Outubro de 2026',
      highlight:
          'Uma atualização especial com foco em expressão bíblica, novos avatares, molduras personalizadas e facilidade de login em qualquer aparelho.',
      items: [
        // ── Novos Recursos (Implementações) ─────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Nova Tela de Criação na Comunidade',
          description:
              'Interface dinâmica com seletor de categorias (🕊️ Reflexão, 🙏 Pedido de Oração, 📖 Versículo, ✨ Testemunho), atalhos de versículos com 1 toque e Prévia ao Vivo em tempo real antes de publicar.',
          customIcon: Icons.post_add_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Galeria de Avatares Pré-definidos',
          description:
              'Agora você pode escolher ilustrações prontas para o seu perfil organizadas em Personagens Bíblicos, Fé & Devoção e Criação, sem precisar enviar fotos pessoais da galeria.',
          customIcon: Icons.account_circle_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Molduras & Círculos Decorativos no Perfil',
          description:
              'Personalize sua foto com 8 estilos exclusivos de aros iluminados (Ouro Real, Aurora Celestial, Pentecostes, Safira, Esmeralda, Púrpura e Estelar) visíveis no perfil e na barra superior.',
          customIcon: Icons.stars_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Acesso com Senha para Contas Google',
          description:
              'Usuários que entram com a Conta Google agora podem cadastrar uma senha de acesso diretamente no perfil ou na recuperação de senha, permitindo entrar em aparelhos sem o Google conectado.',
          customIcon: Icons.lock_reset_rounded,
        ),

        // ── Modificações & Melhorias ─────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Visual do Card Comunidade na Tela Inicial',
          description:
              'O card da Comunidade recebeu um novo gradiente Índigo Celestial (#4F46E5 → #7C3AED) com ícone de balão de diálogo, criando contraste marcante com os recursos de estudo.',
          customIcon: Icons.palette_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Botão de Criação em Destaque & Feed Mais Fluido',
          description:
              'O botão flutuante da Comunidade deu lugar a uma pílula dourada estilizada no topo da tela, permitindo visualização de mais postagens com stories no tempo ideal.',
          customIcon: Icons.view_stream_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Tela de Login Focada e Segura',
          description:
              'Interface de autenticação simplificada com destaque para o botão Google e campos de e-mail/senha, removendo opções confusas.',
          customIcon: Icons.login_rounded,
        ),

        // ── Correções & Ajustes ──────────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.fix,
          title: 'Correção no Reconhecimento de Senha em Outro Aparelho',
          description:
              'Resolvido o problema em que contas Google apresentavam credencial inválida ao tentar login por e-mail em um segundo dispositivo.',
          customIcon: Icons.devices_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.fix,
          title: 'Estabilidade de Layout e Renderização',
          description:
              'Ajustes nos diálogos e cartões de temas bíblicos (incluindo o tema Rubi) para evitar falhas visuais ou cortes de texto.',
          customIcon: Icons.bug_report_rounded,
        ),
      ],
    ),
  ];

  /// Retorna as notas da versão mais recente cadastrada
  static ReleaseNoteVersion get latest => allVersions.first;

  /// Busca as notas de uma versão específica pelo buildNumber ou versionName
  static ReleaseNoteVersion? findByVersion({int? buildNumber, String? versionName}) {
    if (buildNumber != null) {
      final match = allVersions.where((v) => v.buildNumber == buildNumber).firstOrNull;
      if (match != null) return match;
    }
    if (versionName != null) {
      final match = allVersions.where((v) => v.versionName == versionName).firstOrNull;
      if (match != null) return match;
    }
    return null;
  }
}
