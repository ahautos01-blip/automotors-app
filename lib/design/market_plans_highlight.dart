import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

class MarketPlansHighlight extends StatelessWidget {
  final VoidCallback onOpen;
  const MarketPlansHighlight({super.key, required this.onOpen});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(7),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        key: const Key('home-plans-highlight'),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
        child: Row(
          children: [
            const Icon(Icons.diamond_outlined, color: marketGold, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uiText(context, 'Packs y suscripción'),
                    style: const TextStyle(
                      color: marketInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    uiText(
                      context,
                      'Elige tu plan para publicar y destacar tus vehículos.',
                    ),
                    style: const TextStyle(
                      color: marketMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.north_east, color: marketGold, size: 20),
          ],
        ),
      ),
    ),
  );
}
