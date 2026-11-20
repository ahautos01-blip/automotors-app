import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:automotors_base/chat_inbox_page.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:automotors_base/main.dart';
import 'package:automotors_base/services/chat_inbox_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _EmptyInbox extends ChatInboxService {
  _EmptyInbox(super.client);
  @override
  RealtimeChannel? watch(void Function() changed) => null;
  @override
  Future<List<Map<String, dynamic>>> load(
    Future<Uint8List> Function(String) loadPhoto,
  ) async => [];
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (_) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets('detail and inbox retain shared chrome and accessible actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final path = Platform.environment['IOS_DETAIL_PREVIEW_PATH'];
    if (path != null)
      await tester.runAsync(() async {
        for (final family in [
          'Preview',
          'Ahem',
          'Roboto',
          '.SF UI Text',
          '.SF UI Display',
          'CupertinoSystemText',
          'CupertinoSystemDisplay',
        ]) {
          await (FontLoader(family)..addFont(
                File('C:/Windows/Fonts/segoeui.ttf')
                    .readAsBytes()
                    .then(ByteData.sublistView),
              ))
              .load();
        }
        await (FontLoader('MaterialIcons')..addFont(
              File(
                'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      });
    final base = automotorsMarketTheme();
    final theme = path == null
        ? base
        : base.copyWith(
            textTheme: base.textTheme.apply(fontFamily: 'Preview'),
            appBarTheme: base.appBarTheme.copyWith(
              titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
                fontFamily: 'Preview',
              ),
            ),
            chipTheme: base.chipTheme.copyWith(
              labelStyle: base.chipTheme.labelStyle?.copyWith(
                fontFamily: 'Preview',
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: base.filledButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'Preview', fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
    for (final screen in ['detail', 'inbox']) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            locale: const Locale('es'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: screen == 'detail'
                ? CarDetailsPage(
                    car: const Car(
                      brand: 'Vehículo',
                      model: 'de ejemplo',
                      year: 2022,
                      km: 35000,
                      price: 24000,
                      fuel: 'Gasolina',
                      description: 'Datos de muestra para revisar el diseño.',
                      phone: '',
                    ),
                    priceText: '24.000 €',
                    onContact: () {},
                  )
                : ChatInboxPage(
                    service: _EmptyInbox(Supabase.instance.client),
                    loadPhoto: (_) async => Uint8List(0),
                    openChat: (_, __) async {},
                  ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (path != null)
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$path-$screen.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
