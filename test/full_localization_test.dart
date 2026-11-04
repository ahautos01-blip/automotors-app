import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/l10n/ui_messages.dart';
import 'package:automotors_base/l10n/ui_text.dart';
import 'package:automotors_base/main.dart';
import 'package:automotors_base/services/automotors_locale_controller.dart';
import 'package:automotors_base/vehicle_feature_control.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Widget localized(String code, Widget page) => MaterialApp(
  locale: Locale(code),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: page,
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      httpClient: MockClient(
        (request) async => http.Response(
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

  test('all translations preserve every numbered substitution', () {
    final placeholder = RegExp(r'\{\d+\}');
    Set<String> variables(String value) =>
        placeholder.allMatches(value).map((m) => m[0]!).toSet();
    for (final entry in uiMessages.entries) {
      expect(entry.value, hasLength(2), reason: entry.key);
      for (final translation in entry.value) {
        expect(translation.trim(), isNotEmpty, reason: entry.key);
        expect(variables(translation), variables(entry.key), reason: entry.key);
      }
    }
  });

  test('user values are preserved and substituted only once', () {
    expect(
      translateUiMessage('¿Quieres eliminar «{0}»?', 'en', ['Guardar {1}']),
      'Delete “Guardar {1}”?',
    );
    expect(
      translateUiMessage('Estado: {0}', 'ca', ['Mi texto personal']),
      'Estat: Mi texto personal',
    );
  });

  for (final code in ['es', 'en', 'ca']) {
    String tr(String source) => translateUiMessage(source, code);

    testWidgets('login fields and validation use $code', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(localized(code, const LoginPage()));
      await tester.pumpAndSettle();
      expect(find.text(tr('Correo electrónico')), findsOneWidget);
      expect(find.text(tr('Contraseña')), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, tr('Iniciar sesión')));
      await tester.pumpAndSettle();
      expect(find.text(tr('Introduce un correo válido')), findsOneWidget);
      expect(
        find.text(tr('La contraseña debe tener al menos 6 caracteres')),
        findsOneWidget,
      );
    });

    testWidgets(
      'publication form labels, quality checks and values use $code',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(localized(code, const AddCarPage()));
        await tester.pumpAndSettle();
        expect(find.text(tr('Calidad de tu anuncio')), findsOneWidget);
        expect(find.text(tr('Marca y modelo seleccionados')), findsOneWidget);
        final year = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == tr('Año'),
        );
        await tester.scrollUntilVisible(
          year,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(year, '2015');
        expect(find.text('2015'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets('plans and all benefits use $code', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await AutomotorsLocaleController.instance.select(code);
      await tester.pumpWidget(localized(code, const PublishOptionsPage()));
      await tester.pumpAndSettle();
      final benefit = find.text(tr('Publica hasta 10 vehículos'));
      await tester.scrollUntilVisible(
        benefit,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(benefit, findsOneWidget);
      expect(find.text(tr('Hasta 3 anuncios destacados')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('featured quota uses $code without changing server values', (
      tester,
    ) async {
      await tester.pumpWidget(
        localized(
          code,
          Scaffold(
            body: VehicleFeatureControl(
              manage: (_) async => {'limit': 3, 'used': 2, 'can_feature': true},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          translateUiMessage('Destacados utilizados: {0} de {1}', code, [2, 3]),
        ),
        findsOneWidget,
      );
      expect(find.text(tr('Destacar vehículo')), findsNWidgets(2));
    });
  }

  testWidgets(
    'home language change translates lower sections and preserves search',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await AutomotorsLocaleController.instance.select('es');
      await tester.pumpWidget(const AutomotorsApp());
      await tester.pumpAndSettle();
      final search = find.byType(TextField).first;
      await tester.enterText(search, 'Volkswagen');
      for (final code in ['en', 'ca']) {
        await AutomotorsLocaleController.instance.select(code);
        await tester.pumpAndSettle();
        expect(find.text('Volkswagen'), findsOneWidget);
        final lowerSection = find.text(
          translateUiMessage('¿Tienes un vehículo?', code),
        );
        await tester.scrollUntilVisible(
          lowerSection,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        expect(lowerSection, findsOneWidget);
        expect(find.text('¿Tienes un vehículo?'), findsNothing);

        await tester.drag(find.byType(Scrollable).first, const Offset(0, 2500));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      // Complete Realtime delayed disconnect in the fake clock.
      await tester.pump(const Duration(seconds: 51));
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
    },
  );
}
