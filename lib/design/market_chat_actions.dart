import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

/// Suggestions only prepare editable text. The user sends it with the composer.
class MarketChatActions extends StatelessWidget {
  const MarketChatActions({
    super.key,
    required this.enabled,
    required this.onCompose,
  });
  final bool enabled;
  final ValueChanged<String> onCompose;

  Future<void> proposeVisit(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
      initialDate: now,
    );
    if (date == null || !context.mounted || !enabled) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !context.mounted || !enabled) return;
    final appointment = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!appointment.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiText(context, 'Elige una fecha y hora futuras.')),
        ),
      );
      return;
    }
    final localizations = MaterialLocalizations.of(context);
    onCompose(
      uiText(
        context,
        '¿Podemos ver el coche el {0} a las {1}? Confírmame si te va bien.',
        [
          localizations.formatMediumDate(date),
          localizations.formatTimeOfDay(time, alwaysUse24HourFormat: true),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final text in [
          '¿Sigue disponible?',
          '¿Tiene historial de mantenimiento?',
        ])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(uiText(context, text)),
              onPressed: enabled
                  ? () => onCompose(uiText(context, text))
                  : null,
            ),
          ),
        ActionChip(
          avatar: const Icon(
            Icons.event_outlined,
            size: 18,
            color: marketAccent,
          ),
          label: Text(uiText(context, 'Proponer visita')),
          onPressed: enabled ? () => proposeVisit(context) : null,
        ),
      ],
    ),
  );
}
