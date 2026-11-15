import 'dart:convert';

import 'package:automotors_base/design/market_facts.dart';
import 'package:automotors_base/design/market_usage.dart';
import 'package:automotors_base/design/seller_dashboard.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/services/market_facts.dart';
import 'package:automotors_base/services/market_usage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  locale: const Locale('es'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);
void main() {
  test('radius uses municipality centers, handles western longitudes and excludes missing data', () {
    const madrid = MarketLocality('28079', 'Madrid', 40.42, -3.7);
    const mataro = MarketLocality('08121', 'Mataró', 41.55, 2.45);
    expect(madrid.distanceTo(mataro), inInclusiveRange(520, 540));
    final criteria = {'locality': madrid.toJson(), 'radius_km': 25};
    expect(matchesMarketRadius(criteria, {'locality': madrid.toJson()}), true);
    expect(matchesMarketRadius(criteria, {'locality': mataro.toJson()}), false);
    expect(matchesMarketRadius(criteria, {}), false);
    expect(matchesMarketRadius({}, {}), true);
    expect(matchesMarketRadius({'locality': {}}, {}), false);
    expect(
      MarketLocality.fromJson({
        'id': 'x',
        'label': 'Madrid',
        'lat': 40.123456,
        'lon': -3.712345,
      })!.toJson()['lat'],
      40.12,
    );
  });
  test('official geocoder handles actual Municipio casing, caches names and resolves the chosen ID only', () async {
    final requests = <Uri>[];
    final service = MunicipalitySearch(
      MockClient((request) async {
        requests.add(request.url);
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('candidates')
                ? [
                    {
                      'id': '8121',
                      'type': 'Municipio',
                      'address': 'Mataró, Barcelona',
                    },
                    {
                      'id': 'street',
                      'type': 'portal',
                      'address': 'Private street',
                    },
                  ]
                : {
                    'id': '8121',
                    'type': 'Municipio',
                    'lat': 41.55417878837446,
                    'lng': 2.4466628496648704,
                  },
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final rows = await service.candidates('Mataró');
    expect(rows.length, 1);
    await service.candidates('mataró');
    expect(requests.length, 1);
    final selected = await service.resolve(rows.single);
    expect(selected.lat, 41.55);
    expect(selected.lon, 2.45);
    expect(requests.last.queryParameters['id'], '8121');
    expect(requests.last.queryParameters.containsKey('q'), false);
    expect(
      requests.every((u) => !u.queryParameters.containsKey('user_id')),
      true,
    );
    await expectLater(
      service.candidates('Calle Mayor 12'),
      throwsFormatException,
    );
    await expectLater(
      service.resolve({'type': 'portal'}),
      throwsFormatException,
    );
  });
  test('usage is off until explicitly enabled and can be disabled', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await MarketUsage.enabled(), false);
    await MarketUsage.setEnabled(true);
    expect(await MarketUsage.enabled(), true);
    await MarketUsage.setEnabled(false);
    expect(await MarketUsage.enabled(), false);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'facts distinguish absent data and preserve buyer details at text scale $scale',
      (t) async {
        await t.binding.setSurfaceSize(const Size(320, 850));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(
          app(
            const MarketFactsView(
              facts: {
                'maintenance': 'documented',
                'itv': 'expired',
                'defects': 'Arañazo en la puerta',
              },
            ),
            scale: scale,
          ),
        );
        expect(
          find.text('Historial de mantenimiento disponible'),
          findsOneWidget,
        );
        expect(find.text('ITV caducada'), findsOneWidget);
        expect(find.text('Arañazo en la puerta'), findsOneWidget);
        expect(find.text('No informado'), findsNWidgets(3));
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      'seller dashboard uses real totals and unavailable is not zero at scale $scale',
      (t) async {
        await t.binding.setSurfaceSize(const Size(320, 850));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(
          app(
            SellerDashboard(
              listings: const [
                {
                  'metrics': {'views': 12, 'favorites': 3, 'conversations': 2},
                },
              ],
              offers: null,
              onInbox: () {},
            ),
            scale: scale,
          ),
        );
        expect(find.text('12'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('—'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'ITV invalid dates cannot be submitted and fact edits are retained',
    (t) async {
      final form = GlobalKey<FormState>();
      Map<String, dynamic> value = {};
      await t.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, setState) => Form(
              key: form,
              child: MarketFactsForm(
                value: value,
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Estado, garantía y localidad'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, '2026-02-30');
      expect(form.currentState!.validate(), false);
      await t.enterText(find.byType(TextFormField).first, '2027-02-28');
      expect(form.currentState!.validate(), true);
      expect(value['itv_until'], '2027-02-28');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('optional usage switch defaults to off', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(app(const MarketUsagePreference()));
    await t.pumpAndSettle();
    expect(t.widget<SwitchListTile>(find.byType(SwitchListTile)).value, false);
  });
}
