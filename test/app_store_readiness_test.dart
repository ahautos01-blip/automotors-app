import 'package:automotors_base/delete_account_page.dart';
import 'package:automotors_base/support_page.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/l10n/ui_text.dart';
import 'package:automotors_base/services/store_product_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

Widget localized(String code, Widget page) => MaterialApp(
  locale: Locale(code),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: page,
);

void main() {
  test('billing period comes from StoreKit, not product name or currency', () {
    final product = AppStoreProduct2Details.fromSK2Product(
      SK2Product(
        id: 'automotors_pro_monthly_199',
        displayName: 'Test',
        displayPrice: '£12.34',
        description: 'Test',
        price: 12.34,
        type: SK2ProductType.autoRenewable,
        priceLocale: SK2PriceLocale(currencyCode: 'GBP', currencySymbol: '£'),
        subscription: const SK2SubscriptionInfo(
          subscriptionGroupID: 'group',
          promotionalOffers: [],
          subscriptionPeriod: SK2SubscriptionPeriod(
            value: 3,
            unit: SK2SubscriptionPeriodUnit.month,
          ),
        ),
      ),
    );
    expect(product.price, '£12.34');
    expect(storeSubscriptionPeriod(product), (count: 3, unit: 'month'));
    expect(
      translateUiMessage(storePeriodMessage(product)!, 'en', [3]),
      '3 months',
    );
    expect(
      translateUiMessage(storePeriodMessage(product)!, 'ca', [3]),
      '3 mesos',
    );
    final unknown = ProductDetails(
      id: 'automotors_pro_monthly_199',
      title: 'Test',
      description: 'Test',
      price: r'$1',
      rawPrice: 1,
      currencyCode: 'USD',
    );
    expect(storeSubscriptionPeriod(unknown), isNull);
    expect(storePeriodMessage(unknown), isNull);
  });
  test('a mismatched market currency never becomes a fabricated euro price', () {
    final dollars = ProductDetails(id:'pro', title:'PRO', description:'', price:r'$179.00', rawPrice:179, currencyCode:'USD');
    final euros = ProductDetails(id:'pro', title:'PRO', description:'', price:'199,00 €', rawPrice:199, currencyCode:'EUR');
    expect(storeDisplayPrice(dollars, expectedCurrency:'EUR'), isNull);
    expect(storeDisplayPrice(euros, expectedCurrency:'EUR'), '199,00 €');
    expect(storeDisplayPrice(dollars), r'$179.00');
  });
  for (final language in ['es', 'en', 'ca']) {
    String tr(String source) => translateUiMessage(source, language);
    testWidgets('support and privacy work without sign-in in $language', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        localized(language, const AutomotorsSupportPage()),
      );
      expect(find.textContaining(automotorsLegalAddress), findsOneWidget);
      await tester.tap(find.text(tr('Política de privacidad')));
      await tester.pumpAndSettle();
      expect(find.text(tr('Datos que utilizamos')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'deletion requires acknowledgement and confirmation in $language',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          localized(
            language,
            DeleteAccountPage(
              deleteAccount: () async {
                calls++;
              },
            ),
          ),
        );
        final request = find.byKey(const Key('request-account-deletion'));
        expect(tester.widget<FilledButton>(request).onPressed, isNull);
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.ensureVisible(request);
        await tester.tap(request);
        await tester.pumpAndSettle();
        expect(calls, 0);
        await tester.tap(find.text(tr('Cancelar')));
        await tester.pumpAndSettle();
        expect(calls, 0);
        await tester.tap(request);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm-account-deletion')));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.text(tr('Tu cuenta se ha eliminado.')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('failed deletion remains visible and can be retried', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      localized(
        'es',
        DeleteAccountPage(
          deleteAccount: () async {
            calls++;
            throw StateError('network');
          },
        ),
      ),
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      final request = find.byKey(const Key('request-account-deletion'));
      await tester.ensureVisible(request);
      await tester.tap(request);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-account-deletion')));
      await tester.pumpAndSettle();
    }
    expect(calls, 2);
    expect(find.textContaining('No se ha podido completar'), findsOneWidget);
    expect(find.text(automotorsSupportEmail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
