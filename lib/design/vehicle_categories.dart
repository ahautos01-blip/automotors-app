import 'package:flutter/material.dart';

import '../services/vehicle_category.dart';
import '../l10n/ui_text.dart';
import 'market_theme.dart';

class VehicleCategoryPicker extends StatelessWidget {
  final VehicleCategory value;
  final ValueChanged<VehicleCategory>? onChanged;
  const VehicleCategoryPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  static IconData icon(VehicleCategory c) => switch (c) {
    VehicleCategory.car => Icons.directions_car_outlined,
    VehicleCategory.motorcycle => Icons.two_wheeler_outlined,
    VehicleCategory.truck => Icons.local_shipping_outlined,
    VehicleCategory.boat => Icons.sailing_outlined,
  };
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final c in VehicleCategory.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: ValueKey('category-${c.id}'),
              selected: c == value,
              avatar: Icon(
                icon(c),
                size: 20,
                color: c == value ? marketAccent : marketMuted,
              ),
              label: Text(uiText(context, c.label)),
              onSelected: onChanged == null ? null : (_) => onChanged!(c),
            ),
          ),
      ],
    ),
  );
}

class VehicleCategoryFields extends StatelessWidget {
  final VehicleCategory category;
  final Map<String, TextEditingController> controllers;
  const VehicleCategoryFields({
    super.key,
    required this.category,
    required this.controllers,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final field in category.fields.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            key: ValueKey('category-field-${field.key}'),
            controller: controllers[field.key],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  '${uiText(context, field.value)} (${uiText(context, 'Opcional')})',
            ),
            validator: (v) {
              final error = category.validate(field.key, v ?? '');
              if (error != null) return error;
              if (field.key == 'payload_kg') {
                final payload = num.tryParse(v ?? ''),
                    gross = num.tryParse(
                      controllers['gross_weight_kg']?.text ?? '',
                    );
                if (payload != null && gross != null && payload > gross)
                  return uiText(
                    context,
                    'La carga útil no puede superar la masa máxima',
                  );
              }
              return null;
            },
          ),
        ),
    ],
  );
}

class VehicleCategoryFilters extends StatelessWidget {
  final VehicleCategory category;
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const VehicleCategoryFilters({
    super.key,
    required this.category,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final field in category.fields.entries)
        for (final bound in ['min', 'max'])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              key: ValueKey('${category.id}-$bound-${field.key}'),
              initialValue: value['${bound}_${field.key}']?.toString() ?? '',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText:
                    '${uiText(context, field.value)} · ${bound == 'min' ? uiText(context, 'Desde') : uiText(context, 'Hasta')}',
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) => category.validate(field.key, v ?? ''),
              onChanged: (v) {
                if (category.validate(field.key, v) != null) return;
                final next = Map<String, dynamic>.from(value);
                final k = '${bound}_${field.key}';
                if (v.trim().isEmpty) {
                  next.remove(k);
                } else {
                  next[k] = num.parse(v.replaceAll(',', '.'));
                }
                onChanged(next);
              },
            ),
          ),
    ],
  );
}
