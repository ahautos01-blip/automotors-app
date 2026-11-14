import 'package:supabase_flutter/supabase_flutter.dart';

typedef CommunityRpc = Future<dynamic> Function(
  String name,
  Map<String, dynamic> parameters,
);
Future<dynamic> _communityRpc(String name, Map<String, dynamic> parameters) =>
    Supabase.instance.client.rpc(name, params: parameters);

class CommunityModerationService {
  CommunityModerationService({CommunityRpc? request})
    : _request = request ?? _communityRpc;
  final CommunityRpc _request;
  Future<List<Map<String,dynamic>>> activities(String reportId) async => List<Map<String,dynamic>>.from(await _request('community_report_activities',{'p_report':reportId}) as List);
  Future<Map<String,dynamic>> overview() async => Map<String,dynamic>.from(await _request('community_overview',{}) as Map);
  Future<bool> hasAccess() async =>
      await _request('community_moderation_access', {}) == true;
  Future<List<Map<String, dynamic>>> reports({
    Map<String, dynamic>? before,
    bool includeClosed = false,
  }) async {
    final result = await _request('community_reports', {
      'p_before_created': before?['created_at'],
      'p_before_id': before?['id'],
      'p_before_kind': before?['kind'],
      'p_include_closed': includeClosed,
    });
    return List<Map<String, dynamic>>.from(
      (result as List).map((row) => Map<String, dynamic>.from(row as Map)),
    );
  }

  Future<Map<String, dynamic>> detail(String kind, String id) async =>
      Map<String, dynamic>.from(
        await _request('community_report_detail', {'p_kind': kind, 'p_id': id})
            as Map,
      );
  Future<List<Map<String, dynamic>>> messages(
    String reportId,
    String beforeId,
  ) async {
    final result = await _request('community_report_messages', {
      'p_report_id': reportId,
      'p_before_id': beforeId,
    });
    return List<Map<String, dynamic>>.from(
      (result as List).map((row) => Map<String, dynamic>.from(row as Map)),
    );
  }

  Future<Map<String, dynamic>> review(
    String kind,
    String id,
    String action,
    String note,
  ) async => Map<String, dynamic>.from(
    await _request('community_review_report', {
      'p_kind': kind,
      'p_id': id,
      'p_action': action,
      'p_note': note,
    }) as Map,
  );
  Future<Map<String, dynamic>> approvePublication(
    String reportId,
    String fingerprint,
    String note,
  ) async => Map<String, dynamic>.from(
    await _request('community_approve_publication', {
      'p_report_id': reportId,
      'p_expected_fingerprint': fingerprint,
      'p_note': note,
    }) as Map,
  );
}
