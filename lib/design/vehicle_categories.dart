import 'package:flutter/material.dart';

import '../services/vehicle_category.dart';
import '../l10n/ui_text.dart';
import 'market_theme.dart';

class VehicleCategoryPicker extends StatelessWidget {
  final VehicleCategory value;
  final ValueChanged<VehicleCategory>? onChanged;
  final bool dense;
  const VehicleCategoryPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });
  static IconData icon(VehicleCategory c) => switch (c) {
    VehicleCategory.car => Icons.directions_car_outlined,
    VehicleCategory.motorcycle => Icons.two_wheeler_outlined,
    VehicleCategory.truck => Icons.local_shipping_outlined,
    VehicleCategory.boat => Icons.sailing_outlined,
  };
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final columns = size.maxWidth >= 700 ? 4 : 2;
      final width = (size.maxWidth - 10 * (columns - 1)) / columns;
      final scale = MediaQuery.textScalerOf(context).scale(1);
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in VehicleCategory.values)
            SizedBox(
              width: width,
              height: (dense ? 62 : 94) * scale.clamp(1, 2),
              child: Semantics(
                button: true,
                selected: c == value,
                label: uiText(context, c.label),
                excludeSemantics: true,
                enabled: onChanged != null,
                onTap: onChanged == null ? null : () => onChanged!(c),
                child: Material(
                  color: c == value ? marketInk : marketSurface,
                  borderRadius: BorderRadius.circular(26),
                  child: InkWell(
                    key: ValueKey('category-${c.id}'),
                    borderRadius: BorderRadius.circular(26),
                    onTap: onChanged == null ? null : () => onChanged!(c),
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: c == value ? marketGold : marketLine,
                          width: c == value ? 1.5 : .5,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: dense ? 6 : 12,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon(c),
                            size: dense ? 20 : 30,
                            color: c == value ? marketGold : marketInk,
                          ),
                          SizedBox(height: dense ? 3 : 8),
                          Flexible(
                            child: Text(
                              uiText(context, c.label),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: dense ? 12 : 15,
                                fontWeight: FontWeight.w800,
                                color: c == value ? marketSurface : marketInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
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
