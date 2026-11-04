import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:automotors_base/main.dart';
import 'package:automotors_base/design/market_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final dir = Platform.environment['AUTOMOTORS_VISUAL_FONT_DIR'];
    if (dir != null) {
      final loader = FontLoader('Roboto')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File('$dir/roboto-regular.ttf').readAsBytes(),
            ),
          ),
        );
      await loader.load();
    }
  });
  for (final label in ['C', 'B', 'ECO', 'CERO']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$label stays square in stretched emissions column at $scale',
        (t) async {
          await t.binding.setSurfaceSize(const Size(390, 400));
          addTearDown(() => t.binding.setSurfaceSize(null));
          await t.pumpWidget(
            MaterialApp(
              theme: automotorsMarketTheme(),
              home: RepaintBoundary(
                key: Key('proof'),
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('EMISIONES'),
                          const SizedBox(height: 16),
                          EnvironmentalSticker(label: label, size: 72),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(
            t.getSize(find.byKey(const Key('environmental-sticker-disc'))),
            const Size(72, 72),
          );
          expect(t.takeException(), isNull);
          if (label == 'ECO' &&
              scale == 2 &&
              Platform.environment['AUTOMOTORS_VISUAL_PROOF'] != null) {
            await t.runAsync(() async {
              final boundary = t.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('proof')),
              );
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(Platform.environment['AUTOMOTORS_VISUAL_PROOF']!)
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        },
      );
    }
  }
}
