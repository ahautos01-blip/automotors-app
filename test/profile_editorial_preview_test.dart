import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:automotors_base/main.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:automotors_base/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/messages'),
          (_) async => null,
        );
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        dynamic body = [];
        if (request.url.path.endsWith('/public_seller_profiles'))
          body = {
            'id': 'preview-seller',
            'business_name': 'AUTOMOTORS',
            'account_type': 'empresa',
            'city': 'Mataró',
            'province': 'Barcelona',
          };
        if (request.url.path.endsWith('/seller_about_profiles'))
          body = {'about_us': ''};
        if (request.url.path.endsWith('/seller_trust_summary'))
          body = {'email_confirmed': false};
        if (request.url.path.endsWith('/seller_member_since')) body = null;
        return http.Response(
          jsonEncode(body),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  testWidgets(
    'public profile keeps one identity, honest empty statistics and accessible tabs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1150));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final previewPath = Platform.environment['PROFILE_PREVIEW_PATH'];
      if (previewPath != null) {
        await tester.runAsync(() async {
          final loader = FontLoader('ProfilePreview');
          loader.addFont(
            File('C:/Windows/Fonts/segoeui.ttf')
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)),
          );
          await loader.load();
          final fallback = FontLoader('Ahem');
          fallback.addFont(
            File('C:/Windows/Fonts/segoeui.ttf')
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)),
          );
          await fallback.load();
          final icons = FontLoader('MaterialIcons');
          icons.addFont(
            File(
              'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
          await icons.load();
        });
      }
      final key = GlobalKey();
      final theme = automotorsMarketTheme();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: previewPath == null
                ? theme
                : theme.copyWith(
                    appBarTheme: theme.appBarTheme.copyWith(titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(fontFamily:'ProfilePreview')),
                    chipTheme: theme.chipTheme.copyWith(labelStyle: theme.chipTheme.labelStyle?.copyWith(fontFamily:'ProfilePreview')),
                    textTheme: theme.textTheme.apply(
                      fontFamily: 'ProfilePreview',
                    ),
                    outlinedButtonTheme:OutlinedButtonThemeData(style:theme.outlinedButtonTheme.style?.copyWith(textStyle:const WidgetStatePropertyAll(TextStyle(fontFamily:'ProfilePreview',fontWeight:FontWeight.w600)))),
                  textButtonTheme:TextButtonThemeData(style:TextButton.styleFrom(textStyle:const TextStyle(fontFamily:'ProfilePreview',fontWeight:FontWeight.w600))),
                  primaryTextTheme: theme.primaryTextTheme.apply(
                      fontFamily: 'ProfilePreview',
                    ),
                    filledButtonTheme: FilledButtonThemeData(
                      style: theme.filledButtonTheme.style!.copyWith(
                        textStyle: const WidgetStatePropertyAll(
                          TextStyle(
                            fontFamily: 'ProfilePreview',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
            locale: const Locale('es'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const PublicSellerProfilePage(ownerId: 'preview-seller'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('professional-display-name')),
        findsOneWidget,
      );
      expect(find.text('AUTOMOTORS'), findsOneWidget);
      expect(find.text('Mataró, Barcelona'), findsOneWidget);
      expect(
        find.text('Este vendedor no tiene anuncios disponibles.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      if (previewPath != null) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(previewPath).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('Sobre nosotros'));
      await tester.tap(find.text('Sobre nosotros'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
