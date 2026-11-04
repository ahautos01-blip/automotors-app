import 'package:automotors_base/services/vehicle_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('search handles accents, word order and Volkswagen abbreviations', () {
    expect(
      matchesVehicleSearch('automatico touran VW', [
        'Volkswagen',
        'Touran',
        'Automático (DSG)',
      ]),
      isTrue,
    );
    expect(matchesVehicleSearch('VOLKSWAGEN diesel', ['VW', 'Diésel']), isTrue);
    expect(
      matchesVehicleSearch('touran electrico', [
        'Volkswagen',
        'Touran',
        'Diésel',
      ]),
      isFalse,
    );
    expect(matchesVehicleSearch('automatico', [null, 'Manual']), isFalse);
  });
  test(
    'automatic filter includes DSG but does not assume missing transmissions',
    () {
      expect(
        matchesVehicleTransmission('Automático (DSG)', 'Automático'),
        isTrue,
      );
      expect(matchesVehicleTransmission('Manual', 'Automático'), isFalse);
      expect(matchesVehicleTransmission(null, 'Automático'), isFalse);
      expect(matchesVehicleTransmission(null, 'Todas'), isTrue);
    },
  );
  test(
    'history is bounded, deduplicated and ordered by deliberate searches',
    () async {
      final store = RecentVehicleSearches();
      for (var i = 0; i < 10; i++) {
        await store.remember('Modelo $i');
      }
      expect(await store.load(), [
        'Modelo 9',
        'Modelo 8',
        'Modelo 7',
        'Modelo 6',
        'Modelo 5',
        'Modelo 4',
        'Modelo 3',
        'Modelo 2',
      ]);
      await store.remember('  modelo   5  ');
      final history = await store.load();
      expect(history.first, 'modelo 5');
      expect(
        history.where((v) => normalizeVehicleSearch(v) == 'modelo 5').length,
        1,
      );
      await store.remember('   ');
      expect(await store.load(), history);
      await store.clear();
      expect(await store.load(), isEmpty);
    },
  );
  test('overlapping history writes do not lose a submitted search', () async {
    final store = RecentVehicleSearches();
    await Future.wait([store.remember('BMW'), store.remember('Audi')]);
    expect(await store.load(), ['Audi', 'BMW']);
  });
  test(
    'corrupt device history cannot block searching and can be replaced',
    () async {
      SharedPreferences.setMockInitialValues({
        RecentVehicleSearches.storageKey: 12,
      });
      final store = RecentVehicleSearches();
      expect(await store.load(), isEmpty);
      await store.remember('Mercedes');
      expect(await store.load(), ['Mercedes']);
    },
  );
}
