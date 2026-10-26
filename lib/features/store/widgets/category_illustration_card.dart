import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../model/store_item.dart';
import 'store_item_cover_art.dart';

/// Card de Categoria da Loja desenhado na mesma linguagem visual luxuosa
/// das capas de livros bíblicos 3D (couro nobre, textura sutil, filetes dourados e fita marcadora).
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

  BookBindingStyle _getBindingStyle(StoreCategory cat) {
    switch (cat) {
      case StoreCategory.bibles:
        return BookBindingStyle.gold;
      case StoreCategory.books:
      case StoreCategory.culture:
        return BookBindingStyle.brown;
      case StoreCategory.commentaries:
      case StoreCategory.expository:
        return BookBindingStyle.purple;
      case StoreCategory.dictionaries:
        return BookBindingStyle.sapphire;
      default:
        return BookBindingStyle.onyx;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _getBindingStyle(widget.category);
    final theme = BookBindingTheme.getTheme(style);

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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered ? theme.goldAccent : theme.goldAccent.withValues(alpha: 0.35),
                width: _isHovered ? 1.8 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: theme.goldAccent.withValues(alpha: _isHovered ? 0.25 : 0.08),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // ── 1. Fundo em Couro Legítimo Nobre (Mesma Paleta dos Livros) ──
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

                  // ── 2. Textura Sutil de Granulação de Couro ───────────
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CategoryLeatherPainter(theme.leatherTextureColor),
                    ),
                  ),

                  // ── 3. Filete Dourado Duplo Ornamental de Moldura ─────
                  Positioned(
                    left: 14,
                    top: 10,
                    right: 10,
                    bottom: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.goldAccent.withValues(alpha: 0.45),
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  // ── 4. Lombada 3D do Livro à Esquerda (Spine Effect) ──
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.white.withValues(alpha: 0.2),
                            Colors.black.withValues(alpha: 0.5),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        border: Border(
                          right: BorderSide(
                            color: theme.goldAccent.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── 5. Fita Marcadora de Páginas (Bookmark Ribbon) ────
                  Positioned(
                    top: 0,
                    right: 32,
                    child: Container(
                      width: 10,
                      height: 38,
                      decoration: BoxDecoration(
                        color: theme.ribbonColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 4,
                            offset: const Offset(1, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── 6. Brasão Dourado com o Ícone da Categoria ────────
                  Positioned(
                    top: 18,
                    left: 22,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.goldAccent.withValues(alpha: 0.7),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.goldAccent.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          widget.iconData,
                          color: theme.goldAccent,
                          size: 22,
                        ),
                      ),
                    ),
                  ),

                  // ── 7. Badge de Quantidade no Topo Direito ────────────
                  Positioned(
                    top: 18,
                    right: 50,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.goldAccent.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.itemCount > 0 ? '${widget.itemCount} volumes' : 'Em breve',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: theme.goldAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                  // ── 8. Textos e Pílula na Base do Card ────────────────
                  Positioned(
                    left: 22,
                    right: 18,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Rótulo da Categoria
                        Text(
                          widget.label,
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 4,
                                offset: const Offset(1, 1),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Pílula Indicativa de Uso com estilo nobre
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: theme.goldAccent.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            _getDestinationText(widget.category),
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              color: theme.goldAccent,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
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

  String _getDestinationText(StoreCategory cat) {
    switch (cat) {
      case StoreCategory.bibles:
        return 'Lido na aba Bíblia';
      case StoreCategory.books:
        return 'Lido na Biblioteca';
      case StoreCategory.commentaries:
        return 'Aba Bíblia (Comentários)';
      case StoreCategory.dictionaries:
        return 'Lido em Dicionários';
      case StoreCategory.expository:
        return 'Estudos Expositivos';
      case StoreCategory.homiletics:
        return 'Esboços e Sermões';
      case StoreCategory.culture:
        return 'História & Cultura';
      case StoreCategory.audios:
        return 'Harpa & Louvores';
      default:
        return 'Módulo Keryx';
    }
  }
}

/// Textura diagonal suave de couro
class _CategoryLeatherPainter extends CustomPainter {
  final Color textureColor;

  const _CategoryLeatherPainter(this.textureColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = textureColor
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    const step = 10.0;
    for (double i = 0; i < size.width + size.height; i += step) {
      canvas.drawLine(
        Offset(0, i),
        Offset(i, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryLeatherPainter oldDelegate) => false;
}
