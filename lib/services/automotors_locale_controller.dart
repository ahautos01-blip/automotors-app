import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central locale state for AUTOMOTORS. Use this controller from the language
/// selector and pass [locale] to MaterialApp to update the entire widget tree.
class AutomotorsLocaleController extends ChangeNotifier {
  AutomotorsLocaleController._();
  static final AutomotorsLocaleController instance = AutomotorsLocaleController._();

  static const preferenceKey = 'automotors_locale';
  static const supportedCodes = <String>{'es', 'en', 'ca'};

  Locale _locale = const Locale('es');
  Locale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(preferenceKey);
    if (code != null && supportedCodes.contains(code) && _locale.languageCode != code) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> select(String code) async {
    if (!supportedCodes.contains(code)) {
      throw ArgumentError.value(code, 'code', 'Unsupported language');
    }
    final prefs = await SharedPreferences.getInstance();
    if (_locale.languageCode == code && prefs.getString(preferenceKey) == code) return;
    await prefs.setString(preferenceKey, code);
    _locale = Locale(code);
    notifyListeners();
  }
}
