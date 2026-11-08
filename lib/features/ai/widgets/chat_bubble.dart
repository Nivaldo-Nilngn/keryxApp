import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/theme/app_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/ai/model/chat_model.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';

class ChatBubble extends ConsumerWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return message.isUser ? _buildUser(context) : _buildAi(context, ref);
  }

  // ---------- Mensagem do usuário ----------
  Widget _buildUser(BuildContext context) {
    const gold = AppTheme.kPrimaryGold;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 56, right: 16, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gold, gold.withValues(alpha: 0.82)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(5),
          ),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SelectableText(
          message.text,
          style: GoogleFonts.outfit(
            fontSize: 15,
            height: 1.45,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ---------- Mensagem da IA ----------
  Widget _buildAi(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const gold = AppTheme.kPrimaryGold;
    final onSurface = theme.colorScheme.onSurface;

    final markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: GoogleFonts.lora(
        fontSize: 15.5,
        height: 1.68,
        color: onSurface.withValues(alpha: 0.94),
      ),
      strong: GoogleFonts.outfit(
        fontSize: 15.5,
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFFFFD56B) : const Color(0xFFB45309),
      ),
      em: GoogleFonts.lora(
        fontSize: 15.5,
        fontStyle: FontStyle.italic,
        color: onSurface.withValues(alpha: 0.88),
      ),
      h1: GoogleFonts.outfit(
        fontSize: 21,
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFFFFD56B) : const Color(0xFF92400E),
        height: 1.4,
      ),
      h2: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFFFFD56B) : const Color(0xFF92400E),
        height: 1.4,
      ),
      h3: GoogleFonts.outfit(
        fontSize: 16.5,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.4,
      ),
      listBullet: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? gold : const Color(0xFFB45309),
      ),
      listIndent: 20,
      blockSpacing: 14,
      // Citações bíblicas e destaques: faixa lateral dourada sutil, texto livre
      blockquote: GoogleFonts.lora(
        fontSize: 15,
        fontStyle: FontStyle.italic,
        height: 1.65,
        color: onSurface.withValues(alpha: 0.90),
      ),
      blockquotePadding: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: (isDark ? gold : const Color(0xFFD97706)).withValues(alpha: 0.7), width: 3)),
      ),
      tableHead: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: isDark ? gold : const Color(0xFFB45309),
      ),
      tableBody: GoogleFonts.lora(fontSize: 13, height: 1.45, color: onSurface),
      tableBorder: TableBorder.all(
        color: (isDark ? gold : const Color(0xFFD97706)).withValues(alpha: 0.25),
        width: 1,
        borderRadius: BorderRadius.circular(8),
      ),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      tableColumnWidth: const FlexColumnWidth(),
      code: GoogleFonts.robotoMono(
        fontSize: 13.5,
        backgroundColor: onSurface.withValues(alpha: 0.08),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: onSurface.withValues(alpha: 0.12), width: 1)),
      ),
    );

    final formattedContent = _formatStudyContent(message.text);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identificador sutil da IATheos no topo da resposta
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD56B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: Color(0xFF1E1B18),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'IATheos',
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Texto livre e contínuo, sem caixas sufocantes
          MarkdownBody(
            data: formattedContent,
            selectable: true,
            styleSheet: markdownStyle,
          ),

          if (message.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Copiar',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    _toast(context, 'Texto copiado!');
                  },
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.bookmark_add_outlined,
                  label: 'Salvar',
                  onTap: () {
                    final key = 'iatheos_${DateTime.now().millisecondsSinceEpoch}';
                    ref
                        .read(annotationsProvider.notifier)
                        .saveAnnotation(key, message.text);
                    _toast(context, 'Salvo nas suas anotações!');
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Divider(color: onSurface.withValues(alpha: 0.08), height: 16),
          ],
        ],
      ),
    );
  }

  /// Converte tabelas Markdown rígidas em tópicos e seções arejadas
  /// de estudo bíblico, sem caixas presas.
  static String _formatStudyContent(String text) {
    if (!text.contains('|')) return text;

    final lines = text.split('\n');
    final result = <String>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Verifica se a linha atual e a próxima formam uma tabela Markdown (| col | col |)
      if (trimmed.startsWith('|') && trimmed.endsWith('|') && i + 1 < lines.length) {
        final nextTrimmed = lines[i + 1].trim();
        final isSeparator = nextTrimmed.startsWith('|') &&
            RegExp(r'^\|(?:\s*:?-+:?\s*\|)+$').hasMatch(nextTrimmed);

        if (isSeparator) {
          final rawHeaders = trimmed
              .split('|')
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toList();

          i += 2; // Pula cabeçalho e divisor

          final rows = <List<String>>[];
          while (i < lines.length &&
              lines[i].trim().startsWith('|') &&
              lines[i].trim().endsWith('|')) {
            final rowCells = lines[i]
                .trim()
                .split('|')
                .map((c) => c.trim())
                .toList();
            if (rowCells.isNotEmpty && rowCells.first.isEmpty) {
              rowCells.removeAt(0);
            }
            if (rowCells.isNotEmpty && rowCells.last.isEmpty) {
              rowCells.removeLast();
            }

            if (rowCells.isNotEmpty) {
              rows.add(rowCells);
            }
            i++;
          }

          // Converte linhas da tabela em tópicos limpos e livres
          result.add('');
          for (final row in rows) {
            if (row.isEmpty) continue;
            final rawTitle = row[0].replaceAll(RegExp(r'^\*\*|\*\*$'), '').trim();
            final header0 = rawHeaders.isNotEmpty ? rawHeaders[0].toLowerCase() : '';

            // Escolhe um emoji bíblico/teológico elegante para o título
            String icon = '📌';
            if (header0.contains('texto') ||
                header0.contains('passagem') ||
                header0.contains('versículo') ||
                rawTitle.contains(RegExp(r'\d+:\d+'))) {
              icon = '📖';
            } else if (header0.contains('visão') ||
                header0.contains('teologia') ||
                header0.contains('doutrina') ||
                header0.contains('posição')) {
              icon = '🏛️';
            }

            if (row.length == 2) {
              final content = row[1].replaceAll(RegExp(r'<br\s*/?>'), '\n');
              result.add('**$icon $rawTitle**\n$content\n');
            } else {
              result.add('**$icon $rawTitle**');
              for (var c = 1; c < row.length; c++) {
                final colHeader = c < rawHeaders.length ? rawHeaders[c] : 'Detalhe';
                final cellVal = row[c].replaceAll(RegExp(r'<br\s*/?>'), ' ');
                result.add('• **$colHeader:** $cellVal');
              }
              result.add('');
            }
          }
          continue;
        }
      }

      result.add(line);
      i++;
    }

    return result.join('\n');
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(label, style: GoogleFonts.outfit(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Indicador "IATheos está digitando" (três pontos animados).
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = AppTheme.kPrimaryGold;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD56B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: Color(0xFF1E1B18),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'IATheos está pesquisando...',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: gold.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  // cada ponto sobe e desce com um pequeno atraso
                  final t = (_c.value - i * 0.15) % 1.0;
                  final wave = t < 0.5 ? (t * 2) : (2 - t * 2);
                  return Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                    transform: Matrix4.translationValues(0, -4 * wave, 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gold.withValues(alpha: 0.35 + 0.65 * wave),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}