import 'package:automotors_base/main.dart';
import 'package:automotors_base/design/market_comparison.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Car car({
  double price = 20000,
  List<String> equipment = const ['Navegador', 'Climatizador bizona'],
}) => Car(
  brand: 'Volkswagen',
  model: 'Touran',
  year: 2021,
  km: 50000,
  price: price,
  fuel: 'Gasolina',
  description: '',
  phone: '',
  transmission: 'Automático',
  equipment: equipment,
);

Widget app(List<Car> cars, {double scale = 1, ValueChanged<Car>? onOpen}) =>
    MaterialApp(
      theme: automotorsMarketTheme(),
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: VehicleComparisonPage(cars: cars, onOpenCar: onOpen),
    );

void main() {
  test(
    'missing values are equal; differences compare normalized published text',
    () {
      expect(
        const MarketComparisonField('Cambio', [
          'Automático',
          ' automatico ',
        ]).differs,
        isFalse,
      );
      expect(
        const MarketComparisonField('Cambio', [null, null]).differs,
        isFalse,
      );
      expect(
        const MarketComparisonField('Cambio', ['Manual', null]).differs,
        isTrue,
      );
    },
  );
  for (final count in [2, 3]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        '$count comparison headers fit a small phone at text scale $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 568));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final cars = List.generate(
            count,
            (i) => car(price: 20000 + i * 1000),
          );
          await tester.pumpWidget(app(cars, scale: scale));
          await tester.pumpAndSettle();
          expect(find.text('Comparar vehículos'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('opening a comparison header returns its original car', (
    tester,
  ) async {
    final cars = [car(), car(price: 15000)];
    Car? selected;
    await tester.pumpWidget(app(cars, onOpen: (value) => selected = value));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('comparison-car-1')));
    expect(identical(selected, cars[1]), isTrue);
  });
  testWidgets('equipment ordering does not create a false difference', (
    tester,
  ) async {
    await tester.pumpWidget(
      app([
        car(),
        car(equipment: const ['Climatizador bizona', 'Navegador']),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('comparison-differences-toggle')));
    await tester.pumpAndSettle();
    expect(
      find.text('No hay diferencias en los datos publicados.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'differences-only removes identical fields and retains changed prices',
    (tester) async {
      await tester.pumpWidget(app([car(), car(price: 15000)]));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('comparison-differences-toggle')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('comparison-field-Precio')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('comparison-field-Modelo')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('comparison-field-Cambio')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'unlisted equipment stays unknown rather than being declared absent',
    (tester) async {
      await tester.pumpWidget(
        app([
          car(equipment: const ['Navegador']),
          car(equipment: const []),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('comparison-differences-toggle')));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('comparison-field-Navegador'));
      await tester.scrollUntilVisible(
        field,
        200,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        find.descendant(of: field, matching: find.text('Anunciado')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: field, matching: find.text('No indicado')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
