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
  for(final scale in [1.0,2.0]){
    testWidgets('secondary listing keeps photo, price and independent actions at narrow width scale $scale',(t)async{
      await t.binding.setSurfaceSize(const Size(320,568));addTearDown(()=>t.binding.setSurfaceSize(null));
      var opened=0,saved=0;
      await t.pumpWidget(MaterialApp(theme:automotorsMarketTheme(),builder:(c,w)=>MediaQuery(data:MediaQuery.of(c).copyWith(textScaler:TextScaler.linear(scale)),child:w!),home:Scaffold(body:ListView(children:[
        MarketEditorialCarRow(title:'Volkswagen Touran',price:'29.990 €',details:'2021 · 87.954 km · Gasolina',favorite:IconButton(tooltip:'Save fixture',onPressed:()=>saved++,icon:const Icon(Icons.favorite_border)),onTap:()=>opened++),
      ]))));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Save fixture'));expect(saved,1);expect(opened,0);
      await t.ensureVisible(find.text('29.990 €'));await t.tap(find.text('29.990 €'));expect(opened,1);
      expect(t.takeException(),isNull);
    });
  }
}
