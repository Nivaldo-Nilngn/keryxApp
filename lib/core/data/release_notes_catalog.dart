import 'package:flutter/material.dart';
import '../models/release_notes_model.dart';

class ReleaseNotesCatalog {
  /// Lista de notas de versão ordenadas da mais recente para a mais antiga
  static const List<ReleaseNoteVersion> allVersions = [
    ReleaseNoteVersion(
      versionName: '2.0.8',
      buildNumber: 17,
      title: 'Menu Lateral Completo em Tablets, TopBars Otimizadas & Curadoria',
      releaseDate: '06 de Novembro de 2026',
      highlight:
          'Barra de navegação lateral em tablets e web expandida com acesso direto a todas as ferramentas principais da Home, eliminação de barras superiores redundantes em telas e abas, ordenação alfabética (A-Z) no acervo de estudos e curadoria aprimorada sem links de download externos.',
      items: [
        // ── Novos Recursos (Implementações) ─────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Menu Lateral Completo no Modo Tablet e Web',
          description:
              'A barra lateral agora inclui atalhos diretos e instantâneos para Plano de Estudo, Dicionário e Concordância, Biblioteca de Livros, IATheos Teologia, Comentários e Comunidade.',
          customIcon: Icons.view_sidebar_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Ordenação Alfabética (A-Z) nos Estudos Bíblicos',
          description:
              'Mais de 600 estudos teológicos agora organizados em perfeita ordem alfabética para facilitar a navegação e localização de temas e passagens bíblicas.',
          customIcon: Icons.sort_by_alpha_rounded,
        ),

        // ── Modificações & Melhorias ─────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Remoção de TopBars Redundantes em Tablets',
          description:
              'Eliminação da barra de cabeçalho duplicada (KeryxApp, sino, loja e avatar) em telas e abas integradas, oferecendo uma experiência ampla e limpa no tablet e desktop.',
          customIcon: Icons.fullscreen_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Curadoria Focada do Acervo de Estudos',
          description:
              'Remoção de itens de instaladores externos e downloads de software, mantendo o catálogo exclusivamente com artigos, teologia e reflexões bíblicas.',
          customIcon: Icons.cleaning_services_rounded,
        ),

        // ── Correções (Bugs) ─────────────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.fix,
          title: 'Correção de Overflow e Transições Fluidas',
          description:
              'Ajuste de margens na barra de categorias dos estudos evitando erros de layout, e transição instantânea sem recarregamento ao alternar telas no tablet.',
          customIcon: Icons.speed_rounded,
        ),
      ],
    ),
    ReleaseNoteVersion(
      versionName: '2.0.7',
      buildNumber: 16,
      title: 'Acervo de Estudos Bíblicos, Multiplanos de Leitura & Otimizações',
      releaseDate: '06 de Novembro de 2026',
      highlight:
          'Novo acervo integrado com mais de 600 estudos bíblicos teológicos e exegéticos offline, suporte a múltiplos planos de leitura simultâneos, leitor dedicado de artigos teológicos, curadoria do catálogo e refinamentos visuais de performance.',
      items: [
        // ── Novos Recursos (Implementações) ─────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Acervo de Estudos Bíblicos Integrado',
          description:
              'Acesse diretamente no aplicativo mais de 600 estudos teológicos, doutrinários e exegéticos categorizados, com busca instantânea e banco SQLite local veloz.',
          customIcon: Icons.menu_book_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Multiplanos de Leitura Bíblica',
          description:
              'Agora você pode iniciar e acompanhar múltiplos planos de leitura bíblica simultaneamente (Cronológico, Canônico, Evangelhos, Cartas Paulinas), alternando entre eles com facilidade.',
          customIcon: Icons.event_note_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Leitor Dedicado de Estudos Teológicos',
          description:
              'Leitura confortável com tipografia aprimorada, tempo estimado de leitura, badges de categoria e ferramentas de compartilhamento.',
          customIcon: Icons.article_rounded,
        ),

        // ── Modificações & Melhorias ─────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Curadoria Exclusiva de Conteúdo Teológico',
          description:
              'Catálogo refinado e filtrado para conter exclusivamente artigos e reflexões de teologia, removendo instaladores ou links externos de programas.',
          customIcon: Icons.auto_awesome_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Navegação Simplificada e Limpa',
          description:
              'Remoção de elementos visuais redundantes na Loja e eliminação de setas de retorno desnecessárias em telas integradas à navegação principal.',
          customIcon: Icons.clean_hands_rounded,
        ),

        // ── Correções (Bug Fixes) ───────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.fix,
          title: 'Fluidez do Teclado na Pesquisa de PDFs',
          description:
              'Otimização na renderização do campo de busca na biblioteca de PDFs, garantindo abertura e fechamento suave do teclado sem travamentos.',
          customIcon: Icons.speed_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.fix,
          title: 'Correção de Overflow no Plano de Estudos',
          description:
              'Eliminação de quebra de layout de pixels no cartão de reflexão diária da aba Hoje.',
          customIcon: Icons.check_circle_rounded,
        ),
      ],
    ),
    ReleaseNoteVersion(
      versionName: '2.0.6',
      buildNumber: 15,
      title: 'Estilo da Barra de Navegação, Histórico de IA & Otimizações',
      releaseDate: '04 de Novembro de 2026',
      highlight:
          'Opção de escolher entre barra de navegação Fixa ou Flutuante nas configurações, alinhamento milimétrico do rodapé sem frestas, histórico de IA Theos, formatação visual refinada e grandes otimizações de performance.',
      items: [
        // ── Novos Recursos (Implementações) ─────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Estilo de Barra de Navegação',
          description:
              'Escolha nas configurações do app entre a barra Flutuante moderna ou a barra Fixa no rodapé inferior, com persistência automática no aparelho.',
          customIcon: Icons.view_sidebar_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Histórico de Conversas da IA Theos',
          description:
              'Acesse e retome diálogos anteriores com a IA teológica diretamente no aplicativo através do novo painel de histórico de conversas.',
          customIcon: Icons.history_rounded,
        ),

        // ── Modificações & Melhorias ─────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Formatação Visual Aprimorada na IA',
          description:
              'Respostas bíblicas e doutrinárias agora utilizam cartões visuais com citações em bloco e listas estruturadas, evitando tabelas comprimidas em smartphones.',
          customIcon: Icons.format_list_bulleted_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Performance e Economia de GPU Web',
          description:
              'Otimização no processamento visual no navegador Web, eliminando sobrecarga de contextos gráficos WebGL e garantindo rolagem extremamente suave.',
          customIcon: Icons.speed_rounded,
        ),

        // ── Correções (Bug Fixes) ───────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.fix,
          title: 'Ajuste Perfeito no Rodapé da Tela',
          description:
              'Eliminada a fresta visível na base da tela quando a barra de navegação está no modo fixo, garantindo encaixe 100% sólido e milimétrico.',
          customIcon: Icons.check_circle_outline_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.fix,
          title: 'Correção de Overflow nas Configurações',
          description:
              'Ajustado o cabeçalho expansível e botão de minimizar nas configurações para evitar aviso de overflow em telas compactas.',
          customIcon: Icons.aspect_ratio_rounded,
        ),
      ],
    ),
    ReleaseNoteVersion(
      versionName: '2.0.5',
      buildNumber: 14,
      title: 'Menu Lateral Flutuante, Acesso Rápido a Temas & Otimizações',
      releaseDate: '27 de Outubro de 2026',
      highlight:
          'Novo botão em aba arredondada na borda do menu lateral para tablets e web, atalho direto para alternar temas (Escuro, Claro e Sépia) na barra lateral, e correções de layout.',
      items: [
        // ── Novos Recursos (Implementações) ─────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Aba Flutuante de Abertura do Menu',
          description:
              'Novo botão estilo pílula acoplado à borda do menu lateral para tablets e computadores, com animação fluida e ícone chevron indicador.',
          customIcon: Icons.menu_open_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Atalho Direto de Tema na Barra Lateral',
          description:
              'Acesso rápido com um toque à paleta de temas (Modo Escuro, Claro e Sépia) posicionado no rodapé da barra lateral.',
          customIcon: Icons.palette_outlined,
        ),

        // ── Modificações & Melhorias ─────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Cabeçalho e Logo Aperfeiçoados',
          description:
              'Exibição limpa e centralizada da logo quando o menu está recolhido, com o nome KeryxApp aparecendo com transição suave ao expandir.',
          customIcon: Icons.auto_awesome_rounded,
        ),

        // ── Correções (Bug Fixes) ───────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.fix,
          title: 'Detecção Confiável de Android no Navegador',
          description:
              'Corrigida a identificação de celulares Android no Chrome e navegadores web, garantindo a exibição do banner de download do APK mesmo com o modo "Para Computador" ativado.',
          customIcon: Icons.android_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.fix,
          title: 'Correção de Layout e Resolução Web',
          description:
              'Ajustada a geometria do avatar do perfil para evitar advertências de overflow e eliminada a dependência circular de módulos na versão Web.',
          customIcon: Icons.check_circle_outline_rounded,
        ),
      ],
    ),
    ReleaseNoteVersion(
      versionName: '2.0.4',
      buildNumber: 13,
      title: 'Stories Agrupados, Criação Dedicada & Navegação Bíblica',
      releaseDate: '26 de Outubro de 2026',
      highlight:
          'Stories agrupados por autor com navegação contínua estilo Instagram, modal exclusivo para criar stories de 24h com versículos da Bíblia, e botão Abrir na Bíblia com rolagem direta para o versículo selecionado.',
      items: [
        // ── Novos Recursos (Implementações) ─────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Stories Agrupados por Autor',
          description:
              'Cada usuário ou canal agora aparece apenas uma vez na bandeja do topo com seu avatar e nome. Ao abrir, todos os stories do mesmo autor passam em sequência antes de avançar para o próximo autor.',
          customIcon: Icons.auto_awesome_motion_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Novo Modal Exclusivo de Criar Stories',
          description:
              'Interface dedicada para meditação bíblica de 24 horas, com seletor completo de livros e versículos da Bíblia instalada, reflexão devocional e estilos de gradiente atmosférico.',
          customIcon: Icons.add_circle_outline_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Navegação Direta ao Versículo na Leitura',
          description:
              'Ao tocar em "Abrir na Bíblia" em qualquer post ou story, a tela de leitura abre exatamente no livro e capítulo correto e rola suavemente até o versículo selecionado.',
          customIcon: Icons.menu_book_rounded,
        ),

        // ── Modificações & Melhorias ─────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Separação Clara entre Feed e Stories',
          description:
              'O formulário do Feed agora é 100% focado em postagens da comunidade (orações, reflexões e testemunhos), sem misturar com a bandeja de stories.',
          customIcon: Icons.dashboard_customize_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Avatares Universais & Correção CORS Web',
          description:
              'Avatares do Google agora carregam perfeitamente na versão Web sem bloqueios de CORS, além de gerarem iniciais com belos gradientes quando não houver foto.',
          customIcon: Icons.account_circle_rounded,
        ),
      ],
    ),
    ReleaseNoteVersion(
      versionName: '2.0.3',
      buildNumber: 12,
      title: 'Comunidade Conectada, Tela Otimizada & Mais Segurança',
      releaseDate: '26 de Outubro de 2026',
      highlight:
          'Compartilhe pedidos de oração e testemunhos com toda a igreja em tempo real, aproveite um layout mais espaçoso e confortável no celular, e conte com downloads protegidos e autenticados.',
      items: [
        // ── Novos Recursos (Implementações) ─────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Feed Comunitário e Pedidos de Oração',
          description:
              'Compartilhe seus motivos de oração, louvores e reflexões no feed da Comunidade. Suas mensagens agora sincronizam instantaneamente para que todos os membros possam orar juntos.',
          customIcon: Icons.favorite_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Interações e Respostas no Feed',
          description:
              'Comente nas publicações, deixe mensagens de encorajamento bíblico e participe ativamente da vida comunitária da igreja.',
          customIcon: Icons.forum_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.feature,
          title: 'Verificação Inteligente de Atualizações',
          description:
              'O aplicativo agora confere automaticamente a autenticidade de cada nova atualização baixada, garantindo uma instalação 100% segura e confiável.',
          customIcon: Icons.verified_user_rounded,
        ),

        // ── Modificações & Melhorias ─────────────────────────────────
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Visual Mais Limpo e Espaçoso no Celular',
          description:
              'O card de Intercessão do Dia agora é compacto e pode ser fechado com um toque, liberando muito mais espaço na tela para você acompanhar as postagens e meditar na Palavra.',
          customIcon: Icons.smartphone_rounded,
        ),
        ReleaseNoteItem(
          category: ReleaseNoteCategory.improvement,
          title: 'Instalação Fácil no iPhone e iPad',
          description:
              'Novo guia ilustrado que mostra exatamente onde tocar no Safari para fixar o KeryxApp na sua tela inicial, com instruções sob medida para iPhone e iPad.',
          customIcon: Icons.add_to_home_screen_rounded,
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
