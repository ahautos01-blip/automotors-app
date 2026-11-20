import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'market_facts.dart';

/// A one-shot search origin. Never writes the device position to a profile.
class DeviceLocation {
  static const channel = MethodChannel('automotors/location');
  static bool _busy = false;

  static Future<MarketLocality?> request(BuildContext context) async {
    if (_busy) return null;
    _busy = true;
    try {
      final consent = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Quieres compartir tu ubicación?'),
          content: const Text(
            'Usaremos una ubicación aproximada para buscar vehículos cercanos. '
            'No se publicará en tu perfil ni en tus anuncios. También puedes elegir una localidad manualmente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (consent != true || !context.mounted) return null;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final result = await channel.invokeMapMethod<String, dynamic>(
          'request',
        );
        if (result?['status'] == 'ok') {
          final place = MarketLocality.fromJson({
            'id': 'device',
            'label': 'Mi ubicación aproximada',
            'lat': result?['lat'],
            'lon': result?['lon'],
          });
          if (place != null) return place;
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo usar la ubicación. Puedes elegir una localidad manualmente.',
            ),
          ),
        );
      }
      return null;
    } on MissingPluginException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ubicación no disponible. Elige una localidad manualmente.',
            ),
          ),
        );
      }
      return null;
    } on PlatformException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ubicación no disponible. Elige una localidad manualmente.',
            ),
          ),
        );
      }
      return null;
    } finally {
      _busy = false;
    }
  }
}
