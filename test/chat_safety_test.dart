import 'dart:async';

import 'package:automotors_base/chat_safety_controls.dart';
import 'package:automotors_base/community_moderation_page.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/l10n/ui_text.dart';
import 'package:automotors_base/services/chat_safety_controller.dart';
import 'package:automotors_base/services/community_moderation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget localized(String language, Widget page) => MaterialApp(
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: page,
);
void main() {
  test(
    'chat fails closed, preserves blocks and recovers after a failed request',
    () async {
      var blocked = false, fail = false, duplicate = false;
      final calls = <String>[];
      final controller = ChatSafetyController(
        conversationId: '123',
        request: (id, action, {reason, details}) async {
          expect(id, '123');
          calls.add(action);
          if (fail) throw StateError('offline');
          if (action == 'block') blocked = true;
          if (action == 'unblock') blocked = false;
          return {
            'blocked_by_me': blocked,
            'messaging_allowed': !blocked,
            if (action == 'report') 'report_created': !duplicate,
          };
        },
      );
      addTearDown(controller.dispose);
      expect(controller.canMessage, false);
      expect(await controller.load(), true);
      expect(controller.canMessage, true);
      await controller.setBlocked(true);
      expect(controller.canMessage, false);
      expect(controller.blockedByMe, true);
      expect(await controller.report('fraud', 'Literal {0}'), true);
      expect(controller.lastReportCreated, true);
      duplicate = true;
      await controller.report('fraud', 'Other');
      expect(controller.lastReportCreated, false);
      fail = true;
      expect(await controller.setBlocked(false), false);
      expect(controller.canMessage, false);
      expect(controller.blockedByMe, true);
      fail = false;
      await controller.setBlocked(false);
      expect(controller.canMessage, true);
      expect(calls, [
        'status',
        'block',
        'report',
        'report',
        'unblock',
        'unblock',
      ]);
    },
  );
  test(
    'pending requests cannot notify a disposed controller or enable chat',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      final controller = ChatSafetyController(
        conversationId: '1',
        request: (id, action, {reason, details}) => pending.future,
      );
      final request = controller.load();
      expect(controller.busy, true);
      expect(await controller.setBlocked(true), false);
      controller.dispose();
      pending.complete({'blocked_by_me': false, 'messaging_allowed': true});
      expect(await request, false);
    },
  );
  test('malformed server data never grants messaging access', () async {
    final controller = ChatSafetyController(
      conversationId: '1',
      request: (id, action, {reason, details}) async => {
        'messaging_allowed': 'true',
      },
    );
    expect(await controller.load(), false);
    expect(controller.canMessage, false);
    expect(controller.failed, true);
    controller.dispose();
  });
  test(
    'moderation service preserves pagination and exact action identifiers',
    () async {
      final requests = <Map<String, dynamic>>[];
      final service = CommunityModerationService(
        request: (name, args) async {
          requests.add({'name': name, ...args});
          if (name == 'community_reports') return <dynamic>[];
          if (name == 'community_report_messages') return <dynamic>[];
          return <String, dynamic>{};
        },
      );
      final cursor = {
        'created_at': '2026-11-01T20:00:00Z',
        'id': 'id',
        'kind': 'chat',
      };
      await service.reports(before: cursor, includeClosed: true);
      await service.review('chat', 'report-id', 'restrict_chat', 'Note {1}');
      expect(requests[0], {
        'name': 'community_reports',
        'p_before_created': cursor['created_at'],
        'p_before_id': 'id',
        'p_before_kind': 'chat',
        'p_include_closed': true,
      });
      expect(requests[1], {
        'name': 'community_review_report',
        'p_kind': 'chat',
        'p_id': 'report-id',
        'p_action': 'restrict_chat',
        'p_note': 'Note {1}',
      });
    },
  );
  testWidgets('moderation entry is hidden without server authorization', (
    tester,
  ) async {
    final calls = <String>[];
    final service = CommunityModerationService(
      request: (name, args) async {
        calls.add(name);
        return false;
      },
    );
    await tester.pumpWidget(
      localized('es', Scaffold(body: ModerationEntry(service: service))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Administración'), findsNothing);
    expect(calls, ['community_moderation_access']);
  });
  testWidgets('administration entry opens only after server authorization', (
    tester,
  ) async {
    final service = CommunityModerationService(
      request: (name, args) async =>
          name == 'community_moderation_access' ? true : [],
    );
    await tester.pumpWidget(
      localized('es', Scaffold(body: ModerationEntry(service: service))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Administración'), findsOneWidget);
    await tester.tap(find.text('Administración'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityModerationPage), findsOneWidget);
  });
  for (final language in ['es', 'en', 'ca']) {
    String tr(String source) => translateUiMessage(source, language);
    testWidgets(
      'block requires confirmation and updates the banner in $language',
      (tester) async {
        var blocked = false;
        final calls = <String>[];
        final controller = ChatSafetyController(
          conversationId: '123',
          request: (id, action, {reason, details}) async {
            calls.add(action);
            if (action == 'block') blocked = true;
            if (action == 'unblock') blocked = false;
            return {'blocked_by_me': blocked, 'messaging_allowed': !blocked};
          },
        );
        addTearDown(controller.dispose);
        await controller.load();
        await tester.binding.setSurfaceSize(const Size(320, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          localized(
            language,
            Scaffold(
              appBar: AppBar(
                actions: [ChatSafetyControls(controller: controller)],
              ),
              body: ChatSafetyBanner(controller: controller),
            ),
          ),
        );
        await tester.tap(find.byTooltip(tr('Seguridad del chat')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(tr('Bloquear usuario')));
        await tester.pumpAndSettle();
        expect(calls, ['status']);
        await tester.tap(find.text(tr('Cancelar')));
        await tester.pumpAndSettle();
        expect(blocked, false);
        await tester.tap(find.byTooltip(tr('Seguridad del chat')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(tr('Bloquear usuario')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm-chat-block')));
        await tester.pumpAndSettle();
        expect(controller.canMessage, false);
        expect(calls, ['status', 'block']);
        expect(
          find.text(
            tr(
              'Has bloqueado a este usuario. Puedes desbloquearlo desde el menú del chat.',
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'report requires a reason and preserves user text in $language',
      (tester) async {
        ChatReportDraft? submitted;
        await tester.binding.setSurfaceSize(const Size(320, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          localized(
            language,
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    submitted = await showDialog<ChatReportDraft>(
                      context: context,
                      builder: (_) => const ChatReportDialog(),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('send-chat-report')));
        await tester.pumpAndSettle();
        expect(find.text(tr('Selecciona un motivo')), findsOneWidget);
        expect(submitted, isNull);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(tr('Posible fraude')).last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'Mi texto {1} / original',
        );
        await tester.tap(find.byKey(const Key('send-chat-report')));
        await tester.pumpAndSettle();
        expect(submitted?.reason, 'fraud');
        expect(submitted?.details, 'Mi texto {1} / original');
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'moderator must confirm an action before it is saved in $language',
      (tester) async {
        final actions = <Map<String, dynamic>>[];
        Map<String, dynamic> data(bool restricted) => {
          'id': 'report-id',
          'kind': 'chat',
          'reason': 'harassment',
          'details': 'Original report {0}',
          'status': 'pending',
          'messages': [
            {
              'id': 1,
              'body': 'Original user message',
              'created_at': '2026-11-01T20:00:00Z',
              'sender_role': 'reported',
            },
          ],
          'chat_restricted': restricted,
          'history': <dynamic>[],
        };
        final service = CommunityModerationService(
          request: (name, args) async {
            if (name == 'community_report_detail') return data(false);
            if (name == 'community_review_report') {
              actions.add(args);
              return data(true);
            }
            throw StateError(name);
          },
        );
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          localized(
            language,
            CommunityReportPage(
              kind: 'chat',
              reportId: 'report-id',
              service: service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Original user message'), findsOneWidget);
        final restrict = find.text(tr('Restringir chat del usuario'));
        await tester.ensureVisible(restrict);
        await tester.tap(restrict);
        await tester.pumpAndSettle();
        expect(actions, isEmpty);
        await tester.tap(find.text(tr('Cancelar')));
        await tester.pumpAndSettle();
        expect(actions, isEmpty);
        await tester.tap(restrict);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Reviewed {2}');
        await tester.tap(find.byKey(const Key('confirm-moderation-action')));
        await tester.pumpAndSettle();
        expect(actions, [
          {
            'p_kind': 'chat',
            'p_id': 'report-id',
            'p_action': 'restrict_chat',
            'p_note': 'Reviewed {2}',
          },
        ]);
        expect(find.text(tr('Retirar restricción del chat')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
