import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/main.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      httpClient: MockClient(
        (_) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  for (final status in ['published', 'reserved', 'sold']) {
    testWidgets('contact stays accessible after scrolling a $status car', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var contacts = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: automotorsMarketTheme(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: CarDetailsPage(
            car: Car(
              brand: 'BMW',
              model: '320',
              year: 2020,
              km: 50000,
              price: 20000,
              fuel: 'Diesel',
              description: 'Vehicle description',
              phone: '34600123456',
              status: status,
            ),
            priceText: '20.000 EUR',
            onContact: () => contacts++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = find.byKey(const Key('vehicle-contact-bar'));
      final action = find.descendant(
        of: bar,
        matching: find.byType(FilledButton),
      );
      expect(action.hitTestable(), findsOneWidget);
      final initial = tester.getRect(bar);
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.getRect(bar), initial);
      final button = tester.widget<FilledButton>(action);
      if (status == 'sold') {
        expect(button.onPressed, isNull);
        expect(
          find.descendant(of: bar, matching: find.byType(OutlinedButton)),
          findsNothing,
        );
      } else {
        await tester.tap(action);
        expect(contacts, 1);
        expect(
          find
              .descendant(of: bar, matching: find.byType(OutlinedButton))
              .hitTestable(),
          findsOneWidget,
        );
      }
      // Framework reports layout errors at the end of each test.
    });
  }

  for (final code in ['es', 'en', 'ca']) {
    testWidgets('filters fit a small screen and retain search in $code', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final strings = lookupAppLocalizations(Locale(code));
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          theme: automotorsMarketTheme(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: AllVehiclesPage(cars: const [], onOpenCar: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Porsche');
      await tester.tap(find.text(strings.filters));
      await tester.pumpAndSettle();
      final apply = find.byKey(const Key('apply-catalog-filters'));
      expect(apply.hitTestable(), findsOneWidget);
      final position = tester.getRect(apply);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(apply), position);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(find.text('Porsche'), findsOneWidget);
      expect(find.text(strings.noVehiclesFound), findsOneWidget);
    });
  }

  testWidgets(
    'optional publication details preserve entered values when collapsed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          theme: automotorsMarketTheme(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AddCarPage(),
        ),
      );
      await tester.pumpAndSettle();
      final section = find.byKey(const Key('optional-vehicle-specifications'));
      await tester.scrollUntilVisible(
        section,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Ficha técnica ampliada'));
      await tester.pumpAndSettle();
      final versionLabel = find.text('Versión / acabado (opcional)');
      await tester.scrollUntilVisible(
        versionLabel,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      final field = find.ancestor(
        of: versionLabel,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(field, 'Sport');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ficha técnica ampliada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ficha técnica ampliada'));
      await tester.pumpAndSettle();
      expect(find.text('Sport'), findsNothing);
      await tester.tap(find.text('Ficha técnica ampliada'));
      await tester.pumpAndSettle();
      expect(find.text('Sport'), findsOneWidget);
    },
  );
}
