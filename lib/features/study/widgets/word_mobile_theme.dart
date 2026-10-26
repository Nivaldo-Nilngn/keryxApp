import 'package:flutter/material.dart';

/// Design tokens, cores e constantes visuais da interface do Microsoft Word Mobile
class WordMobileTheme {
  // Cores de Identidade do Microsoft Word
  static const Color primaryBlue = Color(0xFF185ABD);
  static const Color darkBlue = Color(0xFF103F91);
  static const Color headerBlue = Color(0xFF185ABD);
  static const Color accentBlue = Color(0xFF2B579A);
  static const Color lightBlueBg = Color(0xFFEBF3FC);
  static const Color activeTint = Color(0xFF185ABD);

  // Superfícies e bordas
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1F1F23);
  static const Color toolbarBgLight = Color(0xFFF3F4F6);
  static const Color toolbarBgDark = Color(0xFF28282D);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF38383F);

  // Textos
  static const Color textPrimaryLight = Color(0xFF1F2937);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textPrimaryDark = Color(0xFFF3F4F6);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  // Paleta de Realce (Highlighter) oficial do Microsoft Word Mobile
  static const List<HighlightColorOption> highlightColors = [
    HighlightColorOption(name: 'Sem Cor', color: null, icon: Icons.do_not_disturb_alt),
    HighlightColorOption(name: 'Amarelo', color: Color(0xFFFFFF00)),
    HighlightColorOption(name: 'Verde Claro', color: Color(0xFF00FF00)),
    HighlightColorOption(name: 'Ciano', color: Color(0xFF00FFFF)),
    HighlightColorOption(name: 'Magenta', color: Color(0xFFFF00FF)),
    HighlightColorOption(name: 'Azul Claro', color: Color(0xFF0000FF)),
    HighlightColorOption(name: 'Vermelho', color: Color(0xFFFF0000)),
    HighlightColorOption(name: 'Azul Escuro', color: Color(0xFF000080)),
    HighlightColorOption(name: 'Azul Petróleo', color: Color(0xFF008080)),
    HighlightColorOption(name: 'Verde Escuro', color: Color(0xFF008000)),
    HighlightColorOption(name: 'Roxo', color: Color(0xFF800080)),
    HighlightColorOption(name: 'Marrom', color: Color(0xFF800000)),
    HighlightColorOption(name: 'Laranja', color: Color(0xFFFFA500)),
    HighlightColorOption(name: 'Cinza 50%', color: Color(0xFF808080)),
    HighlightColorOption(name: 'Cinza 25%', color: Color(0xFFC0C0C0)),
    HighlightColorOption(name: 'Preto', color: Color(0xFF000000)),
  ];

  // Paleta de Cores de Fonte oficial do Microsoft Office
  static const List<Color> fontColors = [
    Color(0xFF000000), // Automático / Preto
    Color(0xFFFFFFFF), // Branco
    Color(0xFF595959), // Cinza
    Color(0xFF185ABD), // Azul Word
    Color(0xFF107C41), // Verde Excel
    Color(0xFFD83B01), // Laranja Office
    Color(0xFFC43E1C), // PowerPoint
    Color(0xFF742774), // OneNote
    Color(0xFF0078D4), // Windows Blue
    Color(0xFFE81123), // Vermelho
    Color(0xFFFFB900), // Dourado
    Color(0xFF8E8CD8), // Lilás
    Color(0xFF00B7C3), // Turquesa
    Color(0xFFB146C2), // Magenta
  ];

  // Fontes recomendadas do Office e Google Fonts
  static const List<String> availableFonts = [
    'Calibri',
    'Aptos',
    'Arial',
    'Georgia',
    'Times New Roman',
    'Outfit',
    'Inter',
    'Roboto',
    'Merriweather',
  ];

  // Tamanhos de fonte padrão do Word Mobile
  static const List<int> fontSizes = [
    8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72
  ];
}

class HighlightColorOption {
  final String name;
  final Color? color;
  final IconData? icon;

  const HighlightColorOption({
    required this.name,
    this.color,
    this.icon,
  });
}

/// Modelos prontos de documentos no estilo Microsoft Word Bíblico
class WordDocumentTemplate {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String initialContentJson;

  const WordDocumentTemplate({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.initialContentJson,
  });

