import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

List<String> listingSuggestions({
  required int photoCount,
  required String description,
  required bool hasEquipment,
}) {
  final text = description.toLowerCase();
  return [
    if (photoCount < 5) 'Añade al menos cinco fotos variadas del vehículo.',
    if (description.trim().length < 80)
      'Describe el estado, el uso y los desperfectos conocidos.',
    if (!RegExp(r'itv|inspecci[oó]n|inspection|inspecci[oó]').hasMatch(text))
      'Indica la fecha o el estado de la ITV, si lo conoces.',
    if (!RegExp(r'manten|revisi|servic|maintenance').hasMatch(text))
      'Explica el mantenimiento y las revisiones disponibles.',
    if (!hasEquipment) 'Selecciona el equipamiento que puedas confirmar.',
  ];
}

class ListingPreparation extends StatelessWidget {
  final int photoCount;
  final TextEditingController description;
  final bool hasEquipment;
  const ListingPreparation({
    super.key,
    required this.photoCount,
    required this.description,
    required this.hasEquipment,
  });
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: description,
        builder: (context, value, _) {
          final tips = listingSuggestions(
            photoCount: photoCount,
            description: value.text,
            hasEquipment: hasEquipment,
          );
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    uiText(context, 'Prepara un anuncio más completo'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    uiText(
                      context,
                      'Estas recomendaciones no verifican el coche ni son obligatorias. Si desconoces un dato, indícalo en la descripción.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  for (final tip in tips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 20,
                            color: marketAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(uiText(context, tip))),
                        ],
                      ),
                    ),
                  if (tips.isEmpty)
                    Text(
                      uiText(
                        context,
                        'Has cubierto las recomendaciones básicas. Revisa que todos los datos sean correctos.',
                      ),
                    ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    title: Text(uiText(context, 'Guía de fotografías')),
                    leading: const Icon(Icons.photo_camera_outlined),
                    children: [
                      for (final tip in const [
                        'Exterior: frontal, trasera y ambos laterales.',
                        'Interior: asientos, maletero y puesto de conducción.',
                        'Cuadro: kilometraje legible y testigos visibles.',
                        'Detalles: equipamiento y desperfectos sin ocultarlos.',
                        'Usa fotos propias, con luz natural y sin datos personales ajenos.',
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Text(uiText(context, tip)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
}
