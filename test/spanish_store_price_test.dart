import 'package:automotors_base/services/store_product_presentation.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:flutter_test/flutter_test.dart';

AppStoreProduct2Details fixture(
  String id, {
  String currency = 'USD',
  String price = r'$179.00',
  int months = 1,
}) => AppStoreProduct2Details.fromSK2Product(
  SK2Product(
    id: id,
    displayName: id,
    displayPrice: price,
    description: 'Fixture',
    price: 179,
    type: SK2ProductType.autoRenewable,
    priceLocale: SK2PriceLocale(
      currencyCode: currency,
      currencySymbol: currency == 'EUR' ? '€' : r'$',
    ),
    subscription: SK2SubscriptionInfo(
      subscriptionGroupID: 'fixture',
      promotionalOffers: [],
      subscriptionPeriod: SK2SubscriptionPeriod(
        value: months,
        unit: SK2SubscriptionPeriodUnit.month,
      ),
    ),
  ),
);

void main() {
  const prices = {
    'automotors_pack_10': '59,00 €',
    'automotors_pack_15': '75,00 €',
    'automotors_pack_20': '99,00 €',
    'automotors_pro_monthly_199': '199,00 €',
  };
  for (final entry in prices.entries) {
    test(
      '${entry.key} uses the independently verified Spanish price for mismatched metadata',
      () {
        final product = fixture(entry.key);
        expect(spanishStoreDisplayPrice(product), entry.value);
        expect(configuredSpanishSubscriptionPrice(entry.key), entry.value);
        expect(storeSubscriptionPeriod(product), (count: 1, unit: 'month'));
        expect(
          product.price,
          r'$179.00',
        ); // Purchase metadata is never rewritten.
      },
    );
  }
  test(
    'coherent EUR store price takes precedence over the catalog snapshot',
    () {
      final product = fixture(
        'automotors_pro_monthly_199',
        currency: 'EUR',
        price: '209,00 €',
      );
      expect(spanishStoreDisplayPrice(product), '209,00 €');
    },
  );
  test('unknown product never gets a guessed euro amount', () {
    expect(spanishStoreDisplayPrice(fixture('unknown')), isNull);
    expect(configuredSpanishSubscriptionPrice('unknown'), isNull);
  });
  test('a contradictory billing period cannot use the monthly fallback', () {
    expect(
      spanishStoreDisplayPrice(
        fixture('automotors_pro_monthly_199', months: 3),
      ),
      isNull,
    );
  });
  test('dollar-formatted text with an EUR code is still inconsistent', () {
    expect(
      spanishStoreDisplayPrice(
        fixture('automotors_pro_monthly_199', currency: 'EUR'),
      ),
      '199,00 €',
    );
  });
}
