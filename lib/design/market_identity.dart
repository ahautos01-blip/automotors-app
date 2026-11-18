import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

/// The compact brand introduction leaves room for search and real inventory.
class MarketDiscoveryHeading extends StatelessWidget {
  const MarketDiscoveryHeading({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 25, height: 3, color: marketGold),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                uiText(context, 'ENCUENTRA. COMPARA. CONECTA.'),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: marketAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            uiText(context, 'Tu próximo vehículo empieza aquí.'),
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 27),
          ),
        ),
      ],
    ),
  );
}

/// Decorative fallback, never presented as a photograph or verification badge.
class MarketCoverBackdrop extends StatelessWidget {
  const MarketCoverBackdrop({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [marketInk, Color(0xFF3C5147)],
        ),
      ),
      child: CustomPaint(painter: _CoverLines()),
    ),
  );
}

class _CoverLines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = marketGold.withValues(alpha: .24)
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final x = size.width * .5 + i * 30;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoverLines oldDelegate) => false;
}
