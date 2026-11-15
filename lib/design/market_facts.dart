import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../l10n/ui_text.dart';
import '../services/market_facts.dart';
import 'market_theme.dart';

Future<MarketLocality?> chooseMarketLocality(BuildContext context) =>
    showDialog<MarketLocality>(
      context: context,
      builder: (_) => const _LocalityDialog(),
    );

class _LocalityDialog extends StatefulWidget {
  const _LocalityDialog();
  @override
  State<_LocalityDialog> createState() => _LocalityDialogState();
}

class _LocalityDialogState extends State<_LocalityDialog> {
  final query = TextEditingController(), client = http.Client();
  late final search = MunicipalitySearch(client);
  List<Map<String, dynamic>> results = [];
  bool busy = false, failed = false, searched = false;
  @override
  void dispose() {
    query.dispose();
    client.close();
    super.dispose();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final rows = await search.candidates(query.text);
      if (mounted)
        setState(() {
          results = rows;
          searched = true;
        });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(uiText(context, 'Localidad del vehículo')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            uiText(
              context,
              'Escribe solo el municipio. Se consulta CartoCiudad (IGN) sin tu cuenta ni ubicación GPS.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: query,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: uiText(context, 'Municipio'),
            ),
            onSubmitted: (_) => load(),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : load,
            icon: const Icon(Icons.search),
            label: Text(uiText(context, 'Buscar localidad')),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          if (failed)
            Text(
              uiText(
                context,
                'No se pudo buscar. Escribe un municipio y vuelve a intentarlo.',
              ),
            ),
          if (searched && !busy && !failed && results.isEmpty)
            Text(
              uiText(
                context,
                'No se encontraron municipios. Prueba el nombre oficial.',
              ),
            ),
          for (final row in results)
            ListTile(
              title: Text(row['address'].toString()),
              enabled: !busy,
              onTap: () async {
                setState(() => busy = true);
                try {
                  final place = await search.resolve(row);
                  if (context.mounted) Navigator.pop(context, place);
                } catch (_) {
                  if (mounted)
                    setState(() {
                      busy = false;
                      failed = true;
                    });
                }
              },
            ),
          const SizedBox(height: 8),
          Text(
            'Fuente: IGN · CartoCiudad',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(uiText(context, 'Cerrar')),
      ),
    ],
  );
}

