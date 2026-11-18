import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/ui_text.dart';
import 'market_theme.dart';

class LaunchEmptyCatalogue extends StatelessWidget {
  const LaunchEmptyCatalogue({
    super.key,
    required this.onPublish,
    required this.onSaveSearch,
  });
  final VoidCallback onPublish, onSaveSearch;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.directions_car_outlined,
            size: 42,
            color: marketAccent,
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              uiText(context, 'Estamos incorporando los primeros vehículos'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            uiText(
              context,
              'El catálogo está empezando. Publica tu coche o guarda una búsqueda para recibir avisos cuando haya anuncios que encajen contigo.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPublish,
            icon: const Icon(Icons.add),
            label: Text(uiText(context, 'Publicar mi coche')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onSaveSearch,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(uiText(context, 'Guardar una búsqueda')),
          ),
        ],
      ),
    ),
  );
}

class ListingContextHelp extends StatelessWidget {
  const ListingContextHelp({super.key, this.plans = false});
  final bool plans;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: const Icon(Icons.help_outline, color: marketAccent),
      title: Text(
        uiText(
          context,
          plans ? 'Qué incluye cada opción' : 'Ayuda sobre datos y privacidad',
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(
          uiText(
            context,
            plans
                ? 'Puedes publicar gratis dentro de los límites de tu cuenta. Los planes amplían la capacidad y los destacados; no garantizan una venta. Comprueba el precio, el periodo y la renovación antes de confirmar en Apple.'
                : 'La matrícula y el VIN son opcionales. Solo se muestran a otros usuarios si activas su casilla. El VIN identifica el vehículo, pero no acredita su historial ni su estado. No incluyas documentos personales en las fotos. El teléfono es opcional y puedes conversar desde la app.',
          ),
        ),
      ],
    ),
  );
}

class PublicationPreviewPage extends StatelessWidget {
  const PublicationPreviewPage({
    super.key,
    required this.title,
    required this.price,
    required this.details,
    required this.description,
    required this.photos,
    required this.equipment,
  });
  final String title, price, description;
  final Map<String, String> details;
  final List<XFile> photos;
  final List<String> equipment;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(uiText(context, 'Vista previa del anuncio'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          uiText(
            context,
            'Todavía no se ha enviado ni publicado. Revisa los datos que verá el comprador.',
          ),
        ),
        const SizedBox(height: 12),
        if (photos.isNotEmpty)
          SizedBox(
            height: 260,
            child: PageView.builder(
              itemCount: photos.length,
              itemBuilder: (context, index) => Semantics(
                image: true,
                label: uiText(context, 'Fotografía {0} de {1}', [
                  index + 1,
                  photos.length,
                ]),
                child: Column(
                  children: [
                    Expanded(
                      child: FutureBuilder<Uint8List>(
                        future: photos[index].readAsBytes(),
                        builder: (context, snapshot) => snapshot.hasData
                            ? Image.memory(
                                snapshot.data!,
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                              )
                            : Center(
                                child: Text(
                                  uiText(context, 'Cargando fotografía…'),
                                ),
                              ),
                      ),
                    ),
                    Text('${index + 1} / ${photos.length}'),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
        const SizedBox(height: 8),
        Text(price, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          uiText(
            context,
            'Tu perfil de vendedor acompañará al anuncio publicado.',
          ),
        ),
        const SizedBox(height: 16),
        for (final entry in details.entries.where(
          (e) => e.value.trim().isNotEmpty,
        ))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  uiText(context, entry.key),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(uiText(context, entry.value)),
              ],
            ),
          ),
        const Divider(),
        Semantics(
          header: true,
          child: Text(
            uiText(context, 'Descripción'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(
          description.trim().isEmpty
              ? uiText(context, 'Sin descripción')
              : description,
        ),
        if (equipment.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            uiText(context, 'Equipamiento'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in equipment)
                Chip(label: Text(uiText(context, item))),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Text(
          uiText(
            context,
            'Al confirmar se enviará a moderación. Solo será público si supera la comprobación.',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('confirm-publication-preview'),
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.check),
          label: Text(uiText(context, 'Confirmar y enviar a revisión')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(uiText(context, 'Volver a editar')),
        ),
      ],
    ),
  );
}

Map<String, String> publicationIdentifiers({
  required bool showPlate,
  required bool showVin,
  required String plate,
  required String vin,
}) => {
  if (showPlate && plate.trim().isNotEmpty)
    'Matrícula': plate.trim().toUpperCase(),
  if (showVin && vin.trim().isNotEmpty)
    'VIN / bastidor': vin.trim().toUpperCase(),
};
