import 'package:automotors_base/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:automotors_base/terms_acceptance_field.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/l10n/ui_text.dart';
import 'package:automotors_base/services/community_visibility.dart';

void main() {
  for (final language in ['es', 'en', 'ca']) {
    testWidgets('terms require deliberate acceptance in $language', (t) async {
      final form = GlobalKey<FormState>();
      await t.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Form(key: form, child: const TermsAcceptanceField()),
          ),
        ),
      );
      expect(form.currentState!.validate(), false);
      await t.pump();
      expect(
        find.text(
          translateUiMessage(
            'Debes aceptar las condiciones de uso para continuar.',
            language,
          ),
        ),
        findsOneWidget,
      );
      await t.tap(find.byType(Checkbox));
      await t.pump();
      expect(form.currentState!.validate(), true);
      await t.tap(find.byType(Checkbox));
      await t.pump();
      expect(form.currentState!.validate(), false);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('login and signup cannot submit before accepting terms', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const LoginPage(initialEmail: 'person@example.test'),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(1), 'fixture-password');
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await t.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await t.pumpAndSettle();
    expect(
      find.text('Debes aceptar las condiciones de uso para continuar.'),
      findsOneWidget,
    );
    await t.ensureVisible(find.text('¿No tienes cuenta? Crear cuenta'));
    await t.tap(find.text('¿No tienes cuenta? Crear cuenta'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await t.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await t.pumpAndSettle();
    expect(
      find.text('Debes aceptar las condiciones de uso para continuar.'),
      findsOneWidget,
    );
    // No Supabase initialization: neither unauthorised form reaches the API.
    expect(t.takeException(), isNull);
  });
  test('immediate visibility is isolated by viewer and reversible', () {
    final state = CommunityVisibility();
    var changes = 0;
    state.addListener(() => changes++);
    state.record(viewer: 'one', seller: 'seller', blocked: true);
    expect(state.hides('one', 'seller'), true);
    expect(state.hides('two', 'seller'), false);
    expect(state.hides(null, 'seller'), false);
    state.record(viewer: 'one', seller: 'seller', blocked: true);
    expect(changes, 1);
    state.record(viewer: 'one', seller: 'seller', blocked: false);
    expect(state.hides('one', 'seller'), false);
    expect(changes, 2);
    state.dispose();
  });
}
