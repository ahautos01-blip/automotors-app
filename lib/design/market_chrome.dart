import 'dart:ui';

import 'package:flutter/material.dart';

import 'market_theme.dart';

/// Shared chrome for every route, including account and moderation screens.
/// Dark photo viewers retain their original contrast and background.
class MarketAppBar extends AppBar {
  MarketAppBar({
    super.key,
    super.title,
    super.actions,
    super.leading,
    super.automaticallyImplyLeading,
    super.bottom,
    super.centerTitle,
    super.titleSpacing,
    super.toolbarHeight,
    super.leadingWidth,
    super.foregroundColor,
    super.elevation,
    super.scrolledUnderElevation,
    Color? backgroundColor,
  }) : super(
         backgroundColor:
             backgroundColor != null && backgroundColor.computeLuminance() < .2
             ? backgroundColor
             : Colors.transparent,
         surfaceTintColor: Colors.transparent,
         titleTextStyle:
             backgroundColor != null && backgroundColor.computeLuminance() < .2
             ? const TextStyle(
                 color: Colors.white,
                 fontSize: 20,
                 fontWeight: FontWeight.w700,
               )
             : null,
         flexibleSpace: MarketBarSurface(color: backgroundColor ?? marketPaper),
       );
}

/// Bounded route chrome: glass effects never repeat in scrolling listing rows.
class MarketBarSurface extends StatelessWidget {
  const MarketBarSurface({super.key, this.color = marketPaper, this.child});
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final opaque =
        MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context) ||
        color.computeLuminance() < .2;
    final surface = DecoratedBox(
      child: child,
      decoration: BoxDecoration(
        color: opaque ? color : null,
        gradient: opaque
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: .96),
                  color.withValues(alpha: .88),
                ],
              ),
        border: Border(
          bottom: BorderSide(
            color: color.computeLuminance() < .2
                ? Colors.transparent
                : marketLine,
            width: .5,
          ),
        ),
      ),
    );
    return ClipRect(
      child: opaque
          ? surface
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: surface,
            ),
    );
  }
}

/// Shared inset action surface for messaging, purchases and publication.
class MarketActionDock extends StatelessWidget {
  const MarketActionDock({super.key, required this.child, this.top = false});
  final Widget child;
  final bool top;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: top,
    minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: MarketBarSurface(color: marketSurface, child: child),
      ),
    ),
  );
}
