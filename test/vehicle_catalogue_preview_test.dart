import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:automotors_base/main.dart';
import 'package:automotors_base/design/vehicle_categories.dart';
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
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'com.llfbandit.app_links/events',
      'com.llfbandit.app_links/messages',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (r) async => http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        ),
      ),
    );
  });
  testWidgets('four categories precede the homepage editorial header', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final path = Platform.environment['CATALOGUE_PREVIEW_PATH'];
    if (path != null) {
      await tester.runAsync(() async {
        for (final name in ['CataloguePreview', 'Ahem']) {
          final f = FontLoader(name)
            ..addFont(
              File('C:/Windows/Fonts/segoeui.ttf')
                  .readAsBytes()
                  .then(ByteData.sublistView),
            );
          await f.load();
        }
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            File(
              'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          );
        await icons.load();
      });
    }
    final key = GlobalKey(), theme = automotorsMarketTheme();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: path == null
              ? theme
              : theme.copyWith(
                  chipTheme: theme.chipTheme.copyWith(labelStyle: theme.chipTheme.labelStyle?.copyWith(fontFamily:'CataloguePreview')),
                  appBarTheme:theme.appBarTheme.copyWith(titleTextStyle:theme.appBarTheme.titleTextStyle?.copyWith(fontFamily:'CataloguePreview')),
                  textTheme: theme.textTheme.apply(
                    fontFamily: 'CataloguePreview',
                  ),
                  outlinedButtonTheme:OutlinedButtonThemeData(style:theme.outlinedButtonTheme.style?.copyWith(textStyle:const WidgetStatePropertyAll(TextStyle(fontFamily:'CataloguePreview',fontWeight:FontWeight.w600)))),
                  textButtonTheme:TextButtonThemeData(style:TextButton.styleFrom(textStyle:const TextStyle(fontFamily:'CataloguePreview',fontWeight:FontWeight.w600))),
                  primaryTextTheme: theme.primaryTextTheme.apply(
                    fontFamily: 'CataloguePreview',
                  ),
                ),
          home: const HomePage(),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byType(VehicleCategoryPicker)).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('market-search-hero'))).dy,
      ),
    );
    for (final category in ['car', 'motorcycle', 'truck', 'boat'])
      expect(
        find.byKey(ValueKey('category-$category')).hitTestable(),
        findsOneWidget,
      );
    expect(tester.takeException(), isNull);
    if (path != null) {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.scrollUntilVisible(find.byKey(const Key('home-publish-vehicle')), 400,
      scrollable: find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    final publish = find.byKey(const Key('home-publish-vehicle'));
    expect(publish.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(publish).dy,
      lessThan(tester.getTopLeft(find.byType(NavigationBar)).dy));
    await tester.tap(publish);
    await tester.pumpAndSettle();
    expect(find.byType(PublishOptionsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(() => Supabase.instance.dispose());
  });
}
