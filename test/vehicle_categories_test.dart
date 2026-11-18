import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:automotors_base/main.dart';
import 'package:automotors_base/services/vehicle_category.dart';
import 'package:automotors_base/design/vehicle_categories.dart';
import 'package:automotors_base/design/market_facts.dart';

void main() {
  test('legacy listings remain cars and keep their catalog names', () {
    final car = Car.fromListing({
      'vehicle_brands': {'name': 'VW'},
      'vehicle_models': {'name': 'Golf'},
      'km': 120000,
    });
    expect(car.category, VehicleCategory.car);
    expect(car.brand, 'VW');
    expect(car.usageLabel, '120000 km');
  });
  test('boats use declared names and engine hours, never mileage', () {
    final boat = Car.fromListing({
      'vehicle_category': 'boat',
      'declared_brand': 'Beneteau',
      'declared_model': 'Oceanis',
      'category_details': {'length_m': 12.5, 'engine_hours': 420},
    });
    expect(boat.brand, 'Beneteau');
    expect(boat.model, 'Oceanis');
    expect(boat.usageLabel, '420 h de motor');
    expect(boat.summary, isNot(contains('km')));
  });
  test(
    'category fields validate decimals, bounds and unknown measurements',
    () {
      expect(VehicleCategory.boat.validate('length_m', '12,5'), isNull);
      expect(VehicleCategory.truck.validate('axles', '2.5'), isNotNull);
      expect(
        VehicleCategory.motorcycle.validate('engine_cc', 'NaN'),
        isNotNull,
      );
      expect(VehicleCategory.boat.validate('length_m', '201'), isNotNull);
      expect(VehicleCategory.boat.validate('engine_cc', '800'), isNotNull);
      expect(
        VehicleCategory.boat.details({'length_m': '12,5', 'engine_cc': '800'}),
        {'length_m': 12.5},
      );
    },
  );
  test('specific filters exclude absent facts and respect both bounds', () {
    final c = VehicleCategory.truck;
    expect(
      c.matches(
        {'min_payload_kg': 2000, 'max_payload_kg': 5000},
        {'payload_kg': 3000},
      ),
      isTrue,
    );
    expect(c.matches({'min_payload_kg': 2000}, {}), isFalse);
    expect(c.matches({'max_payload_kg': 2000}, {'payload_kg': 3000}), isFalse);
  });
  testWidgets('category choice exposes four distinct destinations', (
    tester,
  ) async {
    VehicleCategory? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleCategoryPicker(
            value: VehicleCategory.car,
            onChanged: (c) => selected = c,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('category-motorcycle')));
    expect(selected, VehicleCategory.motorcycle);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-boat')));
    expect(selected, VehicleCategory.boat);
  });
  testWidgets('boat facts omit ITV and automotive inspection copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarketFactsView(
              roadInspection: false,
              facts: {'itv': 'valid', 'itv_until': '2027-01-01'},
            ),
          ),
        ),
      ),
    );
    expect(find.text('ITV'), findsNothing);
    expect(find.text('Caducidad ITV'), findsNothing);
  });
}
