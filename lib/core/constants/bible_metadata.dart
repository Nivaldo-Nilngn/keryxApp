class BibleMetadata {
  static const Map<int, Map<String, dynamic>> bookDetails = {
    1: {"abbrev": "gn", "group": "Pentateuco", "author": "Moisés", "chapters": 50},
    2: {"abbrev": "ex", "group": "Pentateuco", "author": "Moisés", "chapters": 40},
    3: {"abbrev": "lv", "group": "Pentateuco", "author": "Moisés", "chapters": 27},
    4: {"abbrev": "nm", "group": "Pentateuco", "author": "Moisés", "chapters": 36},
    5: {"abbrev": "dt", "group": "Pentateuco", "author": "Moisés", "chapters": 34},
    6: {"abbrev": "js", "group": "Históricos", "author": "Josué", "chapters": 24},
    7: {"abbrev": "jz", "group": "Históricos", "author": "Samuel", "chapters": 21},
    8: {"abbrev": "rt", "group": "Históricos", "author": "Samuel", "chapters": 4},
    9: {"abbrev": "1sm", "group": "Históricos", "author": "Samuel", "chapters": 31},
    10: {"abbrev": "2sm", "group": "Históricos", "author": "Samuel", "chapters": 24},
    11: {"abbrev": "1rs", "group": "Históricos", "author": "Jeremias", "chapters": 22},
    12: {"abbrev": "2rs", "group": "Históricos", "author": "Jeremias", "chapters": 25},
    13: {"abbrev": "1cr", "group": "Históricos", "author": "Esdras", "chapters": 29},
    14: {"abbrev": "2cr", "group": "Históricos", "author": "Esdras", "chapters": 36},
    15: {"abbrev": "ed", "group": "Históricos", "author": "Esdras", "chapters": 10},
    16: {"abbrev": "ne", "group": "Históricos", "author": "Neemias", "chapters": 13},
    17: {"abbrev": "et", "group": "Históricos", "author": "Mardoqueu", "chapters": 10},
    18: {"abbrev": "jb", "group": "Poéticos", "author": "Desconhecido", "chapters": 42},
    19: {"abbrev": "sl", "group": "Poéticos", "author": "Davi, Asafe, outros", "chapters": 150},
    20: {"abbrev": "pv", "group": "Poéticos", "author": "Salomão", "chapters": 31},
    21: {"abbrev": "ec", "group": "Poéticos", "author": "Salomão", "chapters": 12},
    22: {"abbrev": "ct", "group": "Poéticos", "author": "Salomão", "chapters": 8},
    23: {"abbrev": "is", "group": "Profetas maiores", "author": "Isaías", "chapters": 66},
    24: {"abbrev": "jr", "group": "Profetas maiores", "author": "Jeremias", "chapters": 52},
    25: {"abbrev": "lm", "group": "Profetas maiores", "author": "Jeremias", "chapters": 5},
    26: {"abbrev": "ez", "group": "Profetas maiores", "author": "Ezequiel", "chapters": 48},
    27: {"abbrev": "dn", "group": "Profetas maiores", "author": "Daniel", "chapters": 12},
    28: {"abbrev": "os", "group": "Profetas menores", "author": "Oseias", "chapters": 14},
    29: {"abbrev": "jl", "group": "Profetas menores", "author": "Joel", "chapters": 3},
    30: {"abbrev": "am", "group": "Profetas menores", "author": "Amós", "chapters": 9},
    31: {"abbrev": "ob", "group": "Profetas menores", "author": "Obadias", "chapters": 1},
    32: {"abbrev": "jn", "group": "Profetas menores", "author": "Jonas", "chapters": 4},
    33: {"abbrev": "mq", "group": "Profetas menores", "author": "Miqueias", "chapters": 7},
    34: {"abbrev": "na", "group": "Profetas menores", "author": "Naum", "chapters": 3},
    35: {"abbrev": "hc", "group": "Profetas menores", "author": "Habacuque", "chapters": 3},
    36: {"abbrev": "sf", "group": "Profetas menores", "author": "Sofonias", "chapters": 3},
    37: {"abbrev": "ag", "group": "Profetas menores", "author": "Ageu", "chapters": 2},
    38: {"abbrev": "zc", "group": "Profetas menores", "author": "Zacarias", "chapters": 14},
    39: {"abbrev": "ml", "group": "Profetas menores", "author": "Malaquias", "chapters": 4},
    40: {"abbrev": "mt", "group": "Evangelhos", "author": "Mateus", "chapters": 28},
    41: {"abbrev": "mc", "group": "Evangelhos", "author": "Marcos", "chapters": 16},
    42: {"abbrev": "lc", "group": "Evangelhos", "author": "Lucas", "chapters": 24},
    43: {"abbrev": "jo", "group": "Evangelhos", "author": "João", "chapters": 21},
    44: {"abbrev": "at", "group": "Históricos", "author": "Lucas", "chapters": 28},
    45: {"abbrev": "rm", "group": "Epístolas", "author": "Paulo", "chapters": 16},
    46: {"abbrev": "1co", "group": "Epístolas", "author": "Paulo", "chapters": 16},
    47: {"abbrev": "2co", "group": "Epístolas", "author": "Paulo", "chapters": 13},
    48: {"abbrev": "gl", "group": "Epístolas", "author": "Paulo", "chapters": 6},
    49: {"abbrev": "ef", "group": "Epístolas", "author": "Paulo", "chapters": 6},
    50: {"abbrev": "fp", "group": "Epístolas", "author": "Paulo", "chapters": 4},
    51: {"abbrev": "cl", "group": "Epístolas", "author": "Paulo", "chapters": 4},
    52: {"abbrev": "1ts", "group": "Epístolas", "author": "Paulo", "chapters": 5},
    53: {"abbrev": "2ts", "group": "Epístolas", "author": "Paulo", "chapters": 3},
    54: {"abbrev": "1tm", "group": "Epístolas", "author": "Paulo", "chapters": 6},
    55: {"abbrev": "2tm", "group": "Epístolas", "author": "Paulo", "chapters": 4},
    56: {"abbrev": "tt", "group": "Epístolas", "author": "Paulo", "chapters": 3},
    57: {"abbrev": "fm", "group": "Epístolas", "author": "Paulo", "chapters": 1},
    58: {"abbrev": "hb", "group": "Epístolas", "author": "Desconhecido", "chapters": 13},
    59: {"abbrev": "tg", "group": "Epístolas", "author": "Tiago", "chapters": 5},
    60: {"abbrev": "1pe", "group": "Epístolas", "author": "Pedro", "chapters": 5},
    61: {"abbrev": "2pe", "group": "Epístolas", "author": "Pedro", "chapters": 3},
    62: {"abbrev": "1jo", "group": "Epístolas", "author": "João", "chapters": 5},
    63: {"abbrev": "2jo", "group": "Epístolas", "author": "João", "chapters": 1},
    64: {"abbrev": "3jo", "group": "Epístolas", "author": "João", "chapters": 1},
    65: {"abbrev": "jd", "group": "Epístolas", "author": "Judas", "chapters": 1},
    66: {"abbrev": "ap", "group": "Proféticos", "author": "João", "chapters": 22},
  };

  static Map<String, dynamic>? getMetadata(int id) {
    return bookDetails[id];
  }

  /// Nomes completos dos 66 livros em Português (índice 1-based).
  static const Map<int, String> bookNames = {
    1: 'Gênesis',          2: 'Êxodo',            3: 'Levítico',
    4: 'Números',          5: 'Deuteronômio',      6: 'Josué',
    7: 'Juízes',           8: 'Rute',              9: '1 Samuel',
    10: '2 Samuel',        11: '1 Reis',           12: '2 Reis',
    13: '1 Crônicas',      14: '2 Crônicas',       15: 'Esdras',
    16: 'Neemias',         17: 'Ester',            18: 'Jó',
    19: 'Salmos',          20: 'Provérbios',        21: 'Eclesiastes',
    22: 'Cânticos',        23: 'Isaías',            24: 'Jeremias',
    25: 'Lamentações',     26: 'Ezequiel',          27: 'Daniel',
    28: 'Oséias',          29: 'Joel',              30: 'Amós',
    31: 'Obadias',         32: 'Jonas',             33: 'Miqueias',
    34: 'Naum',            35: 'Habacuque',         36: 'Sofonias',
    37: 'Ageu',            38: 'Zacarias',          39: 'Malaquias',
    40: 'Mateus',          41: 'Marcos',            42: 'Lucas',
    43: 'João',            44: 'Atos',              45: 'Romanos',
    46: '1 Coríntios',     47: '2 Coríntios',       48: 'Gálatas',
    49: 'Efésios',         50: 'Filipenses',         51: 'Colossenses',
    52: '1 Tessalonicenses', 53: '2 Tessalonicenses', 54: '1 Timóteo',
    55: '2 Timóteo',       56: 'Tito',              57: 'Filemom',
    58: 'Hebreus',         59: 'Tiago',             60: '1 Pedro',
    61: '2 Pedro',         62: '1 João',            63: '2 João',
    64: '3 João',          65: 'Judas',             66: 'Apocalipse',
  };

  /// Retorna o nome completo do livro pelo ID (1–66).
  static String getBookName(int id) {
    return bookNames[id] ?? 'Livro $id';
  }

  static List<Map<String, dynamic>> get books => bookNames.entries.map((e) => {'id': e.key, 'name': e.value}).toList();

  static String _removeAccents(String str) {
    const withAccents = 'àáâãäåèéêëìíîïòóôõöùúûüýñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝÑÇ';
    const withoutAccents = 'aaaaaaeeeeiiiiooooouuuuyncAAAAAAEEEEIIIIOOOOOUUUUYNC';
    var result = str;
    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return result;
  }

  static const Map<String, int> _aliases = {
    'jb': 18,
    'job': 18,
    'jó': 18,
    'jo': 43,
    'jão': 43,
    'jao': 43,
    'ps': 19,
    'jn': 32, // Jonas
  };

  /// Busca o ID do livro por nome, abreviatura ou ID numérico.
  static int findBookId(String query) {
    if (query.isEmpty) return 1;

    final trimmed = query.trim();

    // 1. Tenta numérico
    final id = int.tryParse(trimmed);
    if (id != null && id >= 1 && id <= 66) return id;

    final lowerQuery = trimmed.toLowerCase();
    final cleanQuery = _removeAccents(lowerQuery);

    // 2. Tenta alias conhecido (ex: 'jó' -> 18, 'jo' -> 43, 'jb' -> 18, 'jao' -> 43)
    if (_aliases.containsKey(lowerQuery)) {
      return _aliases[lowerQuery]!;
    }
    if (_aliases.containsKey(cleanQuery)) {
      return _aliases[cleanQuery]!;
    }

    // 3. Tenta abreviação exata declarada
    for (var entry in bookDetails.entries) {
      if (entry.value['abbrev'].toString().toLowerCase() == cleanQuery) {
        return entry.key;
      }
    }

    // 4. Tenta nome completo exato (com ou sem acento)
    for (var entry in bookNames.entries) {
      final nameLower = entry.value.toLowerCase();
      if (nameLower == lowerQuery || _removeAccents(nameLower) == cleanQuery) {
        return entry.key;
      }
    }

    // 5. Busca parcial por início da palavra (prefixo)
    for (var entry in bookNames.entries) {
      final cleanName = _removeAccents(entry.value.toLowerCase());
      if (cleanName.startsWith(cleanQuery)) {
        return entry.key;
      }
    }

    // 6. Busca parcial genérica
    for (var entry in bookNames.entries) {
      final cleanName = _removeAccents(entry.value.toLowerCase());
      if (cleanName.contains(cleanQuery) || cleanQuery.contains(cleanName)) {
        return entry.key;
      }
    }

    return 1; // Default Genesis
  }

  static const Map<String, String> versionNames = {
    'NVI': 'Nova Versão Internacional (NVI)',
    'ACF': 'Almeida Corrigida Fiel (ACF)',
    'ACF2007': 'Almeida Corrigida Fiel 2007 (ACF)',
    'ACF 2011 FIEL 2011': 'Almeida Corrigida Fiel 2011 (ACF)',
    'ARA': 'Almeida Revista e Atualizada (ARA)',
    'ARA_S': 'Almeida Revista e Atualizada + Strong (ARA_S)',
    'ARA+STRONG ATUALIZADA + STRONG': 'Almeida Revista e Atualizada + Strong (ARA_S)',
    'ARA+STRONG - ATUALIZADA + STRONG': 'Almeida Revista e Atualizada + Strong (ARA_S)',
    'ARC': 'Almeida Revista e Corrigida (ARC)',
    'ARC1969': 'Almeida Revista e Corrigida 1969 (ARC)',
    'ARC2009 SBB CORRIGIDA 2009': 'Almeida Revista e Corrigida 2009 (ARC)',
    'NVT': 'Nova Versão Transformadora (NVT)',
    'NAA': 'Nova Almeida Atualizada (NAA)',
    'NOVA ALMEIDA ATUALIZADA 2017': 'Nova Almeida Atualizada 2017 (NAA)',
    'NBV': 'Nova Bíblia Viva (NBV)',
    'NTLH': 'Nova Tradução na Linguagem de Hoje (NTLH)',
    'AS21': 'Almeida Século 21 (AS21)',
    'A21': 'Almeida Século 21 (A21)',
    'JFAA': 'João Ferreira de Almeida Atualizada (JFAA)',
    'JFA RA BR': 'João Ferreira de Almeida Revista e Atualizada (JFA-RA)',
    'JFA RC PT': 'João Ferreira de Almeida Revista e Corrigida (JFA-RC)',
    'JFARASTRONG': 'João Ferreira de Almeida + Strong',
    'TB': 'Tradução Brasileira 1917 (TB)',
    'TB TRADUCAO BRASILEIRA EDICAO 2010': 'Tradução Brasileira 2010 (TB)',
    'KJA': 'King James Atualizada (KJA)',
    'KJA KING JAMES': 'King James Atualizada (KJA)',
    'KJF': 'King James Fiel 2000 (KJF)',
    'LTT2009': 'Bíblia Literal Anotada (LTT2009)',
    'LTT 2015 LITERAL 2015': 'Bíblia Literal Anotada (2015)',
    'LTT2009 LITERAL': 'Bíblia Literal Anotada 2009 (LTT)',
    'VFL': 'Versão Fácil de Ler (VFL)',
    'VFL VERSAO FACIL DE LER': 'Versão Fácil de Ler (VFL)',
    'NA': 'Nova Almeida (NA)',
    'VIVA': 'Bíblia Viva (VIVA)',
    'AMPLIFICADA': 'Bíblia Amplificada',
    'MENSAGEM': 'A Mensagem',
    'BIBLIA0 MSG AMENSAGEM': 'A Mensagem',
    'BIBLIA DE JERUSALEM': 'Bíblia de Jerusalém',
    'BIBLIALIVRE': 'Bíblia Livre',
    'BLIVRE': 'Bíblia Livre',
    'BJP': 'Bíblia Judaica',
    'BPT': 'A Bíblia para Todos (BPT)',
    'BPT BIBLIA PARA TODOS': 'Bíblia Para Todos (BPT)',
    'CNBB': 'Bíblia CNBB',
    'CORRIGIDA FIEL 1753 1995': 'Almeida Corrigida Fiel 1995 (ACF)',
    'EDICAO PASTORAL': 'Bíblia Edição Pastoral',
    'GREGO TR': 'Novo Testamento Grego Textus Receptus (TR)',
    'HISB': 'Bíblia Hebraica (HiSB)',
    'NT HEBRAICO': 'Novo Testamento Hebraico',
    'RVP REINA VALERA PORTUGUES': 'Reina-Valera em Português (RVP)',
    'TNM TRADUCAO DO NOVO MUNDO': 'Tradução do Novo Mundo (TNM)',
  };

  /// Quantidade canônica de versículos por capítulo para todos os 66 livros da Bíblia (1..66).
  static const Map<int, List<int>> bookVerseCounts = {
    1: [31, 25, 24, 26, 32, 22, 24, 22, 29, 32, 32, 20, 18, 24, 21, 16, 27, 33, 38, 18, 34, 24, 20, 67, 34, 35, 46, 22, 35, 43, 55, 32, 20, 31, 29, 43, 36, 30, 23, 23, 57, 38, 34, 34, 28, 34, 31, 22, 33, 26],
    2: [22, 25, 22, 31, 23, 30, 25, 32, 35, 29, 10, 51, 22, 31, 27, 36, 16, 27, 25, 26, 36, 31, 33, 18, 40, 37, 21, 43, 46, 38, 18, 35, 23, 35, 35, 38, 29, 31, 43, 38],
    3: [17, 16, 17, 35, 19, 30, 38, 36, 24, 20, 47, 8, 59, 57, 33, 34, 16, 30, 37, 27, 24, 33, 44, 23, 55, 46, 34],
    4: [54, 34, 51, 49, 31, 27, 89, 26, 23, 36, 35, 16, 33, 45, 41, 50, 13, 32, 22, 29, 35, 41, 30, 25, 18, 65, 23, 31, 40, 16, 54, 42, 56, 29, 34, 13],
    5: [46, 37, 29, 49, 33, 25, 26, 20, 29, 22, 32, 32, 18, 29, 23, 22, 20, 22, 21, 20, 23, 30, 25, 22, 19, 19, 26, 68, 29, 20, 30, 52, 29, 12],
    6: [18, 24, 17, 24, 15, 27, 26, 35, 27, 43, 23, 24, 33, 15, 63, 10, 18, 28, 51, 9, 45, 34, 16, 33],
    7: [36, 23, 31, 24, 31, 40, 25, 35, 57, 18, 40, 15, 25, 20, 20, 31, 13, 31, 30, 48, 25],
    8: [22, 23, 18, 22],
    9: [28, 36, 21, 22, 12, 21, 17, 22, 27, 27, 15, 25, 23, 52, 35, 23, 58, 30, 24, 42, 15, 23, 29, 22, 44, 25, 12, 25, 11, 31, 13],
    10: [27, 32, 39, 12, 25, 23, 29, 18, 13, 19, 27, 31, 39, 33, 37, 23, 29, 33, 43, 26, 22, 51, 39, 25],
    11: [53, 46, 28, 34, 18, 38, 51, 66, 28, 29, 43, 33, 34, 31, 34, 34, 24, 46, 21, 43, 29, 53],
    12: [18, 25, 27, 44, 27, 33, 20, 29, 37, 36, 21, 21, 25, 29, 38, 20, 41, 37, 37, 21, 26, 20, 37, 20, 30],
    13: [54, 55, 24, 43, 26, 81, 40, 40, 44, 14, 47, 40, 14, 17, 29, 43, 27, 17, 19, 8, 30, 19, 32, 31, 31, 32, 34, 21, 30],
    14: [17, 18, 17, 22, 14, 42, 22, 18, 31, 19, 23, 16, 22, 15, 19, 14, 19, 34, 11, 37, 20, 12, 21, 27, 28, 23, 9, 27, 36, 27, 21, 33, 25, 33, 27, 23],
    15: [11, 70, 13, 24, 17, 22, 28, 36, 15, 44],
    16: [11, 20, 32, 23, 19, 19, 73, 18, 38, 39, 36, 47, 31],
    17: [22, 23, 15, 17, 14, 14, 10, 17, 32, 3],
    18: [22, 13, 26, 21, 27, 30, 21, 22, 35, 22, 20, 25, 28, 22, 35, 22, 16, 21, 29, 29, 34, 30, 17, 25, 6, 14, 23, 28, 25, 31, 40, 22, 33, 37, 16, 33, 24, 41, 30, 24, 34, 17],
    19: [6, 12, 8, 8, 12, 10, 17, 9, 20, 18, 7, 8, 6, 7, 5, 11, 15, 50, 14, 9, 13, 31, 6, 10, 22, 12, 14, 9, 11, 12, 24, 11, 22, 22, 28, 12, 40, 22, 13, 17, 13, 11, 5, 26, 17, 11, 9, 14, 20, 23, 19, 9, 6, 7, 23, 13, 11, 11, 17, 12, 8, 12, 11, 10, 13, 20, 7, 35, 36, 5, 24, 20, 28, 23, 10, 12, 20, 72, 13, 19, 16, 8, 18, 12, 13, 17, 7, 18, 52, 17, 16, 15, 5, 23, 11, 13, 12, 9, 9, 5, 8, 28, 22, 35, 45, 48, 43, 13, 31, 7, 10, 10, 9, 8, 18, 19, 2, 29, 176, 7, 8, 9, 4, 8, 5, 6, 5, 6, 8, 8, 3, 18, 3, 3, 21, 26, 9, 8, 24, 13, 10, 7, 12, 15, 21, 10, 20, 14, 9, 6],
    20: [33, 22, 35, 27, 23, 35, 27, 36, 18, 32, 31, 28, 25, 35, 33, 33, 28, 24, 29, 30, 31, 29, 35, 34, 28, 28, 27, 28, 27, 33, 31],
    21: [18, 26, 22, 16, 20, 12, 29, 17, 18, 20, 10, 14],
    22: [17, 17, 11, 16, 16, 13, 13, 14],
    23: [31, 22, 26, 6, 30, 13, 25, 22, 21, 34, 16, 6, 22, 32, 9, 14, 14, 7, 25, 6, 17, 25, 18, 23, 12, 21, 13, 29, 24, 33, 9, 20, 24, 17, 10, 22, 38, 22, 8, 31, 29, 25, 28, 28, 25, 13, 15, 22, 26, 11, 23, 15, 12, 17, 13, 12, 21, 14, 21, 22, 11, 12, 19, 12, 25, 24],
    24: [19, 37, 25, 31, 31, 30, 34, 22, 26, 25, 23, 17, 27, 22, 21, 21, 27, 23, 15, 18, 14, 30, 40, 10, 38, 24, 22, 17, 32, 24, 40, 44, 26, 22, 19, 32, 21, 28, 18, 16, 18, 22, 13, 30, 5, 28, 7, 47, 39, 46, 64, 34],
    25: [22, 22, 66, 22, 22],
    26: [28, 10, 27, 17, 17, 14, 27, 18, 11, 22, 25, 28, 23, 23, 8, 63, 24, 32, 14, 49, 32, 31, 49, 27, 17, 21, 36, 26, 21, 26, 18, 32, 33, 31, 15, 38, 28, 23, 29, 49, 26, 20, 27, 31, 25, 24, 23, 35],
    27: [21, 49, 30, 37, 31, 28, 28, 27, 27, 21, 45, 13],
    28: [11, 23, 5, 19, 15, 11, 16, 14, 17, 15, 12, 14, 16, 9],
    29: [20, 32, 21],
    30: [15, 16, 15, 13, 27, 14, 17, 14, 15],
    31: [21],
    32: [17, 10, 10, 11],
    33: [16, 13, 12, 13, 15, 16, 20],
    34: [15, 13, 19],
    35: [17, 20, 19],
    36: [18, 15, 20],
    37: [15, 23],
    38: [21, 13, 10, 14, 11, 15, 14, 23, 17, 12, 17, 14, 9, 21],
    39: [14, 17, 18, 6],
    40: [25, 23, 17, 25, 48, 34, 29, 34, 38, 42, 30, 50, 58, 36, 39, 28, 27, 35, 30, 34, 46, 46, 39, 51, 46, 75, 66, 20],
    41: [45, 28, 35, 41, 43, 56, 37, 38, 50, 52, 33, 44, 37, 72, 47, 20],
    42: [80, 52, 38, 44, 39, 49, 50, 56, 62, 42, 54, 59, 35, 35, 32, 31, 37, 43, 48, 47, 38, 71, 56, 53],
    43: [51, 25, 36, 54, 47, 71, 53, 59, 41, 42, 57, 50, 38, 31, 27, 33, 26, 40, 42, 31, 25],
    44: [26, 47, 26, 37, 42, 15, 60, 40, 43, 48, 30, 25, 52, 28, 41, 40, 34, 28, 41, 38, 40, 30, 35, 27, 27, 32, 44, 31],
    45: [32, 29, 31, 25, 21, 23, 25, 39, 33, 21, 36, 21, 14, 23, 33, 27],
    46: [31, 16, 23, 21, 13, 20, 40, 13, 27, 33, 34, 31, 13, 40, 58, 24],
    47: [24, 17, 18, 18, 21, 18, 16, 24, 15, 18, 33, 21, 14],
    48: [24, 21, 29, 31, 26, 18],
    49: [23, 22, 21, 32, 33, 24],
    50: [30, 30, 21, 23],
    51: [29, 23, 25, 18],
    52: [10, 20, 13, 18, 28],
    53: [12, 17, 18],
    54: [20, 15, 16, 16, 25, 21],
    55: [18, 26, 17, 22],
    56: [16, 15, 15],
    57: [25],
    58: [14, 18, 19, 16, 14, 20, 28, 13, 28, 39, 40, 29, 25],
    59: [27, 26, 18, 17, 20],
    60: [25, 25, 22, 19, 14],
    61: [21, 22, 18],
    62: [10, 29, 24, 21, 21],
    63: [13],
    64: [14],
    65: [25],
    66: [20, 29, 22, 11, 14, 17, 17, 13, 21, 11, 19, 17, 18, 20, 8, 21, 18, 24, 21, 15, 27, 21],
  };

  /// Retorna o total de versículos para um livro e capítulo específicos de forma instantânea (0ms).
  static int getVerseCount(int bookId, int chapter) {
    final list = bookVerseCounts[bookId];
    if (list != null && chapter >= 1 && chapter <= list.length) {
      return list[chapter - 1];
    }
    return 30; // fallback seguro
  }
}
