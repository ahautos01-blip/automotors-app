import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'dart:convert';

import 'package:automotors_base/main.dart';
import 'package:automotors_base/design/market_watchlists.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const uid = '11111111-1111-4111-8111-111111111111';
const listing = '22222222-2222-4222-8222-222222222222';
Widget app(Widget page, {double scale = 1, String lang = 'es'}) => MaterialApp(
  theme: automotorsMarketTheme(),
  locale: Locale(lang),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (c, w) => MediaQuery(
    data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
    child: w!,
  ),
  home: RepaintBoundary(key: const ValueKey('watch-proof'), child: page),
);
void main() {
  final patches = <http.Request>[];
  bool fail = false;
  bool missing = false;
  final raw = <String, dynamic>{
    'id': listing,
    'status': 'published',
    'price': 18000,
    'year': 2021,
    'km': 40000,
    'fuel': 'Diésel',
    'vehicle_brands': {'name': 'Volkswagen'},
    'vehicle_models': {'name': 'Touran'},
    'vehicle_photos': [],
  };
  setUpAll(() async {
    final fontDir = Platform.environment['AUTOMOTORS_VISUAL_FONT_DIR'];
    if (fontDir != null) {
      for (final font in {
        'Roboto': 'roboto-regular.ttf',
        'MaterialIcons': 'materialicons-regular.otf',
      }.entries) {
        final loader = FontLoader(font.key)
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File('$fontDir/${font.value}').readAsBytes(),
              ),
            ),
          );
        await loader.load();
      }
    }
    SharedPreferences.setMockInitialValues({});
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': uid, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.fixture';
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        final headers = {'content-type': 'application/json'};
        if (r.url.path == '/auth/v1/token') {
          return http.Response(
            jsonEncode({
              'access_token': token,
              'refresh_token': 'fixture',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': uid,
                'aud': 'authenticated',
                'role': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
            200,
            headers: headers,
            request: r,
          );
        }
        if (r.method == 'PATCH') {
          patches.add(r);
          if (fail) {
            return http.Response(
              '{"message":"offline","code":"fixture"}',
              503,
              headers: headers,
              request: r,
            );
          }
          if (r.url.path.endsWith('saved_vehicles')) {
            return http.Response(
              jsonEncode({
                'reference_price': 20000,
                ...jsonDecode(r.body) as Map,
              }),
              200,
              headers: headers,
              request: r,
            );
          }
          if (r.url.path.endsWith('saved_vehicle_searches')) {
            return http.Response(
              jsonEncode({
                'notify_new_listings': false,
                'notify_price_drops': true,
              }),
              200,
              headers: headers,
              request: r,
            );
          }
          return http.Response('[]', 200, headers: headers, request: r);
        }
        Object rows = [];
        if (r.url.path.endsWith('saved_vehicles')) {
          rows = [
            {
              'listing_id': listing,
              'reference_price': 20000,
              'notify_price_drops': false,
            },
          ];
        }
        if (r.url.path.endsWith('saved_vehicle_searches')) {
          rows = [
            {
              'id': listing,
              'name': 'Mi Touran',
              'criteria': {'brand': 'Volkswagen'},
              'notify_new_listings': true,
              'notify_price_drops': true,
            },
          ];
        }
        if (r.url.path.endsWith('vehicle_listings')) {
          rows = missing ? [] : [raw];
        }
        if (r.url.path.endsWith('vehicle_search_alerts')) {
          rows = [
            {
              'id': listing,
              'listing_id': listing,
              'alert_type': 'price_drop',
              'title': 'Bajada de precio',
              'message': 'Touran',
              'previous_price': 20000,
              'current_price': 19000,
              'read_at': null,
            },
          ];
        }
        return http.Response(
          jsonEncode(rows),
          200,
          headers: headers,
          request: r,
        );
      }),
    );
    await Supabase.instance.client.auth.setSession('fixture');
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(() {
    patches.clear();
    fail = false;
    missing = false;
  });
  for (final lang in ['es', 'en', 'ca']) {
    testWidgets('favorite card fits small phone and scaled text in $lang', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        app(
          Scaffold(
            body: ListView(
              children: [
                MarketFavoriteCard(
                  title: 'Volkswagen Touran R-Line',
                  details: '2021 · 40.000 km · Diésel',
                  price: 18000,
                  referencePrice: 20000,
                  watching: false,
                  onOpen: () {},
                  onRemove: () {},
                  onWatch: (_) {},
                ),
              ],
            ),
          ),
          scale: 1.5,
          lang: lang,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('18.000 €'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'favorites load current server price and persist only opt-in field',
    (t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => t.binding.setSurfaceSize(null));
      Car? opened;
      await t.pumpWidget(
        app(SavedVehiclesPage(cars: const [], onOpenCar: (c) => opened = c)),
      );
      await t.pumpAndSettle();
      expect(find.text('18.000 €'), findsOneWidget);
      expect(find.text('Ha bajado 2.000 €'), findsOneWidget);
      final proof = Platform.environment['AUTOMOTORS_VISUAL_PROOF'];
      if (proof != null) {
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('watch-proof')),
        );
        await t.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(proof).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await t.tap(find.text('Avisarme si baja'));
      await t.pumpAndSettle();
      expect(jsonDecode(patches.single.body), {'notify_price_drops': true});
      expect(patches.single.url.queryParameters['user_id'], 'eq.$uid');
      await t.tap(find.text('Volkswagen Touran'));
      await t.pumpAndSettle();
      expect(opened?.price, 18000);
    },
  );
  testWidgets('failed preference update retains the confirmed switch value', (
    t,
  ) async {
    await t.pumpWidget(
      app(SavedVehiclesPage(cars: const [], onOpenCar: (_) {})),
    );
    await t.pumpAndSettle();
    fail = true;
    await t.tap(find.text('Avisarme si baja'));
    await t.pumpAndSettle();
    expect(t.widget<SwitchListTile>(find.byType(SwitchListTile)).value, false);
    expect(
      find.text('No se pudo actualizar favoritos. Inténtalo de nuevo.'),
      findsOneWidget,
    );
  });
  testWidgets('saved search preferences are scoped to user and search', (
    t,
  ) async {
    await t.pumpWidget(app(SavedSearchesPage(onApply: (_) {})));
    await t.pumpAndSettle();
    await t.tap(find.text('Anuncios nuevos'));
    await t.pumpAndSettle();
    expect(jsonDecode(patches.single.body), {'notify_new_listings': false});
    expect(patches.single.url.queryParameters['user_id'], 'eq.$uid');
    expect(patches.single.url.queryParameters['id'], 'eq.$listing');
    expect(
      t.widgetList<SwitchListTile>(find.byType(SwitchListTile)).first.value,
      false,
    );
  });
  testWidgets('price alert opens fresh car and writes only read_at', (t) async {
    Car? selected;
    await t.pumpWidget(
      app(VehicleSearchAlertsPage(onOpenCar: (c) => selected = c)),
    );
    await t.pumpAndSettle();
    expect(find.text('20.000 € → 19.000 €'), findsOneWidget);
    await t.tap(find.text('Bajada de precio'));
    await t.pumpAndSettle();
    expect(selected?.price, 18000);
    expect(jsonDecode(patches.single.body).keys, ['read_at']);
  });
  testWidgets(
    'removed listing alert fails gracefully instead of opening stale car',
    (t) async {
      missing = true;
      Car? selected;
      await t.pumpWidget(
        app(VehicleSearchAlertsPage(onOpenCar: (c) => selected = c)),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Bajada de precio'));
      await t.pumpAndSettle();
      expect(selected, isNull);
      expect(find.text('Este aviso ya no está disponible.'), findsOneWidget);
    },
  );
}
