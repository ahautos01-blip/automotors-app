import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

class ModerationOverview extends StatelessWidget {
  const ModerationOverview({
    super.key,
    required this.data,
    required this.onReport,
  });
  final Map<String, dynamic> data;
  final ValueChanged<String> onReport;
  @override
  Widget build(BuildContext context) {
    final checks = List<Map<String, dynamic>>.from(
      data['checks'] as List? ?? [],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            uiText(context, 'Resumen de administración'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in const [
              ('open_reports', 'Denuncias abiertas'),
              ('pending_checks', 'Comprobaciones pendientes'),
              ('failed_checks', 'Comprobaciones fallidas'),
              ('drafts', 'Borradores y pausados'),
            ])
              SizedBox(
                width: 210,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data[item.$1] ?? 0}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(uiText(context, item.$2)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          uiText(context, 'Últimas comprobaciones de publicación'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          uiText(
            context,
            'Hasta 100 comprobaciones recientes. Los borradores personales no se publican ni se aprueban automáticamente.',
          ),
        ),
        for (final check in checks)
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.fact_check_outlined,
                color: marketAccent,
              ),
              title: Text(check['title']?.toString() ?? ''),
              subtitle: Text(
                uiText(context, switch (check['state']) {
                  'processing' => 'Comprobación en curso',
                  'changed' =>
                    'Contenido modificado; necesita una nueva comprobación',
                  'rejected' => 'Contenido rechazado',
                  _ => 'No se completó la comprobación',
                }),
              ),
              trailing: check['report_id'] != null
                  ? const Icon(Icons.chevron_right)
                  : null,
              onTap: check['report_id'] == null
                  ? null
                  : () => onReport(check['report_id'].toString()),
            ),
          ),
        if (checks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              uiText(
                context,
                'No hay comprobaciones de publicación pendientes.',
              ),
            ),
          ),
        const Divider(height: 32),
      ],
    );
  }
}
