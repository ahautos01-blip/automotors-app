import 'dart:convert';

import 'package:automotors_base/main.dart';
import 'package:automotors_base/services/local_market_state.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const owner = '11111111-1111-4111-8111-111111111111';
Widget app(Widget home) => MaterialApp(
  locale: const Locale('es'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: home,
);
Future<void> settle(WidgetTester tester) async {
  // Supabase JSON decoding uses a real isolate, outside the widget clock.
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  late LocalMarketState storage;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': owner, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.fixture';
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object result = [];
        if (request.url.path == '/auth/v1/token')
          result = {
            'access_token': token,
            'refresh_token': 'fixture',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': owner,
              'aud': 'authenticated',
              'role': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            },
          };
        if (request.url.path.endsWith('vehicle_brands'))
          result = [
            {'id': 1, 'name': 'Volkswagen'},
          ];
        if (request.url.path.endsWith('vehicle_models'))
          result = [
            {'id': 2, 'name': 'Golf', 'brand_id': 1},
          ];
        if (request.url.path.endsWith('lookup-vehicle'))
          result = {'allowed': false};
        return http.Response(
          jsonEncode(result),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'fixture',
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(() async {
    await (await SharedPreferences.getInstance()).clear();
  });
  testWidgets('publication resumes account draft after leaving the form', (
    tester,
  ) async {
    storage = LocalMarketState();
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(AddCarPage(localState: storage)));
    await settle(tester);
    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Año',
    );
    await tester.scrollUntilVisible(
      field,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(field, '2021');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byTooltip('Guardar borrador'));
    await settle(tester);
    expect(find.text('Borrador guardado en este dispositivo.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.pumpWidget(app(AddCarPage(localState: storage)));
    await settle(tester);
    expect(
      find.text('Borrador recuperado. Puedes continuar donde lo dejaste.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      field,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<TextField>(field).controller!.text, '2021');
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
  testWidgets('draft requests photos again after a full application restart', (
    tester,
  ) async {
    storage = LocalMarketState();
    await storage.write('automotors.publication-draft.v1.$owner', {
      'fields': {'year': '2020'},
      'photoCount': 3,
    });
    await tester.pumpWidget(app(AddCarPage(localState: storage)));
    await settle(tester);
    expect(
      find.text('Borrador recuperado. Vuelve a seleccionar las fotografías.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
  testWidgets('catalog restores combined criteria and recent ordering', (
    tester,
  ) async {
    storage = LocalMarketState();
    await storage.write('automotors.catalog-filters.v1', {
      'brand': 'Volkswagen',
      'fuel': 'Diésel',
      'max_price': 25000,
      'sort': 'recent',
    });
    final cars = [
      Car(
        brand: 'Volkswagen',
        model: 'Golf',
        year: 2021,
        km: 40000,
        price: 20000,
        fuel: 'Diésel',
        description: '',
        phone: '',
        listedAt: DateTime(2026, 1),
      ),
      Car(
        brand: 'BMW',
        model: '320',
        year: 2023,
        km: 10000,
        price: 40000,
        fuel: 'Gasolina',
        description: '',
        phone: '',
        listedAt: DateTime(2026, 2),
      ),
    ];
    await tester.pumpWidget(
      app(AllVehiclesPage(localState: storage, cars: cars, onOpenCar: (_) {})),
    );
    await settle(tester);
    expect(find.textContaining('Volkswagen Golf'), findsWidgets);
    expect(find.textContaining('BMW 320'), findsNothing);
    expect(find.text('Anuncios más recientes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
