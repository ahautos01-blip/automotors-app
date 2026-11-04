import 'package:shared_preferences/shared_preferences.dart';

String normalizeVehicleSearch(String value) {
  var result = value.trim().toLowerCase();
  const groups = {
    'a': 'àáâäãå',
    'e': 'èéêë',
    'i': 'ìíîï',
    'o': 'òóôöõ',
    'u': 'ùúûü',
    'n': 'ñ',
    'c': 'ç',
  };
  for (final entry in groups.entries) {
    result = result.replaceAll(RegExp('[${entry.value}]'), entry.key);
  }
  return result.replaceAll(RegExp(r'[\s\-_.,/]+'), ' ').trim();
}

bool matchesVehicleSearch(String query, Iterable<String?> fields) {
  final words = normalizeVehicleSearch(query)
      .split(' ')
      .where((part) => part.isNotEmpty);
  final document = normalizeVehicleSearch(fields.whereType<String>().join(' '))
      .replaceAll(RegExp(r'\b(volkswagen|vw)\b'), 'volkswagen vw');
  return words.every(document.contains);
}

bool matchesVehicleTransmission(String? actual, String selected) {
  if (selected == 'Todas') return true;
  final value = normalizeVehicleSearch(actual ?? '');
  final filter = normalizeVehicleSearch(selected);
  return filter == 'automatico'
      ? value.startsWith('automatico')
      : value == filter;
}

/// Local device history only; never uploaded or attached to an account.
class RecentVehicleSearches {
  static const storageKey = 'automotors.recent-vehicle-searches.v1';
  final Future<SharedPreferences> _preferences;
  Future<void> _pending = Future.value();
  RecentVehicleSearches({Future<SharedPreferences>? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance();

  String _clean(String value) => String.fromCharCodes(
    value.replaceAll(RegExp(r'\s+'), ' ').trim().runes.take(80),
  );

  Future<List<String>> load() async {
    try {
      final values = (await _preferences).getStringList(storageKey) ?? const [];
      final seen = <String>{};
      return values
          .map(_clean)
          .where((v) => v.isNotEmpty && seen.add(normalizeVehicleSearch(v)))
          .take(8)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> remember(String query) {
    final clean = _clean(query);
    _pending = _pending.then((_) async {
      if (clean.isEmpty) return;
      final values = await load();
      final updated = [
        clean,
        ...values.where(
          (v) => normalizeVehicleSearch(v) != normalizeVehicleSearch(clean),
        ),
      ].take(8).toList();
      try {
        await (await _preferences).setStringList(storageKey, updated);
      } catch (_) {
        /* Search works without local persistence. */
      }
    });
    return _pending;
  }

  Future<void> clear() {
    _pending = _pending.then((_) async {
      try {
        await (await _preferences).remove(storageKey);
      } catch (_) {
        /* Best effort on unavailable device storage. */
      }
    });
    return _pending;
  }
}
