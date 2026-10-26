import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../model/store_item.dart';

/// Card interativo ilustrado para as categorias da Loja
class CategoryIllustrationCard extends StatefulWidget {
  final StoreCategory category;
  final String label;
  final int itemCount;
  final IconData iconData;
  final Color baseColor;
  final VoidCallback onTap;

  const CategoryIllustrationCard({
    super.key,
    required this.category,
    required this.label,
    required this.itemCount,
    required this.iconData,
    required this.baseColor,
    required this.onTap,
  });

  @override
  State<CategoryIllustrationCard> createState() => _CategoryIllustrationCardState();
}

class _CategoryIllustrationCardState extends State<CategoryIllustrationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.baseColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131722),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered ? color : color.withValues(alpha: 0.3),
                width: _isHovered ? 1.8 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: color.withValues(alpha: _isHovered ? 0.22 : 0.08),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // ── Arte de Fundo Temática Ilustrada ──────────────────
                  Positioned.fill(
                    child: _buildThematicBackground(widget.category, color),
                  ),

                  // ── Gradiente Escuro Suave para Garantir Legibilidade ──
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.black.withValues(alpha: 0.4),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // ── Badge de Quantidade no Topo Direito ──────────────
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_rounded, size: 11, color: color),
                          const SizedBox(width: 4),
                          Text(
                            widget.itemCount > 0 ? '${widget.itemCount}' : 'Em breve',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: widget.itemCount > 0 ? color : Colors.white60,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Ícone no Topo Esquerdo em Container de Vidro ─────
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: color.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        widget.iconData,
                        color: color,
                        size: 24,
                      ),
                    ),
                  ),

                  // ── Textos e Descrição na Base ─────────────────────────
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: color.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            _getDestinationText(widget.category),
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              color: color,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Retorna a ilustração artística vetorial de acordo com a categoria
  Widget _buildThematicBackground(StoreCategory category, Color color) {
    switch (category) {
      case StoreCategory.bibles:
        return CustomPaint(
          painter: _BibleIllustrationPainter(color),
        );
      case StoreCategory.books:
        return CustomPaint(
          painter: _BooksIllustrationPainter(color),
        );
      case StoreCategory.commentaries:
      case StoreCategory.expository:
        return CustomPaint(
          painter: _CommentariesIllustrationPainter(color),
        );
      case StoreCategory.dictionaries:
        return CustomPaint(
          painter: _DictionariesIllustrationPainter(color),
        );
      default:
        return CustomPaint(
          painter: _GenericStoreIllustrationPainter(color),
        );
    }
  }

  String _getDestinationText(StoreCategory cat) {
    switch (cat) {
      case StoreCategory.bibles:
        return '📖 Lido na aba Bíblia';
      case StoreCategory.books:
        return '📚 Lido na Biblioteca';
      case StoreCategory.commentaries:
        return '🔍 Aba Bíblia (Comentários)';
      case StoreCategory.dictionaries:
        return '📖 Lido em Dicionários';
      case StoreCategory.expository:
        return '📖 Estudos Expositivos';
      case StoreCategory.homiletics:
        return '🎙️ Esboços e Sermões';
      case StoreCategory.culture:
        return '🏛️ História & Cultura';
      case StoreCategory.audios:
        return '🎵 Harpa & Louvores';
      default:
        return '✨ Módulo Keryx';
    }
  }
}

// ── Pintores Artísticos de Fundo por Categoria ───────────────────────────────

/// Ilustração para Bíblias: Bíblia Sagrada aberta com raios celestiais e feixes de luz
class _BibleIllustrationPainter extends CustomPainter {
  final Color baseColor;

  const _BibleIllustrationPainter(this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.72;
    final cy = size.height * 0.42;

    // Raios de luz celestial saindo do centro
    final rayPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - (math.pi / 8);
      final ex = cx + math.cos(angle) * (size.width * 0.55);
      final ey = cy + math.sin(angle) * (size.height * 0.55);
      canvas.drawLine(Offset(cx, cy), Offset(ex, ey), rayPaint);
    }

    // Desenho vetorial da Bíblia aberta
    final bookPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Página Esquerda
    final leftPage = Path()
      ..moveTo(cx, cy + 24)
      ..quadraticBezierTo(cx - 26, cy + 28, cx - 44, cy + 18)
      ..lineTo(cx - 44, cy - 20)
      ..quadraticBezierTo(cx - 26, cy - 10, cx, cy - 16)
      ..close();

    // Página Direita
    final rightPage = Path()
      ..moveTo(cx, cy + 24)
      ..quadraticBezierTo(cx + 26, cy + 28, cx + 44, cy + 18)
      ..lineTo(cx + 44, cy - 20)
      ..quadraticBezierTo(cx + 26, cy - 10, cx, cy - 16)
      ..close();

