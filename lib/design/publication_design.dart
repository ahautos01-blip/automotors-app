import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

/// A visible price/capacity choice; selecting never starts a purchase.
class PublicationPlanChoice extends StatelessWidget {
  const PublicationPlanChoice({
    super.key,
    required this.name,
    required this.price,
    required this.capacity,
    required this.selected,
    required this.onTap,
    this.recommended = false,
  });
  final String name, price, capacity;
  final bool selected, recommended;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? marketInk : marketSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? marketGold : marketLine,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : marketInk,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 19,
                    color: selected ? marketGold : marketMuted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                price,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: selected ? Colors.white : marketInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                uiText(context, capacity),
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? const Color(0xFFE2E9E3) : marketMuted,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                uiText(context, recommended ? 'Más popular' : 'Ver ventajas'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? marketGold : marketAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PublicationHeading extends StatelessWidget {
  const PublicationHeading({
    super.key,
    required this.title,
    required this.subtitle,
  });
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 36, height: 3, color: marketGold),
        const SizedBox(height: 14),
        Text(
          uiText(context, title),
          style: const TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          uiText(context, subtitle),
          style: const TextStyle(
            color: marketMuted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    ),
  );
}
