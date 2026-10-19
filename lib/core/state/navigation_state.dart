import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  bool get canGoBack => state != 0;

  bool get canPop => !canGoBack;

  void setIndex(int index) {
    if (state == index) return;
    state = index;
    // Sempre garante que a navbar volta a aparecer ao mudar de aba
    ref.read(navbarVisibleProvider.notifier).state = true;
  }

  bool goBack() {
    if (state != 0) {
      state = 0;
      ref.read(navbarVisibleProvider.notifier).state = true;
      return true;
    }
    return false;
  }
}

final navigationProvider = NotifierProvider<NavigationNotifier, int>(() => NavigationNotifier());
final navbarVisibleProvider = StateProvider<bool>((ref) => true);
