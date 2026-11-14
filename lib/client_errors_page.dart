import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/ui_text.dart';

class ClientErrorsPage extends StatefulWidget {
  const ClientErrorsPage({super.key});
  @override
  State<ClientErrorsPage> createState() => _ClientErrorsPageState();
}

class _ClientErrorsPageState extends State<ClientErrorsPage> {
  late Future<List<Map<String, dynamic>>> future = load();
  Future<List<Map<String, dynamic>>> load() async =>
      List<Map<String, dynamic>>.from(
        await Supabase.instance.client.rpc('client_error_summary') as List,
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(uiText(context, 'Incidencias técnicas')),
      actions: [
        IconButton(
          tooltip: uiText(context, 'Actualizar'),
          onPressed: () => setState(() => future = load()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
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
        final rows = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              uiText(
                context,
                'Incidencias agrupadas de los últimos 7 días. No contienen mensajes, contraseñas ni identidad de usuarios. Los eventos repetidos se agrupan y no equivalen a usuarios afectados.',
              ),
            ),
            if (rows.isEmpty)
              Text(uiText(context, 'No hay incidencias registradas.')),
            for (final row in rows)
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(
                  uiText(context, switch (row['category']) {
                    'photo' => 'Fotografías',
                    'publication' => 'Publicación',
                    'purchase' => 'Compras',
                    'chat' => 'Chat',
                    'catalogue' => 'Catálogo',
                    _ => 'Aplicación',
                  }),
                ),
                subtitle: Text(
                  '${row['day']} · ${row['code']} · build ${row['app_build']}',
                ),
                trailing: Text('${row['occurrences']}'),
              ),
          ],
        );
      },
    ),
  );
}
