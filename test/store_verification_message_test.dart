import 'package:automotors_base/services/store_verification_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account conflict explains recovery without revealing another email', () {
    final message = storeVerificationMessage(409, {
      'error': 'Esta suscripción ya está vinculada a otra cuenta AUTOMOTORS.',
    });
    expect(message, contains('otra cuenta'));
    expect(message, contains('primera compra'));
    expect(message, contains('restaura'));
  });

  test('expired and revoked transactions have distinct explanations', () {
    expect(storeVerificationMessage(409, {'verified': false, 'status': 'expired'}),
        contains('Restaurar compras no renueva'));
    expect(storeVerificationMessage(409, {'verified': false, 'status': 'revoked'}),
        contains('revocada'));
  });

  test('expired session asks for login before restoring', () {
    expect(storeVerificationMessage(401, null), contains('Inicia sesión'));
  });

  test('unknown rejection never repeats private backend details', () {
    for (final status in [0, 200, 409, 422, 500, 503]) {
      final message = storeVerificationMessage(status, {'error': 'private-diagnostic'});
      expect(message, isNot(contains('private-diagnostic')));
    }
    expect(storeVerificationMessage(409, null), contains('antes de repetir'));
  });
}
