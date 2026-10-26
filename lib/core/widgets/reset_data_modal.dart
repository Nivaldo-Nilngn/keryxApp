import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/services/data_reset_service.dart';
import 'package:keryx_app/core/theme/app_theme.dart';

/// Exibe o modal responsivo para redefinição e limpeza seletiva de dados.
/// Adapta-se automaticamente para tela cheia / bottom sheet no mobile e diálogo no desktop/tablet.
void showResetDataModal(BuildContext context, [WidgetRef? ref]) {
  final mediaQuery = MediaQuery.of(context);
  final isDesktopOrTablet = mediaQuery.size.width >= 700;

  if (isDesktopOrTablet) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 540,
            maxHeight: MediaQuery.of(ctx).size.height * 0.90,
          ),
          child: const _ResetDataContent(isDialog: true),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.94,
          ),
          child: const _ResetDataContent(isDialog: false),
        ),
      ),
    );
  }
}

class _ResetDataContent extends ConsumerStatefulWidget {
  final bool isDialog;

  const _ResetDataContent({
    required this.isDialog,
  });

  @override
  ConsumerState<_ResetDataContent> createState() => _ResetDataContentState();
}

class _ResetDataContentState extends ConsumerState<_ResetDataContent> {
  final TextEditingController _confirmController = TextEditingController();
  final ResetDataOptions _options = ResetDataOptions();
  bool _isOptionsExpanded = false; // Minimizado por padrão conforme pedido pelo usuário
  bool _isUnderstood = false;
  String _confirmText = '';
  bool _isResetting = false;
  String _statusMessage = '';

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isKeywordMatch {
    final clean = _confirmText.trim().toUpperCase();
    return clean == 'LIMPAR' || clean == 'RESETAR';
  }

