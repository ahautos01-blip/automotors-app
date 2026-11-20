import 'package:flutter/material.dart';

/// Vector speech bubble and telephone handset for the WhatsApp contact action.
class WhatsAppMark extends StatelessWidget {
  const WhatsAppMark({super.key, this.size = 25, this.color = Colors.white});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _WhatsAppPainter(color),
    ),
  );
}

class _WhatsAppPainter extends CustomPainter {
  const _WhatsAppPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final outline = Path()
      ..moveTo(4.2, 16.8)
      ..cubicTo(1.4, 12.5, 2.5, 6.9, 6.8, 4.2)
      ..cubicTo(11.1, 1.4, 16.7, 2.5, 19.4, 6.8)
      ..cubicTo(22.2, 11.1, 21.1, 16.7, 16.8, 19.4)
      ..cubicTo(13.9, 21.2, 10.2, 21.3, 7.2, 19.6)
      ..lineTo(2.8, 20.9)
      ..close();
    canvas.drawPath(
      outline,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.65
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final handset = Path()
      ..moveTo(7.7, 6.6)
      ..cubicTo(6.8, 6.6, 6.2, 7.5, 6.3, 8.6)
      ..cubicTo(6.5, 12.7, 11.2, 17.2, 15.1, 17.2)
      ..cubicTo(16.3, 17.2, 17.5, 16.3, 17.5, 15.2)
      ..lineTo(17.5, 14.6)
      ..lineTo(14.6, 13.2)
      ..lineTo(13.3, 14.6)
      ..cubicTo(11.5, 13.9, 10.1, 12.5, 9.3, 10.8)
      ..lineTo(10.4, 9.4)
      ..lineTo(9.1, 6.6)
      ..close();
    canvas.drawPath(handset, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WhatsAppPainter oldDelegate) =>
      oldDelegate.color != color;
}
