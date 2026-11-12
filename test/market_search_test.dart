import 'package:automotors_base/main.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/services/vehicle_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Car fixture(
  String brand,
  String model,
  double price,
  String fuel,
  String transmission,
  String bodyType,
) => Car(
  brand: brand,
  model: model,
  year: 2021,
  km: 50000,
  price: price,
  fuel: fuel,
  transmission: transmission,
  bodyType: bodyType,
  description: '',
  phone: '',
);
Widget catalog() => MaterialApp(
  theme: automotorsMarketTheme(),
  locale: const Locale('es'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: AllVehiclesPage(
    cars: [
      fixture(
        'Volkswagen',
        'Touran',
        15000,
        'Diésel',
        'Automático (DSG)',
        'SUV',
      ),
      fixture('Renault', 'Zoe', 18000, 'Eléctrico', 'Automático', 'Compacto'),
      fixture('BMW', '320', 35000, 'Gasolina', 'Manual', 'SUV'),
    ],
    onOpenCar: (_) {},
  ),
);
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

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('quick filters combine and reset including DSG', (tester) async {
    await tester.pumpWidget(catalog());
    await tester.pumpAndSettle();
    expect(find.textContaining('3 vehículos'), findsOneWidget);
    for (final entry in [('Automático', 2), ('SUV', 1), ('Eléctrico', 0)]) {
      final chip = find.widgetWithText(FilterChip, entry.$1);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.textContaining('${entry.$2} vehículo'), findsOneWidget);
    }
    await tester.tap(find.byTooltip('Restablecer filtros').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('3 vehículos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'submitted searches return from local history and can be erased',
    (tester) async {
      await tester.pumpWidget(catalog());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'VW automatico');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.textContaining('1 vehículo'), findsOneWidget);
      expect(await RecentVehicleSearches().load(), ['VW automatico']);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Búsquedas recientes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VW automatico'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'VW automatico',
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Búsquedas recientes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar historial'));
      await tester.pumpAndSettle();
      expect(await RecentVehicleSearches().load(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
