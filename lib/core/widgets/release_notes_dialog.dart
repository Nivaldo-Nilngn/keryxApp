import 'package:flutter/material.dart';
import 'package:keryx_app/core/theme/app_fonts.dart';
import '../models/release_notes_model.dart';
import '../data/release_notes_catalog.dart';
import '../theme/app_theme.dart';

/// Tela Completa e Moderna de Notas de Atualização ("O que há de novo!")
/// Design limpo, arejado, com suporte a modo claro/escuro e tópicos escaneáveis.
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
              begin: const Offset(0, 0.06),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Cores temáticas elegantes e adaptáveis
    final bgColor = isDark ? const Color(0xFF0F111A) : const Color(0xFFF8F9FD);
    final surfaceColor = isDark ? const Color(0xFF161924) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Filtra os itens com base na categoria selecionada
    final filteredItems = _selectedCategory == null
        ? noteVersion.items
        : noteVersion.items.where((i) => i.category == _selectedCategory).toList();

    final featureCount = noteVersion.items.where((i) => i.category == ReleaseNoteCategory.feature).length;
    final improvementCount = noteVersion.items.where((i) => i.category == ReleaseNoteCategory.improvement).length;
    final fixCount = noteVersion.items.where((i) => i.category == ReleaseNoteCategory.fix).length;

    // Parse inteligente da mensagem do admin (se houver)
    final parsedAdmin = _parseAdminNotes(widget.adminReleaseNotes);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: Material(
            color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Icon(Icons.close_rounded, color: textPrimary, size: 20),
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: widget.isAfterUpdate
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isAfterUpdate
                      ? const Color(0xFF10B981).withValues(alpha: 0.35)
                      : AppTheme.kPrimaryGold.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isAfterUpdate ? Icons.verified_rounded : Icons.auto_awesome_rounded,
                    size: 13,
                    color: widget.isAfterUpdate ? const Color(0xFF34D399) : AppTheme.kPrimaryGold,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.isAfterUpdate ? 'ATUALIZADO' : 'NOVA VERSÃO',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: widget.isAfterUpdate ? const Color(0xFF34D399) : AppTheme.kPrimaryGold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              parsedAdmin?.versionBadge ?? 'v${noteVersion.versionName}',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            if (parsedAdmin?.versionBadge == null && noteVersion.buildNumber > 0) ...[
              const SizedBox(width: 4),
              Text(
                '(${noteVersion.buildNumber})',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: textSecondary.withValues(alpha: 0.6),
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
              // ── Cabeçalho Hero Arejado & Elegante ───────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _buildModernHeroHeader(
                    context,
                    noteVersion,
                    isDark,
                    textPrimary,
                    textSecondary,
                  ),
                ),
              ),

              // ── Destaques do Administrador Estruturados (se houver) ──────
              if (parsedAdmin != null && parsedAdmin.bullets.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _buildParsedAdminCard(
                      parsedAdmin,
                      isDark,
                      surfaceColor,
                      borderColor,
                      textPrimary,
                      textSecondary,
                    ),
                  ),
                ),

              // ── Seletor de Categorias por Pílulas ─────────────────────────
              if (filteredItems.isNotEmpty || _selectedCategory != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildFilterPills(
                      totalCount: noteVersion.items.length,
                      featureCount: featureCount,
                      improvementCount: improvementCount,
                      fixCount: fixCount,
                      isDark: isDark,
                      borderColor: borderColor,
                    ),
                  ),
                ),

              // ── Lista de Novidades Ajustadas para Tela Cheia ─────────────
              if (filteredItems.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filteredItems[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildReleaseItemCard(
                            item,
                            isDark,
                            surfaceColor,
                            borderColor,
                            textPrimary,
                            textSecondary,
                          ),
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
      bottomNavigationBar: _buildFooter(context, isDark, surfaceColor, borderColor),
    );
  }

  /// Cabeçalho arejado, sem parecer uma caixa pesada
  Widget _buildModernHeroHeader(
    BuildContext context,
    ReleaseNoteVersion version,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF1E1B18),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isAfterUpdate ? 'ATUALIZAÇÃO INSTALADA' : 'NOTAS DE LANÇAMENTO',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: widget.isAfterUpdate ? const Color(0xFF10B981) : AppTheme.kPrimaryGold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        version.releaseDate,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          widget.isAfterUpdate ? 'O que há de novo nesta versão' : version.title,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.3,
            height: 1.25,
          ),
        ),
        if (version.highlight.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.6),
                  width: 3.5,
                ),
              ),
            ),
            child: Text(
              version.highlight,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Converte a mensagem do administrador de bloco denso em tópicos escaneáveis e elegantes
  Widget _buildParsedAdminCard(
    _ParsedAdminNote parsed,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141724) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.06 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de Cabeçalho do Card de Destaques
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Color(0xFF818CF8),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Destaques da Atualização',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF818CF8),
                    ),
                  ),
                ),
                if (parsed.versionBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      parsed.versionBadge!,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFA5B4FC),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Lista de Tópicos
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: parsed.bullets.asMap().entries.map((entry) {
                final index = entry.key;
                final bullet = entry.value;
                final isLast = index == parsed.bullets.length - 1;

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: bullet.iconColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          bullet.icon,
                          size: 16,
                          color: bullet.iconColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          bullet.text,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                            color: textPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
    required bool isDark,
    required Color borderColor,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Todos',
            count: totalCount,
            isSelected: _selectedCategory == null,
            icon: Icons.all_inclusive_rounded,
            activeColor: AppTheme.kPrimaryGold,
            isDark: isDark,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Novos Recursos',
            count: featureCount,
            isSelected: _selectedCategory == ReleaseNoteCategory.feature,
            icon: Icons.auto_awesome_rounded,
            activeColor: const Color(0xFF10B981),
            isDark: isDark,
            onTap: () => setState(() => _selectedCategory = ReleaseNoteCategory.feature),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Modificações',
            count: improvementCount,
            isSelected: _selectedCategory == ReleaseNoteCategory.improvement,
            icon: Icons.trending_up_rounded,
            activeColor: const Color(0xFF6366F1),
            isDark: isDark,
            onTap: () => setState(() => _selectedCategory = ReleaseNoteCategory.improvement),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Correções',
            count: fixCount,
            isSelected: _selectedCategory == ReleaseNoteCategory.fix,
            icon: Icons.healing_rounded,
            activeColor: const Color(0xFFF59E0B),
            isDark: isDark,
            onTap: () => setState(() => _selectedCategory = ReleaseNoteCategory.fix),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required IconData icon,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.16)
                : (isDark ? const Color(0xFF161924) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeColor : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : activeColor)
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.25)
                      : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? (isDark ? Colors.white : activeColor)
                        : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card espaçoso e refinado de cada item da versão
  Widget _buildReleaseItemCard(
    ReleaseNoteItem item,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final catColor = item.category.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: catColor.withValues(alpha: isDark ? 0.2 : 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                color: catColor.withValues(alpha: 0.25),
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
                        color: catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category.label.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.description,
                  style: GoogleFonts.manrope(
                    fontSize: 12.8,
                    color: textSecondary,
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

  /// Rodapé com botão elegante, menos agressivo e perfeitamente equilibrado
  Widget _buildFooter(BuildContext context, bool isDark, Color surfaceColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
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
      ),
    );
  }

  /// Faz o parse da mensagem do administrador para separar versão e tópicos escaneáveis
  _ParsedAdminNote? _parseAdminNotes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final text = raw.trim();

    String? versionBadge;
    String content = text;

    // Detecta padrão inicial "Versão X.Y.Z:" ou "Versão X.Y:"
    final versionRegex = RegExp(r'^(Vers[aã]o\s+[\d\.]+):?\s*', caseSensitive: false);
    final match = versionRegex.firstMatch(text);
    if (match != null) {
      versionBadge = match.group(1);
      content = text.substring(match.end).trim();
    }

    // Divide em sentenças por ';' ou quebras de linha
    List<String> rawParts;
    if (content.contains(';')) {
      rawParts = content.split(';');
    } else if (content.contains('\n')) {
      rawParts = content.split('\n');
    } else {
      rawParts = [content];
    }

    final List<_AdminBulletPoint> bullets = [];
    for (var part in rawParts) {
      var item = part.trim();
      // Remove marcadores existentes como '-' ou '•'
      if (item.startsWith('-') || item.startsWith('•')) {
        item = item.substring(1).trim();
      }
      if (item.endsWith('.')) {
        item = item.substring(0, item.length - 1).trim();
      }
      if (item.isEmpty) continue;

      // Capitaliza primeira letra
      item = item[0].toUpperCase() + item.substring(1);

      // Escolhe ícone contextual baseado nas palavras-chave
      final lower = item.toLowerCase();
      IconData icon = Icons.check_circle_rounded;
      Color color = const Color(0xFF10B981);

      if (lower.contains('nuvem') || lower.contains('firestore') || lower.contains('sincroniz')) {
        icon = Icons.cloud_done_rounded;
        color = const Color(0xFF38BDF8);
      } else if (lower.contains('plano') || lower.contains('progresso') || lower.contains('semana') || lower.contains('dia')) {
        icon = Icons.calendar_month_rounded;
        color = const Color(0xFF818CF8);
      } else if (lower.contains('háptico') || lower.contains('celebraç') || lower.contains('feedback')) {
        icon = Icons.celebration_rounded;
        color = const Color(0xFFFBBF24);
      } else if (lower.contains('leitor') || lower.contains('bíblia') || lower.contains('bíblico') || lower.contains('texto')) {
        icon = Icons.menu_book_rounded;
        color = const Color(0xFF34D399);
      } else if (lower.contains('estimativa') || lower.contains('ritmo') || lower.contains('estatística') || lower.contains('gráfico')) {
        icon = Icons.insights_rounded;
        color = const Color(0xFFA78BFA);
      } else if (lower.contains('lembrete') || lower.contains('alarme') || lower.contains('notifica')) {
        icon = Icons.notifications_active_rounded;
        color = const Color(0xFFF472B6);
      } else if (lower.contains('correção') || lower.contains('salvamento') || lower.contains('ajuste') || lower.contains('isolamento')) {
        icon = Icons.healing_rounded;
        color = const Color(0xFFF59E0B);
      }

      bullets.add(_AdminBulletPoint(text: item, icon: icon, iconColor: color));
    }

    return _ParsedAdminNote(versionBadge: versionBadge, bullets: bullets);
  }
}

class _AdminBulletPoint {
  final String text;
  final IconData icon;
  final Color iconColor;

  _AdminBulletPoint({
    required this.text,
    required this.icon,
    required this.iconColor,
  });
}

class _ParsedAdminNote {
  final String? versionBadge;
  final List<_AdminBulletPoint> bullets;

  _ParsedAdminNote({
    this.versionBadge,
    required this.bullets,
  });
}
