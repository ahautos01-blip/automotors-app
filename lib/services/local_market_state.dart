import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Serializes local saves so an older write cannot resurrect a cleared draft.
class LocalMarketState {
  LocalMarketState({Future<SharedPreferences>? preferences})
    : _preferences = preferences;
  final Future<SharedPreferences>? _preferences;
  Future<SharedPreferences> get _store =>
      _preferences ?? SharedPreferences.getInstance();
  Future<void>? _pending;

  Future<Map<String, dynamic>> read(String key) async {
    if (_pending != null) await _pending;
    try {
      final raw = (await _store).getString(key);
      if (raw == null) return {};
      final value = jsonDecode(raw);
      return value is Map ? Map<String, dynamic>.from(value) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> write(String key, Map<String, dynamic> value) {
    final encoded = jsonEncode(value);
    return _enqueue(() async {
      if (!await (await _store).setString(key, encoded)) {
        throw StateError('Local save failed');
      }
    });
  }

  Future<void> remove(String key) => _enqueue(() async {
    await (await _store).remove(key);
  });

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pending == null
        ? operation()
        : _pending!.then((_) => operation());
    _pending = result.catchError((Object _) {});
    return result;
  }
}
