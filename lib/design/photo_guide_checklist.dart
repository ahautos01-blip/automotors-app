import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';

const photoGuideShots = <String, String>{
  'front': 'Frontal',
  'rear': 'Trasera',
  'sides': 'Ambos laterales',
  'seats': 'Asientos e interior',
  'dashboard': 'Cuadro y kilometraje',
  'boot': 'Maletero',
  'details': 'Equipamiento y detalles',
  'damage': 'Desperfectos conocidos',
};

class PhotoGuideChecklist extends StatelessWidget {
  const PhotoGuideChecklist({
    super.key,
    required this.completed,
    required this.onChanged,
  });
  final Set<String> completed;
  final ValueChanged<Set<String>> onChanged;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: Text(uiText(context, 'Prepara tus fotos')),
      subtitle: Text(
        uiText(context, 'Tomas revisadas: {0}/{1}', [
          completed.length,
          photoGuideShots.length,
        ]),
      ),
      leading: const Icon(Icons.photo_camera_outlined),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            uiText(
              context,
              'Marca las tomas que has añadido. Es una lista personal; no analizamos ni verificamos las fotos. Usa luz natural y muestra los desperfectos.',
            ),
          ),
        ),
        for (final shot in photoGuideShots.entries)
          CheckboxListTile(
            title: Text(uiText(context, shot.value)),
            value: completed.contains(shot.key),
            onChanged: (checked) {
              final next = Set<String>.of(completed);
              if (checked == true) {
                next.add(shot.key);
              } else {
                next.remove(shot.key);
              }
              onChanged(next);
            },
          ),
      ],
    ),
  );
}
