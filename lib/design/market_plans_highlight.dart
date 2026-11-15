import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

class MarketPlansHighlight extends StatelessWidget {
  final VoidCallback onOpen;
  const MarketPlansHighlight({super.key, required this.onOpen});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onOpen,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      key: const Key('home-plans-highlight'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: marketInk,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: marketGold.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.diamond_outlined, color: marketGold, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  uiText(context, 'Packs y suscripción'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            uiText(
              context,
              'Elige tu plan para publicar y destacar tus vehículos.',
            ),
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: marketGold,
              foregroundColor: marketInk,
            ),
            icon: const Icon(Icons.arrow_forward),
            label: Text(uiText(context, 'Ver packs y suscripción')),
          ),
        ],
      ),
    ),
  );
}
