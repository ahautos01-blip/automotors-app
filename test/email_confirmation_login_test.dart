import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:automotors_base/main.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/l10n/ui_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final dir = Platform.environment['AUTOMOTORS_VISUAL_FONT_DIR'];
    if (dir != null) {
      for (final entry in {
        'Roboto': 'roboto-regular.ttf',
        'MaterialIcons': 'materialicons-regular.otf',
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File('$dir/${entry.value}').readAsBytes(),
              ),
            ),
          );
        await loader.load();
      }
    }
  });
  for (final language in ['es', 'en', 'ca']) {
    testWidgets('verified account shows login message in $language', (t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          theme: automotorsMarketTheme().copyWith(
            filledButtonTheme: FilledButtonThemeData(
              style: automotorsMarketTheme().filledButtonTheme.style!.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const RepaintBoundary(
            key: Key('proof'),
            child: LoginPage(
              initialMessage: 'Cuenta verificada. Ya puedes iniciar sesión.',
              initialEmail: 'verificado@example.test',
            ),
          ),
        ),
      );
      await t.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/automotors_app_icon.png'),
          t.element(find.byType(LoginPage)),
        );
      });
      await t.pumpAndSettle();
      expect(
        find.text(
          translateUiMessage(
            'Cuenta verificada. Ya puedes iniciar sesión.',
            language,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('verificado@example.test'), findsOneWidget);
      expect(
        find.text(
          translateUiMessage('Reenviar correo de verificación', language),
        ),
        findsNothing,
      );
      expect(find.text(translateUiMessage('He olvidado mi contraseña', language)), findsOneWidget);
      expect(t.takeException(), isNull);
      final proof = Platform.environment['AUTOMOTORS_VISUAL_PROOF'];
      if (language == 'es' && proof != null)
        await t.runAsync(() async {
          final image = await t
              .renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('proof')),
              )
              .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(proof).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
    });
  }
  testWidgets('invalid confirmation offers resend instead of success', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const LoginPage(
          initialMessage: 'No se pudo validar este enlace.',
          initialMessageIsError: true,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Reenviar correo de verificación'), findsOneWidget);
    expect(
      find.text('Cuenta verificada. Ya puedes iniciar sesión.'),
      findsNothing,
    );
  });
}
