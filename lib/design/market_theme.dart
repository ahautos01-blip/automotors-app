import 'package:flutter/material.dart';

const marketPaper = Color(0xFFFAF9F6);
const marketSurface = Color(0xFFFFFFFF);
const marketHeroChip = Color(0xFF343C39);
const marketInk = Color(0xFF1D2423);
const marketMuted = Color(0xFF69706B);
const marketLine = Color(0xFFE4E5DF);
const marketTint = Color(0xFFEFEEE7);
const marketGold = Color(0xFFD7B34D);
const marketAccent = Color(0xFF876B24);

ThemeData automotorsMarketTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: marketPaper,
  canvasColor: marketSurface,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: marketGold,
        brightness: Brightness.light,
      ).copyWith(
        primary: marketAccent,
        onPrimary: marketSurface,
        secondary: marketAccent,
        surface: marketSurface,
        onSurface: marketInk,
        outline: marketLine,
        error: const Color(0xFFB3261E),
      ),
  dividerColor: marketLine,
  appBarTheme: const AppBarTheme(
    backgroundColor: marketPaper,
    foregroundColor: marketInk,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  cardTheme: const CardThemeData(
    color: marketSurface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: marketSurface,
    hintStyle: const TextStyle(color: marketMuted),
    labelStyle: const TextStyle(color: marketMuted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: marketLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: marketLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: marketAccent, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: marketGold,
      foregroundColor: marketInk,
      minimumSize: const Size(44, 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: marketInk,
      side: const BorderSide(color: marketLine),
      minimumSize: const Size(44, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: marketAccent),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: marketPaper,
    indicatorColor: marketTint,
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        color: states.contains(WidgetState.selected)
            ? marketAccent
            : marketMuted,
      ),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        color: states.contains(WidgetState.selected) ? marketInk : marketMuted,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w500,
        fontSize: 11,
      ),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: marketInk,
    contentTextStyle: const TextStyle(color: marketSurface),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
);
