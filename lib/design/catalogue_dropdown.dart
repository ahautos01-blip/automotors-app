import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import '../services/vehicle_search.dart';
import 'market_theme.dart';

class CatalogueDropdown extends StatelessWidget {
  final String label, hint, otherLabel;
  final int? value;
  final List<Map<String, dynamic>> options;
  final ValueChanged<int>? onChanged;
  final bool loading;
  final bool customOption;
  const CatalogueDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.otherLabel,
    required this.value,
    required this.options,
    required this.onChanged,
    this.loading = false,
    this.customOption = true,
  });
  Future<int?> choose(BuildContext context) async {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CatalogueChoices(
        label: label,
        otherLabel: otherLabel,
        options: options,
        value: value,
        customOption: customOption,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FormField<int>(
    initialValue: value,
    validator: (v) =>
        v == null ? uiText(context, 'Selecciona una opción') : null,
    builder: (field) {
      final selected = options.where((row) => row['id'] == value).firstOrNull;
      return InkWell(
        key: ValueKey('catalogue-$label'),
        onTap: onChanged == null || loading
            ? null
            : () async {
                final result = await choose(context);
                if (result != null && context.mounted) {
                  field.didChange(result);
                  onChanged!(result);
                }
              },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: uiText(context, label),
            errorText: field.errorText,
            enabled: onChanged != null,
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.expand_more),
          ),
          child: Text(
            value == 0
                ? uiText(context, otherLabel)
                : selected?['name']?.toString() ?? uiText(context, hint),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    },
  );
}

class _CatalogueChoices extends StatefulWidget {
  final String label, otherLabel;
  final List<Map<String, dynamic>> options;
  final int? value;
  final bool customOption;
  const _CatalogueChoices({
    required this.label,
    required this.otherLabel,
    required this.options,
    required this.value,
    required this.customOption,
  });
  @override
  State<_CatalogueChoices> createState() => _CatalogueChoicesState();
}

class _CatalogueChoicesState extends State<_CatalogueChoices> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final found = widget.options
        .where(
          (row) => matchesVehicleSearch(search.text, [row['name'].toString()]),
        )
        .toList();
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, inset),
        child: SizedBox(
          height: (MediaQuery.sizeOf(context).height - inset) * .78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                uiText(context, widget.label),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: uiText(context, 'Buscar por nombre'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: found.isEmpty
                    ? Center(
                        child: Text(
                          uiText(
                            context,
                            widget.customOption
                                ? 'No hay coincidencias. Puedes escribir otra opción.'
                                : 'No hay coincidencias.',
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: found.length,
                        itemBuilder: (_, i) {
                          final row = found[i];
                          return ListTile(
                            title: Text(row['name'].toString()),
                            trailing: row['id'] == widget.value
                                ? const Icon(Icons.check, color: marketAccent)
                                : null,
                            onTap: () => Navigator.pop(
                              context,
                              (row['id'] as num).toInt(),
                            ),
                          );
                        },
                      ),
              ),
              OutlinedButton.icon(
                icon: Icon(
                  widget.customOption
                      ? Icons.edit_outlined
                      : Icons.filter_alt_off_outlined,
                ),
                label: Text(uiText(context, widget.otherLabel)),
                onPressed: () => Navigator.pop(context, 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CatalogueStringDropdown extends StatelessWidget {
  final String label, value, allLabel;
  final List<String> options;
  final ValueChanged<String>? onChanged;
  const CatalogueStringDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final names = options.where((v) => v != allLabel).toSet().toList();
    if (value != allLabel && !names.contains(value)) names.add(value);
    final rows = [
      for (var i = 0; i < names.length; i++) {'id': i + 1, 'name': names[i]},
    ];
    return CatalogueDropdown(
      key: ValueKey('$label-$value'),
      label: label,
      hint: allLabel,
      otherLabel: allLabel,
      customOption: false,
      value: value == allLabel ? 0 : names.indexOf(value) + 1,
      options: rows,
      onChanged: onChanged == null
          ? null
          : (id) => onChanged!(id == 0 ? allLabel : names[id - 1]),
    );
  }
}
