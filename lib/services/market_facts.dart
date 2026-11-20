import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

Map<String, dynamic> listingMarketFacts(Map<String, dynamic> listing) {
  final facts = listing['market_facts'] is Map
      ? Map<String, dynamic>.from(listing['market_facts'])
      : <String, dynamic>{};
  if (listing.containsKey('seller_location')) {
    facts.remove('locality');
    final location = listing['seller_location'];
    if (location is Map) {
      final locality = MarketLocality.fromJson(location['locality']);
      if (locality != null) facts['locality'] = locality.toJson();
      final label = ['city', 'province']
          .map((key) => location[key]?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .join(', ');
      if (label.isNotEmpty) facts['profile_location_label'] = label;
    }
  }
  return facts;
}

String marketLocationLabel(Map<String, dynamic> facts) =>
    facts['profile_location_label']?.toString() ??
    MarketLocality.fromJson(facts['locality'])?.label ??
    'No informado';

class MarketLocality {
  final String id, label;
  final double lat, lon;
  const MarketLocality(this.id, this.label, this.lat, this.lon);
  static MarketLocality? fromJson(dynamic value) {
    if (value is! Map ||
        value['id'] is! String ||
        value['label'] is! String ||
        value['lat'] is! num ||
        value['lon'] is! num)
      return null;
    final lat = (value['lat'] as num).toDouble(),
        lon = (value['lon'] as num).toDouble();
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat < 27 ||
        lat > 44 ||
        lon < -19 ||
        lon > 5 ||
        (value['label'] as String).length > 120)
      return null;
    return MarketLocality(
      value['id'],
      value['label'],
      double.parse(lat.toStringAsFixed(2)),
      double.parse(lon.toStringAsFixed(2)),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'lat': lat,
    'lon': lon,
  };
  double distanceTo(MarketLocality other) {
    double radians(double n) => n * math.pi / 180;
    final a =
        math.pow(math.sin(radians(other.lat - lat) / 2), 2) +
        math.cos(radians(lat)) *
            math.cos(radians(other.lat)) *
            math.pow(math.sin(radians(other.lon - lon) / 2), 2);
    return 6371 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}

bool matchesMarketRadius(
  Map<String, dynamic> criteria,
  Map<String, dynamic> facts,
) {
  final origin = MarketLocality.fromJson(criteria['locality']);
  if (origin == null) return !criteria.containsKey('locality');
  final target = MarketLocality.fromJson(facts['locality']);
  final radius = criteria['radius_km'];
  return target != null &&
      radius is num &&
      radius.isFinite &&
      radius >= 10 &&
      radius <= 500 &&
      origin.distanceTo(target) <= radius;
}

/// Explicit municipality searches only: no GPS, account IDs or street addresses.
class MunicipalitySearch {
  final http.Client client;
  MunicipalitySearch(this.client);
  final _cache = <String, List<Map<String, dynamic>>>{};
  Future<List<Map<String, dynamic>>> candidates(String query) async {
    final q = query.trim();
    if (q.length < 2 ||
        q.length > 80 ||
        !RegExp(r"^[a-zA-ZÀ-ž .,'’()-]+$").hasMatch(q))
      throw const FormatException('Municipality name required');
    if (_cache.containsKey(q.toLowerCase())) return _cache[q.toLowerCase()]!;
    final response = await client
        .get(
          Uri.https('www.cartociudad.es', '/geocoder/api/geocoder/candidates', {
            'q': q,
            'limit': '10',
            'countrycodes': 'es',
            'no_process': 'callejero,carretera,portal,toponimo,ngbe,expendeduria,punto_recarga_electrica,provincia,comunidad autonoma,poblacion',
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200)
      throw const FormatException('Locality service unavailable');
    final raw = jsonDecode(utf8.decode(response.bodyBytes));
    if (raw is! List) throw const FormatException('Invalid locality response');
    final result = raw
        .whereType<Map>()
        .where(
          (v) =>
              v['type']?.toString().toLowerCase() == 'municipio' &&
              v['address'] is String &&
              v['id'] != null,
        )
        .take(8)
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
    if (_cache.length >= 30) _cache.clear();
    return _cache[q.toLowerCase()] = result;
  }

  Future<MarketLocality> resolve(Map<String, dynamic> candidate) async {
    if (candidate['type']?.toString().toLowerCase() != 'municipio')
      throw const FormatException('Municipality required');
    final response = await client
        .get(
          Uri.https('www.cartociudad.es', '/geocoder/api/geocoder/find', {
            'type': candidate['type'].toString(),
            'id': candidate['id'].toString(),
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200)
      throw const FormatException('Locality service unavailable');
    dynamic value = jsonDecode(utf8.decode(response.bodyBytes));
    if (value is List) value = value.isEmpty ? null : value.first;
    if (value is! Map ||
        (value['type'] != null &&
            value['type']?.toString().toLowerCase() != 'municipio'))
      throw const FormatException('Invalid locality');
    final result = MarketLocality.fromJson({
      'id': candidate['id'].toString(),
      'label': candidate['address'],
      'lat': value['lat'],
      'lon': value['lng'] ?? value['lon'],
    });
    if (result == null)
      throw const FormatException('Invalid locality coordinates');
    return result;
  }
}

const marketMaintenance = {
  'unknown': 'No informado',
  'documented': 'Historial de mantenimiento disponible',
  'partial': 'Historial parcial',
  'none': 'Sin historial de mantenimiento',
};
const marketItv = {
  'unknown': 'No informado',
  'valid': 'ITV vigente según vendedor',
  'expired': 'ITV caducada',
  'not_required': 'ITV aún no exigible',
};
const marketWarranty = {
  'unknown': 'No informado',
  'included': 'Garantía incluida: consultar condiciones',
  'none': 'Sin garantía comercial adicional',
};
