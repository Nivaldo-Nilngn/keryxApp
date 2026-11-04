import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/core/state/font_state.dart';

enum NavBarStyle {
  floating, // Padrão: cápsula flutuante estilizada
  fixed,    // Fixo: barra fixada no rodapé da tela
}

class NavBarStyleNotifier extends StateNotifier<NavBarStyle> {
  final SharedPreferences? _prefs;

  NavBarStyleNotifier(this._prefs) : super(_loadInitial(_prefs));

  static const String _prefKey = 'app_nav_bar_style';

  static NavBarStyle _loadInitial(SharedPreferences? prefs) {
    final val = prefs?.getString(_prefKey);
    if (val == 'fixed') {
      return NavBarStyle.fixed;
    }
    return NavBarStyle.floating;
  }

  Future<void> setStyle(NavBarStyle style) async {
    state = style;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, style == NavBarStyle.fixed ? 'fixed' : 'floating');
    } catch (_) {}
  }
}

final navBarStyleProvider = StateNotifierProvider<NavBarStyleNotifier, NavBarStyle>((ref) {
  try {
    final prefs = ref.watch(sharedPreferencesProvider);
    return NavBarStyleNotifier(prefs);
  } catch (_) {
    return NavBarStyleNotifier(null);
  }
});

