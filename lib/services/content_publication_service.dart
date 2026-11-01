import 'package:supabase_flutter/supabase_flutter.dart';

typedef ContentPublicationRequest = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);
Future<Map<String, dynamic>> _publishRequest(Map<String, dynamic> body) async {
  try {
    final response = await Supabase.instance.client.functions.invoke(
      'moderate-listing',
      body: body,
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
  } on FunctionException catch (error) {
    return error.details is Map
        ? Map<String, dynamic>.from(error.details as Map)
        : <String, dynamic>{'error': 'provider_unavailable'};
  }
}

class ContentPublicationResult {
  const ContentPublicationResult({
    required this.published,
    required this.state,
    this.errorCode,
  });
  final bool published;
  final String state;
  final String? errorCode;
  factory ContentPublicationResult.fromJson(Map<String, dynamic> value) =>
      ContentPublicationResult(
        published: value['published'] == true && value['state'] == 'approved',
        state: value['state']?.toString() ?? 'error',
        errorCode: (value['error_code'] ?? value['error'])?.toString(),
      );
  String get message {
    if (published) return '¡Anuncio publicado correctamente!';
    if (errorCode == 'publication_limit') {
      return 'Tu anuncio sigue en borrador. Has alcanzado el límite de publicaciones de tu plan.';
    }
    if (state == 'rejected') {
      return 'Tu anuncio sigue en borrador y se ha enviado a revisión de moderación. Puedes revisar el contenido o contactar con soporte.';
    }
    if (state == 'changed' || errorCode == 'content_changed') {
      return 'El contenido ha cambiado durante la comprobación. El anuncio sigue en borrador; vuelve a intentarlo.';
    }
    if (errorCode == 'unsupported_image') {
      return 'Tu anuncio sigue en borrador. Utiliza fotografías JPG, PNG o WebP de menos de 20 MB.';
    }
    return 'No se pudo confirmar la publicación. Revisa el estado del anuncio en tu garaje antes de reintentar.';
  }
}

class ContentPublicationService {
  ContentPublicationService({ContentPublicationRequest? request})
    : _request = request ?? _publishRequest;
  final ContentPublicationRequest _request;
  Future<ContentPublicationResult> publish(
    String listingId, {
    String targetStatus = 'published',
  }) async {
    try {
      return ContentPublicationResult.fromJson(
        await _request({
          'action': 'publish',
          'listing_id': listingId,
          'target_status': targetStatus,
        }),
      );
    } catch (_) {
      return const ContentPublicationResult(
        published: false,
        state: 'error',
        errorCode: 'provider_unavailable',
      );
    }
  }
}

String listingContentStateMessage(String? state) => switch (state) {
  'processing' => 'Comprobación automática en curso.',
  'rejected' => 'Contenido pendiente de revisión de moderación.',
  'error' => 'Comprobación pendiente: reintenta activar el anuncio.',
  'changed' =>
    'Contenido modificado: activa el anuncio para comprobarlo de nuevo.',
  _ => '',
};
