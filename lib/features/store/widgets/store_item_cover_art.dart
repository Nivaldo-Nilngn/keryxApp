import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../model/store_item.dart';

/// Estilos e temas de encadernação de luxo para capas de livros bíblicos
enum BookBindingStyle {
  burgundy, // Couro Vinho Imperial / Bordô
  onyx, // Couro Preto Ônix com Folheado a Ouro
  navy, // Couro Azul Noturno Celestial
  brown, // Couro Marrom Havana / Tabaco
  emerald, // Couro Verde Esmeralda
  gold, // Dourado Imperial Clássico
  purple, // Púrpura Teológico (ideal para comentários)
  sapphire, // Safira / Azul Léxico (ideal para dicionários)
}

class BookBindingTheme {
  final List<Color> gradientColors;
  final Color goldAccent;
  final Color leatherTextureColor;
  final Color ribbonColor;

  const BookBindingTheme({
    required this.gradientColors,
    required this.goldAccent,
    required this.leatherTextureColor,
    required this.ribbonColor,
  });

  static BookBindingTheme getTheme(BookBindingStyle style) {
    switch (style) {
      case BookBindingStyle.burgundy:
        return const BookBindingTheme(
          gradientColors: [Color(0xFF5A1414), Color(0xFF380B0B)],
          goldAccent: Color(0xFFFFD56B),
          leatherTextureColor: Color(0x22FFA5A5),
          ribbonColor: Color(0xFFDC2626),
        );
      case BookBindingStyle.onyx:
        return const BookBindingTheme(
          gradientColors: [Color(0xFF262629), Color(0xFF131316)],
          goldAccent: Color(0xFFFFE082),
          leatherTextureColor: Color(0x1AFFFFFF),
          ribbonColor: Color(0xFFD97706),
        );
      case BookBindingStyle.navy:
        return const BookBindingTheme(
          gradientColors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
          goldAccent: Color(0xFFFFD56B),
          leatherTextureColor: Color(0x2093C5FD),
          ribbonColor: Color(0xFF2563EB),
        );
      case BookBindingStyle.brown:
        return const BookBindingTheme(
          gradientColors: [Color(0xFF5F2B0E), Color(0xFF321303)],
          goldAccent: Color(0xFFFFD079),
          leatherTextureColor: Color(0x22FCD34D),
          ribbonColor: Color(0xFFB45309),
        );
      case BookBindingStyle.emerald:
        return const BookBindingTheme(
          gradientColors: [Color(0xFF065F46), Color(0xFF022C22)],
          goldAccent: Color(0xFFFFE58F),
          leatherTextureColor: Color(0x206EE7B7),
          ribbonColor: Color(0xFF059669),
        );
      case BookBindingStyle.gold:
        return const BookBindingTheme(
          gradientColors: [Color(0xFF8A5A12), Color(0xFF4A3004)],
          goldAccent: Color(0xFFFFF2B2),
          leatherTextureColor: Color(0x30FDE68A),
          ribbonColor: Color(0xFFE11D48),
        );
      case BookBindingStyle.purple:
        return const BookBindingTheme(
          gradientColors: [Color(0xFF4C1D95), Color(0xFF2E1065)],
          goldAccent: Color(0xFFFFD56B),
          leatherTextureColor: Color(0x22C084FC),
          ribbonColor: Color(0xFF7C3AED),
        );
      case BookBindingStyle.sapphire:
        return const BookBindingTheme(
          gradientColors: [Color(0xFF075985), Color(0xFF082F49)],
          goldAccent: Color(0xFFBAE6FD),
          leatherTextureColor: Color(0x227DD3FC),
          ribbonColor: Color(0xFF0284C7),
        );
    }
  }
}

/// Componente que renderiza uma Capa de Livro Bíblico 3D realista
/// com lombada, siglas douradas, encadernação em couro e ornamentos sagrados.
class StoreItemCoverArt extends StatelessWidget {
  final StoreItem item;
  final double width;
  final double height;
  final double borderRadius;
  final bool showRibbon;
  final String? customImageUrl;

  const StoreItemCoverArt({
    super.key,
    required this.item,
    this.width = 50,
    this.height = 64,
    this.borderRadius = 10,
    this.showRibbon = true,
    this.customImageUrl,
  });

