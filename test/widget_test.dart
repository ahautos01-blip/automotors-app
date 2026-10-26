import 'package:flutter_test/flutter_test.dart';
import 'package:automotors_base/main.dart';

void main() {
  group('validWhatsAppDigits', () {
    test('convierte un móvil español de nueve cifras a formato internacional', () {
      expect(validWhatsAppDigits('612 345 678'), '34612345678');
    });

    test('conserva un número español con prefijo 34', () {
      expect(validWhatsAppDigits('+34 612 345 678'), '34612345678');
    });

    test('acepta el prefijo internacional 0034', () {
      expect(validWhatsAppDigits('0034 612 345 678'), '34612345678');
    });

    test('rechaza números demasiado cortos o con formato español inválido', () {
      expect(validWhatsAppDigits('123'), isNull);
      expect(validWhatsAppDigits('3412345678'), isNull);
    });
  });

  group('etiquetas medioambientales', () {
    test('devuelve los iconos esperados para etiquetas reconocidas', () {
      expect(environmentalLabelIcon('CERO'), Icons.electric_car);
      expect(environmentalLabelIcon('ECO'), Icons.eco);
      expect(environmentalLabelIcon('C'), Icons.verified);
      expect(environmentalLabelIcon('B'), Icons.local_taxi);
    });

    test('usa el icono por defecto para una etiqueta desconocida', () {
      expect(environmentalLabelIcon('desconocida'), Icons.block);
    });
  });
}
