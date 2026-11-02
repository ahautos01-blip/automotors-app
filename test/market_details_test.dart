import 'dart:async';

import 'package:automotors_base/design/market_details.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child, {bool reducedMotion = false}) => MaterialApp(
    theme: automotorsMarketTheme(),
    locale: const Locale('es'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: child),
    ),
  );

  testWidgets(
    'seller summary presents only returned public identity and opens profile',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opened = 0;
      await tester.pumpWidget(
        app(
          MarketSellerSummary(
            profile: Future.value({
              'full_name': 'Persona',
              'business_name': 'Auto Ejemplo',
              'city': 'Mataró',
            }),
            onOpen: () => opened++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Auto Ejemplo'), findsOneWidget);
      expect(find.text('Mataró'), findsOneWidget);
      expect(find.text('Persona'), findsNothing);
      expect(find.byIcon(Icons.verified), findsNothing);
      await tester.tap(find.text('Auto Ejemplo'));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing or failed public profile keeps the profile action usable',
    (tester) async {
      final result = Completer<Map<String, dynamic>?>();
      var opened = 0;
      await tester.pumpWidget(
        app(
          MarketSellerSummary(profile: result.future, onOpen: () => opened++),
        ),
      );
      result.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver perfil del vendedor'));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion skips the card entrance animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const MarketReveal(child: Text('Ready')), reducedMotion: true),
    );
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets(
    'entrance animation completes and does not keep loading forever',
    (tester) async {
      await tester.pumpWidget(app(const MarketReveal(child: Text('Ready'))));
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    },
  );

  testWidgets(
    'saved-search naming validates input and closes without controller disposal errors',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await promptMarketSavedSearchName(context, ''),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('market-search-name')),
        '  SUV familiar  ',
      );
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(result, 'SUV familiar');
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelling search naming returns no value', (tester) async {
    String? result = 'pending';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await promptMarketSavedSearchName(context, 'SUV'),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}
