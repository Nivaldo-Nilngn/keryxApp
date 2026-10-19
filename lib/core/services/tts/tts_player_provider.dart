import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'tts_service.dart';

class TTSPlaybackState {
  final bool isPlaying;
  final String? bookId;
  final String? bookName;
  final int chapter;
  final int currentVerseIndex;
  final List<String> verses;
  final bool isFinished;

  TTSPlaybackState({
    this.isPlaying = false,
    this.bookId,
    this.bookName,
    this.chapter = 1,
    this.currentVerseIndex = 0,
    this.verses = const [],
    this.isFinished = false,
  });

  TTSPlaybackState copyWith({
    bool? isPlaying,
    String? bookId,
    String? bookName,
    int? chapter,
    int? currentVerseIndex,
    List<String>? verses,
    bool? isFinished,
  }) {
    return TTSPlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      bookId: bookId ?? this.bookId,
      bookName: bookName ?? this.bookName,
      chapter: chapter ?? this.chapter,
      currentVerseIndex: currentVerseIndex ?? this.currentVerseIndex,
      verses: verses ?? this.verses,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}

final ttsPlayerProvider = StateNotifierProvider<TTSPlayerNotifier, TTSPlaybackState>((ref) {
  final ttsService = ref.read(ttsServiceProvider);
  return TTSPlayerNotifier(ttsService);
});

class TTSPlayerNotifier extends StateNotifier<TTSPlaybackState> {
  final TTSService ttsService;
  bool _isCancelled = false;

  TTSPlayerNotifier(this.ttsService) : super(TTSPlaybackState());

  Future<void> playChapter(
    String bookId,
    String bookName,
    int chapter,
    List<String> verses, {
    int startVerseIndex = 0,
  }) async {
    _isCancelled = false;
    
    if (kIsWeb) {
      ttsService.stop(); 
    } else {
      await ttsService.stop();
    }
    
    state = state.copyWith(
      isPlaying: true,
      bookId: bookId,
      bookName: bookName,
      chapter: chapter,
      verses: verses,
      currentVerseIndex: startVerseIndex,
      isFinished: false,
    );

    _playLoop();
  }

  Future<void> _playLoop() async {
    while (state.currentVerseIndex < state.verses.length && !_isCancelled) {
      if (!state.isPlaying) break;
      
      String verse = state.verses[state.currentVerseIndex];
      if (verse.trim().isNotEmpty) {
        try {
          await ttsService.speakAndWait(verse);
        } catch (e) {
          // If interrupted (e.g. by stop/skip), we break out and do NOT increment the verse.
          debugPrint("Loop de áudio interrompido: $e");
          break;
        }
      }
      
      if (!_isCancelled && state.isPlaying) {
         if (state.currentVerseIndex < state.verses.length - 1) {
           state = state.copyWith(currentVerseIndex: state.currentVerseIndex + 1);
         } else {
           // End of chapter
           state = state.copyWith(isPlaying: false, isFinished: true);
           break;
         }
      }
    }
  }

  Future<void> pause() async {
    _isCancelled = true;
    state = state.copyWith(isPlaying: false);
    await ttsService.stop();
  }

  Future<void> resume() async {
    if (state.verses.isEmpty) return;
    _isCancelled = false;
    state = state.copyWith(isPlaying: true);
    _playLoop();
  }

  Future<void> stop() async {
    _isCancelled = true;
    state = state.copyWith(isPlaying: false, currentVerseIndex: 0, isFinished: false);
    await ttsService.stop();
  }

  Future<void> skipNextVerse() async {
    if (state.verses.isEmpty) return;
    if (state.currentVerseIndex < state.verses.length - 1) {
      _isCancelled = true;
      await ttsService.stop();
      state = state.copyWith(currentVerseIndex: state.currentVerseIndex + 1);
      
      // Allow small delay for TTS to actually stop before restarting
      await Future.delayed(const Duration(milliseconds: 200));
      _isCancelled = false;
      if (state.isPlaying) {
        _playLoop();
      }
    }
  }

  Future<void> skipPreviousVerse() async {
    if (state.verses.isEmpty) return;
    if (state.currentVerseIndex > 0) {
      _isCancelled = true;
      await ttsService.stop();
      state = state.copyWith(currentVerseIndex: state.currentVerseIndex - 1);
      
      await Future.delayed(const Duration(milliseconds: 200));
      _isCancelled = false;
      if (state.isPlaying) {
        _playLoop();
      }
    }
  }
}
