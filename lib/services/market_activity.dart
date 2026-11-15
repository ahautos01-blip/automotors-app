import 'package:supabase_flutter/supabase_flutter.dart';

class MarketActivityService {
  MarketActivityService(this.client);
  final SupabaseClient client;
  Future<Map<String, dynamic>> load() async {
    final user = client.auth.currentUser?.id;
    if (user == null) throw const AuthException('Sign-in required');
    final value = await client.rpc('my_market_activity');
    if (client.auth.currentUser?.id != user) {
      throw const AuthException('Session changed');
    }
    return Map<String, dynamic>.from(value as Map);
  }
}
