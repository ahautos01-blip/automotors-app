import 'dart:convert';

import 'package:automotors_base/main.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/l10n/ui_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final submissions = <Map<String, dynamic>>[];
  const userId = '11111111-1111-4111-8111-111111111111';
  const listingId = '22222222-2222-4222-8222-222222222222';
  final token =
      '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': userId, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.fixture';
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            jsonEncode({
              'access_token': token,
              'refresh_token': 'fixture-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': userId,
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 'tester@example.test',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/rest/v1/vehicle_listing_reports' &&
            request.method == 'POST') {
          submissions.add(Map<String, dynamic>.from(jsonDecode(request.body)));
          return http.Response('', 201);
        }
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
    await Supabase.instance.client.auth.setSession('fixture-refresh');
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(submissions.clear);
  Widget page(String locale) => MaterialApp(
    locale: Locale(locale),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: CarDetailsPage(
      car: const Car(
        brand: 'VW',
        model: 'Golf',
        year: 2020,
        km: 10000,
        price: 20000,
        fuel: 'Diésel',
        description: '',
        phone: '',
        listingId: listingId,
      ),
      priceText: '20.000 €',
      onContact: () {},
    ),
  );
  for (final locale in ['es', 'en', 'ca']) {
    testWidgets(
      'visible listing report, all reasons and explicit submission in $locale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(page(locale));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('report-listing-action')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('report-listing-button')),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(
          find.byKey(const Key('report-listing-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('report-listing-button')));
        await tester.pumpAndSettle();
        for (final reason in [
          'Información falsa',
          'Precio sospechoso',
          'Anuncio duplicado',
          'Posible fraude',
          'Contenido inapropiado',
          'Otro',
        ]) {
          expect(find.text(translateUiMessage(reason, locale)), findsOneWidget);
        }
        final reason = find.text(translateUiMessage('Posible fraude', locale));
        await tester.ensureVisible(reason);
        await tester.tap(reason);
        await tester.pumpAndSettle();
        expect(submissions, isEmpty);
        await tester.enterText(
          find.byType(TextField),
          '  Información de prueba  ',
        );
        await tester.tap(
          find.text(translateUiMessage('Enviar reporte', locale)),
        );
        await tester.pumpAndSettle();
        expect(submissions, [
          {
            'reporter_id': userId,
            'listing_id': listingId,
            'reason': 'Posible fraude',
            'details': 'Información de prueba',
          },
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('cancelling either report step sends nothing', (tester) async {
    await tester.pumpWidget(page('es'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-listing-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(submissions, isEmpty);
    await tester.tap(find.byKey(const Key('report-listing-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(submissions, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
