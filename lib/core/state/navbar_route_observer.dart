import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation_state.dart';

/// [NavbarRouteObserver] é um NavigatorObserver centralizado que garante
/// que a Navbar seja sempre visível ao navegar para qualquer nova rota.
///
/// Regras implementadas:
/// - didPush  → nova tela aberta → Navbar visível
/// - didPop   → voltou à tela anterior → Navbar visível
/// - didReplace → tela substituída → Navbar visível
///
/// Isso elimina a necessidade de resetar o estado da Navbar em cada tela
/// individualmente, garantindo comportamento global e consistente.
class NavbarRouteObserver extends NavigatorObserver {
  final ProviderContainer _container;

  NavbarRouteObserver(this._container);

  void _showNavbar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _container.read(navbarVisibleProvider.notifier).state = true;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // Ignora routes que não são páginas completas (ex: DialogRoute, BottomSheet)
    if (route is PageRoute) {
      _showNavbar();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute) {
      _showNavbar();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _showNavbar();
    }
  }
}
