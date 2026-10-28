import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Native APNs integration. Device ownership is tied to the live Supabase session.
class IosPushService with WidgetsBindingObserver {
  static const _channel = MethodChannel('automotors/push');
  final SupabaseClient db;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  Map<String, dynamic>? _device;
  Map<String, dynamic>? _pending;
  bool _opening = false;
  bool _started = false;
  final Set<String> _opened = {};
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  IosPushService({required this.db, required this.onOpen});

  Future<void> start() async {
    if (!supported || _started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'deviceToken') {
        _device = Map<String, dynamic>.from(call.arguments as Map);
        await _saveDevice();
      } else if (call.method == 'notificationOpened') {
        _pending = Map<String, dynamic>.from(call.arguments as Map);
        await _openPending();
      }
    });
    db.auth.onAuthStateChange.listen((state) {
      if (state.session != null) {
        unawaited(_register());
        unawaited(_openPending());
      }
    });
    try {
      final initial = await _channel.invokeMapMethod<String, dynamic>('initialize');
      if (initial?['device'] is Map) _device = Map<String, dynamic>.from(initial!['device'] as Map);
      if (initial?['notification'] is Map) _pending = Map<String, dynamic>.from(initial!['notification'] as Map);
      if (db.auth.currentSession != null) await _register();
      await _openPending();
    } on PlatformException {
      // Push failure must not stop login, chat, sales or application startup.
    } on MissingPluginException {
      // Older native builds continue to work without push support.
    }
  }

  Future<void> _register() async {
    if (!supported || db.auth.currentSession == null) return;
    try {
      final granted = await _channel.invokeMethod<bool>('register') ?? false;
      if (granted) await _saveDevice();
      else await _removeDevice();
    } catch (_) { /* Retry on the next foreground or sign-in event. */ }
  }

  Future<void> _saveDevice() async {
    if (_device == null || db.auth.currentSession == null) return;
    try {
      await db.rpc('register_push_device', params: {
        'p_token': _device!['token'], 'p_environment': _device!['environment'],
      });
    } catch (_) { /* Keep the token in memory and retry after resume. */ }
  }

  Future<void> _removeDevice() async {
    final userId = db.auth.currentUser?.id;
    if (_device == null || userId == null) return;
    await db.from('push_devices').delete().eq('user_id', userId)
        .eq('token', _device!['token']).eq('environment', _device!['environment']);
  }

  /// Call before signing out, while the user's JWT can still remove the token.
  Future<void> unregister() async {
    if (!supported) return;
    try { await _removeDevice(); } catch (_) { /* Session revocation also deletes the device. */ }
    try { await _channel.invokeMethod<void>('unregister'); } catch (_) { /* Older native build. */ }
    _device = null;
    _pending = null;
  }

  Future<void> _openPending() async {
    if (_opening || _pending == null) return;
    final route = _pending!;
    final id = route['notification_id']?.toString();
    if (id == null || _opened.contains(id)) { _pending = null; return; }
    _opening = true;
    _pending = null;
    try {
      await onOpen(route);
      _opened.add(id);
    } catch (_) { /* Do not crash when an old notification points to deleted data. */ }
    finally {
      _opening = false;
      if (_pending != null) unawaited(_openPending());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_register());
  }
}
