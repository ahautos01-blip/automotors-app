import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/design/market_details.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/design/market_vehicle_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets(
      'editorial listing preserves price, state and actions at $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var opens = 0;
        var saves = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: automotorsMarketTheme(),
            locale: const Locale('es'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    MarketEditorialCarRow(
                      title: 'Mercedes-Benz Clase E',
                      version: '220 d AMG Line Automático',
                      price: '199.990 €',
                      details: '2023 · 120.000 km · Diésel',
                      status: const Text('Reservado'),
                      favorite: IconButton(
                        tooltip: 'Guardar',
                        onPressed: () => saves++,
                        icon: const Icon(Icons.favorite_border),
                      ),
                      onTap: () => opens++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('199.990 €'), findsOneWidget);
        expect(find.text('Reservado'), findsOneWidget);
        await tester.tap(find.byTooltip('Guardar'));
        expect(saves, 1);
        expect(opens, 0);
        await tester.tap(find.text('Mercedes-Benz Clase E'));
        expect(opens, 1);
      },
    );
  }

  testWidgets(
    'technical disclosure preserves values when reopened with enlarged text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: automotorsMarketTheme(),
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: ListView(
                children: [
                  MarketDetailSection(
                    sectionKey: Key('specs'),
                    title: 'Ficha técnica',
                    icon: Icons.tune,
                    children: [
                      Text('VIN: WBA12345678901234'),
                      Text('Transmisión: Automático'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('VIN: WBA12345678901234'), findsNothing);
      await tester.tap(find.text('Ficha técnica'));
      await tester.pumpAndSettle();
      expect(find.text('VIN: WBA12345678901234'), findsOneWidget);
      await tester.tap(find.text('Ficha técnica'));
      await tester.pumpAndSettle();
      expect(find.text('VIN: WBA12345678901234'), findsNothing);
      await tester.tap(find.text('Ficha técnica'));
      await tester.pumpAndSettle();
      expect(find.text('Transmisión: Automático'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
