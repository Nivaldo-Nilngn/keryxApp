import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/release_notes_model.dart';
import '../data/release_notes_catalog.dart';
import '../theme/app_theme.dart';

/// Tela Completa de Notas de Atualização ("O que há de novo!")
/// Proporciona leitura confortável, fluida e espaçosa em qualquer dispositivo móvel.
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

  /// Método estático utilitário para abrir a tela de novidades em tela cheia com transição suave
  static Future<void> show(
    BuildContext context, {
    ReleaseNoteVersion? version,
    String? adminReleaseNotes,
    bool isAfterUpdate = false,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, anim1, anim2) {
          return ReleaseNotesDialog(
            version: version,
            adminReleaseNotes: adminReleaseNotes,
            isAfterUpdate: isAfterUpdate,
          );
        },
        transitionsBuilder: (context, anim1, anim2, child) {
          final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    );
  }

  @override
  State<ReleaseNotesDialog> createState() => _ReleaseNotesDialogState();
}

/// Alias para uso intuitivo como tela
typedef ReleaseNotesScreen = ReleaseNotesDialog;

class _ReleaseNotesDialogState extends State<ReleaseNotesDialog> {
  ReleaseNoteCategory? _selectedCategory; // null = Todos

  @override
  Widget build(BuildContext context) {
    final noteVersion = widget.version ?? ReleaseNotesCatalog.latest;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    // Filtra os itens com base na categoria selecionada
    final filteredItems = _selectedCategory == null
        ? noteVersion.items
        : noteVersion.items.where((i) => i.category == _selectedCategory).toList();

    final featureCount = noteVersion.items.where((i) => i.category == ReleaseNoteCategory.feature).length;
    final improvementCount = noteVersion.items.where((i) => i.category == ReleaseNoteCategory.improvement).length;
    final fixCount = noteVersion.items.where((i) => i.category == ReleaseNoteCategory.fix).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0E16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0E16),
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: const Color(0xFF1B1F2E),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).pop(),
              child: const Center(
                child: Icon(Icons.close_rounded, color: Colors.white70, size: 20),
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.isAfterUpdate
                    ? const Color(0xFF10B981).withValues(alpha: 0.18)
                    : AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.isAfterUpdate
                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                      : AppTheme.kPrimaryGold.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Text(
                widget.isAfterUpdate ? 'ATUALIZAÇÃO' : 'NOVA VERSÃO',
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
              'v${noteVersion.versionName}',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (noteVersion.buildNumber > 0) ...[
              const SizedBox(width: 4),
              Text(
                '(${noteVersion.buildNumber})',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: Colors.white38,
                ),
              ),
            ],
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 720 : double.infinity,
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Cabeçalho Hero Comemorativo ─────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _buildHeroCard(context, noteVersion),
                ),
              ),

              // ── Recado do Administrador (se houver) ──────────────────────
              if (widget.adminReleaseNotes != null && widget.adminReleaseNotes!.trim().isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _buildAdminNotesBanner(widget.adminReleaseNotes!.trim()),
                  ),
                ),

              // ── Seletor de Categorias por Pílulas ─────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildFilterPills(
                    totalCount: noteVersion.items.length,
                    featureCount: featureCount,
                    improvementCount: improvementCount,
                    fixCount: fixCount,
                  ),
                ),
              ),

              // ── Lista de Novidades Ajustadas para Tela Cheia ─────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filteredItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildReleaseItemCard(item),
                      );
                    },
                    childCount: filteredItems.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildFooter(context),
    );
  }

  /// Card de Abertura / Destaque com visual nobre
  Widget _buildHeroCard(BuildContext context, ReleaseNoteVersion version) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151926),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.kPrimaryGold.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppTheme.kPrimaryGold.withValues(alpha: 0.05),
            blurRadius: 32,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar com halo dourado comemorativo
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD56B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF1E1B18),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isAfterUpdate
                          ? '✨ ATUALIZAÇÃO CONCLUÍDA'
                          : 'NOTAS DE LANÇAMENTO',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: widget.isAfterUpdate
                            ? const Color(0xFF34D399)
                            : AppTheme.kPrimaryGold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      version.releaseDate,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.isAfterUpdate ? 'O que há de novo nesta versão!' : version.title,
            style: GoogleFonts.outfit(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            version.highlight,
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              color: Colors.white70,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  /// Banner com mensagem específica enviada pelo administrador
  Widget _buildAdminNotesBanner(String notes) {
    return Container(
      width: double.infinity,
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
                  'Mensagem do Administrador',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFA5B4FC),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
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

  /// Pílulas horizontais de filtro
  Widget _buildFilterPills({
    required int totalCount,
    required int featureCount,
    required int improvementCount,
    required int fixCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.18) : const Color(0xFF181C2B),
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
                size: 15,
                color: isSelected ? activeColor : Colors.white60,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
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

  /// Card espaçoso de cada item da versão
  Widget _buildReleaseItemCard(ReleaseNoteItem item) {
    final catColor = item.category.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151926),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: catColor.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: catColor.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Icon(
              item.customIcon ?? item.category.icon,
              color: catColor,
              size: 24,
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
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        item.category.label.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: catColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: GoogleFonts.outfit(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.description,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Rodapé Fixo com Botão Nobre
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0E16),
        border: Border(
          top: BorderSide(color: Color(0x1FFFFFFF), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD56B), Color(0xFFD97706)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).pop(),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF1E1B18),
                        size: 21,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isAfterUpdate ? 'Explorar Recursos ✨' : 'Entendido, Glória a Deus! 🙏',
                        style: GoogleFonts.outfit(
                          fontSize: 15.5,
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
      ),
    );
  }
}