class MarketRadiusFilter extends StatelessWidget {
  final Map<String, dynamic> criteria;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const MarketRadiusFilter({
    super.key,
    required this.criteria,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final place = MarketLocality.fromJson(criteria['locality']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.location_on_outlined),
          label: Text(
            place?.label ?? uiText(context, 'Buscar por localidad y radio'),
          ),
          onPressed: () async {
            final selected = await chooseMarketLocality(context);
            if (selected != null)
              onChanged({
                'locality': selected.toJson(),
                'radius_km': criteria['radius_km'] ?? 50,
              });
          },
        ),
        if (place != null) ...[
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  value:
                      [
                        10,
                        25,
                        50,
                        100,
                        200,
                        500,
                      ].contains(criteria['radius_km'])
                      ? criteria['radius_km']
                      : 50,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Radio aproximado'),
                  ),
                  items: [
                    for (final km in [10, 25, 50, 100, 200, 500])
                      DropdownMenuItem(value: km, child: Text('$km km')),
                  ],
                  onChanged: (km) => onChanged({
                    'locality': place.toJson(),
                    'radius_km': km ?? 50,
                  }),
                ),
              ),
              IconButton(
                tooltip: uiText(context, 'Quitar localidad'),
                onPressed: () => onChanged({}),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            uiText(
              context,
              'Distancia en línea recta entre municipios. No incluye anuncios sin localidad.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class MarketFactsForm extends StatefulWidget {
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const MarketFactsForm({
    super.key,
    required this.value,
    required this.onChanged,
  });
  @override
  State<MarketFactsForm> createState() => _MarketFactsFormState();
}

class _MarketFactsFormState extends State<MarketFactsForm> {
  Map<String, dynamic> get value => widget.value;
  late final date = TextEditingController(
    text: value['itv_until']?.toString() ?? '',
  );
  late final defects = TextEditingController(
    text: value['defects']?.toString() ?? '',
  );
  @override
  void didUpdateWidget(covariant MarketFactsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incomingDate = value['itv_until']?.toString() ?? '',
        incomingDefects = value['defects']?.toString() ?? '';
    if (date.text != incomingDate) date.text = incomingDate;
    if (defects.text != incomingDefects) defects.text = incomingDefects;
  }

  @override
  void dispose() {
    date.dispose();
    defects.dispose();
    super.dispose();
  }

  void change(String key, dynamic v) => widget.onChanged({...value, key: v});
  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: false,
    tilePadding: EdgeInsets.zero,
    title: Text(uiText(context, 'Estado, garantía y localidad')),
    subtitle: Text(
      uiText(context, 'Información opcional facilitada por el vendedor'),
    ),
    children: [
      for (final section in [
        ('maintenance', 'Mantenimiento', marketMaintenance),
        ('itv', 'ITV', marketItv),
        ('warranty', 'Garantía', marketWarranty),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: section.$3.containsKey(value[section.$1])
                ? value[section.$1]
                : 'unknown',
            decoration: InputDecoration(labelText: uiText(context, section.$2)),
            items: [
              for (final item in section.$3.entries)
                DropdownMenuItem(
                  value: item.key,
                  child: Text(uiText(context, item.value), maxLines: 2),
                ),
            ],
            onChanged: (v) => change(section.$1, v),
          ),
        ),
      TextFormField(
        controller: date,
        maxLength: 10,
        decoration: InputDecoration(
          labelText: uiText(context, 'Caducidad ITV (AAAA-MM-DD, opcional)'),
        ),
        validator: (text) {
          if (text == null || text.trim().isEmpty) return null;
          final d = DateTime.tryParse(text);
          return d != null &&
                  RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) &&
                  d.toIso8601String().startsWith(text)
              ? null
              : uiText(context, 'Introduce una fecha válida');
        },
        onChanged: (v) => change('itv_until', v.trim()),
      ),
      TextFormField(
        controller: defects,
        maxLength: 1000,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: uiText(
            context,
            'Defectos y reparaciones pendientes (opcional)',
          ),
        ),
        onChanged: (v) => change('defects', v),
      ),
      OutlinedButton.icon(
        icon: const Icon(Icons.location_on_outlined),
        label: Text(
          MarketLocality.fromJson(value['locality'])?.label ??
              uiText(context, 'Añadir localidad aproximada'),
        ),
        onPressed: () async {
          final selected = await chooseMarketLocality(context);
          if (selected != null) change('locality', selected.toJson());
        },
      ),
      if (value['locality'] != null)
        TextButton(
          onPressed: () => change('locality', null),
          child: Text(uiText(context, 'Quitar localidad')),
        ),
      Text(
        uiText(
          context,
          'No publiques direcciones particulares ni documentos. Estos datos no son una certificación de AUTOMOTORS.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class MarketFactsView extends StatelessWidget {
  final Map<String, dynamic> facts;
  const MarketFactsView({super.key, required this.facts});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: marketSurface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: marketLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          uiText(context, 'Estado y transparencia'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final row in [
          (
            'Mantenimiento',
            marketMaintenance[facts['maintenance']] ?? 'No informado',
          ),
          ('ITV', marketItv[facts['itv']] ?? 'No informado'),
          (
            'Caducidad ITV',
            facts['itv_until']?.toString().isNotEmpty == true
                ? facts['itv_until'].toString()
                : 'No informado',
          ),
          ('Garantía', marketWarranty[facts['warranty']] ?? 'No informado'),
          (
            'Defectos conocidos',
            facts['defects']?.toString().trim().isNotEmpty == true
                ? facts['defects'].toString()
                : 'No informado',
          ),
          (
            'Localidad',
            MarketLocality.fromJson(facts['locality'])?.label ?? 'No informado',
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  uiText(context, row.$1),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  uiText(context, row.$2),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          uiText(
            context,
            'Información declarada por el vendedor. Comprueba el historial, la ITV y las condiciones de garantía antes de comprar.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
