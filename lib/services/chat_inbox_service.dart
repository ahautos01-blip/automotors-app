import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'vehicle_search.dart';

class ChatInboxService {
  ChatInboxService(this.client);
  final SupabaseClient client;
  RealtimeChannel? watch(void Function() changed) => client
      .channel('inbox-personal-${DateTime.now().microsecondsSinceEpoch}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_messages',
        callback: (_) => changed(),
      )
      .subscribe();
  Future<void> action(String id, String action) async {
    if (!{'hide', 'restore', 'pin', 'unpin'}.contains(action) ||
        int.tryParse(id) == null)
      throw const FormatException('Invalid inbox action');
    await client.rpc(
      'chat_inbox_action',
      params: {'p_conversation_id': id, 'p_action': action},
    );
  }

  Future<List<Map<String, dynamic>>> load(
    Future<Uint8List> Function(String) loadPhoto,
  ) async {
    final viewer = client.auth.currentUser?.id;
    if (viewer == null) throw const AuthException('Sign-in required');
    final raw = await client.rpc('chat_inbox_snapshot');
    if (client.auth.currentUser?.id != viewer)
      throw const AuthException('Session changed');
    final rows = List<Map<String, dynamic>>.from(raw as List);
    final profiles = <String, String?>{};
    final listings = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final listingId = row['listing_id']?.toString();
      row['vehicle_title'] = null;
      row['participant_name'] = null;
      if (listingId != null) {
        try {
          if (!listings.containsKey(listingId)) {
            final listing = await client
                .from('vehicle_listings')
                .select(
                  'declared_brand,declared_model,vehicle_brands(name),vehicle_models(name),vehicle_photos(storage_path,position)',
                )
                .eq('id', listingId)
                .maybeSingle();
            final detail = <String, dynamic>{};
            if (listing != null) {
              final brand = listing['declared_brand']!=null ? {'name':listing['declared_brand']} : listing['vehicle_brands'];
              final model = listing['declared_model']!=null ? {'name':listing['declared_model']} : listing['vehicle_models'];
              final title =
                  '${brand is Map ? brand['name'] ?? '' : ''} ${model is Map ? model['name'] ?? '' : ''}'
                      .trim();
              if (title.isNotEmpty) detail['vehicle_title'] = title;
              final photos = listing['vehicle_photos'] is List
                  ? List<Map<String, dynamic>>.from(listing['vehicle_photos'])
                  : <Map<String, dynamic>>[];
              photos.sort(
                (a, b) => ((a['position'] as num?)?.toInt() ?? 0).compareTo(
                  (b['position'] as num?)?.toInt() ?? 0,
                ),
              );
              if (photos.isNotEmpty && photos.first['storage_path'] is String) {
                try {
                  detail['vehicle_photo'] = await loadPhoto(
                    photos.first['storage_path'],
                  );
                } catch (_) {
                  /* Keep the placeholder. */
                }
              }
            }
            listings[listingId] = detail;
          }
          row.addAll(listings[listingId]!);
        } catch (_) {
          /* An unavailable listing must not hide a conversation. */
        }
      }
      final other =
          (row['buyer_id'] == viewer ? row['seller_id'] : row['buyer_id'])
              ?.toString();
      if (other != null) {
        try {
          if (!profiles.containsKey(other)) {
            final profile = await client
                .from('public_seller_profiles')
                .select('full_name,business_name,account_type')
                .eq('id', other)
                .maybeSingle();
            final professional = [
              'empresa',
              'autonomo',
            ].contains(profile?['account_type']);
            final business = profile?['business_name']?.toString().trim() ?? '';
            final name = profile?['full_name']?.toString().trim() ?? '';
            profiles[other] = professional && business.isNotEmpty
                ? business
                : name.isNotEmpty
                ? name
                : null;
          }
          row['participant_name'] = profiles[other];
        } catch (_) {
          /* Only public identity is requested, never private profiles. */
        }
      }
      if (client.auth.currentUser?.id != viewer)
        throw const AuthException('Session changed');
    }
    return rows;
  }
}

List<Map<String, dynamic>> filterChatInbox(
  List<Map<String, dynamic>> rows, {
  required bool deleted,
  required String query,
}) {
  return rows.where((row) {
    if ((row['deleted'] == true) != deleted) return false;
    return matchesVehicleSearch(query, [
      row['vehicle_title']?.toString(),
      row['participant_name']?.toString(),
    ]);
  }).toList();
}
