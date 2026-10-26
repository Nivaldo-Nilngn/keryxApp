import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:keryx_app/core/services/bible_service.dart';
import 'package:keryx_app/core/utils/bible_text_parser.dart';
import 'package:keryx_app/core/state/font_state.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/responsive_layout.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/reading/view/text_settings_bottom_sheet.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';

/// Abre a tela completa de Comparação de Versões em múltiplas traduções
void showVerseComparisonScreen(
  BuildContext context, {
  required BibleBook currentBook,
  required int currentChapter,
  required List<int> selectedVerseNumbers,
  void Function(int targetBookId, int targetChapter, int targetVerse)? onNavigateToVerse,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => VerseComparisonScreen(
        currentBook: currentBook,
        currentChapter: currentChapter,
        selectedVerseNumbers: selectedVerseNumbers,
        onNavigateToVerse: onNavigateToVerse,
      ),
    ),
  );
}

class VerseComparisonScreen extends ConsumerWidget {
  final BibleBook currentBook;
  final int currentChapter;
  final List<int> selectedVerseNumbers;
  final void Function(int targetBookId, int targetChapter, int targetVerse)? onNavigateToVerse;

  static final RegExp _parensRegex = RegExp(r'\((.*?)\)');
  static final RegExp _leadingDigitsRegex = RegExp(r'^(\d+)\s*(.*)$');

  const VerseComparisonScreen({
    super.key,
    required this.currentBook,
    required this.currentChapter,
    required this.selectedVerseNumbers,
    this.onNavigateToVerse,
  });

