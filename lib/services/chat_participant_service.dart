import 'package:supabase_flutter/supabase_flutter.dart';

/// Derive the other participant from a conversation readable by this account.
/// Never trust a participant id supplied by the listing or a message body.
Future<String> loadChatParticipantId(
  SupabaseClient client,
  String conversationId,
) async {
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw const AuthException('Sign-in required');
  final row = await client
      .from('chat_conversations')
      .select('buyer_id, seller_id')
      .eq('id', conversationId)
      .maybeSingle();
  if (row == null) throw const FormatException('Conversation unavailable');
  final buyer = row['buyer_id']?.toString();
  final seller = row['seller_id']?.toString();
  final other = userId == seller
      ? buyer
      : userId == buyer
      ? seller
      : null;
  if (other == null || other.isEmpty || other == userId) {
    throw const FormatException('Participant unavailable');
  }
  return other;
}
