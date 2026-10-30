import 'package:flutter_test/flutter_test.dart';
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

  test('Unknown locale is rejected without changing the selection', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AutomotorsLocaleController.instance;
    await controller.select('es');
    await expectLater(controller.select('xx'), throwsArgumentError);
    expect(controller.locale.languageCode, 'es');
  });
}
