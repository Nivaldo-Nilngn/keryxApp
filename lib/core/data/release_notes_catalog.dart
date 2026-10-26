import 'package:flutter/material.dart';
import '../models/release_notes_model.dart';

class ReleaseNotesCatalog {
  /// Lista de notas de versão ordenadas da mais recente para a mais antiga
  static const List<ReleaseNoteVersion> allVersions = [
    ReleaseNoteVersion(
      versionName: '2.0.3',
      buildNumber: 12,
      title: 'Comunidade em Nuvem D1, Segurança & Mobile Compacto',
      releaseDate: '26 de Outubro de 2026',
      highlight:
          'Persistência em nuvem D1 para a Comunidade, verificação rigorosa de integridade por SHA-256 no instalador de atualizações, layout mobile ultra compacto para oração e stories, e detecção PWA refinada para iPad e iPhone.',
      items: [
        // ── Novos Recursos (Implementações) ─────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Persistência D1 na Comunidade',
          description:
              'Posts, intercessões e comentários agora são armazenados em nuvem Cloudflare D1 em tempo real, garantindo persistência global entre usuários.',
          customIcon: Icons.people_alt_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Validação Criptográfica SHA-256 no APK',
          description:
              'Atualizações contam com verificação streaming de integridade por hash SHA-256, impedindo instalações corrompidas ou adulteradas.',
          customIcon: Icons.verified_user_rounded,
        ),

        // ── Modificações & Melhorias ─────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Layout de Oração e Stories Compacto no Mobile',
          description:
              'O card de Intercessão do Dia foi reduzido para um formato fino de 46px com opção de dispensar, e a bandeja de stories foi ajustada para otimizar a visualização do feed em smartphones.',
          customIcon: Icons.smartphone_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Orientação de Instalação PWA Especializada',
          description:
              'Distinção precisa entre iPhone (botão Compartilhar na barra inferior) e iPad (botão Compartilhar no canto superior/topo).',
          customIcon: Icons.tablet_mac_rounded,
        ),

        // ── Correções & Ajustes ──────────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.fix,
          title: 'Publicação Segura Fora do Pacote do App',
          description:
              'Tokens administrativos e rotas de publicação de versão foram desacoplados do cliente móvel, reforçando a segurança do ecossistema.',
          customIcon: Icons.security_rounded,
        ),
      ],
    ),
    ReleaseNoteVersion(
      versionName: '2.0.2',
      buildNumber: 11,
      title: 'IATheos Inteligente, Capas 3D & Notas em Tela Cheia',
      releaseDate: '26 de Outubro de 2026',
      highlight:
          'Grande reformulação da IA Teológica com modos de estudo especializados, novas capas 3D de livros bíblicos encadernados em couro e nova experiência de notas de atualização em tela cheia.',
      items: [
        // ── Novos Recursos (Implementações) ─────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'IATheos com Especialidades Teológicas',
          description:
              'A IA agora conta com 5 modos de pesquisa dedicados: Geral, Exegese (grego/hebraico), História & Patrística, Esboços de Pregação e Mensagens Devocionais.',
          customIcon: Icons.auto_awesome_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Mosaico 2x2 & Avatar Celestial da IA',
          description:
              'Nova interface moderna estilo ChatGPT/Perplexity com avatar iluminado em auréola dourada e cards organizados com cores temáticas por categoria.',
          customIcon: Icons.dashboard_customize_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Capas 3D em Couro com Siglas Douradas na Loja',
          description:
              'Todas as 91 Bíblias e comentários agora exibem capas de livros tridimensionais com textura de couro nobre, lombadas detalhadas, fita marcadora e siglas oficiais douradas.',
          customIcon: Icons.menu_book_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Notificações & Modal de Atualização Automática',
          description:
              'Sempre que o app for atualizado, o sistema notifica no Android e exibe uma janela comemorativa detalhando tudo o que foi implementado, modificado ou corrigido.',
          customIcon: Icons.notifications_active_rounded,
        ),

        // ── Modificações & Melhorias ─────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Remoção do Acesso Anônimo no Login',
          description:
              'O botão de entrar como convidado foi removido para assegurar sincronização completa de anotações, marcadores e compras na nuvem.',
          customIcon: Icons.security_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Performance e Renderização Otimizada na Loja',
          description:
              'Cards de categorias e itens redesenhados em Flutter nativo, reduzindo consumo de memória e dispensando imagens pesadas na listagem.',
          customIcon: Icons.speed_rounded,
        ),

        // ── Correções & Ajustes ──────────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.fix,
          title: 'Ajuste de Disparo de Atualização nos Dispositivos',
          description:
              'Sincronização imediata entre os endpoints de versão na Cloudflare e os aparelhos conectados.',
          customIcon: Icons.cloud_sync_rounded,
        ),
      ],
    ),
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
