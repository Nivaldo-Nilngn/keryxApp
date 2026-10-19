import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
    const gold = AppTheme.kPrimaryGold;
    final onSurface = theme.colorScheme.onSurface;

    final markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: GoogleFonts.lora(fontSize: 15.5, height: 1.65, color: onSurface.withValues(alpha: 0.92)),
      strong: GoogleFonts.lora(fontSize: 15.5, fontWeight: FontWeight.w700, color: gold),
      em: GoogleFonts.lora(fontSize: 15.5, fontStyle: FontStyle.italic, color: onSurface),
      h1: GoogleFonts.lora(fontSize: 21, fontWeight: FontWeight.w700, color: gold, height: 1.4),
      h2: GoogleFonts.lora(fontSize: 18.5, fontWeight: FontWeight.w700, color: gold, height: 1.4),
      h3: GoogleFonts.lora(fontSize: 16.5, fontWeight: FontWeight.w700, color: gold, height: 1.4),
      listBullet: GoogleFonts.lora(fontSize: 15.5, color: gold),
      listIndent: 20,
      blockSpacing: 12,
      // Versículos e citações: destaque com faixa dourada
      blockquote: GoogleFonts.lora(
        fontSize: 15.5,
        fontStyle: FontStyle.italic,
        height: 1.65,
        color: onSurface.withValues(alpha: 0.88),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      blockquoteDecoration: BoxDecoration(
        color: gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: gold, width: 3)),
      ),
      code: GoogleFonts.robotoMono(
        fontSize: 13.5,
        backgroundColor: onSurface.withValues(alpha: 0.08),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: gold.withValues(alpha: 0.25), width: 1)),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 16, top: 6, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AiAvatar(),
            const SizedBox(width: 10),
            Flexible(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(color: gold.withValues(alpha: 0.14)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarkdownBody(
                      data: message.text,
                      selectable: true,
                      styleSheet: markdownStyle,
                    ),
                    if (message.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
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
                          const SizedBox(width: 4),
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

class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

  @override
  Widget build(BuildContext context) {
    const gold = AppTheme.kPrimaryGold;
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gold.withValues(alpha: 0.14),
        border: Border.all(color: gold.withValues(alpha: 0.5)),
      ),
      child: const Icon(Icons.auto_stories_rounded, size: 16, color: gold),
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
    final theme = Theme.of(context);
    const gold = AppTheme.kPrimaryGold;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 16, top: 6, bottom: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _AiAvatar(),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: gold.withValues(alpha: 0.14)),
              ),
              child: AnimatedBuilder(
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
            ),
          ],
        ),
      ),
    );
  }
}