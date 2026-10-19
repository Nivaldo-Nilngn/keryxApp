import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';

class ReadingSelectionState {
  final BibleBook? book;
  final int chapter;
  final Set<int> selectedVerses;

  ReadingSelectionState({
    this.book,
    this.chapter = 1,
    this.selectedVerses = const {},
  });

  ReadingSelectionState copyWith({
    BibleBook? book,
    int? chapter,
    Set<int>? selectedVerses,
  }) {
    return ReadingSelectionState(
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      selectedVerses: selectedVerses ?? this.selectedVerses,
    );
  }

  int? get firstSelectedVerse {
    if (selectedVerses.isEmpty) return null;
    final list = selectedVerses.toList()..sort();
    return list.first;
  }

  int? get lastSelectedVerse {
    if (selectedVerses.isEmpty) return null;
    final list = selectedVerses.toList()..sort();
    return list.last;
  }
}

class ReadingSelectionNotifier extends Notifier<ReadingSelectionState> {
  @override
  ReadingSelectionState build() {
    return ReadingSelectionState();
  }

  void updateLocation(BibleBook book, int chapter) {
    if (state.book?.abbrev != book.abbrev || state.chapter != chapter) {
      state = state.copyWith(book: book, chapter: chapter, selectedVerses: {});
    }
  }

  void toggleVerse(int verseNumber) {
    final newSet = Set<int>.from(state.selectedVerses);
    if (newSet.contains(verseNumber)) {
      newSet.remove(verseNumber);
    } else {
      newSet.add(verseNumber);
    }
    state = state.copyWith(selectedVerses: newSet);
  }

  void clearSelection() {
    state = state.copyWith(selectedVerses: {});
  }
}

final readingSelectionProvider =
    NotifierProvider<ReadingSelectionNotifier, ReadingSelectionState>(() {
  return ReadingSelectionNotifier();
});
