import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'vehicle_category.dart';
import 'vehicle_search.dart';

String catalogueKey(String name) =>
    normalizeVehicleSearch(name).replaceAll(RegExp(r'[^a-z0-9]'), '');

Map<String, dynamic> catalogueListingIdentity({
  required VehicleCategory category,
  required int? brandId,
  required int? modelId,
  required String brand,
  required String model,
}) {
  final known =
      category == VehicleCategory.car &&
      (brandId ?? 0) > 0 &&
      (modelId ?? 0) > 0;
  if (!known &&
      (brand.trim().isEmpty ||
          brand.trim().length > 80 ||
          model.trim().isEmpty ||
          model.trim().length > 100))
    throw ArgumentError('Invalid make or model');
  return {
    'brand_id': known ? brandId : null,
    'model_id': known ? modelId : null,
    'declared_brand': known ? null : brand.trim(),
    'declared_model': known ? null : model.trim(),
  };
}

/// Bundled public reference suggestions plus the existing server catalogue.
/// Local negative IDs are UI keys only and are never written as foreign keys.
class VehicleCatalogue {
  final SupabaseClient? client;
  final AssetBundle bundle;
  VehicleCatalogue({this.client, AssetBundle? bundle})
    : bundle = bundle ?? rootBundle;
  Future<Map<String, dynamic>>? _reference;
  static Map<String, dynamic>? _bundledReference;
  bool serverUnavailable = false;
  Object? serverError;
  Future<Map<String, dynamic>> reference() => _reference ??= _readReference();
  Future<Map<String, dynamic>> _readReference() async {
    if (identical(bundle, rootBundle) && _bundledReference != null)
      return _bundledReference!;
    final bytes = await bundle.load('assets/vehicle_catalogue.json');
    final result = Map<String, dynamic>.from(
      jsonDecode(
        utf8.decode(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        ),
      ),
    );
    if (identical(bundle, rootBundle)) _bundledReference = result;
    return result;
  }

  Future<List<Map<String, dynamic>>> _pages(
    String table, {
    int? brandId,
  }) async {
    final result = <Map<String, dynamic>>[];
    for (var from = 0; ; from += 500) {
      final query = (client ?? Supabase.instance.client)
          .from(table)
          .select(brandId == null ? 'id,name' : 'id,name,brand_id');
      final rows =
          await (brandId == null ? query : query.eq('brand_id', brandId))
              .order('name')
              .order('id')
              .range(from, from + 499);
      result.addAll(List<Map<String, dynamic>>.from(rows));
      if (rows.length < 500) break;
    }
    return result;
  }

  static List<Map<String, dynamic>> merge(
    List<Map<String, dynamic>> remote,
    Iterable<String> local,
  ) {
    final byName = <String, Map<String, dynamic>>{};
    final names = local.toSet().toList()
      ..sort((a, b) => catalogueKey(a).compareTo(catalogueKey(b)));
    for (var i = 0; i < names.length; i++) {
      byName[catalogueKey(names[i])] = {'id': -i - 1, 'name': names[i]};
    }
    for (final row in remote) {
      byName[catalogueKey(row['name'].toString())] = row;
    }
    return byName.values.toList()..sort(
      (a, b) =>
          catalogueKey(a['name'].toString())
              .compareTo(catalogueKey(b['name'].toString())),
    );
  }

  Future<List<Map<String, dynamic>>> brands(VehicleCategory category) async {
    final data = (await reference())[category.id] as Map? ?? {};
    List<Map<String, dynamic>> remote = [];
    if (category == VehicleCategory.car) {
      try {
        remote = await _pages('vehicle_brands');
        serverUnavailable = false;
        serverError = null;
      } catch (error) {
        serverUnavailable = true;
        serverError = error;
      }
    }
    return merge(
      remote,
      data.keys.cast<String>().where(
        (name) => name.trim().isNotEmpty && name.length <= 80,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> models(
    VehicleCategory category,
    int id,
    String name,
  ) async {
    final data = (await reference())[category.id] as Map? ?? {};
    final matching = data.keys.cast<String>().where(
      (b) => catalogueKey(b) == catalogueKey(name),
    );
    final local = [
      for (final brand in matching) ...List<String>.from(data[brand]),
    ];
    List<Map<String, dynamic>> remote = [];
    if (category == VehicleCategory.car && id > 0) {
      try {
        remote = await _pages('vehicle_models', brandId: id);
        serverUnavailable = false;
        serverError = null;
      } catch (error) {
        serverUnavailable = true;
        serverError = error;
      }
    }
    return merge(remote, local);
  }
}
