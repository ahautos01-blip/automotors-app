import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:automotors_base/chat_market_page.dart';
import 'package:automotors_base/design/market_safety.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/l10n/app_localizations.dart';

void main() {
  test('offer amount parser rejects ambiguous grouping, negatives and precision loss', () {
    expect(parseMarketOffer('12000,50'), 12000.5);
    expect(parseMarketOffer('12000.50'), 12000.5);
    expect(parseMarketOffer('0'), isNull);
    expect(parseMarketOffer('-1'), isNull);
    expect(parseMarketOffer('1.000'), isNull);
    expect(parseMarketOffer('1,234.50'), isNull);
    expect(parseMarketOffer('1.999'), isNull);
    expect(parseMarketOffer('Infinity'), isNull);
    expect(parseMarketOffer('100000001'), isNull);
  });
  testWidgets('offer dialog validates before returning a proposal', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const MarketProposalDialog(kind: 'offer'),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '1.000');
    await tester.tap(find.text('Enviar propuesta'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Introduce un importe válido.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '12000,50');
    await tester.tap(find.text('Enviar propuesta'));
    await tester.pumpAndSettle();
    expect(result, '12000,50');
    expect(tester.takeException(), isNull);
  });
  for (final language in ['es', 'en', 'ca'])
    testWidgets(
      'safety and factual trust indicators fit large text in $language',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: automotorsMarketTheme(),
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    SellerTrustIndicators(
                      professional: true,
                      emailConfirmed: true,
                    ),
                    MarketSafetyAdvice(),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(ExpansionTile));
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Chip), findsNWidgets(2));
      },
    );
  testWidgets('no unperformed identity or email verification is claimed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: SellerTrustIndicators(professional: true)),
      ),
    );
    expect(find.text('Perfil profesional declarado'), findsOneWidget);
    expect(find.text('Correo confirmado'), findsNothing);
    expect(find.text('Identidad verificada'), findsNothing);
  });
}