  bool get _canConfirm =>
      _options.hasAnySelected &&
      _isUnderstood &&
      _isKeywordMatch &&
      !_isResetting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_isResetting,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141529) : Colors.white,
          borderRadius: widget.isDialog
              ? BorderRadius.circular(28)
              : const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          widget.isDialog ? 24 : 12,
          20,
          widget.isDialog ? 20 : 0,
        ),
        // Proteção explícita de SafeArea para botões do sistema/home bar do dispositivo
        child: SafeArea(
          top: false,
          bottom: !widget.isDialog,
          minimum: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Puxador visual para modal de arrasto no celular
              if (!widget.isDialog)
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

              // Cabeçalho com ícone de alerta e botão fechar
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.cleaning_services_rounded,
                      color: Color(0xFFEF4444),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Limpeza e Redefinição',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _options.isAllSelected ? 'TUDO' : '${_options.selectedCount}/7',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _options.isAllSelected
                              ? 'Padrão: apagar tudo e recomeçar do zero'
                              : '${_options.selectedCount} categorias selecionadas para limpar',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            color: const Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isResetting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Conteúdo rolável completo
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Seletor com Minimizar/Expandir (Padrão: Tudo marcado, minimizado)
                      _buildCollapsibleSelectionSection(theme),

                      const SizedBox(height: 12),

                      // Card: O que é sempre preservado
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Sempre preservado no seu acesso:',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildDetailItem('Sua conta e login (email e autenticação Firebase)', isPositive: true),
                            _buildDetailItem('Permissões e nível de acesso (Administrador Principal)', isPositive: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Regra de Validação 1: Checkbox de ciência explícita
                      Material(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _isResetting
                              ? null
                              : () => setState(() => _isUnderstood = !_isUnderstood),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _isUnderstood
                                    ? const Color(0xFFEF4444)
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.12),
                                width: _isUnderstood ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _isUnderstood,
                                  activeColor: const Color(0xFFEF4444),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: _isResetting
                                      ? null
                                      : (val) => setState(() => _isUnderstood = val ?? false),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _options.isAllSelected
                                        ? 'Estou ciente de que todos os dados locais serão apagados permanentemente.'
                                        : 'Estou ciente de que os itens selecionados serão apagados permanentemente.',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Regra de Validação 2: Digitar LIMPAR
                      Text(
                        'Para confirmar, digite a palavra LIMPAR abaixo:',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _confirmController,
                        enabled: !_isResetting,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (val) => setState(() => _confirmText = val),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'LIMPAR',
                          hintStyle: GoogleFonts.outfit(
                            letterSpacing: 2,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _isKeywordMatch
                                  ? const Color(0xFFEF4444)
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                              width: _isKeywordMatch ? 1.5 : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      if (_isResetting) ...[
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          color: const Color(0xFFEF4444),
                          backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _statusMessage.isNotEmpty ? _statusMessage : 'Processando limpeza...',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: const Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Botões de Ação protegidos acima da barra de navegação/Safe Area
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isResetting ? null : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _canConfirm ? _handleReset : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          disabledBackgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.25),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: _canConfirm ? 3 : 0,
                        ),
                        child: Text(
                          _options.isAllSelected
                              ? 'APAGAR TUDO E REINICIAR'
                              : 'LIMPAR SELECIONADOS (${_options.selectedCount})',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: _canConfirm ? Colors.white : Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Seção expansível/recolhível com resumo quando minimizada e opções detalhadas quando aberta
  Widget _buildCollapsibleSelectionSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho clicável para expandir/minimizar
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isResetting
                  ? null
                  : () => setState(() => _isOptionsExpanded = !_isOptionsExpanded),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Itens para Limpar',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_options.selectedCount}/7',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isOptionsExpanded
                                ? 'Toque nas caixas abaixo para desmarcar'
                                : (_options.isAllSelected
                                    ? 'Padrão: Todos os 7 itens marcados'
                                    : '${_options.selectedCount} selecionados · Toque para alterar'),
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.kPrimaryGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.kPrimaryGold.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _isOptionsExpanded ? 'Recolher' : 'Alterar',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.kPrimaryGold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _isOptionsExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppTheme.kPrimaryGold,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Se estiver minimizado, exibe pequenas tags dos itens selecionados
          if (!_isOptionsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (_options.biblesAndStore) _buildMiniTag('Bíblias & Loja', const Color(0xFF3B82F6)),
                  if (_options.pdfsAndEbooks) _buildMiniTag('PDFs & E-books', const Color(0xFFEC4899)),
                  if (_options.readingProgress) _buildMiniTag('Progresso Bíblico', const Color(0xFFF59E0B)),
                  if (_options.documentsAndStudies) _buildMiniTag('Documentos', const Color(0xFF8B5CF6)),
                  if (_options.favoritesAndHighlights) _buildMiniTag('Favoritos/Cores', const Color(0xFF10B981)),
                  if (_options.verseAnnotations) _buildMiniTag('Anotações', const Color(0xFF06B6D4)),
                  if (_options.cachesAndHistory) _buildMiniTag('Caches', const Color(0xFF6B7280)),
                  if (!_options.hasAnySelected)
                    _buildMiniTag('Nenhum selecionado', Colors.grey),
                ],
              ),
            ),

          // Se estiver expandido, exibe a barra de marcar tudo e os 7 itens detalhados
          if (_isOptionsExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selecione o que apagar:',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isResetting
                        ? null
                        : () {
                            setState(() {
                              final selectAll = !_options.isAllSelected;
                              _options.setAll(selectAll);
                            });
                          },
                    icon: Icon(
                      _options.isAllSelected
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                      size: 15,
                      color: const Color(0xFFEF4444),
                    ),
                    label: Text(
                      _options.isAllSelected ? 'Desmarcar Tudo' : 'Marcar Tudo',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Column(
                children: [
                  _buildOptionTile(
                    title: 'Bíblias e Loja',
                    subtitle: 'Bíblias, comentários, dicionários e livros baixados localmente',
                    icon: Icons.menu_book_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    value: _options.biblesAndStore,
                    onChanged: (val) => setState(() => _options.biblesAndStore = val ?? false),
                    theme: theme,
                  ),
                  _buildOptionTile(
                    title: 'PDFs e E-books Baixados',
                    subtitle: 'Documentos PDF, e-books e progresso de páginas da biblioteca',
                    icon: Icons.picture_as_pdf_rounded,
                    iconColor: const Color(0xFFEC4899),
                    value: _options.pdfsAndEbooks,
                    onChanged: (val) => setState(() => _options.pdfsAndEbooks = val ?? false),
                    theme: theme,
                  ),
                  _buildOptionTile(
                    title: 'Progresso de Leitura Bíblica',
                    subtitle: 'Status de livros ("LENDO"/"CONCLUÍDO"), capítulos lidos e streaks',
                    icon: Icons.auto_stories_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    value: _options.readingProgress,
                    onChanged: (val) => setState(() => _options.readingProgress = val ?? false),
                    theme: theme,
                  ),
                  _buildOptionTile(
                    title: 'Documentos e Estudos',
                    subtitle: 'Documentos criados pelo usuário, esboços de sermão e estudos',
                    icon: Icons.edit_note_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    value: _options.documentsAndStudies,
                    onChanged: (val) => setState(() => _options.documentsAndStudies = val ?? false),
                    theme: theme,
                  ),
                  _buildOptionTile(
                    title: 'Favoritos e Marcações Coloridas',
                    subtitle: 'Todos os versículos favoritados e marcações de cor no texto',
                    icon: Icons.bookmark_rounded,
                    iconColor: const Color(0xFF10B981),
                    value: _options.favoritesAndHighlights,
                    onChanged: (val) => setState(() => _options.favoritesAndHighlights = val ?? false),
                    theme: theme,
                  ),
                  _buildOptionTile(
                    title: 'Anotações em Versículos',
                    subtitle: 'Notas pessoais e comentários vinculados diretamente aos versículos',
                    icon: Icons.comment_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    value: _options.verseAnnotations,
                    onChanged: (val) => setState(() => _options.verseAnnotations = val ?? false),
                    theme: theme,
                  ),
                  _buildOptionTile(
                    title: 'Caches e Temporários',
                    subtitle: 'Caches do banco, buscas recentes e histórico de navegação temporário',
                    icon: Icons.cached_rounded,
                    iconColor: const Color(0xFF6B7280),
                    value: _options.cachesAndHistory,
                    onChanged: (val) => setState(() => _options.cachesAndHistory = val ?? false),
                    theme: theme,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: value
            ? const Color(0xFFEF4444).withValues(alpha: 0.08)
            : theme.colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? const Color(0xFFEF4444).withValues(alpha: 0.35)
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: value ? 1.3 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isResetting ? null : () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Checkbox(
                  value: value,
                  activeColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: _isResetting ? null : onChanged,
                ),
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
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
    );
  }

  Future<void> _handleReset() async {
    setState(() {
      _isResetting = true;
      _statusMessage = 'Iniciando limpeza...';
    });

    try {
      await DataResetService.resetData(
        ref,
        options: _options,
        onProgress: (step) {
          if (mounted) {
            setState(() {
              _statusMessage = step;
            });
          }
        },
      );

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _options.isAllSelected
                        ? 'Todos os dados foram redefinidos! O aplicativo começou do zero.'
                        : '${_options.selectedCount} categorias de dados foram limpas com sucesso!',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResetting = false;
          _statusMessage = 'Erro ao limpar: $e';
        });
      }
    }
  }

  Widget _buildDetailItem(String text, {bool isPositive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPositive ? Icons.check_circle_outline_rounded : Icons.remove_circle_outline_rounded,
            size: 13,
            color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
