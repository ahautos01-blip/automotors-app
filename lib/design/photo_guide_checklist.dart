import 'package:flutter/material.dart';

import '../l10n/ui_text.dart';
import '../services/vehicle_category.dart';

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
    this.category=VehicleCategory.car,
  });
  final Set<String> completed;
  final ValueChanged<Set<String>> onChanged;
  final VehicleCategory category;
  Map<String,String> get shots => switch(category) {
    VehicleCategory.car => photoGuideShots,
    VehicleCategory.motorcycle => const {'front':'Frontal','rear':'Trasera','sides':'Ambos laterales','dashboard':'Cuadro y kilometraje','engine':'Motor y transmisión','tyres':'Neumáticos y frenos','damage':'Desperfectos conocidos'},
    VehicleCategory.truck => const {'front':'Frontal','rear':'Trasera','sides':'Ambos laterales','dashboard':'Cuadro y kilometraje','cab':'Cabina','load':'Zona de carga y chasis','tyres':'Neumáticos y ejes','damage':'Desperfectos conocidos'},
    VehicleCategory.boat => const {'hull':'Casco y cubierta','helm':'Puesto de mando','engine':'Motor y horas de uso','interior':'Interior y camarotes','equipment':'Equipamiento náutico','damage':'Desperfectos conocidos'},
  };
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: Text(uiText(context, 'Prepara tus fotos')),
      subtitle: Text(
        uiText(context, 'Tomas revisadas: {0}/{1}', [
          completed.where(shots.containsKey).length,
          shots.length,
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
        for (final shot in shots.entries)
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
