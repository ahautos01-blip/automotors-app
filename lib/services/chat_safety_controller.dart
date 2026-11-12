import 'community_visibility.dart';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef ChatSafetyRequest = Future<Map<String, dynamic>> Function(
  String conversationId,
  String action, {
  String? reason,
  String? details,
});

Future<Map<String, dynamic>> _requestSafety(
  String conversationId,
  String action, {
  String? reason,
  String? details,
}) async {
  final result = await Supabase.instance.client.rpc(
    'community_chat_safety',
    params: {
      'p_conversation_id': conversationId,
      'p_action': action,
      'p_reason': reason,
      'p_details': details,
    },
  );
  return Map<String, dynamic>.from(result as Map);
}

class ChatSafetyController extends ChangeNotifier {
  ChatSafetyController({
    required this.conversationId,
    ChatSafetyRequest? request,
  }) : _request = request ?? _requestSafety;
  final String conversationId;
  final ChatSafetyRequest _request;
  bool busy = false;
  bool loaded = false;
  bool failed = false;
  bool blockedByMe = false;
  bool _allowed = false;
  bool lastReportCreated = false;
  bool _disposed = false;
  bool get canMessage => loaded && !busy && !failed && _allowed;
  Future<bool> load() => _run('status');
  Future<bool> setBlocked(bool blocked) => _run(blocked ? 'block' : 'unblock');
  Future<bool> report(String reason, String details) =>
      _run('report', reason: reason, details: details);
  Future<bool> _run(String action, {String? reason, String? details}) async {
    if (busy || _disposed) return false;
    busy = true;
    failed = false;
    notifyListeners();
    try {
      final result = await _request(
        conversationId,
        action,
        reason: reason,
        details: details,
      );
      if (_disposed) return false;
      if (result['blocked_by_me'] is! bool ||
          result['messaging_allowed'] is! bool ||
          (action == 'report' && result['report_created'] is! bool)) {
        throw const FormatException('Invalid safety response');
      }
      blockedByMe = result['blocked_by_me'] as bool;
      if ((action == 'block' || action == 'unblock') &&
          result['viewer_id'] is String &&
          result['other_user_id'] is String) {
        CommunityVisibility.instance.record(
          viewer: result['viewer_id'] as String,
          seller: result['other_user_id'] as String,
          blocked: blockedByMe,
        );
      }
      _allowed = result['messaging_allowed'] as bool;
      lastReportCreated = result['report_created'] == true;
      loaded = true;
      return true;
    } catch (_) {
      if (!_disposed) failed = true;
      return false;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
