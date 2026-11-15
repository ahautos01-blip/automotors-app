import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

class MarketSafetyAdvice extends StatelessWidget {
  const MarketSafetyAdvice({super.key});
  @override
  Widget build(BuildContext context) => ExpansionTile(
    leading: const Icon(Icons.shield_outlined, color: marketAccent),
    title: Text(uiText(context, 'Consejos para una compraventa segura')),
    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    children: [
      for (final tip in const [
        'No envíes señales ni pagos antes de comprobar el coche y la identidad de la otra persona.',
        'No compartas contraseñas, códigos de acceso ni documentos completos por el chat.',
        'Desconfía de enlaces de pago, transportistas impuestos y precios demasiado bajos.',
        'Queda en un lugar público y avisa a alguien de confianza. Comprueba el vehículo y su documentación.',
        'Una oferta aceptada o una cita no reservan el coche ni sustituyen el contrato de compraventa.',
        'Si algo no encaja, detén la operación y utiliza Denunciar o Bloquear.',
      ])
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(uiText(context, tip)),
        ),
    ],
  );
}

class SellerTrustIndicators extends StatelessWidget {
  const SellerTrustIndicators({
    super.key,
    required this.professional,
    this.emailConfirmed = false,
  });
  final bool professional, emailConfirmed;
  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          uiText(
            dialogContext,
            professional ? 'Perfil profesional' : 'Correo confirmado',
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (professional) ...[
                Text(
                  uiText(
                    dialogContext,
                    'El vendedor ha indicado que es profesional. AUTOMOTORS no ha verificado su documentación.',
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                uiText(
                  dialogContext,
                  'Estos indicadores no acreditan la identidad del vendedor ni el historial o estado del vehículo.',
                ),
              ),
              const SizedBox(height: 14),
              Text(
                uiText(
                  dialogContext,
                  'Información facilitada por el vendedor. Consulta sus valoraciones y confirma los datos antes de comprar.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(uiText(dialogContext, 'Cerrar')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      if (emailConfirmed)
        ActionChip(
          onPressed: () => _showDetails(context),
          avatar: const Icon(Icons.mark_email_read_outlined, size: 18),
          label: Text(uiText(context, 'Correo confirmado')),
        ),
      if (professional)
        ActionChip(
          onPressed: () => _showDetails(context),
          avatar: const Icon(Icons.business_outlined, size: 18),
          label: Text(uiText(context, 'Perfil profesional')),
        ),
    ],
  );
}
