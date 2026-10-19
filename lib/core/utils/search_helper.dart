/// SearchHelper — busca inteligente para títulos de PDF
///
/// Recursos:
///   • Normalização de acentos (ção→cao, João→joao)
///   • Insensível a maiúsculas/minúsculas
///   • Multi-palavra: "vida eterna" acha arquivos com ambas as palavras
///   • Prefixo: "evangel" acha "evangelho", "evangelismo"
///   • Score de relevância: match exato > prefixo > contém > parcial
///   • Resultados ordenados por relevância
class SearchHelper {
  SearchHelper._();

  // ── Tabela de normalização de acentos ──────────────────────────────────────
  static const String _accented =
      'àáâãäåèéêëìíîïòóôõöùúûüýÿñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝŸÑÇ';
  static const String _normal =
      'aaaaaaeeeeiiiiooooouuuuyyNcAAAAAAEEEEIIIIOOOOOUUUUYYNC';

  /// Remove acentos, coloca em minúsculas e troca separadores por espaço.
  static String normalize(String text) {
    final buffer = StringBuffer();
    for (final ch in text.toLowerCase().runes) {
      final char = String.fromCharCode(ch);
      final idx = _accented.indexOf(char);
      buffer.write(idx >= 0 ? _normal[idx].toLowerCase() : char);
    }
    // Troca separadores comuns por espaço e remove extensão .pdf
    return buffer
        .toString()
        .replaceAll(RegExp(r'[_\-\.\(\)\[\]]+'), ' ')
        .replaceAll(RegExp(r'\s*\.pdf\s*$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Calcula score de relevância entre query e título (0.0 – 1.0).
  ///
  /// Pontuação por token:
  ///   1.0 = token exato
  ///   0.9 = token exato como prefixo de palavra
  ///   0.7 = título contém token (substring)
  ///   0.4 = fuzzy (1 caractere diferente) em alguma palavra
  ///   0.0 = nenhum match
  static double score(String query, String title) {
    final normQ = normalize(query);
    final normT = normalize(title);

    final qTokens =
        normQ.split(' ').where((t) => t.length >= 2).toList();
    if (qTokens.isEmpty) return 0.0;

    final tTokens =
        normT.split(' ').where((t) => t.isNotEmpty).toList();

    double total = 0.0;
    for (final qt in qTokens) {
      double best = 0.0;

      // 1. Título inteiro contém o token (mais rápido)
      if (normT.contains(qt)) {
        // Verifica se é match de palavra inteira
        best = tTokens.any((tt) => tt == qt)
            ? 1.0
            : tTokens.any((tt) => tt.startsWith(qt))
                ? 0.9
                : 0.7;
      }

      // 2. Fuzzy por token (só se ainda sem score alto e token >= 4 chars)
      if (best < 0.5 && qt.length >= 4) {
        for (final tt in tTokens) {
          if (_fuzzyDistance(qt, tt) <= 1) {
            best = best < 0.4 ? 0.4 : best;
            break;
          }
        }
      }

      total += best;
    }

    return total / qTokens.length;
  }

  /// Distância de Levenshtein simplificada (só 0 ou 1 diferenças).
  static int _fuzzyDistance(String a, String b) {
    if (a == b) return 0;
    if ((a.length - b.length).abs() > 2) return 99;

    // Inserção/deleção de 1 char
    final shorter = a.length <= b.length ? a : b;
    final longer = a.length <= b.length ? b : a;

    if (longer.length - shorter.length == 1) {
      // Verifica se shorter é substring de longer removendo um char
      for (int i = 0; i < longer.length; i++) {
        final candidate = longer.substring(0, i) + longer.substring(i + 1);
        if (candidate == shorter) return 1;
      }
      return 99;
    }

    // Substituição de 1 char (mesmo tamanho)
    int diffs = 0;
    for (int i = 0; i < shorter.length && diffs <= 1; i++) {
      if (shorter[i] != longer[i]) diffs++;
    }
    return diffs <= 1 ? diffs : 99;
  }

  /// Filtra e ordena uma lista por relevância.
  ///
  /// [minScore] controla o quão "frouxo" é o match:
  ///   Aumentar → mais preciso (menos resultados)
  ///   Diminuir → mais resultados, possíveis falsos positivos
  static List<T> search<T>({
    required List<T> items,
    required String Function(T) getTitle,
    required String query,
    double minScore = 0.35,
  }) {
    if (query.trim().isEmpty) return items;

    final scored = <({T item, double s})>[];
    for (final item in items) {
      final s = score(query, getTitle(item));
      if (s >= minScore) scored.add((item: item, s: s));
    }

    scored.sort((a, b) => b.s.compareTo(a.s));
    return scored.map((r) => r.item).toList();
  }
}
