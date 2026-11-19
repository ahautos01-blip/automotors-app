import 'dart:ui';

import 'package:flutter/material.dart';

import 'market_theme.dart';

/// One bounded blur for navigation, never repeated inside scrolling cards.
class MarketGlassNavigation extends StatelessWidget {
  const MarketGlassNavigation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final accessible =
        MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: marketSurface.withValues(alpha: accessible ? 1 : .86),
        border: Border.all(color: marketLine, width: .5),
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: accessible
              ? surface
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: surface,
                ),
        ),
      ),
    );
  }
}