  /// Extrai a sigla bíblica oficial ou monograma representativo do título
  static String extractAcronym(StoreItem item) {
    final title = item.name.trim();

    // 1. Procura por parênteses: ex: "Almeida Corrigida Fiel 1994 (ACF)" -> "ACF"
    final parenthesisMatch = RegExp(r'\(([^)]+)\)').firstMatch(title);
    if (parenthesisMatch != null) {
      final inside = parenthesisMatch.group(1)!.trim();
      // Se for sigla curta (até 6 caracteres)
      if (inside.isNotEmpty && inside.length <= 6 && !inside.contains(' ')) {
        return inside.toUpperCase();
      }
    }

    // 2. Tenta extrair siglas conhecidas no nome
    final knownAcronyms = [
      'ACF', 'ARC', 'ARA', 'NVI', 'NVT', 'NAA', 'KJA', 'KJV', 'BPT',
      'MSG', 'AEC', 'NTLH', 'ASV', 'TB', 'VULGATA', 'LXX', 'PESHITTA',
      'HEBRAICO', 'GREGO', 'HARPA', 'CANTOR', 'STRONG', 'MOODY',
      'SHEDD', 'CHAMPLIN', 'HENRY', 'SPURGEON', 'CALVINO', 'LIVRO',
    ];

    final upperTitle = title.toUpperCase();
    for (final acr in knownAcronyms) {
      if (upperTitle.contains(acr)) {
        return acr;
      }
    }

    // 3. Fallback: Primeiras letras das palavras principais
    final words = title
        .replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúÁÉÍÓÚãõÃÕâêîôûÂÊÎÔÛçÇ\s]'), '')
        .split(' ')
        .where((w) => w.length > 2 && !['para', 'com', 'dos', 'das', 'que'].contains(w.toLowerCase()))
        .take(3)
        .toList();

    if (words.length >= 2) {
      return words.map((w) => w[0].toUpperCase()).join();
    } else if (words.isNotEmpty && words.first.length >= 3) {
      return words.first.substring(0, 3).toUpperCase();
    }

