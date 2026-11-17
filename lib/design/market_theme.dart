import 'package:flutter/material.dart';

const marketPaper = Color(0xFFF6F5F0);
const marketSurface = Color(0xFFFFFFFF);
const marketHeroChip = Color(0xFF343C39);
const marketInk = Color(0xFF1B3028);
const marketMuted = Color(0xFF58665D);
const marketLine = Color(0xFFE0E3DC);
const marketTint = Color(0xFFEFEEE7);
const marketGold = Color(0xFFC7A044);
const marketAccent = Color(0xFF765B1E);

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
        primary: marketInk,
        onPrimary: marketSurface,
        secondary: marketAccent,
        surface: marketSurface,
        onSurface: marketInk,
        outline: marketLine,
        error: const Color(0xFFB3261E),
      ),
  dividerColor: marketLine,
  visualDensity: VisualDensity.standard,
  materialTapTargetSize: MaterialTapTargetSize.padded,
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  iconTheme: const IconThemeData(color: marketInk, size: 20),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 36,
      height: 1.08,
      fontWeight: FontWeight.w500,
      letterSpacing: -1.5,
      color: marketInk,
    ),
    headlineMedium: TextStyle(
      fontSize: 30,
      height: 1.12,
      fontWeight: FontWeight.w500,
      letterSpacing: -1.1,
      color: marketInk,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w500,
      letterSpacing: -.5,
      color: marketInk,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: marketInk,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: marketInk),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: marketInk),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: marketMuted),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: marketInk,
    ),
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    iconColor: marketMuted,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: marketPaper,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: marketPaper,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  ),
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
      borderRadius: BorderRadius.all(Radius.circular(9)),
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: false,
    hintStyle: TextStyle(color: marketMuted),
    labelStyle: TextStyle(color: marketMuted),
    contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 16),
    border: UnderlineInputBorder(borderSide: BorderSide(color: marketLine)),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: marketLine),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: marketAccent, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: marketInk,
      foregroundColor: marketSurface,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      textStyle: const TextStyle(fontWeight: FontWeight.w500),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: marketInk,
      side: const BorderSide(color: marketLine),
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: marketAccent,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: marketInk,
    unselectedLabelColor: marketMuted,
    indicatorColor: marketAccent,
    labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    dividerColor: marketLine,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: marketSurface,
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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
  ),
);