    canvas.drawPath(leftPage, bookPaint);
    canvas.drawPath(leftPage, borderPaint);
    canvas.drawPath(rightPage, bookPaint);
    canvas.drawPath(rightPage, borderPaint);

    // Cruz sutil de luz no topo
    final crossPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.75)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(cx, cy - 36), Offset(cx, cy - 24), crossPaint);
    canvas.drawLine(Offset(cx - 5, cy - 32), Offset(cx + 5, cy - 32), crossPaint);
  }

  @override
  bool shouldRepaint(covariant _BibleIllustrationPainter oldDelegate) => false;
}

/// Ilustração para Livros: Coleção de livros clássicos empilhados com marcadores
class _BooksIllustrationPainter extends CustomPainter {
  final Color baseColor;

  const _BooksIllustrationPainter(this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.72;
    final cy = size.height * 0.45;

    final paint = Paint()
      ..color = baseColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = baseColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    // Livro 1 (Base inclinada)
    canvas.save();
    canvas.translate(cx, cy + 18);
    canvas.rotate(-0.06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-36, -8, 72, 16),
        const Radius.circular(4),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-36, -8, 72, 16),
        const Radius.circular(4),
      ),
      stroke,
    );
    canvas.restore();

    // Livro 2 (Meio)
    canvas.save();
    canvas.translate(cx + 2, cy);
    canvas.rotate(0.04);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-32, -8, 64, 16),
        const Radius.circular(4),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-32, -8, 64, 16),
        const Radius.circular(4),
      ),
      stroke,
    );
    canvas.restore();

    // Livro 3 (Topo)
    canvas.save();
    canvas.translate(cx - 2, cy - 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-28, -7, 56, 14),
        const Radius.circular(4),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-28, -7, 56, 14),
        const Radius.circular(4),
      ),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BooksIllustrationPainter oldDelegate) => false;
}

/// Ilustração para Comentários: Pergaminho antigo com caneta-tinteiro de pena
class _CommentariesIllustrationPainter extends CustomPainter {
  final Color baseColor;

  const _CommentariesIllustrationPainter(this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.72;
    final cy = size.height * 0.42;

    final paint = Paint()
      ..color = baseColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = baseColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    // Pergaminho enrolado nas bordas
    final scroll = Path()
      ..moveTo(cx - 32, cy - 28)
      ..quadraticBezierTo(cx, cy - 34, cx + 32, cy - 28)
      ..lineTo(cx + 32, cy + 24)
      ..quadraticBezierTo(cx, cy + 18, cx - 32, cy + 24)
      ..close();

    canvas.drawPath(scroll, paint);
    canvas.drawPath(scroll, stroke);

    // Linhas de texto escritas no pergaminho
    final linePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.45)
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(cx - 20, cy - 14), Offset(cx + 16, cy - 14), linePaint);
    canvas.drawLine(Offset(cx - 20, cy - 4), Offset(cx + 20, cy - 4), linePaint);
    canvas.drawLine(Offset(cx - 20, cy + 6), Offset(cx + 10, cy + 6), linePaint);

    // Pena clássica inclinada
    final featherPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.7)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(cx + 18, cy - 36), Offset(cx + 32, cy + 4), featherPaint);
  }

  @override
  bool shouldRepaint(covariant _CommentariesIllustrationPainter oldDelegate) => false;
}

/// Ilustração para Dicionários: Letras sagradas gregas (Α, Ω) e hebraicas (א, ת)
class _DictionariesIllustrationPainter extends CustomPainter {
  final Color baseColor;

  const _DictionariesIllustrationPainter(this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.72;
    final cy = size.height * 0.42;

    // Círculo decorativo ao redor das letras
    final circlePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), 36, circlePaint);

    // Letra Alfa 'A'
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Α',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: baseColor.withValues(alpha: 0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx - 22, cy - 22));

    // Letra Ômega 'Ω'
    final textPainter2 = TextPainter(
      text: TextSpan(
        text: 'Ω',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: baseColor.withValues(alpha: 0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter2.paint(canvas, Offset(cx + 2, cy - 4));
  }

  @override
  bool shouldRepaint(covariant _DictionariesIllustrationPainter oldDelegate) => false;
}

/// Ilustração genérica para outras categorias
class _GenericStoreIllustrationPainter extends CustomPainter {
  final Color baseColor;

  const _GenericStoreIllustrationPainter(this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.72;
    final cy = size.height * 0.42;

    final circlePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(Offset(cx, cy), 32, circlePaint);
    canvas.drawCircle(Offset(cx, cy), 20, circlePaint);
  }

  @override
  bool shouldRepaint(covariant _GenericStoreIllustrationPainter oldDelegate) => false;
}
