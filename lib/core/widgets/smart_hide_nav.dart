import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SmartHideNav extends StatelessWidget {
  final Widget child;
  final bool isVisible;
  final Duration duration;

  const SmartHideNav({
    super.key,
    required this.child,
    required this.isVisible,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: duration,
      opacity: isVisible ? 1.0 : 0.0,
      curve: Curves.easeInOut,
      child: AnimatedSlide(
        duration: duration,
        offset: isVisible ? Offset.zero : const Offset(0, 1.0),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }
}

/// Helper para detectar a direção do scroll
bool handleNavbarScrollNotification(ScrollNotification notification, bool currentVisible, Function(bool) onUpdate) {
  if (notification.metrics.axis != Axis.vertical) return false;

  if (notification is UserScrollNotification) {
    if (notification.direction == ScrollDirection.reverse) {
      if (currentVisible) onUpdate(false);
    } else if (notification.direction == ScrollDirection.forward) {
      if (!currentVisible) onUpdate(true);
    }
  }
  
  // No topo, sempre mostra
  if (notification is ScrollUpdateNotification && notification.metrics.pixels <= 10) {
    if (!currentVisible) onUpdate(true);
  }
  
  return false; // Permite que a notificação continue subindo
}
