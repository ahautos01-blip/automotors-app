import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

const marketPaper = Color(0xFFF4F5F3);
const marketSurface = Color(0xFFFFFFFF);
const marketHeroChip = Color(0xFF343C39);
const marketInk = Color(0xFF1B3028);
const marketMuted = Color(0xFF58665D);
const marketLine = Color(0xFFE0E3DC);
const marketTint = Color(0xFFEFEEE7);
const marketGold = Color(0xFFC7A044);
const marketAccent = Color(0xFF876B24);

ThemeData automotorsMarketTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  cupertinoOverrideTheme: const CupertinoThemeData(
    primaryColor: marketInk,
    scaffoldBackgroundColor: marketPaper,
    barBackgroundColor: Color(0xEBFFFFFF),
  ),
  scaffoldBackgroundColor: marketPaper,
  canvasColor: marketSurface,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: marketInk,
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
  // MaterialPageRoute keeps the native interactive back gesture on iPhone.
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    },
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      backgroundColor: marketInk.withValues(alpha: .06),
      shape: const CircleBorder(),
    ),
  ),
  iconTheme: const IconThemeData(color: marketInk, size: 20),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 36,
      height: 1.08,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.5,
      color: marketInk,
    ),
    headlineMedium: TextStyle(
      fontSize: 30,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.1,
      color: marketInk,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -.5,
      color: marketInk,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: marketInk,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: marketInk),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: marketInk),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: marketMuted),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: marketInk,
    ),
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    iconColor: marketMuted,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(22)),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: marketSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 12,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: marketSurface,
    surfaceTintColor: Colors.transparent,
    modalBarrierColor: Color(0x441B3028),
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: marketPaper,
    foregroundColor: marketInk,
    titleTextStyle: TextStyle(
      color: marketInk,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  cardTheme: const CardThemeData(
    color: marketSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 1,
    shadowColor: Color(0x141B3028),
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(26)),
      side: BorderSide(color: Color(0xFFE8EBE5), width: .5),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF0F2EE),
    hintStyle: const TextStyle(color: marketMuted),
    labelStyle: const TextStyle(color: marketMuted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: marketAccent, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: marketInk,
      foregroundColor: marketSurface,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: marketInk,
      side: const BorderSide(color: marketLine),
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      shape: const StadiumBorder(),
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
    labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    dividerColor: Colors.transparent,
    indicatorSize: TabBarIndicatorSize.tab,
    indicator: BoxDecoration(
      color: marketSurface,
      borderRadius: BorderRadius.all(Radius.circular(18)),
      boxShadow: [
        BoxShadow(
          color: Color(0x141B3028),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: marketSurface,
    selectedColor: marketTint,
    side: const BorderSide(color: marketLine, width: .5),
    shape: const StadiumBorder(),
    labelStyle: const TextStyle(
      color: marketInk,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: marketSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 12,
    shadowColor: marketInk.withValues(alpha: .12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: marketAccent),
  navigationBarTheme: NavigationBarThemeData(
    elevation: 0,
    height: 72,
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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
);
