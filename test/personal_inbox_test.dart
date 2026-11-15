import 'dart:convert';
import 'dart:typed_data';

import 'package:automotors_base/chat_inbox_page.dart';
import 'package:automotors_base/design/market_plans_highlight.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/l10n/ui_text.dart';
import 'package:automotors_base/services/chat_inbox_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const uid = '11111111-1111-4111-8111-111111111111',
    other = '22222222-2222-4222-8222-222222222222';
Map<String, dynamic> chat(String id, String title, String name) => {
  'id': id,
  'listing_id': 'listing-$id',
  'buyer_id': uid,
  'seller_id': other,
  'vehicle_title': title,
  'participant_name': name,
  'last_message': '¿Podemos ver el coche mañana?',
  'last_message_at': '2026-11-15T10:00:00Z',
  'last_message_by_me': false,
  'unread_count': 2,
  'deleted': false,
  'pinned': false,
};

class FakeInbox extends ChatInboxService {
  FakeInbox() : super(Supabase.instance.client);
  final rows = [
    chat('1', 'Volkswagen Golf', 'Omar'),
    chat('2', 'BMW Serie 3', 'Marta'),
  ];
  final actions = <String>[];
  bool fail = false;
  @override
  RealtimeChannel? watch(void Function() changed) => null;
  @override
  Future<List<Map<String, dynamic>>> load(
    Future<Uint8List> Function(String) photo,
  ) async => rows.map((r) => Map<String, dynamic>.from(r)).toList()
    ..sort(
      (a, b) =>
          (b['pinned'] == true ? 1 : 0).compareTo(a['pinned'] == true ? 1 : 0),
    );
  @override
  Future<void> action(String id, String action) async {
    if (fail) throw StateError('fixture');
    actions.add('$id:$action');
    final row = rows.firstWhere((r) => r['id'] == id);
    if (action == 'hide') {
      row['deleted'] = true;
      row['pinned'] = false;
    }
    if (action == 'restore') row['deleted'] = false;
    if (action == 'pin') {
      row['pinned'] = true;
      row['deleted'] = false;
    }
    if (action == 'unpin') row['pinned'] = false;
  }
}

