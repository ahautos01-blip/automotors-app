import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/services/device_location.dart';
import '../lib/services/market_facts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'location requires consent and returns only an approximate search origin',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      var calls = 0;
      MarketLocality? selected;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        DeviceLocation.channel,
        (call) async {
          calls++;
          return {'status': 'ok', 'lat': 41.5378, 'lon': 2.4445};
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          DeviceLocation.channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await DeviceLocation.request(context);
                },
                child: const Text('Ubicación'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(selected, isNull);
      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(selected!.lat, 41.54);
      expect(selected!.lon, 2.44);
      expect(selected!.label, 'Mi ubicación aproximada');
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
