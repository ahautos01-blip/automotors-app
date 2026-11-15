import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';

class OfferAgreementCard extends StatelessWidget {
  const OfferAgreementCard({
    super.key,
    required this.amount,
    required this.onVisit,
    required this.onMessage,
  });
  final String amount;
  final VoidCallback? onVisit, onMessage;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        uiText(context, 'Importe acordado: {0} €', [amount]),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(
        uiText(
          context,
          'La propuesta está aceptada. Coordinad la visita y revisad el coche y la documentación antes de pagar. No se ha cobrado ni marcado como vendido.',
        ),
      ),
      Wrap(
        spacing: 8,
        children: [
          FilledButton(
            onPressed: onVisit,
            child: Text(uiText(context, 'Concertar una visita')),
          ),
          TextButton(
            onPressed: onMessage,
            child: Text(uiText(context, 'Continuar por el chat')),
          ),
        ],
      ),
    ],
  );
}
