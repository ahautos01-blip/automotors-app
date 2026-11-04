import 'package:flutter_test/flutter_test.dart';
import 'package:automotors_base/services/verified_store_plans.dart';

void main() {
  final now = DateTime.utc(2026, 10, 28, 3);
  Map<String, dynamic> row(String product, {String status='active', DateTime? expiry, DateTime? start}) => {
    'product_id': product, 'status': status,
    'started_at': (start ?? now.subtract(const Duration(hours: 1))).toIso8601String(),
    'expires_at': (expiry ?? now.add(const Duration(hours: 1))).toIso8601String(),
  };

  test('every verified active pack can publish; pending, expired and revoked cannot', () {
    for (final product in VerifiedStorePlans.productIds) {
      expect(VerifiedStorePlans.fromRows([row(product)],now:now).isActive(product,now:now),isTrue);
      for (final status in ['pending','revoked','expired','canceled']) {
        expect(VerifiedStorePlans.fromRows([row(product,status:status)],now:now).isActive(product,now:now),isFalse);
      }
      expect(VerifiedStorePlans.fromRows([row(product,expiry:now)],now:now).isActive(product,now:now),isFalse);
      expect(VerifiedStorePlans.fromRows([row(product,start:now.add(const Duration(hours: 1)))],now:now).isActive(product,now:now),isFalse);
    }
  });

  test('restored grace period remains active only until verified expiry', () {
    const product='automotors_pack_20';
    final expiry=now.add(const Duration(minutes: 5));
    final plans=VerifiedStorePlans.fromRows([row(product,status:'grace_period',expiry:expiry)],now:now);
    expect(plans.isActive(product,now:now),isTrue);
    expect(plans.isActive(product,now:expiry),isFalse);
    expect(plans.nextExpiry,expiry);
    expect(plans.isActive('automotors_pack_15',now:now),isFalse);
  });

  test('overlapping renewals keep the latest expiry and reject malformed records', () {
    const product='automotors_pack_20';
    final expiry=now.add(const Duration(days: 30));
    final plans=VerifiedStorePlans.fromRows([
      row(product),row(product,expiry:expiry),
      {...row('automotors_pack_10'),'expires_at':null},
      row('unknown_product'),
    ],now:now);
    expect(plans.nextExpiry,expiry);
    expect(plans.isActive('automotors_pack_10',now:now),isFalse);
    expect(plans.isActive('unknown_product',now:now),isFalse);
  });
}
