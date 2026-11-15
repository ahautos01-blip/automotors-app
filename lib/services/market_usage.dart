import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Voluntary coarse counters, never a user journey or free-form payload.
class MarketUsage {
  static const key = 'automotors.optional-usage.v1';
  static const stages = {
    'catalogue',
    'detail',
    'contact',
    'publication_start',
    'publication_complete',
  };
  static final _sent = <String>{};
  static Future<bool> enabled() async =>
      (await SharedPreferences.getInstance()).getBool(key) ?? false;
  static Future<void> setEnabled(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(key, value);
    _sent.clear();
  }

  static void record(String stage) {
    if (stages.contains(stage)) unawaited(_send(stage));
  }

  static Future<void> _send(String stage) async {
    try {
      if (!await enabled() || !_sent.add(stage)) return;
      final db = Supabase.instance.client;
      if (db.auth.currentSession == null) {
        _sent.remove(stage);
        return;
      }
      await db
          .rpc('record_market_usage', params: {'p_stage': stage, 'p_build': 47})
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      /* Optional measurement cannot block the app. */
    }
  }
}
