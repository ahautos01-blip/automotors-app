import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:automotors_base/design/market_editorial.dart';
import 'package:automotors_base/design/market_plans_highlight.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/l10n/app_localizations.dart';

void main() {
  for (final locale in ['es', 'en', 'ca']) {
    testWidgets(
      'editorial hierarchy and plan access remain readable at 200% in $locale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var opened = false;
        var selected = -1;
        await tester.pumpWidget(
          MaterialApp(
            theme: automotorsMarketTheme(),
            locale: Locale(locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        const MarketEditorialIntro(
                          eyebrow: 'COMPRA CON CRITERIO',
                          title: 'Tu próximo coche,\nmás cerca.',
                          subtitle:
                              'Encuentra. Compara. Habla con el vendedor.',
                        ),
                        MarketPlansHighlight(onOpen: () => opened = true),
                        MarketPublicationSteps(
                          current: 0,
                          onSelect: (i) => selected = i,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const Key('home-plans-highlight')),
        );
        await tester.tap(find.byKey(const Key('home-plans-highlight')));
        expect(opened, true);
        final chip = find.byKey(const ValueKey('publication-step-2'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        expect(selected, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
