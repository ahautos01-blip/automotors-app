import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// A local image containing only the public listing summary supplied by the caller.
Future<Uint8List> listingShareCard({
  required String title,
  required String price,
  required String details,
  required String link,
  Uint8List? photo,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  const width = 1080.0;
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, width, 1080),
    ui.Paint()..color = const ui.Color(0xFFF7F5EE),
  );
  ui.Image? image;
  try {
    if (photo != null) {
      try {
        final codec = await ui.instantiateImageCodec(photo, targetWidth: 1200);
        try {
          image = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      } catch (_) {
        image = null;
      }
      if (image != null)
        paintImage(
          canvas: canvas,
          rect: const ui.Rect.fromLTWH(0, 130, width, 570),
          image: image!,
          fit: BoxFit.cover,
        );
    }
    void line(
      String value,
      double top,
      double size,
      ui.Color color, {
      int maxLines = 1,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontSize: size,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: 984);
      painter.paint(canvas, ui.Offset(48, top));
      painter.dispose();
    }

    const ink = ui.Color(0xFF21372E), gold = ui.Color(0xFF876A22);
    line('AUTOMOTORS', 35, 48, ink);
    if (image == null) line(title, 300, 70, ink, maxLines: 3);
    line(title, 730, 49, ink, maxLines: 2);
    line(price, 850, 64, gold);
    line(details, 940, 30, ink);
    line(link, 1008, 24, gold);
    final picture = recorder.endRecording();
    try {
      final result = await picture.toImage(1080, 1080);
      try {
        return (await result.toByteData(format: ui.ImageByteFormat.png))!.buffer
            .asUint8List();
      } finally {
        result.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    image?.dispose();
  }
}
