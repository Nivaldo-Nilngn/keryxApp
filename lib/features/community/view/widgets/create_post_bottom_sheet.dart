import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/features/community/view_model/community_feed_provider.dart';

class CreatePostBottomSheet extends ConsumerStatefulWidget {
  const CreatePostBottomSheet({super.key});

  @override
  ConsumerState<CreatePostBottomSheet> createState() =>
      _CreatePostBottomSheetState();
}

class _CreatePostBottomSheetState extends ConsumerState<CreatePostBottomSheet> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _verseTextController = TextEditingController();

  String _selectedTheme = 'gold';
  bool _includeVerse = true;
  bool _isPublishing = false;

  @override
  void dispose() {
    _captionController.dispose();
    _referenceController.dispose();
    _verseTextController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final caption = _captionController.text.trim();
    final refText = _referenceController.text.trim();
    final verse = _verseTextController.text.trim();

    if (caption.isEmpty && verse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva uma mensagem ou adicione um versículo.')),
      );
      return;
    }

    setState(() => _isPublishing = true);

    final service = ref.read(communityServiceProvider);
    final post = await service.createPost(
      caption: caption,
      bibleReference: _includeVerse && refText.isNotEmpty ? refText : null,
      bibleText: _includeVerse && verse.isNotEmpty ? verse : null,
      cardTheme: _selectedTheme,
    );

    if (mounted) {
      if (post != null) {
        ref.read(communityFeedProvider.notifier).addLocalPost(post);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sua bênção foi compartilhada na Comunidade! 🎉'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF181824) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Puxador
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Cabeçalho
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Nova Postagem',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  _isPublishing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.kPrimaryGold,
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _publish,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.kPrimaryGold,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Publicar',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  // Campo de Reflexão / Legenda
                  TextField(
                    controller: _captionController,
                    maxLines: 4,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.45,
                    ),
                    decoration: InputDecoration(
                      hintText: 'O que Deus falou ao seu coração hoje? Deixe uma reflexão ou pedido de oração...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Switch para incluir Cartão de Versículo
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.format_quote_rounded, color: AppTheme.kPrimaryGold, size: 20),
                    ),
                    title: Text(
                      'Destacar Versículo Bíblico',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    value: _includeVerse,
                    activeThumbColor: AppTheme.kPrimaryGold,
                    onChanged: (val) => setState(() => _includeVerse = val),
                  ),

                  if (_includeVerse) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222234) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _referenceController,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.kPrimaryGold,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Referência (ex: Salmos 23:1)',
                              hintStyle: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                              ),
                              prefixIcon: const Icon(Icons.menu_book, color: AppTheme.kPrimaryGold, size: 18),
                              border: InputBorder.none,
                            ),
                          ),
                          const Divider(height: 1),
                          TextField(
                            controller: _verseTextController,
                            maxLines: 3,
                            style: GoogleFonts.merriweather(
                              fontSize: 13.5,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Cole ou digite o texto do versículo...',
                              hintStyle: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'ESTILO DO CARTÃO BÍBLICO',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildThemeChip('Dourado', 'gold', const Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        _buildThemeChip('Índigo', 'indigo', const Color(0xFF4F46E5)),
                        const SizedBox(width: 8),
                        _buildThemeChip('Esmeralda', 'emerald', const Color(0xFF059669)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeChip(String label, String value, Color color) {
    final isSelected = _selectedTheme == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTheme = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.25 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 5, backgroundColor: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
