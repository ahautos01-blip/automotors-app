import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/design/market_vehicle_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double contrast(Color a, Color b) {
    final values = [a.computeLuminance(), b.computeLuminance()]..sort();
    return (values.last + .05) / (values.first + .05);
  }

  test(
    'approved light palette keeps normal text and gold actions readable',
    () {
      final theme = automotorsMarketTheme();
      expect(theme.brightness, Brightness.light);
      expect(marketHeroChip.a, 1);
      expect(
        contrast(marketSurface, marketHeroChip),
        greaterThanOrEqualTo(4.5),
      );
      expect(contrast(marketInk, marketPaper), greaterThanOrEqualTo(4.5));
      expect(contrast(marketMuted, marketSurface), greaterThanOrEqualTo(4.5));
      expect(contrast(marketAccent, marketSurface), greaterThanOrEqualTo(4.5));
      expect(contrast(marketInk, marketGold), greaterThanOrEqualTo(4.5));
    },
  );

  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'photo card preserves separate favorite, comparison and detail actions at scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var details = 0, favorites = 0, comparisons = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: automotorsMarketTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SizedBox(
                height: 370,
                child: MarketVehicleCard(
                  title: 'Volkswagen Touran R-Line',
                  price: '29.990 €',
                  details: '2021 · 87.954 km · Gasolina',
                  version: 'Automático',
                  favorite: IconButton(
                    tooltip: 'Favorite',
                    onPressed: () => favorites++,
                    icon: const Icon(Icons.favorite_border),
                  ),
                  comparison: IconButton(
                    tooltip: 'Compare',
                    onPressed: () => comparisons++,
                    icon: const Icon(Icons.compare),
                  ),
                  onTap: () => details++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Favorite'));
        await tester.tap(find.byTooltip('Compare'));
        expect(favorites, 1);
        expect(comparisons, 1);
        expect(details, 0);
        await tester.tap(find.text('29.990 €'));
        expect(details, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
