/// Stable database identifiers. Existing listings remain cars by default.
enum VehicleCategory {
  car('car', 'Coches'),
  motorcycle('motorcycle', 'Motos'),
  truck('truck', 'Camiones'),
  boat('boat', 'Embarcaciones');

  final String id, label;
  const VehicleCategory(this.id, this.label);
  static VehicleCategory parse(Object? value) =>
      values.firstWhere((category) => category.id == value, orElse: () => car);
  bool get isRoad => this != boat;
  List<String> get fuels => [
    'Diésel',
    'Gasolina',
    'Híbrido',
    'Eléctrico',
    if (this == boat) 'Sin motor',
  ];
  Map<String, String> get fields => switch (this) {
    car => const {},
    motorcycle => const {
      'engine_cc': 'Cilindrada (cc)',
      'seat_height_mm': 'Altura del asiento (mm)',
    },
    truck => const {
      'gross_weight_kg': 'Masa máxima autorizada (kg)',
      'payload_kg': 'Carga útil (kg)',
      'axles': 'Ejes',
    },
    boat => const {
      'length_m': 'Eslora (m)',
      'beam_m': 'Manga (m)',
      'engine_hours': 'Horas de motor',
      'cabins': 'Camarotes',
    },
  };
  Map<String, double> get maximums => switch (this) {
    car => const {},
    motorcycle => const {'engine_cc': 10000, 'seat_height_mm': 2000},
    truck => const {
      'gross_weight_kg': 200000,
      'payload_kg': 200000,
      'axles': 20,
    },
    boat => const {
      'length_m': 200,
      'beam_m': 100,
      'engine_hours': 1000000,
      'cabins': 100,
    },
  };
  String? validate(String key, String value) {
    if (value.trim().isEmpty) return null;
    final n = double.tryParse(value.trim().replaceAll(',', '.'));
    if (!fields.containsKey(key) ||
        n == null ||
        !n.isFinite ||
        n < 0 ||
        n > maximums[key]!)
      return 'Introduce un valor válido';
    if (!['length_m', 'beam_m'].contains(key) && n != n.roundToDouble())
      return 'Introduce un número entero';
    return null;
  }

  Map<String, num> details(Map<String, String> values) => {
    for (final key in fields.keys)
      if ((values[key] ?? '').trim().isNotEmpty &&
          validate(key, values[key]!) == null)
        key: num.parse(values[key]!.trim().replaceAll(',', '.')),
  };

  bool matches(Map<String, dynamic> criteria, Map<String, dynamic> data) {
    for (final key in fields.keys) {
      for (final bound in ['min', 'max']) {
        final requested = criteria['${bound}_$key'];
        if (requested == null) continue;
        final n = num.tryParse('$requested'),
            actual = num.tryParse('${data[key]}');
        if (n == null ||
            !n.isFinite ||
            n < 0 ||
            n > maximums[key]! ||
            actual == null ||
            !actual.isFinite)
          return false;
        if (bound == 'min' && actual < n || bound == 'max' && actual > n)
          return false;
      }
    }
    return true;
  }
}
