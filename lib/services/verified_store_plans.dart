/// A store callback alone is never enough: these rows come from the server's
/// read-only subscription records after purchase verification.
class VerifiedStorePlans {
  final Map<String, DateTime> _expires;
  const VerifiedStorePlans._(this._expires);
  static const empty = VerifiedStorePlans._({});
  static const productIds = {
    'automotors_pack_10', 'automotors_pack_15', 'automotors_pack_20',
    'automotors_pro_monthly_199',
  };

  factory VerifiedStorePlans.fromRows(List<Map<String, dynamic>> rows, {DateTime? now}) {
    final instant = (now ?? DateTime.now()).toUtc();
    final expires = <String, DateTime>{};
    for (final row in rows) {
      final product = row['product_id']?.toString() ?? '';
      final expiry = DateTime.tryParse(row['expires_at']?.toString() ?? '')?.toUtc();
      final start = DateTime.tryParse((row['started_at'] ?? row['created_at'])?.toString() ?? '')?.toUtc();
      if (!productIds.contains(product) ||
          !['active', 'grace_period'].contains(row['status']) ||
          expiry == null || !expiry.isAfter(instant) || start == null || start.isAfter(instant)) {
        continue;
      }
      if (expires[product] == null || expiry.isAfter(expires[product]!)) expires[product] = expiry;
    }
    return VerifiedStorePlans._(Map.unmodifiable(expires));
  }

  bool isActive(String productId, {DateTime? now}) =>
    _expires[productId]?.isAfter(now ?? DateTime.now()) ?? false;

  DateTime? get nextExpiry => _expires.isEmpty ? null :
    _expires.values.reduce((a, b) => a.isBefore(b) ? a : b);
}
