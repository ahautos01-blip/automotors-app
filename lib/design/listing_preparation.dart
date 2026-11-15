import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

List<String> listingSuggestions({
  required int photoCount,
  required String description,
  required bool hasEquipment,
  Map<String, dynamic> marketFacts = const {},
}) {
  final text = description.toLowerCase();
  return [
    if (photoCount < 5) 'Añade al menos cinco fotos variadas del vehículo.',
    if (description.trim().length < 80)
      'Describe el estado, el uso y los desperfectos conocidos.',
    if (marketFacts['itv'] == null &&
        !RegExp(r'itv|inspecci[oó]n|inspection|inspecci[oó]').hasMatch(text))
      'Indica la fecha o el estado de la ITV, si lo conoces.',
    if (marketFacts['maintenance'] == null &&
        !RegExp(r'manten|revisi|servic|maintenance').hasMatch(text))
      'Explica el mantenimiento y las revisiones disponibles.',
    if (!hasEquipment) 'Selecciona el equipamiento que puedas confirmar.',
  ];
}

class ListingPreparation extends StatelessWidget {
  final int photoCount;
  final TextEditingController description;
  final bool hasEquipment;
  final List<MapEntry<String, bool>>? checks;
  final Map<String, dynamic> marketFacts;
  const ListingPreparation({
    super.key,
    required this.photoCount,
    required this.description,
    required this.hasEquipment,
    this.checks,
    this.marketFacts = const {},
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
            marketFacts: marketFacts,
          );
          final allChecks =
              checks ??
              [
                MapEntry('Al menos 5 fotografías', photoCount >= 5),
                MapEntry(
                  'Descripción detallada',
                  value.text.trim().length >= 80,
                ),
                MapEntry('Equipamiento confirmado', hasEquipment),
                MapEntry(
                  'Mantenimiento mencionado',
                  !tips.contains(
                    'Explica el mantenimiento y las revisiones disponibles.',
                  ),
                ),
                MapEntry(
                  'Estado de la ITV indicado',
                  !tips.contains(
                    'Indica la fecha o el estado de la ITV, si lo conoces.',
                  ),
                ),
              ];
          final done = allChecks.where((v) => v.value).length;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    uiText(context, 'Calidad de tu anuncio'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: uiText(context, 'Datos completados: {0} de {1}', [
                      done,
                      allChecks.length,
                    ]),
                    child: LinearProgressIndicator(
                      value: done / allChecks.length,
                      minHeight: 8,
                      backgroundColor: marketLine,
                      color: marketAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    uiText(context, 'Datos completados: {0} de {1}', [
                      done,
                      allChecks.length,
                    ]),
                  ),
                  if (tips.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        uiText(context, 'Siguiente mejora: {0}', [
                          uiText(context, tips.first),
                        ]),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(uiText(context, 'Ver datos completados')),
                    children: [
                      for (final item in allChecks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                item.value
                                    ? Icons.check_circle_outline
                                    : Icons.radio_button_unchecked,
                                color: marketAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(uiText(context, item.key))),
                            ],
                          ),
                        ),
                    ],
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