Widget app(Widget child, {String locale = 'es', double scale = 1}) =>
    MaterialApp(
      theme: automotorsMarketTheme(),
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    );
Future<Uint8List> noPhoto(String _) async => Uint8List(0);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': uid, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.fixture';
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((r) async {
        requests.add(r);
        dynamic body = [];
        if (r.url.path == '/auth/v1/token')
          body = {
            'access_token': token,
            'refresh_token': 'fixture',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': uid,
              'aud': 'authenticated',
              'role': 'authenticated',
              'created_at': '2026-01-01T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          };
        if (r.url.path.endsWith('/chat_inbox_snapshot'))
          body = [chat('7', 'ignored', 'ignored')];
        if (r.url.path.endsWith('/vehicle_listings'))
          body = {
            'vehicle_brands': {'name': 'Volkswagen'},
            'vehicle_models': {'name': 'Golf'},
            'vehicle_photos': [],
          };
        if (r.url.path.endsWith('/public_seller_profiles'))
          body = {
            'full_name': 'Private fallback',
            'business_name': 'Motor Empresa',
            'account_type': 'empresa',
          };
        return http.Response(
          jsonEncode(body),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'fixture',
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  test('search matches vehicle and public peer identity and excludes the other tab', () {
    final rows = [
      chat('1', 'Volkswagen Golf', 'Ómar'),
      {...chat('2', 'BMW Serie 3', 'Marta'), 'deleted': true},
    ];
    expect(
      filterChatInbox(rows, deleted: false, query: 'omar').single['id'],
      '1',
    );
    expect(
      filterChatInbox(rows, deleted: false, query: 'VW golf').single['id'],
      '1',
    );
    expect(filterChatInbox(rows, deleted: false, query: 'BMW'), isEmpty);
    expect(
      filterChatInbox(rows, deleted: true, query: 'marta').single['id'],
      '2',
    );
  });
  test(
    'service uses public peer identity and action does not accept an actor ID',
    () async {
      requests.clear();
      final service = ChatInboxService(Supabase.instance.client);
      final rows = await service.load(noPhoto);
      expect(rows.single['vehicle_title'], 'Volkswagen Golf');
      expect(rows.single['participant_name'], 'Motor Empresa');
      expect(requests.any((r) => r.url.path.endsWith('/user_profiles')), false);
      await service.action('7', 'hide');
      final payload = jsonDecode(requests.last.body) as Map;
      expect(payload, {'p_conversation_id': '7', 'p_action': 'hide'});
      await expectLater(
        service.action('7', 'delete_everyone'),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'delete requires confirmation, supports undo and can be recovered from deleted tab',
    (t) async {
      final service = FakeInbox();
      await t.pumpWidget(
        app(
          ChatInboxPage(
            service: service,
            loadPhoto: noPhoto,
            openChat: (_, __) async {},
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('chat-inbox-menu-1')));
      await t.pumpAndSettle();
      await t.tap(find.text('Eliminar conversación'));
      await t.pumpAndSettle();
      expect(service.actions, isEmpty);
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      expect(find.text('Volkswagen Golf'), findsOneWidget);
      await t.tap(find.byKey(const Key('chat-inbox-menu-1')));
      await t.pumpAndSettle();
      await t.tap(find.text('Eliminar conversación'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('confirm-personal-chat-delete')));
      await t.pumpAndSettle();
      expect(service.actions, ['1:hide']);
      expect(find.text('Volkswagen Golf'), findsNothing);
      await t.tap(find.text('Deshacer'));
      await t.pumpAndSettle();
      expect(find.text('Volkswagen Golf'), findsOneWidget);
      service.rows[0]['deleted'] = true;
      await t.tap(find.byTooltip('Actualizar mensajes'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Ver eliminadas'));
      await t.pumpAndSettle();
      expect(find.text('Volkswagen Golf'), findsOneWidget);
      expect(find.text('BMW Serie 3'), findsNothing);
      await t.tap(find.byKey(const Key('chat-inbox-menu-1')));
      await t.pumpAndSettle();
      await t.tap(find.text('Recuperar conversación'));
      await t.pumpAndSettle();
      expect(find.text('Volkswagen Golf'), findsNothing);
      await t.tap(find.byTooltip('Volver a mis mensajes'));
      await t.pumpAndSettle();
      expect(find.text('Volkswagen Golf'), findsOneWidget);
    },
  );
  testWidgets(
    'pin sorts the important chat first and search filters local public names',
    (t) async {
      final service = FakeInbox();
      await t.pumpWidget(
        app(
          ChatInboxPage(
            service: service,
            loadPhoto: noPhoto,
            openChat: (_, __) async {},
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('chat-inbox-menu-2')));
      await t.pumpAndSettle();
      await t.tap(find.text('Fijar conversación'));
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(find.byKey(const Key('chat-inbox-2'))).dy,
        lessThan(t.getTopLeft(find.byKey(const Key('chat-inbox-1'))).dy),
      );
      await t.enterText(find.byType(TextField), 'Omar');
      await t.pumpAndSettle();
      expect(find.text('Volkswagen Golf'), findsOneWidget);
      expect(find.text('BMW Serie 3'), findsNothing);
      expect(find.text('¿Podemos ver el coche mañana?'), findsOneWidget);
    },
  );
  testWidgets('failed deletion keeps the conversation visible', (t) async {
    final service = FakeInbox()..fail = true;
    await t.pumpWidget(
      app(
        ChatInboxPage(
          service: service,
          loadPhoto: noPhoto,
          openChat: (_, __) async {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('chat-inbox-menu-1')));
    await t.pumpAndSettle();
    await t.tap(find.text('Eliminar conversación'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('confirm-personal-chat-delete')));
    await t.pumpAndSettle();
    expect(find.text('Volkswagen Golf'), findsOneWidget);
    expect(service.actions, isEmpty);
    expect(
      find.text('No se pudo actualizar la conversación. Vuelve a intentarlo.'),
      findsOneWidget,
    );
  });
  for (final locale in ['es', 'en', 'ca'])
    for (final scale in [1.0, 2.0])
      testWidgets(
        'inbox and prominent plans fit small screens in $locale at $scale',
        (t) async {
          await t.binding.setSurfaceSize(const Size(320, 700));
          addTearDown(() => t.binding.setSurfaceSize(null));
          await t.pumpWidget(
            app(
              ChatInboxPage(
                service: FakeInbox(),
                loadPhoto: noPhoto,
                openChat: (_, __) async {},
              ),
              locale: locale,
              scale: scale,
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          var opened = false;
          await t.pumpWidget(
            app(
              Scaffold(
                body: SingleChildScrollView(
                  child: MarketPlansHighlight(onOpen: () => opened = true),
                ),
              ),
              locale: locale,
              scale: scale,
            ),
          );
          await t.pumpAndSettle();
          await Scrollable.ensureVisible(
            t.element(find.byType(FilledButton)),
            alignment: .5,
          );
          await t.pumpAndSettle();
          await t.tap(find.byType(FilledButton));
          expect(opened, true);
          expect(t.takeException(), isNull);
        },
      );
}
