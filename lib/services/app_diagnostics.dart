
import 'package:flutter/foundation.dart';

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class AppDiagnostics {
  static bool _installed = false;
  static void install() {
    if (_installed) return;
    _installed = true;
    final flutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      record('app', details.exception);
      flutterHandler?.call(details);
    };
    final platformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      record('app', error);
      return platformHandler?.call(error, stack) ?? false;
    };
  }

  static final _last = <String, DateTime>{};
  static void record(String category, Object error) {
    const allowed = {
      'app',
      'catalogue',
      'publication',
      'photo',
      'chat',
      'purchase',
    };
    if (!allowed.contains(category)) return;
    final now = DateTime.now();
    if (_last[category] != null &&
        now.difference(_last[category]!) < const Duration(minutes: 1))
      return;
    _last[category] = now;
    unawaited(_send(category, error));
  }

  static Future<void> _send(String category, Object error) async {
    try {
      final db = Supabase.instance.client;
      if (db.auth.currentSession == null) return;
      final code = error is TimeoutException
          ? 'network'
          : error is PostgrestException && error.code == '42501'
          ? 'permission'
          : error is FunctionException
          ? 'unavailable'
          : 'unknown';
      // Never serialize the error, its message, request, user identity or stack.
      await db
          .rpc(
            'record_client_error',
            params: {'p_category': category, 'p_code': code, 'p_build': 42},
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      /* Diagnostics must never interrupt a user action. */
    }
  }
}
