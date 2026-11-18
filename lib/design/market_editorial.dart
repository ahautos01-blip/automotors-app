import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

class MarketEditorialIntro extends StatelessWidget {
  const MarketEditorialIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.photo,
    this.plain = false,
  });
  final String eyebrow, title;
  final String? subtitle;
  final Uint8List? photo;
  final bool plain;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(plain ? 0 : 20),
    child: Stack(
      children: [
        if (photo != null)
          Positioned.fill(
            child: Image.memory(
              photo!,
              fit: BoxFit.cover,
              cacheWidth: 1000,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => const ColoredBox(color: marketInk),
            ),
          ),
        Container(
          width: double.infinity,
          padding: plain
              ? const EdgeInsets.fromLTRB(0, 12, 0, 24)
              : const EdgeInsets.fromLTRB(22, 28, 22, 30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                plain
                    ? marketPaper
                    : marketInk.withValues(alpha: photo == null ? 1 : .94),
                plain
                    ? marketPaper
                    : marketInk.withValues(alpha: photo == null ? 1 : .8),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                uiText(context, eyebrow),
                style: TextStyle(
                  color: plain ? marketAccent : const Color(0xFFE2CC8B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                uiText(context, title),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: plain ? marketInk : Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.13,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  uiText(context, subtitle!),
                  style: TextStyle(
                    color: plain ? marketMuted : const Color(0xFFE1E7DF),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class MarketPublicationSteps extends StatelessWidget {
  const MarketPublicationSteps({
    super.key,
    required this.current,
    required this.onSelect,
    this.enabled = true,
  });
  final int current;
  final ValueChanged<int> onSelect;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in const [
          'Vehículo',
          'Fotos',
          'Revisión',
        ].asMap().entries)
          ChoiceChip(
            selected: current == entry.key,
            showCheckmark: false,
            avatar: CircleAvatar(
              radius: 11,
              backgroundColor: current == entry.key
                  ? marketSurface
                  : marketTint,
              child: Text(
                '${entry.key + 1}',
                style: const TextStyle(fontSize: 11, color: marketInk),
              ),
            ),
            label: Text(uiText(context, entry.value)),
            selectedColor: marketInk,
            labelStyle: TextStyle(
              color: current == entry.key ? marketSurface : marketInk,
            ),
            onSelected: enabled ? (_) => onSelect(entry.key) : null,
          ),
      ],
    ),
  );
}
