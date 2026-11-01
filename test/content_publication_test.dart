import 'package:flutter/material.dart';
import 'package:automotors_base/community_moderation_page.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/services/community_moderation_service.dart';
import 'package:automotors_base/services/content_publication_service.dart';
import 'package:automotors_base/l10n/ui_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publication requires an explicit verified approval', () {
    for (final data in <Map<String, dynamic>>[
      {},
      {'published': true},
      {'published': true, 'state': 'rejected'},
      {'state': 'approved'},
      {'state': 'approved', 'published': 'true'},
    ]) {
      expect(ContentPublicationResult.fromJson(data).published, false);
    }
    expect(
      ContentPublicationResult.fromJson({
        'state': 'approved',
        'published': true,
      }).published,
      true,
    );
  });
  test(
    'provider errors preserve the draft and never grant publication',
    () async {
      final service = ContentPublicationService(
        request: (body) async => throw StateError('offline'),
      );
      final result = await service.publish('listing');
      expect(result.published, false);
      expect(result.message, contains('garaje'));
    },
  );
  test(
    'only listing identity and requested publication state reach the server',
    () async {
      Map<String, dynamic>? request;
      final service = ContentPublicationService(
        request: (body) async {
          request = body;
          return {'published': true, 'state': 'approved'};
        },
      );
      expect(
        (await service.publish(
          'owned-listing',
          targetStatus: 'reserved',
        )).published,
        true,
      );
      expect(request, {
        'action': 'publish',
        'listing_id': 'owned-listing',
        'target_status': 'reserved',
      });
    },
  );
  test('every non-publication result has localized guidance in English and Catalan', () {
    for (final result in [
      const ContentPublicationResult(published: false, state: 'rejected'),
      const ContentPublicationResult(published: false, state: 'changed'),
      const ContentPublicationResult(
        published: false,
        state: 'error',
        errorCode: 'publication_limit',
      ),
      const ContentPublicationResult(
        published: false,
        state: 'error',
        errorCode: 'unsupported_image',
      ),
      const ContentPublicationResult(published: false, state: 'error'),
    ]) {
      expect(translateUiMessage(result.message, 'en'), isNot(result.message));
      expect(translateUiMessage(result.message, 'ca'), isNot(result.message));
    }
    for (final state in ['processing', 'rejected', 'error', 'changed']) {
      final message = listingContentStateMessage(state);
      expect(translateUiMessage(message, 'en'), isNot(message));
      expect(translateUiMessage(message, 'ca'), isNot(message));
    }
  });
  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'reviewed publication binds approval to the displayed fingerprint in $language',
      (tester) async {
        final calls = <Map<String, dynamic>>[];
        Map<String, dynamic> data(String automatic) => {
          'id': 'report',
          'kind': 'listing',
          'reason': 'Contenido inapropiado',
          'details': 'Original report',
          'status': 'pending',
          'listing': {
            'year': 2020,
            'version': 'Example',
            'price': 10000,
            'description': 'Original ad',
          },
          'photos': <dynamic>[],
          'listing_held': false,
          'chat_restricted': false,
          'automatic_state': automatic,
          'automatic_fingerprint': 'reviewed-hash',
          'history': <dynamic>[],
        };
        final service = CommunityModerationService(
          request: (name, args) async {
            if (name == 'community_report_detail') return data('rejected');
            if (name == 'community_approve_publication') {
              calls.add(args);
              return data('approved');
            }
            throw StateError(name);
          },
        );
        await tester.binding.setSurfaceSize(const Size(320, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: CommunityReportPage(
              kind: 'listing',
              reportId: 'report',
              service: service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final approval = find.text(
          translateUiMessage(
            'Aprobar publicación tras revisar el contenido',
            language,
          ),
        );
        await tester.ensureVisible(approval);
        await tester.tap(approval);
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
        await tester.tap(find.text(translateUiMessage('Cancelar', language)));
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
        await tester.tap(approval);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Reviewed {1}');
        await tester.tap(find.byKey(const Key('confirm-moderation-action')));
        await tester.pumpAndSettle();
        expect(calls, [
          {
            'p_report_id': 'report',
            'p_expected_fingerprint': 'reviewed-hash',
            'p_note': 'Reviewed {1}',
          },
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
