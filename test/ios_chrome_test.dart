import 'package:automotors_base/design/market_chrome.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared chrome preserves back navigation and reachable actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: automotorsMarketTheme().copyWith(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) => Scaffold(
            appBar: MarketAppBar(title: const Text('Inicio')),
            body: FilledButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: MarketAppBar(title: const Text('Ficha')),
                    bottomNavigationBar: MarketActionDock(
                      child: FilledButton(
                        onPressed: () => calls++,
                        child: const Text('Contactar'),
                      ),
                    ),
                    body: ListView(
                      children: List.generate(
                        30,
                        (i) => ListTile(title: Text('Dato $i')),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contactar'));
    expect(calls, 1);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route chrome respects high contrast and dark photo viewers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: automotorsMarketTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: true),
          child: child!,
        ),
        home: Scaffold(
          appBar: MarketAppBar(
            title: const Text('Fotos'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          bottomNavigationBar: const MarketActionDock(child: Text('Acción')),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      tester.widget<MarketAppBar>(find.byType(MarketAppBar)).backgroundColor,
      Colors.black,
    );
    expect(tester.takeException(), isNull);
  });
}
