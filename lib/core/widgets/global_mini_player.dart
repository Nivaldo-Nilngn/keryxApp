import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/services/tts/tts_player_provider.dart';
import 'package:keryx_app/features/bible/reading/view/reading_screen.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/bible/view/tts_settings_sheet.dart';
import 'package:keryx_app/core/theme/app_theme.dart';

class GlobalMiniPlayer extends ConsumerStatefulWidget {
  const GlobalMiniPlayer({super.key});

  @override
  ConsumerState<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends ConsumerState<GlobalMiniPlayer> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final ttsState = ref.watch(ttsPlayerProvider);
    final ttsNotifier = ref.read(ttsPlayerProvider.notifier);

    if (ttsState.verses.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        if (!_isExpanded) {
          final books = ref.read(booksProvider).valueOrNull;
          if (books != null && ttsState.bookId != null) {
            final currentBook = books.firstWhere((b) => b.id.toString() == ttsState.bookId);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReadingScreen(
                  book: currentBook,
                  initialChapter: ttsState.chapter,
                ),
              ),
            );
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.kSurfaceDark,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isExpanded) ...[
              // Botão para fechar o expandido
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white54, size: 28),
                onPressed: () => setState(() => _isExpanded = false),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              // Engrenagem (Configurações TTS)
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70, size: 28),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const TtsSettingsSheet(),
                  );
                },
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              // Pular para o anterior
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white, size: 28),
                onPressed: () => ttsNotifier.skipPreviousVerse(),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],

            // Botão Principal (Play/Pause)
            GestureDetector(
              onTap: () {
                if (ttsState.isPlaying) {
                  ttsNotifier.pause();
                } else {
                  ttsNotifier.resume();
                }
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.kPrimaryGold,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    ttsState.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                    size: 32,
                  ),
                ),
              ),
            ),

            if (_isExpanded) ...[
              // Pular para o próximo
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
                onPressed: () => ttsNotifier.skipNextVerse(),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              // Parar e fechar player
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 28),
                onPressed: () => ttsNotifier.stop(),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],

            // Quando está compactado, mostra o ícone de expandir à esquerda do play
            if (!_isExpanded) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white54, size: 28),
                onPressed: () => setState(() => _isExpanded = true),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
