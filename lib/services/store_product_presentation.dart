import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

/// Store-provided period only: product identifiers are not billing metadata.
({int count, String unit})? storeSubscriptionPeriod(ProductDetails product) {
  if (product is AppStoreProduct2Details) {
    final period = product.sk2Product.subscription?.subscriptionPeriod;
    if (period != null && period.value > 0) {
      return (count: period.value, unit: period.unit.name);
    }
  } else if (product is AppStoreProductDetails) {
    final period = product.skProduct.subscriptionPeriod;
    if (period != null && period.numberOfUnits > 0) {
      return (count: period.numberOfUnits, unit: period.unit.name);
    }
  }
  return null;
}

String? storePeriodMessage(ProductDetails product) {
  final period = storeSubscriptionPeriod(product);
  if (period == null) return null;
  final units = switch (period.unit) {
    'day' => ('día', 'días'),
    'week' => ('semana', 'semanas'),
    'month' => ('mes', 'meses'),
    'year' => ('año', 'años'),
    _ => null,
  };
  if (units == null) return null;
  return period.count == 1 ? units.$1 : '{0} ${units.$2}';
}

/// Never relabel or convert a store amount when its currency disagrees with the
/// market configured in App Store Connect. The native purchase sheet is final.
String? storeDisplayPrice(ProductDetails product, {String? expectedCurrency}) {
  if (expectedCurrency != null && product.currencyCode != expectedCurrency) {
    return null;
  }
  return product.price;
}

/// Spain-only catalog checked in App Store Connect on 2026-11-02.
/// All four are auto-renewable monthly subscriptions, each available in Spain
/// only. These are independently confirmed EUR prices, never FX conversions.
/// Synchronize this snapshot whenever changing Spanish tariffs or territories.
/// Product pages: 6827338470 (10), 6827338063 (15), 6827337711 (20),
/// 6827335055 (PRO), app 6827315199, group 22517049.
const _confirmedSpanishMonthlyCents = <String, int>{
  'automotors_pack_10': 5900,
  'automotors_pack_15': 7500,
  'automotors_pack_20': 9900,
  'automotors_pro_monthly_199': 19900,
};

String? configuredSpanishSubscriptionPrice(String productId) {
  final cents = _confirmedSpanishMonthlyCents[productId];
  if (cents == null) return null;
  return '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')} €';
}

/// Prefer coherent EUR store metadata. A mismatched currency can use only the
/// separately verified price of the exact known monthly SKU. Unknown products
/// or conflicting periods remain unavailable for checkout.
String? spanishStoreDisplayPrice(ProductDetails product) {
  if (product.currencyCode == 'EUR' &&
      !product.price.contains(r'$') &&
      !product.price.toUpperCase().contains('USD')) {
    return product.price;
  }
  final period = storeSubscriptionPeriod(product);
  if (period == null || period.count != 1 || period.unit != 'month')
    return null;
  return configuredSpanishSubscriptionPrice(product.id);
}