    return 'BÍBLIA';
  }

  /// Seleciona o estilo de encadernação de couro com base na categoria e nome
  BookBindingStyle _determineStyle() {
    switch (item.category) {
      case StoreCategory.commentaries:
      case StoreCategory.expository:
        return BookBindingStyle.purple;
      case StoreCategory.dictionaries:
        return BookBindingStyle.sapphire;
      case StoreCategory.books:
      case StoreCategory.culture:
        return BookBindingStyle.brown;
      case StoreCategory.homiletics:
        return BookBindingStyle.gold;
      case StoreCategory.audios:
        return BookBindingStyle.gold;
      case StoreCategory.bibles:
      default:
        // Distribui entre as 6 encadernações nobres de Bíblias usando hash consistente
        final hash = item.name.hashCode.abs();
        final styles = [
          BookBindingStyle.burgundy,
          BookBindingStyle.onyx,
          BookBindingStyle.navy,
          BookBindingStyle.brown,
          BookBindingStyle.emerald,
          BookBindingStyle.gold,
        ];
        return styles[hash % styles.length];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se tiver imagem real válida por URL
    if (customImageUrl != null && customImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          imageUrl: customImageUrl!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildProceduralBookCover(context),
          errorWidget: (_, __, ___) => _buildProceduralBookCover(context),
        ),
      );
    }

    return _buildProceduralBookCover(context);
  }

  Widget _buildProceduralBookCover(BuildContext context) {
    final style = _determineStyle();
    final theme = BookBindingTheme.getTheme(style);
    final acronym = extractAcronym(item);
    final isCompact = width <= 55;
    final isLarge = width >= 90;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(borderRadius * 0.5),
          bottomLeft: Radius.circular(borderRadius * 0.5),
          topRight: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: isCompact ? 4 : 8,
            offset: Offset(isCompact ? 1 : 2, isCompact ? 2 : 4),
          ),
          BoxShadow(
            color: theme.goldAccent.withValues(alpha: 0.12),
            blurRadius: isCompact ? 3 : 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(borderRadius * 0.5),
          bottomLeft: Radius.circular(borderRadius * 0.5),
          topRight: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
        child: Stack(
          children: [
            // ── Fundo em Couro Nobre com Gradiente ────────────────────
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.gradientColors,
                  ),
                ),
              ),
            ),

            // ── Textura Sutil de Couro e Granulação ───────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: _LeatherTexturePainter(theme.leatherTextureColor),
              ),
            ),

            // ── Filete Ornamental Dourado de Borda ───────────────────
            Positioned(
              left: isCompact ? 7 : 10,
              top: isCompact ? 3 : 6,
              right: isCompact ? 3 : 6,
              bottom: isCompact ? 3 : 6,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.goldAccent.withValues(alpha: 0.45),
                    width: isCompact ? 0.8 : 1.2,
                  ),
                  borderRadius: BorderRadius.circular(isCompact ? 4 : 6),
                ),
              ),
            ),

            // ── Lombada 3D do Livro à Esquerda (Spine Effect) ────────
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: isCompact ? 6 : 9,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.white.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.45),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  border: Border(
                    right: BorderSide(
                      color: theme.goldAccent.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                ),
              ),
            ),

            // ── Fita Marcadora de Páginas (Bookmark Ribbon) ───────────
            if (showRibbon && !isCompact)
              Positioned(
                top: 0,
                right: width * 0.22,
                child: Container(
                  width: 7,
                  height: height * 0.38,
                  decoration: BoxDecoration(
                    color: theme.ribbonColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 7,
                      height: 4,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),

            // ── Conteúdo Central: Sigla Dourada & Brasão ──────────────
            Positioned.fill(
              left: isCompact ? 7 : 10,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 3 : 6,
                  vertical: isCompact ? 4 : 8,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Ícone ou Brasão no topo da capa
                    Icon(
                      _getEmblemIcon(item.category),
                      color: theme.goldAccent.withValues(alpha: 0.85),
                      size: isCompact ? 12 : (isLarge ? 20 : 15),
                    ),
                    SizedBox(height: isCompact ? 2 : 4),

                    // Sigla Oficial em relevo dourado
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        acronym,
                        maxLines: 1,
                        style: GoogleFonts.outfit(
                          fontSize: isCompact ? 11 : (isLarge ? 17 : 13.5),
                          fontWeight: FontWeight.w900,
                          color: theme.goldAccent,
                          letterSpacing: isCompact ? 0.5 : 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.85),
                              blurRadius: 4,
                              offset: const Offset(1, 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Subtítulo descritivo em capas médias e grandes
                    if (!isCompact) ...[
                      const SizedBox(height: 3),
                      Text(
                        _getCategorySubLabel(item.category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: isLarge ? 8.5 : 7,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getEmblemIcon(StoreCategory category) {
    switch (category) {
      case StoreCategory.bibles:
        return Icons.auto_awesome_rounded;
      case StoreCategory.commentaries:
      case StoreCategory.expository:
        return Icons.edit_note_rounded;
      case StoreCategory.dictionaries:
        return Icons.translate_rounded;
      case StoreCategory.books:
        return Icons.menu_book_rounded;
      case StoreCategory.homiletics:
        return Icons.campaign_rounded;
      case StoreCategory.audios:
        return Icons.music_note_rounded;
      default:
        return Icons.bookmark_added_rounded;
    }
  }

  String _getCategorySubLabel(StoreCategory category) {
    switch (category) {
      case StoreCategory.bibles:
        return 'ESCRITURA';
      case StoreCategory.commentaries:
      case StoreCategory.expository:
        return 'EXEGESE';
      case StoreCategory.dictionaries:
        return 'LÉXICO';
      case StoreCategory.books:
        return 'LIVRO';
      case StoreCategory.homiletics:
        return 'HOMILÉTICA';
      case StoreCategory.audios:
        return 'HINÁRIO';
      default:
        return 'KERYX';
    }
  }
}

/// Pintura procedural de textura fina simulando granulação de couro
class _LeatherTexturePainter extends CustomPainter {
  final Color textureColor;

  const _LeatherTexturePainter(this.textureColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = textureColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Linhas diagonais ultraleves simulando trama de couro
    const step = 8.0;
    for (double i = 0; i < size.width + size.height; i += step) {
      canvas.drawLine(
        Offset(0, i),
        Offset(i, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LeatherTexturePainter oldDelegate) => false;
}
