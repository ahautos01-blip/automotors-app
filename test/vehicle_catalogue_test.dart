import 'dart:convert';
import 'dart:typed_data';

import 'package:automotors_base/services/vehicle_catalogue.dart';
import 'package:automotors_base/services/vehicle_category.dart';
import 'package:automotors_base/design/catalogue_dropdown.dart';
import 'package:automotors_base/design/vehicle_categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReferenceBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'car': {
            'KGM': ['Torres'],
            'Volkswagen': ['Golf', 'Polo'],
          },
          'motorcycle': {
            'BMW': ['R 1300 GS'],
            'Honda': ['PCX 125'],
          },
          'truck': {
            'Scania': ['R'],
          },
          'boat': {
            'Beneteau': ['Oceanis 40.1'],
          },
        }),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('car makes and models load beyond the first 1000 rows and preserve real IDs', () async {
    final offsets = <String, List<int>>{};
    final client = SupabaseClient(
      'https://example.supabase.co',
      'fixture',
      httpClient: MockClient((r) async {
        final table = r.url.pathSegments.last;
        final offset = int.parse(r.url.queryParameters['offset'] ?? '0');
        (offsets[table] ??= []).add(offset);
        final rows = List.generate(
          1203,
          (i) => {
            'id': i + 1,
            'name': 'Item ${i.toString().padLeft(4, '0')}',
            if (table == 'vehicle_models') 'brand_id': 1,
          },
        );
        return http.Response(
          jsonEncode(rows.skip(offset).take(500).toList()),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    final service = VehicleCatalogue(client: client, bundle: ReferenceBundle());
    final makes = await service.brands(VehicleCategory.car);
    expect(
      service.serverUnavailable,
      isFalse,
      reason: '${service.serverError}',
    );
    final models = await service.models(VehicleCategory.car, 1, 'Volkswagen');
    expect(offsets['vehicle_brands'], [0, 500, 1000]);
    expect(offsets['vehicle_models'], [0, 500, 1000]);
    expect(makes.any((r) => r['id'] == 1203), isTrue);
    expect(models.any((r) => r['id'] == 1203), isTrue);
    expect(makes.any((r) => r['name'] == 'KGM'), isTrue);
    expect(models.any((r) => r['name'] == 'Golf'), isTrue);
    await client.dispose();
  });
  test(
    'categories stay isolated and work from the bundled catalogue',
    () async {
      final service = VehicleCatalogue(bundle: ReferenceBundle());
      final makes = await service.brands(VehicleCategory.motorcycle);
      expect(makes.map((r) => r['name']), contains('BMW'));
      expect(makes.map((r) => r['name']), isNot(contains('Beneteau')));
      final bmw = makes.firstWhere((r) => r['name'] == 'BMW');
      expect(
        (await service.models(
          VehicleCategory.motorcycle,
          bmw['id'] as int,
          'BMW',
        )).map((r) => r['name']),
        ['R 1300 GS'],
      );
    },
  );
  test(
    'local IDs never become database foreign keys, including custom cars',
    () {
      final known = catalogueListingIdentity(
        category: VehicleCategory.car,
        brandId: 1,
        modelId: 2,
        brand: 'VW',
        model: 'Golf',
      );
      expect(known['brand_id'], 1);
      expect(known['declared_brand'], isNull);
      final custom = catalogueListingIdentity(
        category: VehicleCategory.car,
        brandId: 1,
        modelId: -2,
        brand: 'VW',
        model: 'Historic model',
      );
      expect(custom['brand_id'], isNull);
      expect(custom['model_id'], isNull);
      expect(custom['declared_model'], 'Historic model');
      expect(
        () => catalogueListingIdentity(
          category: VehicleCategory.car,
          brandId: 0,
          modelId: 0,
          brand: ' ',
          model: 'X',
        ),
        throwsArgumentError,
      );
    },
  );
  testWidgets(
    'searchable dropdown finds a model and closes without disposing a live controller',
    (t) async {
      int? selected;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogueDropdown(
              label: 'Modelo',
              hint: 'Selecciona',
              otherLabel: 'Otro modelo',
              value: null,
              options: const [
                {'id': 1, 'name': 'R 1300 GS'},
                {'id': 2, 'name': 'PCX 125'},
              ],
              onChanged: (v) => selected = v,
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('catalogue-Modelo')));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '1300');
      await t.pumpAndSettle();
      expect(find.text('PCX 125'), findsNothing);
      await t.tap(find.text('R 1300 GS'));
      await t.pumpAndSettle();
      expect(selected, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('all four category buttons remain visible on a narrow screen', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(320, 650));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleCategoryPicker(
            value: VehicleCategory.car,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    for (final c in VehicleCategory.values) {
      final f = find.byKey(ValueKey('category-${c.id}'));
      expect(f.hitTestable(), findsOneWidget);
      expect(t.getSize(f).height, greaterThanOrEqualTo(80));
    }
    expect(t.takeException(), isNull);
  });
}
