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
