import 'package:automotors_base/services/local_market_state.dart';
import 'package:automotors_base/design/market_chat_actions.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('serialized saves cannot restore a cleared draft', () async {
    final state = LocalMarketState();
    final first = state.write('draft.a', {'description': 'old'});
    final second = state.write('draft.a', {'description': 'new'});
    final clear = state.remove('draft.a');
    await Future.wait([first, second, clear]);
    expect(await state.read('draft.a'), isEmpty);
  });
  test('drafts remain separate for different accounts', () async {
    final state = LocalMarketState();
    await state.write('draft.a', {'description': 'A'});
    await state.write('draft.b', {'description': 'B'});
    expect((await state.read('draft.a'))['description'], 'A');
    expect((await state.read('draft.b'))['description'], 'B');
  });
  test('invalid local storage returns an empty state', () async {
    SharedPreferences.setMockInitialValues({
      'bad': '{invalid',
      'list': '[1,2]',
    });
    final state = LocalMarketState();
    expect(await state.read('bad'), isEmpty);
    expect(await state.read('list'), isEmpty);
  });
  for (final code in ['es', 'en', 'ca']) {
    testWidgets('quick replies compose editable text in $code', (tester) async {
      final composed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: MarketChatActions(enabled: true, onCompose: composed.add),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ActionChip).first);
      expect(composed, hasLength(1));
      expect(
        composed.single,
        code == 'es'
            ? '¿Sigue disponible?'
            : code == 'en'
            ? 'Is it still available?'
            : 'Encara està disponible?',
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('blocked chat cannot compose suggestions', (tester) async {
    final composed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketChatActions(enabled: false, onCompose: composed.add),
        ),
      ),
    );
    await tester.tap(find.byType(ActionChip).first);
    expect(composed, isEmpty);
    for (final chip in tester.widgetList<ActionChip>(find.byType(ActionChip))) {
      expect(chip.onPressed, isNull);
    }
  });
  testWidgets('cancelling a viewing proposal does not compose a message', (
    tester,
  ) async {
    final composed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketChatActions(enabled: true, onCompose: composed.add),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final visit = find.text('Suggest a viewing');
    await tester.drag(find.byType(ListView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(visit);
    await tester.pumpAndSettle();
    final dialog = find.byType(DatePickerDialog);
    expect(dialog, findsOneWidget);
    final cancel = MaterialLocalizations.of(tester.element(dialog))
        .cancelButtonLabel;
    await tester.tap(find.text(cancel));
    await tester.pumpAndSettle();
    expect(composed, isEmpty);
  });
}