  String _formatVerseRange(List<int> sorted) {
    if (sorted.isEmpty) return '';
    if (sorted.length == 1) return '${sorted.first}';
    final isSequential = sorted.last - sorted.first == sorted.length - 1;
    return isSequential
        ? '${sorted.first}-${sorted.last}'
        : sorted.join(', ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceBase = Theme.of(context).scaffoldBackgroundColor;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = textPrimary.withValues(alpha: 0.6);

    final fontSettings = ref.watch(fontSettingsProvider);
    final userFontSize = fontSettings.fontSize;
    final isExpanded = ResponsiveLayout.isExpanded(context);

    final sortedVerses = selectedVerseNumbers.toList()..sort();
    final verseRangeText = _formatVerseRange(sortedVerses);

    // Carrega versões locais disponíveis
    final storeState = ref.watch(downloadedStorePackagesProvider);
    final isVersionDownloadedLocally = (String v) {
      if (v == 'NVI' || v == 'ARA_S') return true;
      if (storeState.isDownloaded('$v.sqlite') ||
          storeState.isDownloaded('$v.mybible') ||
          storeState.isDownloaded('$v.bbl.mybible') ||
          storeState.isDownloaded('$v.db')) {
        return true;
      }
      return storeState.availablePackages.any((p) =>
          p.category == StoreCategory.bibles &&
          storeState.isDownloaded(p.filename) &&
          (p.filename.toUpperCase().contains(v.toUpperCase())));
    };

    final localVersions = <String>[];
    for (final v in BibleService.availableVersions) {
      if (isVersionDownloadedLocally(v)) {
        localVersions.add(v);
      }
    }
    for (final v in ['NVI', 'ARA_S']) {
      if (!localVersions.contains(v)) {
        localVersions.add(v);
      }
    }

    final userBibles = storeState.availablePackages.where(
      (p) =>
          p.category == StoreCategory.bibles &&
          storeState.isDownloaded(p.filename),
    );

    for (var bible in userBibles) {
      String rawFilename = bible.filename.split('/').last;
      if (rawFilename.contains('ARA+STRONG - ATUALIZADA + STRONG')) {
        continue;
      }

      final match = _parensRegex.firstMatch(rawFilename);
      String key;
      if (match != null && match.group(1) != null) {
        key = match.group(1)!.trim().toUpperCase();
        if (key == 'ARA-S') key = 'ARA_S';
      } else {
        String stripped = rawFilename;
        for (final ext in ['.bbl.mybible', '.mybible', '.sqlite', '.db']) {
          if (stripped.toLowerCase().endsWith(ext)) {
            stripped = stripped.substring(0, stripped.length - ext.length);
            break;
          }
        }
        key = stripped.trim().toUpperCase();
      }

      final existingKey = BibleMetadata.versionNames.keys.cast<String?>().firstWhere(
        (k) => k?.toUpperCase() == key.toUpperCase(),
        orElse: () => null,
      );

      final finalKey = existingKey ?? key;
      if (!localVersions.contains(finalKey)) {
        localVersions.add(finalKey);
      }
    }

    final comparison = ref.watch(
      compareVersesProvider((
        bookId: currentBook.id.toString(),
        chapter: currentChapter,
        versesStr: sortedVerses.join(','),
        versionsStr: localVersions.join(','),
      )),
    );

    return Scaffold(
      backgroundColor: surfaceBase,
      appBar: AppBar(
        backgroundColor: surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 24),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Voltar',
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${currentBook.name} $currentChapter:$verseRangeText',
              style: GoogleFonts.plusJakartaSans(
                color: textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'COMPARAÇÃO DE VERSÕES',
              style: GoogleFonts.outfit(
                color: isDark ? AppTheme.kPrimaryGold : Theme.of(context).colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Botão rápido: Diminuir tamanho do texto
          IconButton(
            icon: Icon(Icons.text_decrease_rounded, color: textSecondary, size: 20),
            tooltip: 'Diminuir tamanho da fonte',
            onPressed: () {
              final cur = ref.read(fontSettingsProvider).fontSize;
              if (cur > 12) {
                ref.read(fontSettingsProvider.notifier).setFontSize(cur - 1.5);
              }
            },
          ),
          // Botão rápido: Aumentar tamanho do texto
          IconButton(
            icon: Icon(Icons.text_increase_rounded, color: textSecondary, size: 22),
            tooltip: 'Aumentar tamanho da fonte',
            onPressed: () {
              final cur = ref.read(fontSettingsProvider).fontSize;
              if (cur < 38) {
                ref.read(fontSettingsProvider.notifier).setFontSize(cur + 1.5);
              }
            },
          ),
          // Botão completo de configurações de leitura
          IconButton(
            icon: Icon(Icons.tune_rounded, color: textSecondary, size: 22),
            tooltip: 'Configurações de Leitura & Fonte',
            onPressed: () => showTextSettingsBottomSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: comparison.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppTheme.kPrimaryGold,
            strokeWidth: 2.5,
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Erro ao carregar comparação: $e',
              style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (results) {
          if (results.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma versão encontrada para comparação.',
                style: GoogleFonts.outfit(
                  color: textSecondary,
                  fontSize: 14,
                ),
              ),
            );
          }

          if (isExpanded) {
            // Em telas widescreen/tablets: exibe em Grid de 2 colunas amplas
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 220,
              ),
              itemCount: results.length,
              itemBuilder: (context, i) {
                final item = results[i];
                return _buildVersionCard(context, item, isDark, userFontSize);
              },
            );
          }

          // Em celular: lista vertical
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final item = results[i];
              return _buildVersionCard(context, item, isDark, userFontSize);
            },
          );
        },
      ),
    );
  }

  Widget _buildVersionCard(
    BuildContext context,
    Map<String, dynamic> item,
    bool isDark,
    double userFontSize,
  ) {
    final text = item['text'] as String;
    final versionStr = item['version'] as String;
    final displayVersion = () {
      final match = _parensRegex.firstMatch(versionStr);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.toUpperCase();
      }
      return versionStr.toUpperCase();
    }();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).cardColor
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppTheme.kPrimaryGold.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Sigla da Versão + Botão Copiar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF2E2415), Color(0xFF1E1E2A)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.kPrimaryGold.withValues(alpha: 0.4)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Text(
                  displayVersion,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.kPrimaryGold : Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  size: 17,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                tooltip: 'Copiar texto',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final clean = BibleTextParser.cleanToPlainText(text);
                  Clipboard.setData(ClipboardData(text: '$clean ($displayVersion)'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Texto copiado ($displayVersion)!'),
                      duration: const Duration(milliseconds: 1200),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Texto do Versículo em tamanho dinâmico
          Expanded(
            flex: ResponsiveLayout.isExpanded(context) ? 1 : 0,
            child: SingleChildScrollView(
              physics: ResponsiveLayout.isExpanded(context)
                  ? const BouncingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: _buildComparisonVerseText(context, text, userFontSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonVerseText(
    BuildContext context,
    String text,
    double userFontSize,
  ) {
    final clean = text.trim();
    final numFontSize = (userFontSize * 0.88).clamp(13.0, 22.0);

    if (!clean.contains('\n\n')) {
      return Text(
        BibleTextParser.cleanToPlainText(clean),
        style: GoogleFonts.outfit(
          fontSize: userFontSize,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.95),
          height: 1.6,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    final paragraphs = clean.split('\n\n');
    final spans = <InlineSpan>[];
    for (int pIdx = 0; pIdx < paragraphs.length; pIdx++) {
      final p = paragraphs[pIdx].trim();
      final match = _leadingDigitsRegex.firstMatch(p);
      if (match != null) {
        final num = match.group(1)!;
        final content = BibleTextParser.cleanToPlainText(match.group(2)!);
        spans.add(TextSpan(
          text: '$num ',
          style: GoogleFonts.outfit(
            fontSize: numFontSize,
            fontWeight: FontWeight.w800,
            color: AppTheme.kPrimaryGold,
          ),
        ));
        spans.add(TextSpan(
          text: content,
          style: GoogleFonts.outfit(
            fontSize: userFontSize,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.95),
            height: 1.6,
            fontWeight: FontWeight.w400,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: BibleTextParser.cleanToPlainText(p),
          style: GoogleFonts.outfit(
            fontSize: userFontSize,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.95),
            height: 1.6,
            fontWeight: FontWeight.w400,
          ),
        ));
      }
      if (pIdx < paragraphs.length - 1) {
        spans.add(const TextSpan(text: '\n\n'));
      }
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }
}
