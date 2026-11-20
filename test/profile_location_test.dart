import 'package:flutter_test/flutter_test.dart';

import '../lib/services/market_facts.dart';

void main() {
  test('profile location replaces stale independent listing coordinates', () {
    final facts = listingMarketFacts({
      'market_facts': {
        'maintenance': 'documented',
        'locality': {'id': 'old', 'label': 'Madrid', 'lat': 40.42, 'lon': -3.7},
      },
      'seller_location': {'city': 'Mataró', 'province': 'Barcelona'},
    });
    expect(facts.containsKey('locality'), false);
    expect(facts['maintenance'], 'documented');
    expect(marketLocationLabel(facts), 'Mataró, Barcelona');
    expect(
      matchesMarketRadius({
        'locality': {'id': 'old', 'label': 'Madrid', 'lat': 40.42, 'lon': -3.7},
        'radius_km': 50,
      }, facts),
      false,
    );
  });
  test('profile municipality coordinates support radius searches', () {
    final locality = {
      'id': 'mataro',
      'label': 'Mataró',
      'lat': 41.54,
      'lon': 2.44,
    };
    final facts = listingMarketFacts({
      'seller_location': {
        'city': 'Mataró',
        'province': 'Barcelona',
        'locality': locality,
      },
    });
    expect(
      matchesMarketRadius({'locality': locality, 'radius_km': 10}, facts),
      true,
    );
  });
}
