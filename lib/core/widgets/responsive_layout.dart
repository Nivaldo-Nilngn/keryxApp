import 'package:flutter/material.dart';

enum ScreenSize { compact, medium, expanded }

class ResponsiveLayout extends StatelessWidget {
  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder expanded;

  const ResponsiveLayout({
    super.key,
    required this.compact,
    this.medium,
    required this.expanded,
  });

  // Limites baseados no plano
  static const double compactMax = 600;
  static const double mediumMax = 840;

  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < compactMax) return ScreenSize.compact;
    if (width < mediumMax) return ScreenSize.medium;
    return ScreenSize.expanded;
  }

  static bool isCompact(BuildContext context) =>
      getScreenSize(context) == ScreenSize.compact;

  static bool isMedium(BuildContext context) =>
      getScreenSize(context) == ScreenSize.medium;

  static bool isExpanded(BuildContext context) =>
      getScreenSize(context) == ScreenSize.expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < compactMax) {
          return compact(context);
        } else if (constraints.maxWidth < mediumMax) {
          return medium != null ? medium!(context) : compact(context);
        } else {
          return expanded(context);
        }
      },
    );
  }
}
