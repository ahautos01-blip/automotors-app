import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';

class ActiveMarketFilters extends StatelessWidget {
  const ActiveMarketFilters({
    super.key,
    required this.filters,
    required this.onClear,
  });
  final List<MapEntry<String, VoidCallback>> filters;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => filters.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                uiText(context, 'Filtros aplicados'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in filters)
                    InputChip(
                      label: Text(filter.key),
                      onDeleted: filter.value,
                      deleteButtonTooltipMessage: uiText(
                        context,
                        'Quitar filtro',
                      ),
                    ),
                  TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: Text(uiText(context, 'Quitar todos los filtros')),
                  ),
                ],
              ),
            ],
          ),
        );
}
