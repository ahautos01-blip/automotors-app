import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:automotors_base/services/account_session_guard.dart';
import 'package:automotors_base/community_moderation_page.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/l10n/ui_text.dart';

void main() {
  test('only confirmed suspension signs out and notifies', () async {
    var signedOut = 0, notified = 0;
    final guard = AccountSessionGuard(
      sessionKey: () => 'fixture',
      isSuspended: () async => true,
      signOut: () async {
        signedOut++;
      },
      onSuspended: () => notified++,
    );
    await guard.check();
    expect(signedOut, 1);
    expect(notified, 1);
    guard.dispose();
  });
  test('offline or active account is never labelled suspended', () async {
    for (final fails in [true, false]) {
      final guard = AccountSessionGuard(
        sessionKey: () => 'fixture',
        isSuspended: () async {
          if (fails) throw Exception('offline');
          return false;
        },
        signOut: () async => fail('must not sign out'),
        onSuspended: () => fail('must not notify'),
      );
      await guard.check();
      guard.dispose();
    }
  });
  test(
    'a changed session cannot be signed out by the previous response',
    () async {
      String? session = 'old';
      final result = Completer<bool>();
      final guard = AccountSessionGuard(
        sessionKey: () => session,
        isSuspended: () => result.future,
        signOut: () async => fail('wrong session'),
        onSuspended: () => fail('wrong session'),
      );
      final pending = guard.check();
      session = 'new';
      result.complete(true);
      await pending;
      guard.dispose();
    },
  );
  test(
    'no request without a session; disposal ignores late responses',
    () async {
      String? session;
      var calls = 0;
      final result = Completer<bool>();
      final guard = AccountSessionGuard(
        sessionKey: () => session,
        isSuspended: () {
          calls++;
          return result.future;
        },
        signOut: () async => fail('disposed'),
        onSuspended: () => fail('disposed'),
      );
      await guard.check();
      expect(calls, 0);
      session = 'fixture';
      final pending = guard.check();
      guard.dispose();
      result.complete(true);
      await pending;
      expect(calls, 1);
    },
  );
  test(
    'confirmed suspension clears views even when logout request fails',
    () async {
      var notified = 0;
      final guard = AccountSessionGuard(
        sessionKey: () => 'fixture',
        isSuspended: () async => true,
        signOut: () async => throw Exception('offline logout'),
        onSuspended: () => notified++,
      );
      await guard.check();
      expect(notified, 1);
      guard.dispose();
    },
  );
  test(
    'a new session during signout is not replaced by the old notice',
    () async {
      var session = 'old';
      var notified = 0;
      final guard = AccountSessionGuard(
        sessionKey: () => session,
        isSuspended: () async => true,
        signOut: () async {
          session = 'new';
        },
        onSuspended: () => notified++,
      );
      await guard.check();
      expect(notified, 0);
      guard.dispose();
    },
  );
  for (final language in ['es', 'en', 'ca']) {
    testWidgets('suspension confirmation requires a reason in $language', (
      t,
    ) async {
      String? saved;
      await t.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await showDialog<String>(
                    context: context,
                    builder: (_) =>
                        const ModerationActionDialog(action: 'suspend_account'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('confirm-moderation-action')));
      await t.pumpAndSettle();
      expect(
        find.text(
          translateUiMessage('Escribe el motivo de la acción.', language),
        ),
        findsOneWidget,
      );
      expect(saved, isNull);
      await t.enterText(find.byType(TextField), 'Reviewed abusive content');
      await t.tap(find.byKey(const Key('confirm-moderation-action')));
      await t.pumpAndSettle();
      expect(saved, 'Reviewed abusive content');
      expect(t.takeException(), isNull);
    });
  }
}
