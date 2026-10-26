import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/release_notes_model.dart';
import '../data/release_notes_catalog.dart';
import '../theme/app_theme.dart';

class ReleaseNotesDialog extends StatefulWidget {
  final ReleaseNoteVersion? version;
  final String? adminReleaseNotes;
  final bool isAfterUpdate;

  const ReleaseNotesDialog({
    super.key,
    this.version,
    this.adminReleaseNotes,
    this.isAfterUpdate = false,
  });

  /// Método estático utilitário para abrir o diálogo de forma padronizada
  static Future<void> show(
    BuildContext context, {
    ReleaseNoteVersion? version,
    String? adminReleaseNotes,
    bool isAfterUpdate = false,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notas de Atualização',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, anim1, anim2) {
        return ReleaseNotesDialog(
          version: version,
          adminReleaseNotes: adminReleaseNotes,
          isAfterUpdate: isAfterUpdate,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ReleaseNotesDialog> createState() => _ReleaseNotesDialogState();
}

class _ReleaseNotesDialogState extends State<ReleaseNotesDialog> {
  ReleaseNoteCategory? _selectedCategory; // null = Todos

  @override
  Widget build(BuildContext context) {
    final noteVersion = widget.version ?? ReleaseNotesCatalog.latest;
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 500;

    // Filtra os itens com base na categoria selecionada
    final filteredItems = _selectedCategory == null
        ? noteVersion.items
        : noteVersion.items.where((i) => i.category == _selectedCategory).toList();

    final featureCount = noteVersion.items.where((i) => i.category == ReleaseNoteCategory.feature).length;
    final improvementCount = noteVersion.items.where((i) => i.category == ReleaseNoteCategory.improvement).length;
    final fixCount = noteVersion.items.where((i) => i.category == ReleaseNoteCategory.fix).length;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: isCompact ? size.width * 0.92 : 560,
          constraints: BoxConstraints(maxHeight: size.height * 0.88),
          margin: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF141722),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.kPrimaryGold.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppTheme.kPrimaryGold.withValues(alpha: 0.08),
                blurRadius: 48,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Cabeçalho Comemorativo com Gradiente ──────────────────────
                _buildHeader(context, noteVersion),

                // ── Mensagem Personalizada do Administrador (se houver) ──────
                if (widget.adminReleaseNotes != null && widget.adminReleaseNotes!.trim().isNotEmpty)
                  _buildAdminNotesBanner(widget.adminReleaseNotes!.trim()),

                // ── Filtros por Pílulas ─────────────────────────────────────
                _buildFilterPills(
                  totalCount: noteVersion.items.length,
                  featureCount: featureCount,
                  improvementCount: improvementCount,
                  fixCount: fixCount,
                ),

                const Divider(height: 1, color: Color(0x1FFFFFFF)),

                // ── Lista de Novidades ──────────────────────────────────────
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    shrinkWrap: true,
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildReleaseItemCard(filteredItems[index]);
                    },
                  ),
                ),

                // ── Rodapé com Botão Principal ──────────────────────────────
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ReleaseNoteVersion version) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E2235),
            Color(0xFF141722),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0x1FFFFFFF), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone em destaque com brilho
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD56B), Color(0xFFD97706)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF1E1B18),
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.isAfterUpdate
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.isAfterUpdate
                              ? const Color(0xFF10B981).withValues(alpha: 0.5)
                              : AppTheme.kPrimaryGold.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.isAfterUpdate ? '✨ ATUALIZADO COM SUCESSO' : 'NOTAS DE ATUALIZAÇÃO',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.isAfterUpdate
                              ? const Color(0xFF34D399)
                              : AppTheme.kPrimaryGold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'v${version.versionName}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isAfterUpdate ? 'O que há de novo nesta versão!' : version.title,
                  style: GoogleFonts.outfit(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  version.highlight,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
            splashRadius: 20,
            tooltip: 'Fechar',
          ),
        ],
      ),
    );
  }

  Widget _buildAdminNotesBanner(String notes) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_rounded, color: Color(0xFF818CF8), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mensagem da Publicação',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFA5B4FC),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notes,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPills({
    required int totalCount,
    required int featureCount,
    required int improvementCount,
    required int fixCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Todos ($totalCount)',
            isSelected: _selectedCategory == null,
            icon: Icons.all_inclusive_rounded,
            activeColor: AppTheme.kPrimaryGold,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Novos Recursos ($featureCount)',
            isSelected: _selectedCategory == ReleaseNoteCategory.feature,
            icon: Icons.auto_awesome_rounded,
            activeColor: const Color(0xFF10B981),
            onTap: () => setState(() => _selectedCategory = ReleaseNoteCategory.feature),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Modificações ($improvementCount)',
            isSelected: _selectedCategory == ReleaseNoteCategory.improvement,
            icon: Icons.trending_up_rounded,
            activeColor: const Color(0xFF6366F1),
            onTap: () => setState(() => _selectedCategory = ReleaseNoteCategory.improvement),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Correções ($fixCount)',
            isSelected: _selectedCategory == ReleaseNoteCategory.fix,
            icon: Icons.healing_rounded,
            activeColor: const Color(0xFFF59E0B),
            onTap: () => setState(() => _selectedCategory = ReleaseNoteCategory.fix),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required IconData icon,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.18) : const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeColor : Colors.white60,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReleaseItemCard(ReleaseNoteItem item) {
    final catColor = item.category.color;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: catColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: catColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              item.customIcon ?? item.category.icon,
              color: catColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.category.label.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: catColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF141722),
        border: Border(
          top: BorderSide(color: Color(0x1FFFFFFF), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD56B), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).pop(),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Color(0xFF1E1B18),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isAfterUpdate ? 'Explorar Recursos ✨' : 'Entendido, Glória a Deus! 🙏',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E1B18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
