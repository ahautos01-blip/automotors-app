import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/market_usage.dart';
import '../l10n/ui_text.dart';

class MarketUsagePreference extends StatefulWidget {
  const MarketUsagePreference({super.key});
  @override
  State<MarketUsagePreference> createState() => _MarketUsagePreferenceState();
}

class _MarketUsagePreferenceState extends State<MarketUsagePreference> {
  bool? enabled;
  @override
  void initState() {
    super.initState();
    MarketUsage.enabled().then((v) {
      if (mounted) setState(() => enabled = v);
    });
  }

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    value: enabled ?? false,
    onChanged: enabled == null
        ? null
        : (v) async {
            await MarketUsage.setEnabled(v);
            if (mounted) setState(() => enabled = v);
          },
    title: Text(uiText(context, 'Ayudar a mejorar AUTOMOTORS')),
    subtitle: Text(
      uiText(
        context,
        'Opcional. Comparte contadores de uso sin guardar mensajes, búsquedas, ubicación ni identificadores de usuario. Puedes desactivarlo aquí.',
      ),
    ),
  );
}

class MarketUsagePage extends StatefulWidget {
  const MarketUsagePage({super.key});
  @override
  State<MarketUsagePage> createState() => _MarketUsagePageState();
}

class _MarketUsagePageState extends State<MarketUsagePage> {
  late Future<dynamic> data = Supabase.instance.client.rpc(
    'market_usage_summary',
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(uiText(context, 'Uso de la app')),
      actions: [
        IconButton(
          tooltip: uiText(context, 'Actualizar'),
          onPressed: () => setState(
            () => data = Supabase.instance.client.rpc('market_usage_summary'),
          ),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: Text(
              uiText(
                context,
                'No se pudo cargar. Comprueba tu acceso y actualiza.',
              ),
            ),
          );
        final rows = snapshot.data is List ? snapshot.data as List : [];
        const labels = {
          'catalogue': 'Catálogo',
          'detail': 'Ficha del vehículo',
          'contact': 'Contacto iniciado',
          'publication_start': 'Publicación iniciada',
          'publication_complete': 'Publicación completada',
        };
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              uiText(
                context,
                'Contadores opcionales de los últimos 7 días. No representan usuarios únicos ni una tasa de conversión; sirven para detectar pasos con poca actividad.',
              ),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  uiText(context, 'Aún no hay datos de uso compartidos.'),
                ),
              ),
            for (final row in rows)
              ListTile(
                title: Text(
                  uiText(
                    context,
                    labels[row['stage']] ?? row['stage'].toString(),
                  ),
                ),
                subtitle: Text('${row['day']} · build ${row['app_build']}'),
                trailing: Text('${row['occurrences']}'),
              ),
          ],
        );
      },
    ),
  );
}
