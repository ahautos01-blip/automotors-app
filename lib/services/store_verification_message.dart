/// User-facing explanations for rejected store verification responses.
/// Never display arbitrary server errors or treat a rejection as an entitlement.
String storeVerificationMessage(int status, Object? details) {
  final body = details is Map ? details : const <String, Object?>{};
  final error = body['error'];
  if (status == 401) {
    return 'Tu sesión ha caducado. Inicia sesión de nuevo y restaura las compras.';
  }
  if (status == 409) {
    if (error == 'Esta suscripción ya está vinculada a otra cuenta AUTOMOTORS.') {
      return 'Esta suscripción está vinculada a otra cuenta de AUTOMOTORS. '
          'Inicia sesión con la cuenta usada en la primera compra y restaura las compras.';
    }
    if (body['status'] == 'expired') {
      return 'La suscripción ha caducado. Restaurar compras no renueva el plan. '
          'Comprueba su estado en Apple antes de contratarlo de nuevo.';
    }
    if (body['status'] == 'revoked') {
      return 'Apple indica que la suscripción ha sido revocada. '
          'Comprueba su estado con Apple.';
    }
    return 'La compra no ha podido activar el plan. '
        'Contacta con soporte antes de repetir la compra.';
  }
  if (status == 422 || status == 400) {
    return 'No se ha podido validar la transacción de Apple. '
        'Restaura las compras; si el problema continúa, contacta con soporte.';
  }
  return 'No se ha podido verificar la compra. '
      'El plan sigue sin activarse. Intenta restaurar las compras más tarde.';
}
