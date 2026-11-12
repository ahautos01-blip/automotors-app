import 'package:flutter_test/flutter_test.dart';
import 'package:automotors_base/main.dart' show appText;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:automotors_base/services/automotors_locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Catalan language is saved and restored', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AutomotorsLocaleController.instance;
    await controller.select('ca');
    expect(controller.locale.languageCode, 'ca');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AutomotorsLocaleController.preferenceKey), 'ca');

    await controller.select('es');
    await prefs.setString(AutomotorsLocaleController.preferenceKey, 'ca');
    await controller.load();
    expect(controller.locale.languageCode, 'ca');
  });

  test('Catalan translates multiline home and plan text', () async {
    SharedPreferences.setMockInitialValues({});
    await AutomotorsLocaleController.instance.select('ca');
    expect(appText('Encuentra\ntu próximo coche.', 'Find\nyour next car.'),
        'Troba\nel teu pròxim cotxe.');
    expect(appText('Elige la opción que mejor se adapte a ti.\nAumenta la visibilidad de tus anuncios con nuestros packs.', ''),
        'Tria l’opció que s’adapti millor a tu.\nAugmenta la visibilitat dels anuncis amb els nostres paquets.'.replaceAll('’', "'"));
  });

  test('English language is supported and persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AutomotorsLocaleController.instance;
    await controller.select('en');
    expect(controller.locale.languageCode, 'en');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AutomotorsLocaleController.preferenceKey), 'en');
  });

  test('Unknown locale is rejected without changing the selection', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AutomotorsLocaleController.instance;
    await controller.select('es');
    await expectLater(controller.select('xx'), throwsArgumentError);
    expect(controller.locale.languageCode, 'es');
  });
}