  static List<WordDocumentTemplate> get defaultTemplates => [
    const WordDocumentTemplate(
      id: 'blank',
      title: 'Documento em branco',
      subtitle: 'Comece a escrever do zero',
      icon: Icons.note_add_outlined,
      color: WordMobileTheme.primaryBlue,
      initialContentJson: '[{"insert":"\\n"}]',
    ),
    const WordDocumentTemplate(
      id: 'sermon_outline',
      title: 'Esboço de Sermão',
      subtitle: 'Estrutura completa homilética',
      icon: Icons.record_voice_over_outlined,
      color: Color(0xFFD83B01),
      initialContentJson: r'''[
        {"insert":"ESBOÇO DE SERMÃO\n","attributes":{"header":1,"bold":true,"align":"center"}},
        {"insert":"\n"},
        {"insert":"Título: ","attributes":{"bold":true}},
        {"insert":"O Poder da Graça Transformadora\n"},
        {"insert":"Texto Bíblico Base: ","attributes":{"bold":true}},
        {"insert":"Efésios 2:8-10\n"},
        {"insert":"Tema Principal: ","attributes":{"bold":true}},
        {"insert":"Salvação mediante a fé e vida de boas obras\n"},
        {"insert":"\n"},
        {"insert":"I. INTRODUÇÃO\n","attributes":{"header":2,"bold":true}},
        {"insert":"• Gancho inicial: Conectar com uma experiência do cotidiano.\n","attributes":{"list":"bullet"}},
        {"insert":"• Contexto da passagem: A carta aos Efésios e a riqueza de Deus.\n","attributes":{"list":"bullet"}},
        {"insert":"• Proposição: Não somos salvos por mérito, mas para um propósito.\n","attributes":{"list":"bullet"}},
        {"insert":"\n"},
        {"insert":"II. DESENVOLVIMENTO (PONTOS PRINCIPAIS)\n","attributes":{"header":2,"bold":true}},
        {"insert":"1. A Origem da Graça (v. 8) — Um dom imerecido de Deus.\n","attributes":{"bold":true}},
        {"insert":"Explicação exegética e ilustração prática da graça versus merecimento.\n"},
        {"insert":"2. A Exclusão do Orgulho (v. 9) — Salvos para glorificar a Deus.\n","attributes":{"bold":true}},
        {"insert":"Ninguém pode se gloriar; toda honra pertence a Cristo.\n"},
        {"insert":"3. O Propósito da Salvação (v. 10) — Obra-prima para boas obras.\n","attributes":{"bold":true}},
        {"insert":"Fomos recriados para andar nas obras que Ele preparou de antemão.\n"},
        {"insert":"\n"},
        {"insert":"III. APLICAÇÃO PRÁTICA\n","attributes":{"header":2,"bold":true}},
        {"insert":"• Como viver em resposta a essa graça nesta semana?\n","attributes":{"list":"bullet"}},
        {"insert":"• Desafio pessoal: Perdoar como fomos perdoados e servir com amor.\n","attributes":{"list":"bullet"}},
        {"insert":"\n"},
        {"insert":"IV. CONCLUSÃO E APELO\n","attributes":{"header":2,"bold":true}},
        {"insert":"Recapitulação da mensagem e convite à oração e entrega.\n\n"}
      ]''',
    ),
    const WordDocumentTemplate(
      id: 'bible_study',
      title: 'Estudo Bíblico',
      subtitle: 'Análise profunda e aplicação',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF107C41),
      initialContentJson: r'''[
        {"insert":"ESTUDO BÍBLICO EXPOSITIVO\n","attributes":{"header":1,"bold":true,"align":"center"}},
        {"insert":"\n"},
        {"insert":"Passagem em Estudo: ","attributes":{"bold":true}},
        {"insert":"Romanos 8:28-39\n"},
        {"insert":"Data: ","attributes":{"bold":true}},
        {"insert":"Hoje\n"},
        {"insert":"\n"},
        {"insert":"1. Contexto Histórico e Literário\n","attributes":{"header":2,"bold":true}},
        {"insert":"• Autor: Apóstolo Paulo.\n","attributes":{"list":"bullet"}},
        {"insert":"• Destinatários: Cristãos em Roma (judeus e gentios).\n","attributes":{"list":"bullet"}},
        {"insert":"• Objetivo: Consolar a igreja em meio ao sofrimento e perseguição.\n","attributes":{"list":"bullet"}},
        {"insert":"\n"},
        {"insert":"2. Análise do Texto\n","attributes":{"header":2,"bold":true}},
        {"insert":"\"Sabemos que todas as coisas cooperam para o bem daqueles que amam a Deus...\"\n","attributes":{"blockquote":true}},
        {"insert":"• Palavras-chave no grego:\n","attributes":{"bold":true}},
        {"insert":"- Sunergeo (cooperar, trabalhar em conjunto)\n"},
        {"insert":"- Agathos (bem divino, espiritual e eterno)\n"},
        {"insert":"\n"},
        {"insert":"3. Lições Teológicas e Aplicação\n","attributes":{"header":2,"bold":true}},
        {"insert":"• Deus soberanamente orquestra todas as circunstâncias.\n","attributes":{"list":"bullet"}},
        {"insert":"• Nada pode nos separar do amor de Deus que está em Cristo.\n","attributes":{"list":"bullet"}},
        {"insert":"\n"}
      ]''',
    ),
    const WordDocumentTemplate(
      id: 'devotional',
      title: 'Devocional Diário',
      subtitle: 'Oração, meditação e resposta',
      icon: Icons.wb_sunny_outlined,
      color: Color(0xFFFFB900),
      initialContentJson: r'''[
        {"insert":"DEVOCIONAL DIÁRIO\n","attributes":{"header":1,"bold":true,"align":"center"}},
        {"insert":"\n"},
        {"insert":"Data: ","attributes":{"bold":true}},
        {"insert":"Leitura de Hoje\n"},
        {"insert":"Versículo Chave: ","attributes":{"bold":true}},
        {"insert":"Salmos 119:105 — \"Lâmpada para os meus pés é a tua palavra e luz, para o meu caminho.\"\n"},
        {"insert":"\n"},
        {"insert":"O que o texto ensina sobre Deus?\n","attributes":{"header":3,"bold":true}},
        {"insert":"Deus se importa em guiar cada passo do nosso dia a dia.\n\n"},
        {"insert":"O que Deus falou ao meu coração?\n","attributes":{"header":3,"bold":true}},
        {"insert":"Não preciso ter medo do futuro; preciso apenas dar o próximo passo guiado pela Sua luz.\n\n"},
        {"insert":"Motivos de Oração e Gratidão:\n","attributes":{"header":3,"bold":true}},
        {"insert":"1. Gratidão pelo cuidado de Deus.\n","attributes":{"list":"bullet"}},
        {"insert":"2. Pedido de sabedoria e discernimento para decisões.\n","attributes":{"list":"bullet"}},
        {"insert":"\n"}
      ]''',
    ),
    const WordDocumentTemplate(
      id: 'exegetical_notes',
      title: 'Anotação Exegética',
      subtitle: 'Grego, Hebraico e Hermenêutica',
      icon: Icons.translate_rounded,
      color: Color(0xFF742774),
      initialContentJson: r'''[
        {"insert":"CADERNO EXEGÉTICO & LINGUÍSTICO\n","attributes":{"header":1,"bold":true,"align":"center"}},
        {"insert":"\n"},
        {"insert":"Referência: ","attributes":{"bold":true}},
        {"insert":"João 1:1-5\n"},
        {"insert":"Língua Original: ","attributes":{"bold":true}},
        {"insert":"Grego Koiné\n"},
        {"insert":"\n"},
        {"insert":"1. Texto no Original e Transliteração\n","attributes":{"header":2,"bold":true}},
        {"insert":"Ἐν ἀρχῇ ἦν ὁ λόγος, καὶ ὁ λόγος ἦν πρὸς τὸν θεόν...\nEn archē ēn ho logos, kai ho logos ēn pros ton theon...\n","attributes":{"blockquote":true}},
        {"insert":"\n"},
        {"insert":"2. Vocabulário e Termos Strong\n","attributes":{"header":2,"bold":true}},
        {"insert":"• G3056 (Logos): Palavra, verbo, comunicação encarnada.\n","attributes":{"list":"bullet"}},
        {"insert":"• G4314 (Pros): Voltado para, em comunhão íntima face a face.\n","attributes":{"list":"bullet"}},
        {"insert":"• G2316 (Theos): Divindade plena, Deus.\n","attributes":{"list":"bullet"}},
        {"insert":"\n"},
        {"insert":"3. Implicações Doutrinárias\n","attributes":{"header":2,"bold":true}},
        {"insert":"Afirmação inequívoca da pré-existência eterna e divindade de Cristo.\n\n"}
      ]''',
    ),
  ];
}
