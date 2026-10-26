import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const gold = Color(0xFFD4AF37);
const black = Color(0xFF101010);
const panel = Color(0xFF202020);


class AutomotorsBrandMark extends StatelessWidget {
  final double size;
  const AutomotorsBrandMark({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFF5D979), Color(0xFFB88A19)],
      ),
      boxShadow: const [BoxShadow(color: Color(0x332D2200), blurRadius: 8, offset: Offset(0, 3))],
    ),
    child: Center(child: Icon(
      Icons.directions_car_filled_rounded,
      color: const Color(0xFF101010),
      size: size * .62,
    )),
  );
}

const List<String> environmentalLabels = [
  'Sin etiqueta',
  'B',
  'C',
  'ECO',
  'CERO',
];

IconData environmentalLabelIcon(String? label) {
  switch (label) {
    case 'CERO':
      return Icons.electric_car;
    case 'ECO':
      return Icons.eco;
    case 'C':
      return Icons.verified;
    case 'B':
      return Icons.local_taxi;
    default:
      return Icons.block;
  }
}

Color environmentalLabelColor(String? label) {
  switch (label) {
    case 'CERO':
      return const Color(0xFF2F80ED);
    case 'ECO':
      return const Color(0xFF2EAD67);
    case 'C':
      return const Color(0xFF168447);
    case 'B':
      return const Color(0xFFF2C94C);
    default:
      return Colors.grey;
  }
}


/// Insignia visual de la categoría medioambiental DGT. El patrón QR es decorativo,
/// no es un código oficial escaneable.
class EnvironmentalSticker extends StatelessWidget {
  final String? label;
  final double size;
  const EnvironmentalSticker({super.key, required this.label, this.size = 76});

  @override
  Widget build(BuildContext context) {
    final value = (label ?? '').trim().toUpperCase();
    if (!['CERO', 'ECO', 'C', 'B'].contains(value)) return const SizedBox.shrink();
    final base = value == 'CERO' ? const Color(0xFF168FD0)
        : value == 'ECO' ? const Color(0xFF78C900)
        : value == 'C' ? const Color(0xFF63B900) : const Color(0xFFFFD400);
    return SizedBox(width: size, height: size, child: DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: base,
        border: Border.all(color: Colors.white, width: size * .025),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(1, 2))]),
      child: ClipOval(child: Stack(children: [
        Positioned(left: size*.07, top: size*.12, child: Container(
          width: size*.13, height: size*.42, color: Colors.white,
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(11, (_) => Container(height: size*.012, color: Colors.black))))),
        Positioned(right: size*.13, top: size*.16, child: _StickerQr(size: size*.23)),
        Center(child: Padding(padding: EdgeInsets.only(left:size*.1,right:size*.18,top:size*.02),
          child: Text(value == 'CERO' ? '0' : value, style: TextStyle(color: Colors.black,
            fontSize:size*(value == 'CERO' ? .48 : .43),fontWeight:FontWeight.w900,height:1)))),
        Positioned(left:size*.24,right:size*.22,bottom:size*.15,child:Container(
          height:size*.14,color:const Color(0xFFBFC0C0),alignment:Alignment.center,
          child:Text('DGT',style:TextStyle(color:Colors.black,fontWeight:FontWeight.w900,
            fontStyle:FontStyle.italic,fontSize:size*.13)))),
        Positioned(left:size*.1,right:size*.1,bottom:size*.045,child:Container(height:size*.025,color:Colors.white70)),
      ])),
    ));
  }
}
class _StickerQr extends StatelessWidget {
  final double size;
  const _StickerQr({required this.size});
  @override
  Widget build(BuildContext context) => Container(width:size,height:size,padding:EdgeInsets.all(size*.08),
    color:Colors.white,child:CustomPaint(painter:_QrPatternPainter()));
}
class _QrPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p=Paint()..color=Colors.black;
    const cells=13; final cell=size.width/cells;
    for(int y=0;y<cells;y++) { for(int x=0;x<cells;x++) {
      final finder=(x<4&&y<4)||(x>8&&y<4)||(x<4&&y>8);
      final dark=finder ? (x%3==0||y%3==0||(x%3==1&&y%3==1)) : ((x*7+y*11+x*y)%5<2);
      if(dark) canvas.drawRect(Rect.fromLTWH(x*cell,y*cell,cell*.88,cell*.88),p);
    }}
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ndicdhlpbyywqyjgxpnx.supabase.co',
    publishableKey: 'sb_publishable_TBWahz_XJ9lcoBdSSxfpNQ_vhzdDTlu',
  );

  runApp(const AutomotorsApp());
}

/// Devuelve el número para wa.me solo si parece válido.
/// Los teléfonos españoles de 9 cifras se convierten a formato internacional (+34).
String? validWhatsAppDigits(String phone) {
  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0034')) {
    digits = digits.substring(2);
  }
  if (digits.length == 9) {
    digits = '34$digits';
  }
  if (digits.length < 10 || digits.length > 15) return null;
  if (digits.startsWith('34') && digits.length != 11) return null;
  if (!RegExp(r'^[1-9][0-9]+$').hasMatch(digits)) return null;
  return digits;
}

Future<void> openWhatsAppForCar(BuildContext context, Car car) async {
  final digits = validWhatsAppDigits(car.phone);
  if (digits == null) return;
  final message = 'Hola, estoy interesado en tu ${car.brand} ${car.model} anunciado en AUTOMOTORS.';
  final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp en este dispositivo.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp. Comprueba que esté disponible.')),
      );
    }
  }
}

/// Abre la pantalla de acceso y devuelve true si hay una sesión activa.
Future<bool> requireAutomotorsLogin(BuildContext context) async {
  if (Supabase.instance.client.auth.currentUser != null) return true;
  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const LoginPage()),
  );
  return result == true && Supabase.instance.client.auth.currentUser != null;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool creatingAccount = false;
  bool loading = false;
  bool hidePassword = true;
  String? message;
  bool messageIsError = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (loading || !formKey.currentState!.validate()) return;
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      final email = emailController.text.trim();
      final password = passwordController.text;
      if (creatingAccount) {
        final response = await auth.signUp(email: email, password: password);
        if (response.session != null) {
          if (mounted) Navigator.pop(context, true);
          return;
        }
        setState(() {
          message = 'Cuenta creada. Revisa tu correo y confirma la dirección; después vuelve aquí para iniciar sesión.';
          messageIsError = false;
          creatingAccount = false;
        });
      } else {
        await auth.signInWithPassword(email: email, password: password);
        if (mounted) Navigator.pop(context, true);
        return;
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          message = error.message;
          messageIsError = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          message = 'No se pudo completar el acceso. Comprueba la conexión e inténtalo de nuevo.';
          messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta AUTOMOTORS')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AutomotorsBrandMark(size: 64),
                  const SizedBox(height: 12),
                  const Text('AUTOMOTORS', textAlign: TextAlign.center,
                    style: TextStyle(color: gold, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(creatingAccount ? 'Crea tu cuenta para publicar y contactar.' : 'Inicia sesión para publicar y contactar.',
                    textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty || !text.contains('@') || !text.contains('.')) return 'Introduce un correo válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: hidePassword,
                    autofillHints: creatingAccount ? const [AutofillHints.newPassword] : const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => hidePassword = !hidePassword),
                        icon: Icon(hidePassword ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    validator: (value) {
                      final text = value ?? '';
                      if (text.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
                      return null;
                    },
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 14),
                    Text(message!, style: TextStyle(color: messageIsError ? Colors.redAccent : gold)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: loading ? null : submit,
                    style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(creatingAccount ? 'Crear cuenta' : 'Iniciar sesión'),
                  ),
                  TextButton(
                    onPressed: loading ? null : () => setState(() {
                      creatingAccount = !creatingAccount;
                      message = null;
                    }),
                    child: Text(creatingAccount ? 'Ya tengo una cuenta · Iniciar sesión' : '¿No tienes cuenta? Crear cuenta'),
                  ),
                  const SizedBox(height: 8),
                  const Text('Puedes seguir viendo los anuncios sin registrarte.', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Car {
  final String brand;
  final String model;
  final int year;
  final int km;
  final double price;
  final String fuel;
  final String description;
  final String phone;
  final String? matricula;
  final int? cv;
  final int? cilindradaCc;
  final String? etiquetaMedioambiental;
  final String? vin;
  final String? version;
  final String? transmission;
  final String? bodyType;
  final int? doors;
  final int? seats;
  final String? color;
  final int? torqueNm;
  final double? acceleration0100;
  final int? maxSpeedKmh;
  final double? consumptionL100;
  final String? emissionsStandard;
  final int? lengthMm;
  final int? widthMm;
  final int? heightMm;
  final int? wheelbaseMm;
  final int? weightKg;
  final int? trunkLiters;
  final int? tankLiters;
  final List<String> equipment;
  final List<Uint8List> photos;
  final String? listingId;
  final String? ownerId;
  final String status;

  const Car({
    required this.brand,
    required this.model,
    required this.year,
    required this.km,
    required this.price,
    required this.fuel,
    required this.description,
    required this.phone,
    this.matricula,
    this.cv,
    this.cilindradaCc,
    this.etiquetaMedioambiental,
    this.vin,
    this.version,
    this.transmission,
    this.bodyType,
    this.doors,
    this.seats,
    this.color,
    this.torqueNm,
    this.acceleration0100,
    this.maxSpeedKmh,
    this.consumptionL100,
    this.emissionsStandard,
    this.lengthMm,
    this.widthMm,
    this.heightMm,
    this.wheelbaseMm,
    this.weightKg,
    this.trunkLiters,
    this.tankLiters,
    this.equipment = const [],
    this.photos = const [],
    this.listingId,
    this.ownerId,
    this.status = 'published',
  });
}

class _CarFeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CarFeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF202830),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF34414B)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: gold),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _ReservedRibbon extends StatelessWidget {
  const _ReservedRibbon();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF168BFF), Color(0xFF063B96)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      border: const Border(
        top: BorderSide(color: Color(0xFF83D8FF), width: 1),
        bottom: BorderSide(color: Color(0xFF041D52), width: 1),
      ),
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(10),
        bottomRight: Radius.circular(10),
      ),
      boxShadow: [
        BoxShadow(color: const Color(0xFF168BFF).withValues(alpha: .45), blurRadius: 12, offset: const Offset(0, 3)),
      ],
    ),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.lock_rounded, size: 13, color: Colors.white),
      SizedBox(width: 6),
      Text('RESERVADO', style: TextStyle(
        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900,
        letterSpacing: 1.1, shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
      )),
    ]),
  );
}

class AutomotorsApp extends StatelessWidget {
  const AutomotorsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Automotors',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: black,
          foregroundColor: gold,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();
  String selectedFuel = 'Todos';
  String selectedBrand = 'Todas';
  String selectedModel = 'Todos';
  double? minPrice;
  double? maxPrice;
  int? minYear;
  int? maxKm;

  final List<Car> cars = [];
  bool loadingCars = true;

  @override
  void initState() {
    super.initState();
    loadCars();
  }

  Future<void> loadCars() async {
    try {
      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from('vehicle_listings')
          .select('id, status, year, km, price, fuel, description, phone, matricula, cv, cilindrada_cc, etiqueta_medioambiental, version, transmission, body_type, doors, seats, color, torque_nm, acceleration_0_100, max_speed_kmh, consumption_l_100, emissions_standard, length_mm, width_mm, height_mm, wheelbase_mm, weight_kg, trunk_liters, tank_liters, equipment, owner_id, vehicle_brands(name), vehicle_models(name), vehicle_photos(storage_path, position)')
          .inFilter('status', ['published', 'reserved'])
          .order('created_at', ascending: false);

      final loadedCars = <Car>[];
      for (final raw in List<Map<String, dynamic>>.from(rows)) {
        final brandData = raw['vehicle_brands'];
        final modelData = raw['vehicle_models'];
        final photoData = raw['vehicle_photos'];
        final photoRows = photoData is List
            ? List<Map<String, dynamic>>.from(photoData)
            : <Map<String, dynamic>>[];
        photoRows.sort((a, b) => ((a['position'] as num?)?.toInt() ?? 0)
            .compareTo((b['position'] as num?)?.toInt() ?? 0));

        final photoBytes = <Uint8List>[];
        for (final photo in photoRows) {
          final storagePath = photo['storage_path']?.toString();
          if (storagePath == null || storagePath.isEmpty) continue;
          try {
            final bytes = await supabase.storage
                .from('vehicle-photos')
                .download(storagePath);
            photoBytes.add(bytes);
          } catch (_) {
            // Si una foto no está disponible, el anuncio sigue mostrándose.
          }
        }

        loadedCars.add(Car(
          brand: brandData is Map ? (brandData['name']?.toString() ?? 'Marca') : 'Marca',
          model: modelData is Map ? (modelData['name']?.toString() ?? 'Modelo') : 'Modelo',
          year: (raw['year'] as num?)?.toInt() ?? 0,
          km: (raw['km'] as num?)?.toInt() ?? 0,
          price: (raw['price'] as num?)?.toDouble() ?? 0,
          fuel: raw['fuel']?.toString() ?? '',
          description: raw['description']?.toString() ?? '',
          phone: raw['phone']?.toString() ?? '',
          matricula: raw['matricula']?.toString(),
          cv: (raw['cv'] as num?)?.toInt(),
          cilindradaCc: (raw['cilindrada_cc'] as num?)?.toInt(),
          etiquetaMedioambiental: raw['etiqueta_medioambiental']?.toString(),
          version: raw['version']?.toString(),
          transmission: raw['transmission']?.toString(),
          bodyType: raw['body_type']?.toString(),
          doors: (raw['doors'] as num?)?.toInt(),
          seats: (raw['seats'] as num?)?.toInt(),
          color: raw['color']?.toString(),
          torqueNm: (raw['torque_nm'] as num?)?.toInt(),
          acceleration0100: (raw['acceleration_0_100'] as num?)?.toDouble(),
          maxSpeedKmh: (raw['max_speed_kmh'] as num?)?.toInt(),
          consumptionL100: (raw['consumption_l_100'] as num?)?.toDouble(),
          emissionsStandard: raw['emissions_standard']?.toString(),
          lengthMm: (raw['length_mm'] as num?)?.toInt(),
          widthMm: (raw['width_mm'] as num?)?.toInt(),
          heightMm: (raw['height_mm'] as num?)?.toInt(),
          wheelbaseMm: (raw['wheelbase_mm'] as num?)?.toInt(),
          weightKg: (raw['weight_kg'] as num?)?.toInt(),
          trunkLiters: (raw['trunk_liters'] as num?)?.toInt(),
          tankLiters: (raw['tank_liters'] as num?)?.toInt(),
          equipment: raw['equipment'] is List
              ? List<String>.from((raw['equipment'] as List).map((item) => item.toString()))
              : const <String>[],
          photos: photoBytes,
          listingId: raw['id']?.toString(),
          ownerId: raw['owner_id']?.toString(),
          status: raw['status']?.toString() ?? 'published',
        ));
      }

      if (!mounted) return;
      setState(() {
        cars
          ..clear()
          ..addAll(loadedCars);
        loadingCars = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loadingCars = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los anuncios desde Supabase: $error'), duration: const Duration(seconds: 8)),
      );
    }
  }

  List<Car> get filteredCars {
    final query = searchController.text.toLowerCase().trim();
    return cars.where((car) {
      final matchesSearch =
          '${car.brand} ${car.model}'.toLowerCase().contains(query);
      final matchesBrand = selectedBrand == 'Todas' || car.brand == selectedBrand;
      final matchesModel = selectedModel == 'Todos' || car.model == selectedModel;
      final matchesFuel =
          selectedFuel == 'Todos' || car.fuel == selectedFuel;
      final matchesMinPrice = minPrice == null || car.price >= minPrice!;
      final matchesMaxPrice = maxPrice == null || car.price <= maxPrice!;
      final matchesMinYear = minYear == null || car.year >= minYear!;
      final matchesMaxKm = maxKm == null || car.km <= maxKm!;
      return matchesSearch &&
          matchesBrand &&
          matchesModel &&
          matchesFuel &&
          matchesMinPrice &&
          matchesMaxPrice &&
          matchesMinYear &&
          matchesMaxKm;
    }).toList();
  }

  Future<void> openFilters() async {
    final minPriceController =
        TextEditingController(text: minPrice?.toStringAsFixed(0) ?? '');
    final maxPriceController =
        TextEditingController(text: maxPrice?.toStringAsFixed(0) ?? '');
    final minYearController =
        TextEditingController(text: minYear?.toString() ?? '');
    final maxKmController =
        TextEditingController(text: maxKm?.toString() ?? '');
    var fuel = selectedFuel;
    var brand = selectedBrand;
    var model = selectedModel;
    final brands = ['Todas', ...cars.map((car) => car.brand).toSet().toList()..sort()];
    final models = ['Todos', ...cars.where((car) => brand == 'Todas' || car.brand == brand).map((car) => car.model).toSet().toList()..sort()];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF17191E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20, 12, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 42, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Filtrar vehículos',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  const Text('Encuentra el coche que encaja contigo.',
                    style: TextStyle(color: Colors.white60)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: brands.contains(brand) ? brand : 'Todas',
                    decoration: const InputDecoration(labelText: 'Marca'),
                    items: brands.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) {
                      if (value != null) setSheetState(() {
                        brand = value;
                        final available = cars.where((car) => brand == 'Todas' || car.brand == brand).map((car) => car.model).toSet();
                        if (model != 'Todos' && !available.contains(model)) model = 'Todos';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: (brand == 'Todas' ? cars.map((car) => car.model).toSet() : cars.where((car) => car.brand == brand).map((car) => car.model).toSet()).contains(model) ? model : 'Todos',
                    decoration: const InputDecoration(labelText: 'Modelo'),
                    items: ['Todos', ...cars.where((car) => brand == 'Todas' || car.brand == brand).map((car) => car.model).toSet().toList()..sort()].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) { if (value != null) setSheetState(() => model = value); },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: fuel,
                    decoration: const InputDecoration(labelText: 'Combustible'),
                    items: const [
                      DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                      DropdownMenuItem(value: 'Diésel', child: Text('Diésel')),
                      DropdownMenuItem(value: 'Gasolina', child: Text('Gasolina')),
                      DropdownMenuItem(value: 'Híbrido', child: Text('Híbrido')),
                      DropdownMenuItem(value: 'Eléctrico', child: Text('Eléctrico')),
                    ],
                    onChanged: (value) {
                      if (value != null) setSheetState(() => fuel = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: minPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Precio mínimo (€)'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(
                      controller: maxPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Precio máximo (€)'),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: minYearController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Año desde'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(
                      controller: maxKmController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Máximo kilómetros'),
                    )),
                  ]),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          selectedFuel = 'Todos';
                          selectedBrand = 'Todas';
                          selectedModel = 'Todos';
                          minPrice = null;
                          maxPrice = null;
                          minYear = null;
                          maxKm = null;
                        });
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Limpiar'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: gold, foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        double? parseDouble(String value) =>
                            double.tryParse(value.trim().replaceAll(',', '.'));
                        int? parseInt(String value) =>
                            int.tryParse(value.trim().replaceAll('.', ''));
                        setState(() {
                          selectedFuel = fuel;
                          selectedBrand = brand;
                          selectedModel = model;
                          minPrice = parseDouble(minPriceController.text);
                          maxPrice = parseDouble(maxPriceController.text);
                          minYear = parseInt(minYearController.text);
                          maxKm = parseInt(maxKmController.text);
                        });
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Ver resultados'),
                    )),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    minPriceController.dispose();
    maxPriceController.dispose();
    minYearController.dispose();
    maxKmController.dispose();
  }

  String euros(double price) =>
      '${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => '.',
      )} €';

  Future<void> contact(Car car) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final loggedIn = await requireAutomotorsLogin(context);
      if (loggedIn && mounted) await contact(car);
      return;
    }
    if (car.listingId == null || car.ownerId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este vehículo de demostración aún no tiene un chat disponible.')),
      );
      return;
    }
    if (car.ownerId == user.id) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes iniciar un chat contigo mismo.')),
      );
      return;
    }
    try {
      final supabase = Supabase.instance.client;
      final existing = await supabase
          .from('chat_conversations')
          .select('id')
          .eq('listing_id', car.listingId!)
          .eq('buyer_id', user.id)
          .eq('seller_id', car.ownerId!)
          .maybeSingle();
      final conversation = existing ?? await supabase
          .from('chat_conversations')
          .insert({
            'listing_id': car.listingId,
            'buyer_id': user.id,
            'seller_id': car.ownerId,
          })
          .select('id')
          .single();
      if (!mounted) return;
      await Navigator.push<void>(context, MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversation['id'].toString(),
          title: '${car.brand} ${car.model}',
        ),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el chat. Comprueba la configuración de Supabase. ($error)'),
          duration: const Duration(seconds: 6)),
      );
    }
  }

  Future<void> openAddCar() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      final loggedIn = await requireAutomotorsLogin(context);
      if (!loggedIn || !mounted) return;
    }
    final publishFree = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PublishOptionsPage()),
    );
    if (publishFree != true || !mounted) return;

    final car = await Navigator.push<Car>(
      context,
      MaterialPageRoute(builder: (_) => const AddCarPage()),
    );
    if (car != null && mounted) setState(() => cars.insert(0, car));
  }

  void openCarDetails(Car car) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CarDetailsPage(
          car: car,
          priceText: euros(car.price),
          onContact: () => contact(car),
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredCars;
    final isWide = MediaQuery.of(context).size.width >= 760;
    final activeFilterCount = [
      selectedFuel != 'Todos',
      selectedBrand != 'Todas',
      selectedModel != 'Todos',
      minPrice != null,
      maxPrice != null,
      minYear != null,
      maxKm != null,
    ].where((active) => active).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: black,
        titleSpacing: 18,
        title: Row(
          children: [
            const AutomotorsBrandMark(size: 36),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AUTOMOTORS',
                    style: TextStyle(
                      fontSize: 17,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w900,
                    )),
                Text('MOTOR MARKET',
                    style: TextStyle(
                      color: gold, fontSize: 9, letterSpacing: 2.1,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar anuncios',
            onPressed: loadCars,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: gold,
        onRefresh: loadCars,
        child: ListView(
          padding: EdgeInsets.fromLTRB(isWide ? 28 : 16, 10, isWide ? 28 : 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF292D35), Color(0xFF15171B)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Stack(
                children: [
                  const Positioned(
                    right: -10,
                    bottom: -24,
                    child: Icon(Icons.directions_car_filled,
                        size: 135, color: Color(0x18D4AF37)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text('VEHÍCULOS VERIFICADOS',
                          style: TextStyle(color: gold, fontSize: 10,
                            letterSpacing: 1.1, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 14),
                      const Text('Encuentra\ntu próximo coche.',
                        style: TextStyle(fontSize: 29, height: 1.08,
                          fontWeight: FontWeight.w900, letterSpacing: -.6)),
                      const SizedBox(height: 8),
                      const Text('Vehículos de particulares y profesionales.',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push<void>(context,
                          MaterialPageRoute(builder: (_) => AllVehiclesPage(
                            cars: List<Car>.from(cars),
                            onOpenCar: openCarDetails,
                          ))),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                        label: const Text('Ver vehículos'),
                        style: OutlinedButton.styleFrom(foregroundColor: gold, side: const BorderSide(color: gold), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), textStyle: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 18),
                      Row(children: [
                        const Icon(Icons.verified_user_outlined, color: gold, size: 17),
                        const SizedBox(width: 7),
                        Text('${cars.length} vehículos anunciados',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: RawAutocomplete<String>(
                    textEditingController: searchController,
                    focusNode: searchFocusNode,
                    optionsBuilder: (value) {
                      final query = value.text.trim().toLowerCase();
                      if (query.isEmpty) return const Iterable<String>.empty();
                      final options = <String>{};
                      for (final car in cars) {
                        if (car.brand.toLowerCase().contains(query)) options.add(car.brand);
                        if (car.model.toLowerCase().contains(query)) options.add(car.model);
                        final fullName = '${car.brand} ${car.model}';
                        if (fullName.toLowerCase().contains(query)) options.add(fullName);
                      }
                      return options.take(8);
                    },
                    onSelected: (value) {
                      searchController.text = value;
                      setState(() {});
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => onFieldSubmitted(),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Escribe marca o modelo...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: controller.text.isEmpty ? null : IconButton(
                          tooltip: 'Borrar búsqueda', icon: const Icon(Icons.close_rounded),
                          onPressed: () { controller.clear(); setState(() {}); },
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1B1E24),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    optionsViewBuilder: (context, onSelected, options) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: const Color(0xFF202020),
                        elevation: 8,
                        borderRadius: BorderRadius.circular(14),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260, maxWidth: 420),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shrinkWrap: true,
                            children: options.map((option) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.search, color: gold, size: 19),
                              title: Text(option.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () => onSelected(option),
                            )).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 54,
                  width: 56,
                  child: OutlinedButton(
                    onPressed: openFilters,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(color: activeFilterCount > 0 ? gold : Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.tune_rounded, color: gold),
                        if (activeFilterCount > 0)
                          Positioned(
                            right: -9, top: -9,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: gold, shape: BoxShape.circle),
                              child: Text('$activeFilterCount',
                                style: const TextStyle(color: Colors.black, fontSize: 10,
                                  fontWeight: FontWeight.w900)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _fuelChip('Todos'),
                  const SizedBox(width: 8),
                  _fuelChip('Diésel'),
                  const SizedBox(width: 8),
                  _fuelChip('Gasolina'),
                  const SizedBox(width: 8),
                  _fuelChip('Híbrido'),
                  const SizedBox(width: 8),
                  _fuelChip('Eléctrico'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(child: Text('Últimos vehículos', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
                TextButton(onPressed: () => Navigator.push<void>(context,
                  MaterialPageRoute(builder: (_) => AllVehiclesPage(
                    cars: List<Car>.from(cars), onOpenCar: openCarDetails))),
                  child: const Text('Ver todos  →', style: TextStyle(color: gold, fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 10),
            if (loadingCars)
              const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: gold)))
            else if (cars.isNotEmpty)
              SizedBox(
                height: 245,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cars.length > 2 ? 2 : cars.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final car = cars[index];
                    return SizedBox(
                      width: 230,
                      child: Card(
                        color: const Color(0xFF171717), margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: gold.withValues(alpha: .25))),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(onTap: () => openCarDetails(car), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: SizedBox(width: double.infinity, child: Stack(fit: StackFit.expand, children: [car.photos.isNotEmpty ? Image.memory(car.photos.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.directions_car, size: 58, color: gold))) : const Center(child: Icon(Icons.directions_car, size: 58, color: gold)), if (car.status == 'reserved') const Positioned(left: 0, top: 14, child: _ReservedRibbon())]))),
                          Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${car.brand} ${car.model}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text('${car.year} · ${car.km} km · ${car.fuel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                            const SizedBox(height: 4), Text(euros(car.price), style: const TextStyle(color: gold, fontSize: 17, fontWeight: FontWeight.w900)),
                          ])),
                        ])),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: gold.withValues(alpha: .6)), gradient: const LinearGradient(colors: [Color(0xFF241B0A), Color(0xFF101010)])),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('¿Tienes un vehículo?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                const Text('Publica tu anuncio y llega a miles de compradores.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: openAddCar, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Publicar mi vehículo'), style: OutlinedButton.styleFrom(foregroundColor: gold, side: const BorderSide(color: gold), padding: const EdgeInsets.symmetric(vertical: 13), textStyle: const TextStyle(fontWeight: FontWeight.w900)))),
              ]),
            ),
            const SizedBox(height: 12),
            Card(color: const Color(0xFF101010), margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: gold.withValues(alpha: .35))), child: ListTile(
              leading: const Icon(Icons.diamond_outlined, color: gold, size: 34),
              title: const Text('Packs y suscripción', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text('Destaca tus anuncios y consigue más visibilidad.', style: TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.chevron_right_rounded, color: gold),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishOptionsPage())),
            )),

          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF15171B),
        indicatorColor: gold.withValues(alpha: .16),
        selectedIndex: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) async {
          if (index == 0) return;
          if (index == 1) {
            if (Supabase.instance.client.auth.currentUser == null) {
              final loggedIn = await requireAutomotorsLogin(context);
              if (!loggedIn || !context.mounted) return;
            }
            if (!context.mounted) return;
            await Navigator.push<void>(context,
              MaterialPageRoute(builder: (_) => const InboxPage()));
          } else if (index == 2) {
            await openAddCar();
          } else if (index == 3) {
            if (Supabase.instance.client.auth.currentUser == null) {
              final loggedIn = await requireAutomotorsLogin(context);
              if (!loggedIn || !context.mounted) return;
            }
            if (!context.mounted) return;
            final currentUser = Supabase.instance.client.auth.currentUser;
            if (currentUser == null || !context.mounted) return;
            await Navigator.push<void>(context,
              MaterialPageRoute(
                builder: (_) => PublicSellerProfilePage(ownerId: currentUser.id),
              ),
            );
            if (mounted) loadCars();
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Publicar'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _fuelChip(String fuel) {
    final selected = selectedFuel == fuel;
    return ChoiceChip(
      label: Text(fuel),
      selected: selected,
      onSelected: (_) => setState(() => selectedFuel = fuel),
      selectedColor: gold,
      backgroundColor: const Color(0xFF1B1E24),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white70,
        fontSize: 12,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      ),
      side: BorderSide(color: selected ? gold : Colors.white12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      showCheckmark: false,
    );
  }

  Widget _carMeta(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: Colors.white54),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }

  String _formatCompactKm(int km) {
    if (km <= 0) return 'Km —';
    return '${km.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} km';
  }
}

class AllVehiclesPage extends StatefulWidget {
  final List<Car> cars;
  final ValueChanged<Car> onOpenCar;
  const AllVehiclesPage({super.key, required this.cars, required this.onOpenCar});
  @override
  State<AllVehiclesPage> createState() => _AllVehiclesPageState();
}

class _AllVehiclesPageState extends State<AllVehiclesPage> {
  final search = TextEditingController();
  String brand = 'Todas';
  String model = 'Todos';
  String fuel = 'Todos';
  double minPrice = 0, maxPrice = 200000;
  int minKm = 0, maxKm = 300000, minCv = 0, maxCv = 1000;
  int minYear = 1990, maxYear = DateTime.now().year + 1;
  bool showFilters = false;

  @override
  void dispose() { search.dispose(); super.dispose(); }
  String euros(double price) => '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} €';
  String number(int value) => value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  List<String> get brands => ['Todas', ...widget.cars.map((c) => c.brand).toSet().toList()..sort()];
  List<String> get models => ['Todos', ...widget.cars.where((c) => brand == 'Todas' || c.brand == brand).map((c) => c.model).toSet().toList()..sort()];
  List<Car> get results => widget.cars.where((c) {
    final q = search.text.trim().toLowerCase();
    return ('${c.brand} ${c.model}'.toLowerCase().contains(q)) &&
      (brand == 'Todas' || c.brand == brand) && (model == 'Todos' || c.model == model) &&
      (fuel == 'Todos' || c.fuel.toLowerCase() == fuel.toLowerCase()) &&
      c.price >= minPrice && c.price <= maxPrice && c.km >= minKm && c.km <= maxKm &&
      (c.cv == null || (c.cv! >= minCv && c.cv! <= maxCv)) &&
      (c.year == 0 || (c.year >= minYear && c.year <= maxYear));
  }).toList();

  Widget rangeField(String label, int value, int min, int max, ValueChanged<int> onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text(label)), Text(number(value), style: const TextStyle(color: gold, fontWeight: FontWeight.bold))]),
    Slider(value: value.clamp(min, max).toDouble(), min: min.toDouble(), max: max.toDouble(), divisions: 100, activeColor: gold, onChanged: (v) => onChanged(v.round())),
  ]);
  Widget priceRange() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Expanded(child: Text('Precio (€)')), Text('${euros(minPrice)} – ${euros(maxPrice)}', style: const TextStyle(color: gold, fontSize: 12))]),
    RangeSlider(values: RangeValues(minPrice.clamp(0, 200000).toDouble(), maxPrice.clamp(0, 200000).toDouble()), min: 0, max: 200000, divisions: 200, activeColor: gold, onChanged: (v) => setState(() { minPrice = v.start; maxPrice = v.end; })),
  ]);

  @override
  Widget build(BuildContext context) {
    final found = results;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      appBar: AppBar(backgroundColor: const Color(0xFF15171B), title: const Text('Ver vehículos', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(tooltip: 'Restablecer filtros', onPressed: () => setState(() { search.clear(); brand='Todas'; model='Todos'; fuel='Todos'; minPrice=0; maxPrice=200000; minKm=0; maxKm=300000; minCv=0; maxCv=1000; minYear=1990; maxYear=DateTime.now().year+1; }), icon: const Icon(Icons.restart_alt, color: gold))]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: TextField(controller: search, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'Buscar marca, modelo, versión...', prefixIcon: const Icon(Icons.search), suffixIcon: search.text.isEmpty ? null : IconButton(onPressed: () { search.clear(); setState(() {}); }, icon: const Icon(Icons.close)), filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [Expanded(child: Text('${found.length} vehículos encontrados', style: const TextStyle(color: Colors.white70))), OutlinedButton.icon(onPressed: () => setState(() => showFilters = !showFilters), icon: const Icon(Icons.tune, color: gold), label: Text(showFilters ? 'Ocultar filtros' : 'Filtros'), style: OutlinedButton.styleFrom(foregroundColor: gold, side: const BorderSide(color: gold))) ])),
        if (showFilters) Expanded(flex: 0, child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 390), child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: Column(children: [
          Row(children: [Expanded(child: DropdownButtonFormField<String>(value: brand, isExpanded: true, decoration: const InputDecoration(labelText: 'Marca'), items: brands.map((v) => DropdownMenuItem(value:v, child:Text(v, overflow:TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() { brand=v??'Todas'; if (!models.contains(model)) model='Todos'; }))), const SizedBox(width:10), Expanded(child: DropdownButtonFormField<String>(value: models.contains(model)?model:'Todos', isExpanded:true, decoration: const InputDecoration(labelText:'Modelo'), items: models.map((v)=>DropdownMenuItem(value:v,child:Text(v,overflow:TextOverflow.ellipsis))).toList(), onChanged:(v)=>setState(()=>model=v??'Todos')))]),
          const SizedBox(height:8), DropdownButtonFormField<String>(value:fuel, decoration: const InputDecoration(labelText:'Combustible'), items: const ['Todos','Diésel','Gasolina','Híbrido','Eléctrico','GLP','GNC'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>fuel=v??'Todos')),
          const SizedBox(height:8), priceRange(),
          rangeField('Kilometraje mínimo (km)', minKm, 0, 300000, (v)=>setState(()=>minKm=v)),
          rangeField('Kilometraje máximo (km)', maxKm, 0, 300000, (v)=>setState(()=>maxKm=v)),
          rangeField('Potencia mínima (CV)', minCv, 0, 1000, (v)=>setState(()=>minCv=v)),
          rangeField('Potencia máxima (CV)', maxCv, 0, 1000, (v)=>setState(()=>maxCv=v)),
          rangeField('Año mínimo', minYear, 1990, DateTime.now().year+1, (v)=>setState(()=>minYear=v)),
          rangeField('Año máximo', maxYear, 1990, DateTime.now().year+1, (v)=>setState(()=>maxYear=v)),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed:()=>setState(()=>showFilters=false), child: const Text('Mostrar resultados', style: TextStyle(color:gold)))),
        ])))),
        Expanded(child: found.isEmpty ? const Center(child: Text('No hay vehículos que coincidan con estos filtros.', textAlign: TextAlign.center, style: TextStyle(color:Colors.white70))) : LayoutBuilder(builder:(context, constraints) {
          final columns = constraints.maxWidth >= 1100 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: found.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              mainAxisExtent: columns == 1 ? 390 : 380,
            ),
            itemBuilder: (context, index) {
              final car = found[index];
              return Card(
                color: const Color(0xFF11171D),
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: gold.withValues(alpha: .30)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => widget.onOpenCar(car),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        child: Stack(fit: StackFit.expand, children: [
                          car.photos.isNotEmpty
                              ? Image.memory(car.photos.first, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.directions_car, color: gold, size: 64)))
                              : const Center(child: Icon(Icons.directions_car, color: gold, size: 64)),
                          if (car.status == 'reserved')
                            const Positioned(left: 0, top: 18, child: _ReservedRibbon()),
                          Positioned(
                            right: 12, top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: .72), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white24)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 14),
                                const SizedBox(width: 5),
                                Text('${car.photos.length} fotos', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${car.brand} ${car.model}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 9),
                        Wrap(spacing: 7, runSpacing: 6, children: [
                          _CarFeaturePill(icon: Icons.calendar_month_outlined, label: '${car.year}'),
                          _CarFeaturePill(icon: Icons.speed_rounded, label: '${number(car.km)} km'),
                          if (car.cv != null) _CarFeaturePill(icon: Icons.bolt_rounded, label: '${car.cv} CV'),
                          _CarFeaturePill(icon: Icons.local_gas_station_outlined, label: car.fuel),
                        ]),
                        const SizedBox(height: 12),
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Expanded(child: Text(euros(car.price), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: gold, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.4))),
                          const Icon(Icons.arrow_forward_rounded, color: gold, size: 22),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          );
        })),
      ]),
    );
  }
}

class CarDetailsPage extends StatelessWidget {
  final Car car;
  final String priceText;
  final VoidCallback onContact;

  const CarDetailsPage({
    super.key,
    required this.car,
    required this.priceText,
    required this.onContact,
  });

  void _openFullScreenGallery(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullScreenGalleryPage(
          photos: car.photos,
          initialIndex: initialIndex,
          title: '${car.brand} ${car.model}',
        ),
      ),
    );
  }

  String _formatKm(int km) => km.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => '.',
      );

  Widget _technicalRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: gold, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gallery(BuildContext context, {required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: car.photos.isNotEmpty
          ? Stack(
              children: [
                PageView.builder(
                  itemCount: car.photos.length,
                  itemBuilder: (context, index) => InkWell(
                    onTap: () => _openFullScreenGallery(context, index),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.memory(
                        car.photos[index],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ),
                if (car.photos.length > 1)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Text(
                          '${car.photos.length} fotografías · desliza para ver más',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                if (car.etiquetaMedioambiental != null &&
                    car.etiquetaMedioambiental!.trim().isNotEmpty &&
                    car.etiquetaMedioambiental!.toLowerCase() != 'sin etiqueta')
                  Positioned(
                    left: 12,
                    top: 12,
                    child: EnvironmentalSticker(
                      label: car.etiquetaMedioambiental,
                      size: 68,
                    ),
                  ),
              ],
            )
          : const Center(
              child: Icon(Icons.directions_car, size: 100, color: gold),
            ),
    );
  }

  Widget _vehicleInformation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${car.brand} ${car.model}',
          style: const TextStyle(
            fontSize: 27,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          priceText,
          style: const TextStyle(
            color: gold,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 22),
        Card(
          color: panel,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.white10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 2),
                  child: Text(
                    'Características',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _technicalRow(
                  Icons.directions_car_outlined,
                  'Marca y modelo',
                  '${car.brand} ${car.model}',
                ),
                const Divider(height: 1, color: Colors.white12),
                _technicalRow(
                  Icons.calendar_today_outlined,
                  'Año',
                  car.year > 0 ? '${car.year}' : 'No indicado',
                ),
                const Divider(height: 1, color: Colors.white12),
                _technicalRow(
                  Icons.speed,
                  'Kilómetros',
                  '${_formatKm(car.km)} km',
                ),
                const Divider(height: 1, color: Colors.white12),
                _technicalRow(
                  Icons.local_gas_station_outlined,
                  'Combustible',
                  car.fuel.isNotEmpty ? car.fuel : 'No indicado',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Ficha técnica',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (car.matricula != null && car.matricula!.trim().isNotEmpty)
          _technicalRow(
            Icons.confirmation_number_outlined,
            'Matrícula',
            car.matricula!,
          ),
        if (car.vin?.trim().isNotEmpty == true)
          _technicalRow(Icons.qr_code_2_outlined, 'Número VIN / bastidor', car.vin!),
        if (car.cv != null)
          _technicalRow(Icons.speed, 'Potencia', '${car.cv} CV'),
        if (car.cilindradaCc != null)
          _technicalRow(Icons.settings, 'Cilindrada', '${car.cilindradaCc} cc'),
        if (car.etiquetaMedioambiental != null &&
            car.etiquetaMedioambiental!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                EnvironmentalSticker(
                  label: car.etiquetaMedioambiental,
                  size: 54,
                ),
                const SizedBox(width: 12),
                const Text('Etiqueta medioambiental'),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    car.etiquetaMedioambiental!,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: environmentalLabelColor(
                        car.etiquetaMedioambiental,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (car.version?.trim().isNotEmpty == true) _technicalRow(Icons.badge_outlined, 'Versión', car.version!),
        if (car.transmission?.trim().isNotEmpty == true) _technicalRow(Icons.settings_outlined, 'Transmisión', car.transmission!),
        if (car.bodyType?.trim().isNotEmpty == true) _technicalRow(Icons.directions_car_outlined, 'Carrocería', car.bodyType!),
        if (car.doors != null) _technicalRow(Icons.door_front_door_outlined, 'Puertas', '${car.doors}'),
        if (car.seats != null) _technicalRow(Icons.event_seat_outlined, 'Plazas', '${car.seats}'),
        if (car.color?.trim().isNotEmpty == true) _technicalRow(Icons.palette_outlined, 'Color', car.color!),
        if (car.emissionsStandard?.trim().isNotEmpty == true) _technicalRow(Icons.eco_outlined, 'Normativa de emisiones', car.emissionsStandard!),
        if (car.lengthMm != null) _technicalRow(Icons.straighten, 'Longitud', '${car.lengthMm} mm'),
        if (car.widthMm != null) _technicalRow(Icons.straighten, 'Anchura', '${car.widthMm} mm'),
        if (car.heightMm != null) _technicalRow(Icons.height, 'Altura', '${car.heightMm} mm'),
        if (car.wheelbaseMm != null) _technicalRow(Icons.straighten, 'Distancia entre ejes', '${car.wheelbaseMm} mm'),
        if (car.weightKg != null) _technicalRow(Icons.scale_outlined, 'Peso', '${car.weightKg} kg'),
        if (car.trunkLiters != null) _technicalRow(Icons.luggage_outlined, 'Maletero', '${car.trunkLiters} litros'),
        if (car.tankLiters != null) _technicalRow(Icons.local_gas_station_outlined, 'Depósito', '${car.tankLiters} litros'),
        if (car.equipment.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Equipamiento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            color: panel,
            child: Column(
              children: car.equipment.map((item) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline, color: gold),
                title: Text(item),
              )).toList(),
            ),
          ),
        ],
        if (car.description.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            'Descripción',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              car.description,
              style: TextStyle(height: 1.5, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (car.ownerId != null) ...[
          OutlinedButton.icon(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => PublicSellerProfilePage(ownerId: car.ownerId!),
              ),
            ),
            icon: const Icon(Icons.account_circle_outlined, color: gold),
            label: const Text('Ver perfil del vendedor'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: gold),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: onContact,
            icon: const Icon(Icons.chat),
            label: const Text('Enviar mensaje al vendedor'),
          ),
        ),
        if (validWhatsAppDigits(car.phone) != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF25D366),
                side: const BorderSide(color: Color(0xFF25D366)),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => openWhatsAppForCar(context, car),
              icon: const Icon(Icons.phone),
              label: const Text('Contactar por WhatsApp'),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${car.brand} ${car.model}')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 850;
          final maxWidth = isWide ? 1180.0 : 720.0;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: EdgeInsets.all(isWide ? 24 : 16),
                children: [
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _gallery(context, height: 430),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 5,
                          child: _vehicleInformation(context),
                        ),
                      ],
                    )
                  else ...[
                    _gallery(context, height: constraints.maxWidth < 500 ? 270 : 360),
                    const SizedBox(height: 20),
                    _vehicleInformation(context),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PublicSellerProfilePage extends StatefulWidget {
  final String ownerId;
  const PublicSellerProfilePage({super.key, required this.ownerId});

  @override
  State<PublicSellerProfilePage> createState() => _PublicSellerProfilePageState();
}

class _PublicSellerProfilePageState extends State<PublicSellerProfilePage> {
  final supabase = Supabase.instance.client;
  late Future<Map<String, dynamic>> dataFuture;

  @override
  void initState() {
    super.initState();
    dataFuture = loadSeller();
  }

  Future<Map<String, dynamic>> loadSeller() async {
    final profile = await supabase.from('user_profiles')
        .select('id, full_name, account_type, city, province, business_name, phone, profile_photo_path, cover_photo_path, estado_verificacion')
        .eq('id', widget.ownerId)
        .maybeSingle();
    final listings = await supabase.from('vehicle_listings')
        .select('id, status, year, km, price, fuel, phone, etiqueta_medioambiental, vehicle_brands(name), vehicle_models(name), vehicle_photos(storage_path, position)')
        .eq('owner_id', widget.ownerId)
        .inFilter('status', ['published', 'reserved'])
        .order('created_at', ascending: false);
    final soldListings = await supabase.from('vehicle_listings')
        .select('id, status, year, km, price, fuel, phone, etiqueta_medioambiental, vehicle_brands(name), vehicle_models(name), vehicle_photos(storage_path, position)')
        .eq('owner_id', widget.ownerId)
        .eq('status', 'sold')
        .order('created_at', ascending: false);
    final listingRows = List<Map<String, dynamic>>.from(listings);
    final soldRows = List<Map<String, dynamic>>.from(soldListings);
    for (final listing in [...listingRows, ...soldRows]) {
      final rawPhotos = listing['vehicle_photos'];
      final photoRows = rawPhotos is List
          ? List<Map<String, dynamic>>.from(rawPhotos)
          : <Map<String, dynamic>>[];
      photoRows.sort((a, b) => ((a['position'] as num?)?.toInt() ?? 0)
          .compareTo((b['position'] as num?)?.toInt() ?? 0));
      final path = photoRows.isEmpty ? null : photoRows.first['storage_path']?.toString();
      Uint8List? firstPhoto;
      if (path != null && path.isNotEmpty) {
        try {
          firstPhoto = await supabase.storage.from('vehicle-photos').download(path);
        } catch (_) {
          // Si no se puede descargar la imagen, se muestra el icono del vehículo.
        }
      }
      listing['_firstPhotoBytes'] = firstPhoto;
    }
    return {'profile': profile, 'listings': listingRows, 'soldListings': soldRows};
  }

  String? publicPhotoUrl(dynamic path) {
    final value = path?.toString() ?? '';
    if (value.isEmpty) return null;
    return supabase.storage.from('profile-photos').getPublicUrl(value);
  }

  String displayName(Map<String, dynamic>? profile) {
    if (profile == null) return 'Vendedor AUTOMOTORS';
    final type = (profile['account_type'] ?? 'particular').toString().toLowerCase();
    if (type == 'empresa' && (profile['business_name']?.toString().trim().isNotEmpty ?? false)) {
      return profile['business_name'].toString();
    }
    return (profile['full_name']?.toString().trim().isNotEmpty ?? false)
        ? profile!['full_name'].toString() : 'Vendedor AUTOMOTORS';
  }

  String euros(double price) =>
      '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} €';

  Future<void> openListingDetails(Map<String, dynamic> listing) async {
    final listingId = listing['id']?.toString();
    if (listingId == null || listingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar este anuncio.')),
      );
      return;
    }
    try {
      final raw = await supabase
          .from('vehicle_listings')
          .select('id, status, year, km, price, fuel, description, phone, matricula, vin, cv, cilindrada_cc, etiqueta_medioambiental, version, transmission, body_type, doors, seats, color, torque_nm, acceleration_0_100, max_speed_kmh, consumption_l_100, emissions_standard, length_mm, width_mm, height_mm, wheelbase_mm, weight_kg, trunk_liters, tank_liters, equipment, owner_id, vehicle_brands(name), vehicle_models(name), vehicle_photos(storage_path, position)')
          .eq('id', listingId)
          .inFilter('status', ['published', 'reserved', 'sold'])
          .maybeSingle();
      if (raw == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este anuncio ya no está disponible.')),
        );
        return;
      }
      final brandData = raw['vehicle_brands'];
      final modelData = raw['vehicle_models'];
      final photoData = raw['vehicle_photos'];
      final photoRows = photoData is List
          ? List<Map<String, dynamic>>.from(photoData)
          : <Map<String, dynamic>>[];
      photoRows.sort((a, b) => ((a['position'] as num?)?.toInt() ?? 0)
          .compareTo((b['position'] as num?)?.toInt() ?? 0));
      final photoBytes = <Uint8List>[];
      for (final photo in photoRows) {
        final path = photo['storage_path']?.toString();
        if (path == null || path.isEmpty) continue;
        try {
          photoBytes.add(await supabase.storage.from('vehicle-photos').download(path));
        } catch (_) {
          // El anuncio puede abrirse aunque una fotografía no esté disponible.
        }
      }
      final car = Car(
        brand: brandData is Map ? (brandData['name']?.toString() ?? 'Marca') : 'Marca',
        model: modelData is Map ? (modelData['name']?.toString() ?? 'Modelo') : 'Modelo',
        year: (raw['year'] as num?)?.toInt() ?? 0,
        km: (raw['km'] as num?)?.toInt() ?? 0,
        price: (raw['price'] as num?)?.toDouble() ?? 0,
        fuel: raw['fuel']?.toString() ?? '',
        description: raw['description']?.toString() ?? '',
        phone: raw['phone']?.toString() ?? '',
        matricula: raw['matricula']?.toString(),
        vin: raw['vin']?.toString(),
        cv: (raw['cv'] as num?)?.toInt(),
        cilindradaCc: (raw['cilindrada_cc'] as num?)?.toInt(),
        etiquetaMedioambiental: raw['etiqueta_medioambiental']?.toString(),
        version: raw['version']?.toString(),
        transmission: raw['transmission']?.toString(),
        bodyType: raw['body_type']?.toString(),
        doors: (raw['doors'] as num?)?.toInt(),
        seats: (raw['seats'] as num?)?.toInt(),
        color: raw['color']?.toString(),
        torqueNm: (raw['torque_nm'] as num?)?.toInt(),
        acceleration0100: (raw['acceleration_0_100'] as num?)?.toDouble(),
        maxSpeedKmh: (raw['max_speed_kmh'] as num?)?.toInt(),
        consumptionL100: (raw['consumption_l_100'] as num?)?.toDouble(),
        emissionsStandard: raw['emissions_standard']?.toString(),
        lengthMm: (raw['length_mm'] as num?)?.toInt(),
        widthMm: (raw['width_mm'] as num?)?.toInt(),
        heightMm: (raw['height_mm'] as num?)?.toInt(),
        wheelbaseMm: (raw['wheelbase_mm'] as num?)?.toInt(),
        weightKg: (raw['weight_kg'] as num?)?.toInt(),
        trunkLiters: (raw['trunk_liters'] as num?)?.toInt(),
        tankLiters: (raw['tank_liters'] as num?)?.toInt(),
        equipment: raw['equipment'] is List ? List<String>.from((raw['equipment'] as List).map((item) => item.toString())) : const <String>[],
        photos: photoBytes,
        listingId: raw['id']?.toString(),
        ownerId: raw['owner_id']?.toString(),
        status: raw['status']?.toString() ?? 'published',
      );
      if (!mounted) return;
      await Navigator.push<void>(context, MaterialPageRoute(
        builder: (_) => CarDetailsPage(
          car: car,
          priceText: euros(car.price),
          onContact: () => contactSellerFromListing(car),
        ),
      ));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el anuncio: $error')),
      );
    }
  }

  Future<void> contactSellerFromListing(Car car) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      final loggedIn = await requireAutomotorsLogin(context);
      if (!loggedIn || !mounted) return;
    }
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null || car.listingId == null || car.ownerId == null) return;
    if (currentUser.id == car.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes iniciar un chat contigo mismo.')),
      );
      return;
    }
    try {
      final existing = await supabase.from('chat_conversations').select('id')
          .eq('listing_id', car.listingId!)
          .eq('buyer_id', currentUser.id)
          .eq('seller_id', car.ownerId!)
          .maybeSingle();
      final conversation = existing ?? await supabase.from('chat_conversations').insert({
        'listing_id': car.listingId,
        'buyer_id': currentUser.id,
        'seller_id': car.ownerId,
      }).select('id').single();
      if (!mounted) return;
      await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => ChatPage(
        conversationId: conversation['id'].toString(),
        title: '${car.brand} ${car.model}',
      )));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el chat: $error')),
      );
    }
  }

  int selectedProfileTab = 0;

  Widget profileStat(String value, String label) => Expanded(
    child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70), textAlign: TextAlign.center),
    ]),
  );

  Widget profileVehicleGrid(List<Map<String, dynamic>> rows, {required bool sold}) {
    if (rows.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          sold ? 'Este vendedor todavía no tiene vehículos vendidos.' : 'Este vendedor no tiene anuncios disponibles.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
      ));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth < 520 ? 1 : constraints.maxWidth < 900 ? 2 : 3;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: rows.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          mainAxisExtent: columns == 1 ? 365 : 390,
        ),
        itemBuilder: (context, index) {
          final listing = rows[index];
          final brand = listing['vehicle_brands'];
          final model = listing['vehicle_models'];
          final title = '${brand is Map ? brand['name'] ?? 'Marca' : 'Marca'} ${model is Map ? model['name'] ?? 'Modelo' : 'Modelo'}';
          final photo = listing['_firstPhotoBytes'];
          final price = (listing['price'] as num?)?.toDouble() ?? 0;
          final isReserved = listing['status']?.toString() == 'reserved';
          final label = listing['etiqueta_medioambiental']?.toString();
          return Card(
            color: const Color(0xFF10171D),
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF29323A)),
            ),
            child: InkWell(
              onTap: () => openListingDetails(listing),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: SizedBox(width: double.infinity, child: Stack(fit: StackFit.expand, children: [
                  photo is Uint8List
                      ? Image.memory(photo, fit: BoxFit.cover)
                      : const Center(child: Icon(Icons.directions_car, color: gold, size: 42)),
                  if (sold) Positioned.fill(child: Container(color: Colors.black.withValues(alpha: .15))),
                  if ((label ?? '').isNotEmpty && label!.toLowerCase() != 'sin etiqueta' && !sold)
                    Positioned(left: 5, top: 5, child: EnvironmentalSticker(label: label, size: 34)),
                  if (sold || isReserved) Positioned(top: 12, left: 0, right: 0, child: Transform.rotate(
                    angle: -.10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: sold
                            ? const [Color(0xFFFF424A), Color(0xFF970B18)]
                            : const [Color(0xFF168BFF), Color(0xFF063B96)]),
                        boxShadow: [BoxShadow(color: (sold ? const Color(0xFFFF2435) : const Color(0xFF168BFF)).withValues(alpha: .38), blurRadius: 10)],
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(sold ? Icons.verified_rounded : Icons.lock_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        Text(sold ? 'VENDIDO' : 'RESERVADO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: .8)),
                      ]),
                    ),
                  )),
                ]))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 9, 9, 11),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    const SizedBox(height: 5),
                    Text('${listing['year'] ?? ''} · ${((listing['km'] as num?)?.toInt() ?? 0)} km', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 7),
                    Text(euros(price), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: gold, fontSize: 15, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080D11),
    appBar: AppBar(
      backgroundColor: const Color(0xFF080D11),
      foregroundColor: gold,
      automaticallyImplyLeading: true,
      title: null,
      centerTitle: false,
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: gold));
        }
        if (snapshot.hasError) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(
            'No se pudo cargar el perfil público. Comprueba las políticas de lectura de user_profiles en Supabase.\\n${snapshot.error}',
            textAlign: TextAlign.center,
          )));
        }
        final result = snapshot.data ?? {};
        final profile = result['profile'] as Map<String, dynamic>?;
        final listings = List<Map<String, dynamic>>.from(result['listings'] ?? []);
        final soldListings = List<Map<String, dynamic>>.from(result['soldListings'] ?? []);
        final name = displayName(profile);
        final type = (profile?['account_type'] ?? 'particular').toString().toLowerCase();
        final verified = (profile?['estado_verificacion'] ?? '').toString().toLowerCase() == 'aprobada';
        final isVerifiedBusiness = verified && (type == 'empresa' || type == 'autonomo');
        final cover = publicPhotoUrl(profile?['cover_photo_path']);
        final avatar = publicPhotoUrl(profile?['profile_photo_path']);
        final phone = profile?['phone']?.toString() ?? '';
        final digits = validWhatsAppDigits(phone);
        final displayType = type == 'empresa' ? 'Empresa' : type == 'autonomo' ? 'Autónomo' : 'Particular';
        return Column(children: [
          if (isVerifiedBusiness)
            SizedBox(
              height: 178,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                if (cover != null)
                  Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: panel))
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF25211A), Color(0xFF080D11)]),
                    ),
                    child: const Center(child: Icon(Icons.directions_car_filled, color: gold, size: 72)),
                  ),
                Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: .12), Colors.black.withValues(alpha: .82)]))),
                Positioned(left: 18, right: 18, bottom: 18, child: Row(children: [
                  const Icon(Icons.directions_car_filled, color: gold, size: 30),
                  const SizedBox(width: 10),
                  Expanded(child: Text(name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.1))),
                ])),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Transform.translate(
              offset: const Offset(0, -26),
              child: Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: gold, boxShadow: [BoxShadow(color: gold.withValues(alpha: .22), blurRadius: 14)]),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: const Color(0xFF15191D),
                      backgroundImage: avatar == null ? null : NetworkImage(avatar),
                      onBackgroundImageError: avatar == null ? null : (_, __) {},
                      child: avatar == null ? const Icon(Icons.person, color: gold, size: 42) : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white))),
                      if (isVerifiedBusiness) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.verified, color: Color(0xFF168BFF), size: 20)),
                    ]),
                    const SizedBox(height: 3),
                    Text(displayType, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    if (finalCity(profile) is Widget) finalCity(profile),
                  ])),
                  if (supabase.auth.currentUser?.id != widget.ownerId && digits != null) IconButton(
                    tooltip: 'WhatsApp',
                    onPressed: () async {
                      final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent('Hola, te contacto desde tu perfil de AUTOMOTORS.')}');
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 27),
                  ),
                ]),
                const SizedBox(height: 19),
                Row(children: [
                  profileStat('${listings.length}', 'Anuncios'),
                  Container(width: 1, height: 34, color: const Color(0xFF29323A)),
                  profileStat('${soldListings.length}', 'Vendidos'),
                  Container(width: 1, height: 34, color: const Color(0xFF29323A)),
                  profileStat(isVerifiedBusiness ? 'Verificado' : '—', 'Confianza'),
                ]),
                if (supabase.auth.currentUser?.id == widget.ownerId) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push<void>(context, MaterialPageRoute(
                          builder: (_) => const ProfilePage(),
                        ));
                        if (!mounted) return;
                        setState(() => dataFuture = loadSeller());
                      },
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Mis datos y editar perfil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: gold,
                        side: const BorderSide(color: gold),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
                if (supabase.auth.currentUser?.id != widget.ownerId) ...[
                const SizedBox(height: 17),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: digits == null ? null : () async {
                      final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent('Hola, te contacto desde tu perfil de AUTOMOTORS.')}');
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('WhatsApp'),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF25D366), side: const BorderSide(color: Color(0xFF25D366)), padding: const EdgeInsets.symmetric(vertical: 12)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton.icon(
                    onPressed: () async {
                      final user = supabase.auth.currentUser;
                      if (user == null) {
                        final loggedIn = await requireAutomotorsLogin(context);
                        if (!loggedIn || !context.mounted) return;
                      }
                      final currentUser = supabase.auth.currentUser;
                      if (currentUser == null) return;
                      if (currentUser.id == widget.ownerId) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este es tu propio perfil.')));
                        return;
                      }
                      try {
                        final rows = await supabase.from('vehicle_listings').select('id')
                          .eq('owner_id', widget.ownerId).inFilter('status', ['published', 'reserved']).order('created_at', ascending: false).limit(1);
                        if (rows.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este vendedor no tiene anuncios disponibles para iniciar un chat.')));
                          return;
                        }
                        final listingId = rows.first['id'].toString();
                        final existing = await supabase.from('chat_conversations').select('id')
                          .eq('listing_id', listingId).eq('buyer_id', currentUser.id).eq('seller_id', widget.ownerId).maybeSingle();
                        final conversation = existing ?? await supabase.from('chat_conversations').insert({
                          'listing_id': listingId, 'buyer_id': currentUser.id, 'seller_id': widget.ownerId,
                        }).select('id').single();
                        if (!context.mounted) return;
                        await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => ChatPage(
                          conversationId: conversation['id'].toString(), title: name,
                        )));
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir el chat: $e')));
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 17),
                    label: const Text('Enviar mensaje'),
                    style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                  )),
                ]),
                ],
              ]),
            ),
          ),
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF29323A)))),
            child: Row(children: [
              _profileTabButton('Anuncios', 0),
              _profileTabButton('Vendidos', 1),
              _profileTabButton('Sobre nosotros', 2),
              _profileTabButton('Valoraciones', 3),
            ]),
          ),
          Expanded(child: IndexedStack(
            index: selectedProfileTab,
            children: [
              Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 15, 16, 0), child: Row(children: [
                  const Icon(Icons.directions_car_filled, color: Color(0xFF168BFF), size: 24),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Vehículos disponibles', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white))),
                  Text('${listings.length}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                ])),
                const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: Align(alignment: Alignment.centerLeft, child: Text('Anuncios publicados y reservados actualmente', style: TextStyle(color: Colors.white60, fontSize: 12)))),
                Expanded(child: profileVehicleGrid(listings, sold: false)),
              ]),
              Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 15, 16, 0), child: Row(children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFFFF424A), size: 24),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Vehículos vendidos', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white))),
                  Text('${soldListings.length}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                ])),
                const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: Align(alignment: Alignment.centerLeft, child: Text('Historial de vehículos vendidos por este vendedor', style: TextStyle(color: Colors.white60, fontSize: 12)))),
                Expanded(child: profileVehicleGrid(soldListings, sold: true)),
              ]),
              ListView(padding: const EdgeInsets.all(20), children: [
                const Text('Sobre nosotros', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 12),
                Text('$displayType', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                if (finalCity(profile) != const SizedBox.shrink()) finalCity(profile),
                if (isVerifiedBusiness) const ListTile(leading: Icon(Icons.verified_user, color: Color(0xFF25D366)), title: Text('Profesional verificado')),
                const ListTile(leading: Icon(Icons.directions_car, color: gold), title: Text('Vehículos disponibles y vendidos en AUTOMOTORS')),
              ]),
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_border_rounded, color: gold, size: 42),
                SizedBox(height: 10),
                Text('Valoraciones', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
                SizedBox(height: 6),
                Text('Las valoraciones aparecerán aquí cuando estén disponibles.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              ]))),
            ],
          )),
        ]);
      },
    ),
  );

  Widget _profileTabButton(String label, int index) => Expanded(
    child: InkWell(
      onTap: () => setState(() => selectedProfileTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 3),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selectedProfileTab == index ? const Color(0xFF168BFF) : Colors.transparent, width: 3))),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: selectedProfileTab == index ? FontWeight.w900 : FontWeight.w500, color: selectedProfileTab == index ? Colors.white : Colors.white60)),
      ),
    ),
  );

  Widget finalCity(Map<String, dynamic>? profile) {
    final city = profile?['city']?.toString() ?? '';
    final province = profile?['province']?.toString() ?? '';
    final location = [city, province].where((v) => v.trim().isNotEmpty).join(', ');
    return location.isEmpty ? const SizedBox.shrink() : Text(location, style: const TextStyle(color: Colors.white70));
  }
}

class FullScreenGalleryPage extends StatefulWidget {
  final List<Uint8List> photos;
  final int initialIndex;
  final String title;

  const FullScreenGalleryPage({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.title,
  });

  @override
  State<FullScreenGalleryPage> createState() => _FullScreenGalleryPageState();
}

class _FullScreenGalleryPageState extends State<FullScreenGalleryPage> {
  late final PageController pageController;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          if (widget.photos.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${currentIndex + 1} / ${widget.photos.length}',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
        ],
      ),
      body: PageView.builder(
        controller: pageController,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.memory(
              widget.photos[index],
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}


class PersonalAreaPage extends StatelessWidget {
  const PersonalAreaPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Has cerrado sesión.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const AutomotorsBrandMark(size: 30),
          const SizedBox(width: 10),
          const Text('Mi espacio'),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF34302A), Color(0xFF17181B), Color(0xFF111214)],
              ),
              border: Border.all(color: gold.withValues(alpha: .48)),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.workspace_premium, color: gold),
                SizedBox(width: 8),
                Text('TU ESPACIO AUTOMOTORS', style: TextStyle(color: gold, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 14),
              FutureBuilder<Map<String, dynamic>?>(
                future: user == null ? Future.value(null) : Supabase.instance.client
                    .from('user_profiles').select('full_name, business_name').eq('id', user.id).maybeSingle(),
                builder: (context, snapshot) {
                  final profile = snapshot.data ?? <String, dynamic>{};
                  final business = profile['business_name']?.toString().trim() ?? '';
                  final fullName = profile['full_name']?.toString().trim() ?? '';
                  final displayName = business.isNotEmpty ? business : (fullName.isNotEmpty ? fullName : 'Conductor');
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Bienvenido', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -.4)),
                  ]);
                },
              ),
              const SizedBox(height: 8),
              const Text('Tu garaje, tus conversaciones y tus oportunidades, en un solo lugar.', style: TextStyle(color: Colors.white70, height: 1.4)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _PersonalQuickStat(icon: Icons.directions_car_filled_rounded, label: 'MI GARAJE', value: 'Gestiona tus coches', onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const GaragePage())))),
                const SizedBox(width: 12),
                Expanded(child: _PersonalQuickStat(icon: Icons.manage_accounts_rounded, label: 'TU CUENTA', value: 'Tu perfil a medida', onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const ProfilePage())))),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          Card(color: panel, child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: gold),
            title: const Text('Mis mensajes'),
            subtitle: const Text('Consulta tus conversaciones con compradores y vendedores'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const InboxPage())),
          )),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

class GaragePage extends StatefulWidget {
  const GaragePage({super.key});
  @override
  State<GaragePage> createState() => _GaragePageState();
}

class _GaragePageState extends State<GaragePage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> listingsFuture;
  bool busy = false;

  String euros(double price) =>
      '${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => '.',
      )} €';

  @override
  void initState() {
    super.initState();
    listingsFuture = loadMyListings();
  }

  Future<List<Map<String, dynamic>>> loadMyListings() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];
    final rows = await supabase.from('vehicle_listings').select(
      'id,status,year,km,price,fuel,phone,description,cv,cilindrada_cc,etiqueta_medioambiental,vin,owner_id,vehicle_brands(name),vehicle_models(name),vehicle_photos(storage_path,position)'
    ).eq('owner_id', user.id).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  void refreshListings() => setState(() => listingsFuture = loadMyListings());

  String listingName(Map<String, dynamic> listing) {
    final b = listing['vehicle_brands'];
    final m = listing['vehicle_models'];
    return '${b is Map ? b['name'] ?? 'Marca' : 'Marca'} ${m is Map ? m['name'] ?? 'Modelo' : 'Modelo'}';
  }

  Future<void> setListingStatus(Map<String, dynamic> listing, String status) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para gestionar tus anuncios.')),
      );
      return;
    }
    // Estados admitidos en Supabase: draft, published, reserved y sold.
    // Pausar se representa como borrador para mantener compatibilidad.
    final normalizedStatus = status == 'paused' ? 'draft' : status;
    if (!['draft', 'published', 'reserved', 'sold'].contains(normalizedStatus)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado de anuncio no válido.')),
      );
      return;
    }

    setState(() => busy = true);
    try {
      final updated = await supabase
          .from('vehicle_listings')
          .update({'status': normalizedStatus})
          .eq('id', listing['id'].toString())
          .eq('owner_id', user.id)
          .select('id,status')
          .maybeSingle();

      if (updated == null) {
        throw Exception('No se actualizó ningún anuncio. Comprueba que sea tuyo y que siga disponible.');
      }

      if (mounted) {
        final message = normalizedStatus == 'reserved'
            ? 'Anuncio marcado como reservado.'
            : normalizedStatus == 'sold'
                ? 'Anuncio marcado como vendido.'
                : normalizedStatus == 'draft'
                    ? 'Anuncio pausado.'
                    : 'Anuncio activado.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        refreshListings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el anuncio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteListing(Map<String, dynamic> listing) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Eliminar anuncio'),
      content: const Text('¿Seguro que quieres eliminar este anuncio? Esta acción no se puede deshacer.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
      ],
    ));
    if (confirm != true) return;
    setState(() => busy = true);
    try {
      await supabase.from('vehicle_listings').delete().eq('id', listing['id'].toString()).eq('owner_id', supabase.auth.currentUser!.id);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anuncio eliminado.'))); refreshListings(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar el anuncio: $e')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> openDetails(Map<String, dynamic> listing) async {
    try {
      final rawPhotos = listing['vehicle_photos'];
      final photoRows = rawPhotos is List ? List<Map<String, dynamic>>.from(rawPhotos) : <Map<String, dynamic>>[];
      photoRows.sort((a, b) => ((a['position'] as num?)?.toInt() ?? 0).compareTo((b['position'] as num?)?.toInt() ?? 0));
      final photos = <Uint8List>[];
      for (final photo in photoRows) {
        final path = photo['storage_path']?.toString();
        if (path == null || path.isEmpty) continue;
        try { photos.add(await supabase.storage.from('vehicle-photos').download(path)); } catch (_) { }
      }
      final brand = listing['vehicle_brands'];
      final model = listing['vehicle_models'];
      final car = Car(
        brand: brand is Map ? (brand['name']?.toString() ?? 'Marca') : 'Marca',
        model: model is Map ? (model['name']?.toString() ?? 'Modelo') : 'Modelo',
        year: (listing['year'] as num?)?.toInt() ?? 0,
        km: (listing['km'] as num?)?.toInt() ?? 0,
        price: (listing['price'] as num?)?.toDouble() ?? 0,
        fuel: listing['fuel']?.toString() ?? '',
        description: listing['description']?.toString() ?? '',
        phone: listing['phone']?.toString() ?? '',
        cv: (listing['cv'] as num?)?.toInt(),
        cilindradaCc: (listing['cilindrada_cc'] as num?)?.toInt(),
        etiquetaMedioambiental: listing['etiqueta_medioambiental']?.toString(),
        vin: listing['vin']?.toString(),
        photos: photos,
        listingId: listing['id']?.toString(),
        ownerId: listing['owner_id']?.toString(),
      );
      if (!mounted) return;
      await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => CarDetailsPage(
        car: car,
        priceText: euros(car.price),
        onContact: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este es tu anuncio; no puedes contactar contigo mismo.'))),
      )));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir la ficha del vehículo: $e')));
    }
  }

  Future<void> editListing(Map<String, dynamic> listing) async {
    final listingId = listing['id'].toString();
    try {
      // Releer el estado desde Supabase para no depender de un estado antiguo
      // que pudiera seguir en la tarjeta del garaje.
      final current = await supabase
          .from('vehicle_listings')
          .select('status')
          .eq('id', listingId)
          .eq('owner_id', supabase.auth.currentUser!.id)
          .maybeSingle();

      if (!mounted) return;
      if (current == null || current['status']?.toString() == 'sold') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Un vehículo vendido no se puede editar.')),
        );
        refreshListings();
        return;
      }

      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => EditListingPage(listingId: listingId)),
      );
      if (changed == true && mounted) refreshListings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo comprobar el estado del anuncio: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Gestiona tu garaje'),
      actions: [IconButton(onPressed: refreshListings, tooltip: 'Actualizar anuncios', icon: const Icon(Icons.refresh_rounded, color: gold))],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: listingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: gold));
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No se pudieron cargar tus anuncios: ${snapshot.error}')));
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Todavía no tienes anuncios. Publica tu primer vehículo para verlo aquí.')));
        return Stack(children: [
          ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Tus vehículos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Pulsa un anuncio para ver su ficha. Usa el menú para editar, pausar o eliminar.'),
            const SizedBox(height: 16),
            ...rows.map((listing) {
              final status = listing['status']?.toString() ?? 'published';
              final isReserved = status == 'reserved';
              final isSold = status == 'sold';
              final price = (listing['price'] as num?)?.toDouble() ?? 0;
              final rawPhotos = listing['vehicle_photos'];
              final photoRows = rawPhotos is List ? List<Map<String, dynamic>>.from(rawPhotos) : <Map<String, dynamic>>[];
              photoRows.sort((a, b) => ((a['position'] as num?)?.toInt() ?? 0).compareTo((b['position'] as num?)?.toInt() ?? 0));
              return Card(color: panel, clipBehavior: Clip.antiAlias, margin: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                InkWell(onTap: () => openDetails(listing), child: Stack(children: [
                  SizedBox(height: 205, child: GarageListingPhoto(path: photoRows.isEmpty ? null : photoRows.first['storage_path']?.toString())),
                  if (isReserved || isSold) Positioned(top: 16, right: 0, child: Container(
                    padding: const EdgeInsets.fromLTRB(13, 9, 16, 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isReserved
                            ? const [Color(0xFF168BFF), Color(0xFF063B96)]
                            : const [Color(0xFFFF424A), Color(0xFF970B18)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      border: Border(
                        top: BorderSide(color: isReserved ? const Color(0xFF83D8FF) : const Color(0xFFFFA4A8), width: 1),
                        bottom: BorderSide(color: isReserved ? const Color(0xFF041D52) : const Color(0xFF5D0610), width: 1),
                        left: BorderSide(color: Colors.white.withValues(alpha: .7), width: 1),
                      ),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                      boxShadow: [
                        BoxShadow(color: (isReserved ? const Color(0xFF168BFF) : const Color(0xFFFF2435)).withValues(alpha: .38), blurRadius: 14, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(isReserved ? Icons.lock_rounded : Icons.verified_rounded, size: 15, color: Colors.white),
                      const SizedBox(width: 7),
                      Text(isReserved ? 'RESERVADO' : 'VENDIDO', style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.1,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
                      )),
                    ]),
                  )),
                ])),
                Padding(padding: const EdgeInsets.fromLTRB(16, 13, 8, 0), child: Row(children: [
                  Expanded(child: InkWell(onTap: () => openDetails(listing), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(listingName(listing), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('${listing['year'] ?? ''} · ${((listing['km'] as num?)?.toInt() ?? 0)} km · ${euros(price)}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 5),
                    Text('Estado: ${isReserved ? 'Reservado' : isSold ? 'Vendido' : status == 'draft' || status == 'paused' ? 'Pausado' : status == 'published' ? 'Publicado' : status}', style: TextStyle(color: isReserved ? const Color(0xFF64B5F6) : isSold ? Colors.greenAccent : Colors.white60)),
                  ]))),
                  PopupMenuButton<String>(enabled: !busy, tooltip: 'Opciones del anuncio', onSelected: (value) {
                    if (value == 'edit') editListing(listing);
                    if (value == 'pause' && status != 'reserved' && status != 'sold') setListingStatus(listing, status == 'published' ? 'paused' : 'published');
                    if (value == 'delete') deleteListing(listing);
                    if (value == 'publish') setListingStatus(listing, 'published');
                  }, itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', enabled: !isSold, child: ListTile(leading: Icon(Icons.edit_outlined), title: Text(isSold ? 'No editable: vendido' : 'Editar'))),
                    PopupMenuItem(value: 'pause', enabled: status != 'reserved' && status != 'sold', child: ListTile(leading: Icon(status == 'published' ? Icons.pause : Icons.play_arrow), title: Text(status == 'published' ? 'Pausar' : 'Activar'))),
                    const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Eliminar'))),
                  ], icon: const Icon(Icons.more_vert, color: gold)),
                ])),
                Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 14), child: Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: busy || isSold ? null : () => setListingStatus(listing, 'sold'), icon: const Icon(Icons.check_circle_outline), label: const Text('Vendido'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: busy || isSold ? null : () => setListingStatus(listing, isReserved ? 'published' : 'reserved'), icon: Icon(isReserved ? Icons.event_available : Icons.bookmark_border), label: Text(isReserved ? 'Quitar reserva' : 'Reservar'))),
                ])),
              ]));
            }),
          ]),
          if (busy) const Align(alignment: Alignment.topCenter, child: LinearProgressIndicator(color: gold)),
        ]);
      },
    ),
  );
}

class GarageListingPhoto extends StatefulWidget {
  final String? path;
  const GarageListingPhoto({super.key, required this.path});
  @override
  State<GarageListingPhoto> createState() => _GarageListingPhotoState();
}

class _GarageListingPhotoState extends State<GarageListingPhoto> {
  Uint8List? bytes;
  @override
  void initState() { super.initState(); load(); }
  @override
  void didUpdateWidget(covariant GarageListingPhoto oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.path != widget.path) load(); }
  Future<void> load() async {
    final path = widget.path;
    if (path == null || path.isEmpty) { if (mounted) setState(() => bytes = null); return; }
    try {
      final result = await Supabase.instance.client.storage.from('vehicle-photos').download(path);
      if (mounted) setState(() => bytes = result);
    } catch (_) { if (mounted) setState(() => bytes = null); }
  }
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF15171B), width: double.infinity,
    child: bytes == null
      ? const Center(child: Icon(Icons.directions_car_filled, color: gold, size: 64))
      : Image.memory(bytes!, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.directions_car_filled, color: gold, size: 64))),
  );
}

class _PersonalQuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _PersonalQuickStat({required this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .22), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: gold, size: 20), const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: gold, fontSize: 9, letterSpacing: .7, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final fiscalId = TextEditingController();
  final phone = TextEditingController();
  final city = TextEditingController();
  final province = TextEditingController();
  final address = TextEditingController();
  final businessName = TextEditingController();
  String accountType = 'particular';
  String? verificationStatus;
  String? documentName;
  XFile? pickedDocument;
  Uint8List? pickedDocumentBytes;
  XFile? pickedProfilePhoto;
  XFile? pickedCoverPhoto;
  Uint8List? pickedProfilePhotoBytes;
  Uint8List? pickedCoverPhotoBytes;
  String? profilePhotoPath;
  String? coverPhotoPath;
  bool loading = true;
  bool saving = false;
  bool editing = false;

  bool get isProfessional => accountType == 'autonomo' || accountType == 'empresa';
  bool get isVerifiedProfessional => isProfessional && (verificationStatus ?? '').toLowerCase() == 'aprobada';

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    name.dispose();
    fiscalId.dispose();
    phone.dispose();
    city.dispose();
    province.dispose();
    address.dispose();
    businessName.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final row = await supabase.from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) {
        name.text = row['full_name']?.toString() ?? '';
        fiscalId.text = row['fiscal_id']?.toString() ?? '';
        phone.text = row['phone']?.toString() ?? '';
        city.text = row['city']?.toString() ?? '';
        province.text = row['province']?.toString() ?? '';
        address.text = row['address']?.toString() ?? '';
        businessName.text = row['business_name']?.toString() ?? '';
        final type = (row['account_type']?.toString() ?? 'particular').toLowerCase();
        accountType = ['particular', 'autonomo', 'empresa'].contains(type) ? type : 'particular';
        verificationStatus = row['estado_verificacion']?.toString() ?? 'No solicitada';
        documentName = row['verification_document_path']?.toString();
        profilePhotoPath = row['profile_photo_path']?.toString();
        coverPhotoPath = row['cover_photo_path']?.toString();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar el perfil. Comprueba que has aplicado el SQL de configuración. ($e)')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> chooseProfileImage({required bool cover}) async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (cover) { pickedCoverPhoto = file; pickedCoverPhotoBytes = bytes; }
        else { pickedProfilePhoto = file; pickedProfilePhotoBytes = bytes; }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo seleccionar la imagen: $e')));
    }
  }

  Future<String> uploadProfileImage(XFile file, Uint8List bytes, String kind, String userId) async {
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
    final path = '$userId/$kind-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('profile-photos').uploadBinary(path, bytes,
      fileOptions: FileOptions(upsert: true, contentType: ext == 'png' ? 'image/png' : 'image/jpeg'));
    return path;
  }

  Future<void> chooseDocument() async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result.isEmpty) return;

    final file = result.first;
    final bytes = await file.xFile.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception('No se pudieron leer los datos del archivo.');
    }

    if (bytes.length > 10 * 1024 * 1024) {
      throw Exception('El documento no puede superar 10 MB.');
    }

    setState(() {
      pickedDocument = XFile(file.name, bytes: bytes);
    });
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al seleccionar documento: $e')),
    );
  }
}

  Future<void> saveProfile() async {
    if (saving || !formKey.currentState!.validate()) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      String? documentPath;
      if (pickedDocument != null && pickedDocumentBytes != null) {
        final file = pickedDocument!;
        final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        documentPath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
        await supabase.storage.from('verification-documents').uploadBinary(
          documentPath,
          pickedDocumentBytes!,
          fileOptions: FileOptions(
            contentType: file.name.toLowerCase().endsWith('.pdf')
                ? 'application/pdf'
                : file.name.toLowerCase().endsWith('.png')
                    ? 'image/png'
                    : 'image/jpeg',
            upsert: false,
          ),
        );
      }

      if (pickedProfilePhoto != null && pickedProfilePhotoBytes != null) {
        profilePhotoPath = await uploadProfileImage(pickedProfilePhoto!, pickedProfilePhotoBytes!, 'profile', user.id);
      }
      if (pickedCoverPhoto != null && pickedCoverPhotoBytes != null) {
        coverPhotoPath = await uploadProfileImage(pickedCoverPhoto!, pickedCoverPhotoBytes!, 'cover', user.id);
      }

      final data = <String, dynamic>{
        'id': user.id,
        'email': user.email,
        'account_type': accountType == 'Autónomo'
            ? 'autonomo'
            : accountType.toLowerCase(),
        'full_name': name.text.trim(),
        'fiscal_id': fiscalId.text.trim().isEmpty ? null : fiscalId.text.trim(),
        'phone': phone.text.trim(),
        'city': city.text.trim(),
        'province': province.text.trim(),
        'business_name': isProfessional && accountType == 'empresa'
            ? businessName.text.trim()
            : null,
        'address': isProfessional ? address.text.trim() : null,
        'profile_photo_path': profilePhotoPath,
        'cover_photo_path': isVerifiedProfessional ? coverPhotoPath : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (documentPath != null) {
        data['verification_document_path'] = documentPath;
        data['estado_verificacion'] = 'Pendiente';
      } else if (isProfessional && verificationStatus == null) {
        data['estado_verificacion'] = 'No solicitada';
      }
      if (!isProfessional) {
        data['verification_document_path'] = null;
        data['estado_verificacion'] = 'No aplicable';
      }
      await supabase.from('user_profiles').upsert(data, onConflict: 'id');
      if (!mounted) return;
      setState(() {
        verificationStatus = data['estado_verificacion']?.toString() ?? verificationStatus;
        pickedDocument = null;
        pickedDocumentBytes = null;
        pickedProfilePhoto = null;
        pickedCoverPhoto = null;
        pickedProfilePhotoBytes = null;
        pickedCoverPhotoBytes = null;
        editing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil guardado correctamente.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el perfil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget field(String label, TextEditingController controller, {bool requiredField = false, TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (requiredField && (value == null || value.trim().isEmpty)) {
            return 'Completa este campo';
          }
          return null;
        },
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return ListTile(contentPadding: EdgeInsets.zero, title: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)), subtitle: Text(value, style: const TextStyle(fontSize: 16)));
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';
    final profileUrl = profilePhotoPath == null ? null : supabase.storage.from('profile-photos').getPublicUrl(profilePhotoPath!);
    final coverUrl = coverPhotoPath == null ? null : supabase.storage.from('profile-photos').getPublicUrl(coverPhotoPath!);
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [const AutomotorsBrandMark(size: 30), const SizedBox(width: 10), const Text('Mi perfil')]),
        actions: [if (!loading) IconButton(tooltip: editing ? 'Cancelar edición' : 'Editar perfil', icon: Icon(editing ? Icons.close : Icons.edit_outlined, color: gold), onPressed: () => setState(() => editing = !editing))],
      ),
      body: loading ? const Center(child: CircularProgressIndicator(color: gold)) : editing
        ? Form(key: formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
            if (isVerifiedProfessional) ...[
              GestureDetector(onTap: saving ? null : () => chooseProfileImage(cover: true), child: Container(height: 140, decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12), image: pickedCoverPhotoBytes != null ? DecorationImage(image: MemoryImage(pickedCoverPhotoBytes!), fit: BoxFit.cover) : (coverUrl != null ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover) : null)), child: const Center(child: Text('Cambiar foto de portada', style: TextStyle(backgroundColor: Colors.black54))))),
              const SizedBox(height: 12),
            ],
            Center(child: GestureDetector(onTap: saving ? null : () => chooseProfileImage(cover: false), child: CircleAvatar(radius: 48, backgroundColor: gold, backgroundImage: pickedProfilePhotoBytes != null ? MemoryImage(pickedProfilePhotoBytes!) : (profileUrl != null ? NetworkImage(profileUrl) : null) as ImageProvider?, child: (pickedProfilePhotoBytes == null && profileUrl == null) ? const Icon(Icons.add_a_photo, color: Colors.black, size: 28) : null))),
            const SizedBox(height: 8), const Center(child: Text('Pulsa la foto para cambiarla')),
            const SizedBox(height: 16),
            const Text('DATOS DE LA CUENTA', style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.email_outlined, color: gold), title: const Text('Correo electrónico'), subtitle: Text(email)),
            DropdownButtonFormField<String>(value: accountType, decoration: const InputDecoration(labelText: 'Tipo de cuenta'), items: const [DropdownMenuItem(value: 'particular', child: Text('Particular')), DropdownMenuItem(value: 'autonomo', child: Text('Autónomo')), DropdownMenuItem(value: 'empresa', child: Text('Empresa'))], onChanged: saving ? null : (value) { if (value != null) setState(() => accountType = value); }),
            const SizedBox(height: 16), const Text('DATOS PERSONALES', style: TextStyle(color: gold, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
            field(accountType == 'empresa' ? 'Nombre y apellidos de la persona de contacto' : 'Nombre y apellidos', name, requiredField: true),
            if (accountType == 'empresa') field('Razón social de la empresa', businessName, requiredField: true),
            if (isProfessional) field('CIF/NIF o identificación fiscal', fiscalId, requiredField: true) else field('DNI/NIE (opcional)', fiscalId),
            field('Teléfono', phone, requiredField: true, keyboard: TextInputType.phone), field('Ciudad', city, requiredField: true), field('Provincia', province, requiredField: true),
            if (isProfessional) ...[
              field(accountType == 'empresa' ? 'Dirección fiscal de la empresa' : 'Dirección fiscal o profesional', address, requiredField: true),
              const SizedBox(height: 8), const Text('VERIFICACIÓN DE CUENTA', style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8), const Text('Adjunta documentación para solicitar la verificación. La portada solo se habilita cuando la cuenta profesional está aprobada.'),
              OutlinedButton.icon(onPressed: saving ? null : chooseDocument, icon: const Icon(Icons.upload_file), label: Text(documentName == null ? 'Adjuntar documentación' : 'Documento: $documentName')),
              if (verificationStatus != null) Text('Estado de verificación: $verificationStatus'),
            ],
            const SizedBox(height: 24), FilledButton.icon(onPressed: saving ? null : saveProfile, style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)), icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: Text(saving ? 'Guardando...' : 'Guardar perfil')),
          ]))
        : ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: panel, border: Border.all(color: gold.withValues(alpha: .35))),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                if (coverUrl != null) SizedBox(height: 145, width: double.infinity, child: Image.network(coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF292929), alignment: Alignment.center, child: const Icon(Icons.landscape_outlined, color: gold, size: 34)))),
                Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 20), child: Column(children: [
                  CircleAvatar(radius: 48, backgroundColor: gold, backgroundImage: profileUrl == null ? null : NetworkImage(profileUrl), child: profileUrl == null ? const Icon(Icons.person, color: Colors.black, size: 42) : null),
                  const SizedBox(height: 12),
                  Text(name.text.isEmpty ? email : name.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(accountType == 'autonomo' ? 'AUTÓNOMO' : accountType == 'empresa' ? 'EMPRESA' : 'PARTICULAR', style: const TextStyle(color: gold, letterSpacing: 1.3, fontSize: 11, fontWeight: FontWeight.w900)),
                  if (isVerifiedProfessional) const Padding(padding: EdgeInsets.only(top: 8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.verified, color: Color(0xFF2EAD67), size: 17), SizedBox(width: 5), Text('Cuenta profesional verificada', style: TextStyle(color: Color(0xFF2EAD67), fontSize: 12))])),
                  const SizedBox(height: 10),
                  const Text('Tu identidad en AUTOMOTORS', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ])),
              ]),
            ),
            const SizedBox(height: 18),
            const Text('TU INFORMACIÓN', style: TextStyle(color: gold, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (isVerifiedProfessional) Center(child: Text('Verificación: ${verificationStatus ?? 'No solicitada'}', style: const TextStyle(color: gold))),
            const Divider(height: 28), const Text('DATOS DE LA CUENTA', style: TextStyle(color: gold, fontWeight: FontWeight.bold)), _readOnlyRow('Correo electrónico', email),
            const Text('DATOS PERSONALES', style: TextStyle(color: gold, fontWeight: FontWeight.bold)), _readOnlyRow('Nombre y apellidos', name.text), _readOnlyRow('Teléfono', phone.text), _readOnlyRow('Ciudad', city.text), _readOnlyRow('Provincia', province.text),
            if (accountType == 'empresa') _readOnlyRow('Razón social', businessName.text),
            if (isProfessional) ...[_readOnlyRow('Identificación fiscal', fiscalId.text), _readOnlyRow('Dirección fiscal', address.text)],
            const SizedBox(height: 18), FilledButton.icon(onPressed: () => setState(() => editing = true), icon: const Icon(Icons.edit), label: const Text('Editar perfil'), style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black)),
          ]),
    );
  }

}

class EditListingPage extends StatefulWidget {
  final String listingId;
  const EditListingPage({super.key, required this.listingId});
  @override
  State<EditListingPage> createState() => _EditListingPageState();
}

class _EditListingPageState extends State<EditListingPage> {
  final supabase = Supabase.instance.client;
  final formKey = GlobalKey<FormState>();
  final year = TextEditingController();
  final km = TextEditingController();
  final price = TextEditingController();
  final phone = TextEditingController();
  final description = TextEditingController();
  final matricula = TextEditingController();
  final cv = TextEditingController();
  final cilindrada = TextEditingController();
  final vin = TextEditingController();
  String fuel = 'Diésel';
  String? label;
  bool loading = true;
  bool saving = false;

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { year.dispose(); km.dispose(); price.dispose(); phone.dispose(); description.dispose(); matricula.dispose(); cv.dispose(); cilindrada.dispose(); vin.dispose(); super.dispose(); }

  Future<void> load() async {
    try {
      final row = await supabase.from('vehicle_listings').select('id,status,year,km,price,fuel,phone,description,matricula,cv,cilindrada_cc,etiqueta_medioambiental,vin').eq('id', widget.listingId).eq('owner_id', supabase.auth.currentUser!.id).single();
      if (row['status']?.toString() == 'sold') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Un vehículo vendido no se puede editar.')));
        if (mounted) Navigator.pop(context, false);
        return;
      }
      year.text = '${row['year'] ?? ''}'; km.text = '${row['km'] ?? ''}'; price.text = '${row['price'] ?? ''}'; phone.text = '${row['phone'] ?? ''}'; description.text = '${row['description'] ?? ''}'; matricula.text = '${row['matricula'] ?? ''}'; cv.text = '${row['cv'] ?? ''}'; cilindrada.text = '${row['cilindrada_cc'] ?? ''}'; vin.text = '${row['vin'] ?? ''}';
      fuel = row['fuel']?.toString() ?? 'Diésel'; label = row['etiqueta_medioambiental']?.toString();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudieron cargar los datos del anuncio: $e'))); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> save() async {
    final current = await supabase.from('vehicle_listings').select('status').eq('id', widget.listingId).eq('owner_id', supabase.auth.currentUser!.id).maybeSingle();
    if (current == null || current['status']?.toString() == 'sold') {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Un vehículo vendido no se puede editar.')));
      if (mounted) Navigator.pop(context, false);
      return;
    }
    if (!formKey.currentState!.validate()) return;
    final y = int.tryParse(year.text.trim()), k = int.tryParse(km.text.trim());
    final p = double.tryParse(price.text.trim().replaceAll('.', '').replaceAll(',', '.'));
    if (y == null || k == null || p == null || p <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revisa año, kilómetros y precio.'))); return; }
    setState(() => saving = true);
    try {
      await supabase.from('vehicle_listings').update({'year': y, 'km': k, 'price': p, 'fuel': fuel, 'phone': phone.text.replaceAll(RegExp(r'[^0-9]'), ''), 'description': description.text.trim(), 'matricula': matricula.text.trim().isEmpty ? null : matricula.text.trim().toUpperCase(), 'cv': int.tryParse(cv.text.trim()), 'cilindrada_cc': int.tryParse(cilindrada.text.trim()), 'etiqueta_medioambiental': label, 'vin': vin.text.trim().isEmpty ? null : vin.text.trim().toUpperCase()}).eq('id', widget.listingId).eq('owner_id', supabase.auth.currentUser!.id);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anuncio actualizado.'))); Navigator.pop(context, true); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar el anuncio: $e'))); }
    finally { if (mounted) setState(() => saving = false); }
  }

  Widget textField(String label, TextEditingController controller, {bool numeric = false, bool required = false}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: controller, keyboardType: numeric ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: label), validator: (v) => required && (v == null || v.trim().isEmpty) ? 'Completa este campo' : null));

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Editar anuncio')), body: loading ? const Center(child: CircularProgressIndicator(color: gold)) : Form(key: formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
    textField('Año', year, numeric: true, required: true), textField('Kilómetros', km, numeric: true, required: true), textField('Precio (€)', price, numeric: true, required: true),
    DropdownButtonFormField<String>(value: ['Diésel','Gasolina','Híbrido','Eléctrico'].contains(fuel) ? fuel : 'Diésel', decoration: const InputDecoration(labelText: 'Combustible'), items: const [DropdownMenuItem(value:'Diésel',child:Text('Diésel')),DropdownMenuItem(value:'Gasolina',child:Text('Gasolina')),DropdownMenuItem(value:'Híbrido',child:Text('Híbrido')),DropdownMenuItem(value:'Eléctrico',child:Text('Eléctrico'))], onChanged: (v) { if (v != null) setState(() => fuel = v); }),
    textField('Teléfono de contacto', phone), textField('Matrícula', matricula), textField('Potencia (CV)', cv, numeric: true), textField('Cilindrada (cc)', cilindrada, numeric: true), textField('VIN / número de bastidor', vin),
    DropdownButtonFormField<String>(value: environmentalLabels.contains(label) ? label : 'Sin etiqueta', decoration: const InputDecoration(labelText: 'Etiqueta medioambiental'), items: environmentalLabels.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => label = v)),
    textField('Descripción', description), const SizedBox(height: 12), FilledButton.icon(onPressed: saving ? null : save, style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black), icon: const Icon(Icons.save), label: Text(saving ? 'Guardando...' : 'Guardar cambios')),
  ])));
}

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});
  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = loadConversations();
  }

  Future<List<Map<String, dynamic>>> loadConversations() async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Inicia sesión para consultar tus chats.');
    final rows = await supabase
        .from('chat_conversations')
        .select('id, listing_id, buyer_id, seller_id, updated_at')
        .or('buyer_id.eq.${user.id},seller_id.eq.${user.id}')
        .order('updated_at', ascending: false);

    final conversations = <Map<String, dynamic>>[];
    for (final item in List<Map<String, dynamic>>.from(rows)) {
      final row = Map<String, dynamic>.from(item);
      row['vehicle_title'] = 'Vehículo anunciado';
      row['seller_name'] = 'Vendedor';
      row['vehicle_photo'] = null;

      try {
        final listing = await supabase
            .from('vehicle_listings')
            .select('id, owner_id, vehicle_brands(name), vehicle_models(name), vehicle_photos(storage_path, position)')
            .eq('id', row['listing_id'].toString())
            .maybeSingle();

        if (listing != null) {
          final brand = listing['vehicle_brands'];
          final model = listing['vehicle_models'];
          final brandName = brand is Map ? brand['name']?.toString() : null;
          final modelName = model is Map ? model['name']?.toString() : null;
          final title = '${brandName ?? ''} ${modelName ?? ''}'.trim();
          if (title.isNotEmpty) row['vehicle_title'] = title;

          final rawPhotos = listing['vehicle_photos'];
          final photos = rawPhotos is List
              ? List<Map<String, dynamic>>.from(rawPhotos)
              : <Map<String, dynamic>>[];
          photos.sort((a, b) => ((a['position'] as num?)?.toInt() ?? 0)
              .compareTo((b['position'] as num?)?.toInt() ?? 0));
          final path = photos.isEmpty ? null : photos.first['storage_path']?.toString();
          if (path != null && path.isNotEmpty) {
            try {
              row['vehicle_photo'] = await supabase.storage
                  .from('vehicle-photos')
                  .download(path);
            } catch (_) {
              // Si la foto no está disponible, se conserva el icono del vehículo.
            }
          }
        }
      } catch (_) {
        // Un anuncio eliminado o inaccesible no debe impedir ver el resto de chats.
      }

      // Contar mensajes recibidos que todavía no se han leído en esta conversación.
      try {
        final messageRows = await supabase
            .from('chat_messages')
            .select('sender_id, read_at')
            .eq('conversation_id', row['id'].toString());
        row['unread_count'] = List<Map<String, dynamic>>.from(messageRows)
            .where((message) =>
                message['sender_id']?.toString() != user.id &&
                message['read_at'] == null)
            .length;
      } catch (_) {
        row['unread_count'] = 0;
      }

      final sellerUserId = row['seller_id']?.toString();
      if (sellerUserId != null && sellerUserId.isNotEmpty) {
        try {
          final profile = await supabase
              .from('user_profiles')
              .select('full_name, business_name')
              .eq('id', sellerUserId)
              .maybeSingle();
          if (profile != null) {
            final businessName = profile['business_name']?.toString().trim() ?? '';
            final fullName = profile['full_name']?.toString().trim() ?? '';
            row['seller_name'] = businessName.isNotEmpty
                ? businessName
                : (fullName.isNotEmpty ? fullName : 'Usuario');
          }
        } catch (_) {
          // Mantener el nombre genérico si el perfil no está disponible.
        }
      }
      conversations.add(row);
    }
    return conversations;
  }

  @override
  Widget build(BuildContext context) {
    final userId = supabase.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis mensajes', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Actualizar mensajes',
            onPressed: () => setState(() => future = loadConversations()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: gold));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudieron cargar los mensajes. Comprueba que has iniciado sesión y aplicado la migración de chat.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.forum_outlined, size: 54, color: gold),
                    SizedBox(height: 14),
                    Text('Todavía no tienes conversaciones',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text('Cuando contactes con un vendedor, tus mensajes aparecerán aquí.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60)),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final row = rows[index];
              final isBuyer = row['buyer_id'] == userId;
              final title = row['vehicle_title']?.toString() ?? 'Vehículo anunciado';
              final sellerName = row['seller_name']?.toString() ?? 'Usuario';
              final photo = row['vehicle_photo'];
              final unreadCount = (row['unread_count'] as num?)?.toInt() ?? 0;
              return Card(
                color: const Color(0xFF1B1E24),
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                  side: BorderSide(color: Colors.white.withValues(alpha: .08)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          conversationId: row['id'].toString(),
                          listingId: row['listing_id']?.toString(),
                          title: title,
                          vehiclePhoto: photo is Uint8List ? photo : null,
                        ),
                      ),
                    );
                    if (mounted) setState(() => future = loadConversations());
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 76,
                            height: 76,
                            color: const Color(0xFF292D35),
                            child: photo is Uint8List
                                ? Image.memory(photo, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.directions_car_filled, color: gold, size: 34))
                                : const Icon(Icons.directions_car_filled, color: gold, size: 34),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text(sellerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: gold, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(isBuyer ? 'Vendedor' : 'Comprador',
                                style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (unreadCount > 0)
                          Container(
                            constraints: const BoxConstraints(minWidth: 23),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: const BoxDecoration(color: gold, shape: BoxShape.circle),
                            child: Text('$unreadCount', textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, color: gold),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String? listingId;
  final String title;
  final Uint8List? vehiclePhoto;
  const ChatPage({
    super.key,
    required this.conversationId,
    this.listingId,
    required this.title,
    this.vehiclePhoto,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();
  bool sending = false;
  bool markingRead = false;
  late final Stream<List<Map<String, dynamic>>> messagesStream;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    messagesStream = supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .order('created_at');
  }

  Future<void> openVehicleListing() async {
    final listingId = widget.listingId;
    if (listingId == null || listingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se ha podido identificar el anuncio de este chat.')),
      );
      return;
    }
    try {
      final raw = await supabase
          .from('vehicle_listings')
          .select('id, year, km, price, fuel, description, phone, matricula, cv, cilindrada_cc, etiqueta_medioambiental, owner_id, status, vehicle_brands(name), vehicle_models(name), vehicle_photos(storage_path, position)')
          .eq('id', listingId)
          .maybeSingle();
      if (raw == null || !['published', 'reserved'].contains(raw['status']?.toString())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este anuncio ya no está disponible.')),
          );
        }
        return;
      }
      final brandData = raw['vehicle_brands'];
      final modelData = raw['vehicle_models'];
      final photoData = raw['vehicle_photos'];
      final photoRows = photoData is List
          ? List<Map<String, dynamic>>.from(photoData)
          : <Map<String, dynamic>>[];
      photoRows.sort((a, b) => ((a['position'] as num?)?.toInt() ?? 0)
          .compareTo((b['position'] as num?)?.toInt() ?? 0));
      final photoBytes = <Uint8List>[];
      for (final photo in photoRows) {
        final path = photo['storage_path']?.toString();
        if (path == null || path.isEmpty) continue;
        try {
          photoBytes.add(await supabase.storage.from('vehicle-photos').download(path));
        } catch (_) {
          // La ficha puede abrirse aunque alguna foto no esté disponible.
        }
      }
      final car = Car(
        brand: brandData is Map ? (brandData['name']?.toString() ?? 'Marca') : 'Marca',
        model: modelData is Map ? (modelData['name']?.toString() ?? 'Modelo') : 'Modelo',
        year: (raw['year'] as num?)?.toInt() ?? 0,
        km: (raw['km'] as num?)?.toInt() ?? 0,
        price: (raw['price'] as num?)?.toDouble() ?? 0,
        fuel: raw['fuel']?.toString() ?? '',
        description: raw['description']?.toString() ?? '',
        phone: raw['phone']?.toString() ?? '',
        matricula: raw['matricula']?.toString(),
        cv: (raw['cv'] as num?)?.toInt(),
        cilindradaCc: (raw['cilindrada_cc'] as num?)?.toInt(),
        etiquetaMedioambiental: raw['etiqueta_medioambiental']?.toString(),
        photos: photoBytes,
        listingId: raw['id']?.toString(),
        ownerId: raw['owner_id']?.toString(),
      );
      if (!mounted) return;
      await Navigator.push<void>(context, MaterialPageRoute(
        builder: (_) => CarDetailsPage(
          car: car,
          priceText: euros(car.price),
          onContact: () => Navigator.pop(context),
        ),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el anuncio: $error')),
        );
      }
    }
  }

  String euros(double price) =>
      '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} €';

  DateTime _messageDate(Map<String, dynamic> message) {
    final raw = message['created_at']?.toString();
    return DateTime.tryParse(raw ?? '')?.toLocal() ?? DateTime.now();
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'HOY';
    if (day == today.subtract(const Duration(days: 1))) return 'AYER';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> markReceivedMessagesAsRead() async {
    final user = supabase.auth.currentUser;
    if (user == null || markingRead) return;
    markingRead = true;
    try {
      await supabase
          .from('chat_messages')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('conversation_id', widget.conversationId)
          .neq('sender_id', user.id)
          .isFilter('read_at', null);
    } catch (_) {
      // Si la política de Supabase lo impide, los mensajes siguen visibles;
      // revisar RLS y permisos de actualización de la columna read_at.
    } finally {
      markingRead = false;
    }
  }

  Future<void> sendMessage() async {
    final text = controller.text.trim();
    final user = supabase.auth.currentUser;
    if (text.isEmpty || user == null || sending) return;
    setState(() => sending = true);
    try {
      await supabase.from('chat_messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': user.id,
        'body': text,
      });
      controller.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar el mensaje: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Tooltip(
              message: 'Ver anuncio del vehículo',
              child: InkWell(
                onTap: openVehicleListing,
                borderRadius: BorderRadius.circular(9),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: 42,
                    height: 42,
                    color: const Color(0xFF292D35),
                    child: widget.vehiclePhoto != null
                        ? Image.memory(widget.vehiclePhoto!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.directions_car_filled, color: gold, size: 24))
                        : const Icon(Icons.directions_car_filled, color: gold, size: 24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF17191E),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: const [
                Icon(Icons.directions_car_outlined, color: gold, size: 16),
                SizedBox(width: 7),
                Text('Conversación sobre este vehículo',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('No se pueden cargar los mensajes.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: gold));
                }
                final messages = List<Map<String, dynamic>>.from(snapshot.data!);
                messages.sort((a, b) {
                  final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return aDate.compareTo(bDate); // El primer mensaje queda arriba.
                });
                // Solo se actualiza read_at de mensajes entrantes no leídos.
                markReceivedMessagesAsRead();
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Empieza la conversación sobre este vehículo.',
                      style: TextStyle(color: Colors.white60)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final mine = message['sender_id'] == currentUserId;
                    final sentAt = _messageDate(message);
                    final previousDay = index == 0 ? null : _messageDate(messages[index - 1]);
                    final showDay = previousDay == null || previousDay.year != sentAt.year || previousDay.month != sentAt.month || previousDay.day != sentAt.day;
                    return Column(
                      children: [
                        if (showDay) Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                            child: Text(_dayLabel(sentAt), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .7)),
                          )),
                        ),
                        Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 300),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: mine ? gold : panel,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(mine ? 16 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Align(alignment: Alignment.centerLeft, child: Text(
                                  message['body']?.toString() ?? '',
                                  style: TextStyle(color: mine ? Colors.black : Colors.white, height: 1.35),
                                )),
                                const SizedBox(height: 4),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(_timeLabel(sentAt), style: TextStyle(color: mine ? Colors.black54 : Colors.white54, fontSize: 10)),
                                  if (mine) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.done_all, size: 14, color: message['read_at'] != null ? const Color(0xFF1565C0) : Colors.black54),
                                  ],
                                ]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: Color(0xFF17191E),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: sending ? null : sendMessage,
                      icon: sending
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PublishOptionsPage extends StatelessWidget {
  const PublishOptionsPage({super.key});

  static const Color _gold = Color(0xFFFFC447);
  static const Color _bg = Color(0xFF050505);
  static const Color _panel = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    final packs = <_PublishPackData>[
      _PublishPackData(
        title: 'PACK 10', price: '59 €/mes', icon: Icons.diamond_outlined,
        subtitle: 'Todo lo necesario para empezar', cars: '10 anuncios · 3 destacados',
        benefits: const ['Publica hasta 10 vehículos', 'Hasta 3 anuncios destacados', 'Visible en búsquedas', 'Gestión desde tu perfil'],
      ),
      _PublishPackData(
        title: 'PACK 15', price: '75 €/mes', icon: Icons.diamond_outlined,
        subtitle: 'Más visibilidad para tu negocio', cars: '15 anuncios · 5 destacados', popular: true,
        benefits: const ['Publica hasta 15 vehículos', 'Hasta 5 anuncios destacados', 'Etiquetas destacadas', 'Prioridad en búsquedas', 'Estadísticas de visitas'],
      ),
      _PublishPackData(
        title: 'PACK 20', price: '99 €/mes', icon: Icons.diamond_outlined,
        subtitle: 'Para concesionarios con más stock', cars: '20 anuncios · 8 destacados',
        benefits: const ['Publica hasta 20 vehículos', 'Hasta 8 anuncios destacados', 'Mayor visibilidad', 'Prioridad en búsquedas', 'Estadísticas de visitas'],
      ),
      _PublishPackData(
        title: 'AUTOMOTORS PRO', price: '199 €/mes', icon: Icons.workspace_premium_rounded,
        subtitle: 'Para una venta profesional sin límites', cars: 'Anuncios ilimitados',
        benefits: const ['Anuncios ilimitados mientras esté activa', 'Máxima visibilidad', 'Prioridad en búsquedas', 'Estadísticas avanzadas', 'Soporte prioritario'],
      ),
    ];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
        title: const Text('Publicar mi vehículo', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(color: _panel, border: Border(top: BorderSide(color: Color(0xFF5A4720)))),
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.sell_outlined), label: const Text('PUBLICAR GRATIS  →'),
            style: OutlinedButton.styleFrom(foregroundColor: _gold, side: const BorderSide(color: _gold, width: 1.6), padding: const EdgeInsets.symmetric(vertical: 15), textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        children: [
          Container(
            height: 165, padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold.withValues(alpha: .5)),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF33230B), Color(0xFF15120D), Color(0xFF080808)]),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('LLEGA A MÁS COMPRADORES', style: TextStyle(color: _gold, fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('Elige la opción que mejor se adapte a ti.\nAumenta la visibilidad de tus anuncios con nuestros packs.', style: TextStyle(color: Colors.white, height: 1.4)),
            ]),
          ),
          const SizedBox(height: 16),
          for (final pack in packs) ...[
            _PublishPackCard(data: pack),
            const SizedBox(height: 14),
          ],
          const Text('Las compras de packs y la suscripción todavía no están activadas en la aplicación.', style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _PublishPackData {
  final String title, price, subtitle, cars;
  final IconData icon;
  final List<String> benefits;
  final bool popular;
  const _PublishPackData({required this.title, required this.price, required this.icon, required this.subtitle, required this.cars, required this.benefits, this.popular = false});
}

class _PublishPackCard extends StatelessWidget {
  final _PublishPackData data;
  const _PublishPackCard({required this.data});
  static const Color gold = Color(0xFFFFC447);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101010), borderRadius: BorderRadius.circular(19),
        border: Border.all(color: data.popular ? gold : const Color(0xFF67532C), width: data.popular ? 2 : 1),
        boxShadow: data.popular ? [BoxShadow(color: gold.withValues(alpha: .14), blurRadius: 16)] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (data.popular) Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(20)), child: const Text('MÁS POPULAR', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900))),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(data.icon, color: gold, size: 32), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data.title, style: TextStyle(color: data.popular ? gold : Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(data.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12))]),),
          const SizedBox(width: 8), Text(data.price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8), Padding(padding: const EdgeInsets.only(left: 44), child: Text(data.cars, style: const TextStyle(color: gold, fontWeight: FontWeight.w700))),
        const SizedBox(height: 10),
        for (final benefit in data.benefits) Padding(padding: const EdgeInsets.only(left: 44, bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_rounded, color: gold, size: 18), const SizedBox(width: 7), Expanded(child: Text(benefit, style: const TextStyle(color: Colors.white70, fontSize: 13)))])),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La contratación de packs estará disponible cuando se active el sistema de pagos.'))), style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 13)), child: Text('Elegir ${data.title}', style: const TextStyle(fontWeight: FontWeight.w900)))),
      ]),
    );
  }
}

class AddCarPage extends StatefulWidget {
  const AddCarPage({super.key});

  @override
  State<AddCarPage> createState() => _AddCarPageState();
}

class _AddCarPageState extends State<AddCarPage> {
  final formKey = GlobalKey<FormState>();
  final year = TextEditingController();
  final km = TextEditingController();
  final price = TextEditingController();
  final phone = TextEditingController();
  final description = TextEditingController();
  final matricula = TextEditingController();
  final vin = TextEditingController();
  final cv = TextEditingController();
  final cilindradaCc = TextEditingController();
  final version = TextEditingController();
  final doors = TextEditingController();
  final seats = TextEditingController();
  final color = TextEditingController();
  final emissionsStandard = TextEditingController();
  final lengthMm = TextEditingController();
  final widthMm = TextEditingController();
  final heightMm = TextEditingController();
  final wheelbaseMm = TextEditingController();
  final weightKg = TextEditingController();
  final trunkLiters = TextEditingController();
  final tankLiters = TextEditingController();
  String transmission = 'Automático';
  String bodyType = 'Berlina';
  final Set<String> selectedEquipment = {};

  final ImagePicker imagePicker = ImagePicker();
  final List<XFile> photos = [];
  final List<Map<String, dynamic>> brands = [];
  final List<Map<String, dynamic>> models = [];

  int? selectedBrandId;
  int? selectedModelId;
  String fuel = 'Diésel';
  String? etiquetaMedioambiental = 'Sin etiqueta';
  bool loadingBrands = true;
  bool loadingModels = false;
  bool publishing = false;
  int publishedCount = 0;
  bool loadingPublishedCount = true;

  @override
  void initState() {
    super.initState();
    loadBrands();
    loadPublishedCount();
  }

  Future<void> loadPublishedCount() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => loadingPublishedCount = false);
      return;
    }
    try {
      final rows = await supabase
          .from('vehicle_listings')
          .select('id')
          .eq('owner_id', user.id)
          .eq('status', 'published');
      if (!mounted) return;
      setState(() {
        publishedCount = (rows as List).length;
        loadingPublishedCount = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loadingPublishedCount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo comprobar el límite de anuncios: $error')),
      );
    }
  }

  Future<void> showPackages() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Planes AUTOMOTORS'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tus primeros 5 anuncios son gratuitos.'),
              SizedBox(height: 12),
              Text('PACK 10 · 59 €', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('10 publicaciones adicionales y hasta 3 coches destacados.'),
              SizedBox(height: 8),
              Text('PACK 15 · 75 €', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('15 publicaciones adicionales y hasta 5 coches destacados.'),
              SizedBox(height: 8),
              Text('PACK 20 · 99 €', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('20 publicaciones adicionales y hasta 8 coches destacados.'),
              SizedBox(height: 16),
              Divider(),
              Text('AUTOMOTORS PRO · 199 €/mes', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Publicaciones ilimitadas y prioridad para todos tus anuncios mientras la suscripción esté activa.'),
              SizedBox(height: 12),
              Text(
                'Los pagos todavía no están activados. Las compras se habilitarán cuando estén configurados Google Play Billing, Apple In-App Purchase y la validación segura en Supabase. No se realizará ningún cobro desde esta pantalla.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> showSubscriptionInfo() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AUTOMOTORS PRO'),
        content: const Text(
          '199 €/mes. Publicaciones ilimitadas y prioridad para todos tus anuncios mientras la suscripción esté activa. La compra y renovación se gestionarán mediante la tienda del dispositivo. Las suscripciones aún no están activadas y no se realizará ningún cobro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> loadBrands() async {
    try {
      final rows = await Supabase.instance.client
          .from('vehicle_brands')
          .select('id, name')
          .order('name');
      if (!mounted) return;
      setState(() {
        brands
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(rows));
        loadingBrands = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loadingBrands = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar las marcas: $error')),
      );
    }
  }

  Future<void> loadModels(int brandId) async {
    setState(() {
      selectedModelId = null;
      models.clear();
      loadingModels = true;
    });
    try {
      final rows = await Supabase.instance.client
          .from('vehicle_models')
          .select('id, name, brand_id')
          .eq('brand_id', brandId)
          .order('name');
      if (!mounted) return;
      setState(() {
        models.addAll(List<Map<String, dynamic>>.from(rows));
        loadingModels = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loadingModels = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los modelos: $error')),
      );
    }
  }

  Future<void> pickPhotos() async {
    final remaining = 15 - photos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 15 fotografías por vehículo.')),
      );
      return;
    }
    try {
      final selected = await imagePicker.pickMultiImage(
        limit: remaining,
        imageQuality: 90,
      );
      if (!mounted || selected.isEmpty) return;
      setState(() => photos.addAll(selected.take(15 - photos.length)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron seleccionar las fotos: $error')),
      );
    }
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    bool numeric = false,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (requiredField && (value == null || value.trim().isEmpty)) {
            return 'Completa este campo';
          }
          return null;
        },
      ),
    );
  }

  Future<void> publishCar() async {
    if (publishing || !formKey.currentState!.validate()) return;

    final yearValue = int.tryParse(year.text.trim());
    final kmValue = int.tryParse(km.text.trim());
    final priceValue = double.tryParse(
      price.text.trim().replaceAll('.', '').replaceAll(',', '.'),
    );
    final phoneValue = phone.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (yearValue == null ||
        kmValue == null ||
        priceValue == null ||
        yearValue < 1900 ||
        yearValue > 2100 ||
        kmValue < 0 ||
        priceValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa año, kilómetros y precio.'),
        ),
      );
      return;
    }

    final brandId = selectedBrandId;
    final modelId = selectedModelId;
    if (brandId == null || modelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una marca y un modelo.')),
      );
      return;
    }
    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos una fotografía.')),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para publicar.')),
      );
      return;
    }

    // Las primeras cinco publicaciones son gratuitas. Los pagos y créditos
    // todavía no están activos: no se permite publicar más sin validación de tienda.
    try {
      final rows = await supabase
          .from('vehicle_listings')
          .select('id')
          .eq('owner_id', user.id)
          .eq('status', 'published');
      publishedCount = (rows as List).length;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo verificar el límite gratuito: $error')),
      );
      return;
    }

    if (publishedCount >= 5) {
      await showPackages();
      return;
    }

    final selectedBrand = brands.firstWhere(
      (row) => (row['id'] as num).toInt() == brandId,
    );
    final selectedModel = models.firstWhere(
      (row) => (row['id'] as num).toInt() == modelId,
    );

    setState(() => publishing = true);
    final uploadedPaths = <String>[];
    String? listingId;

    try {
      final listing = await supabase.from('vehicle_listings').insert({
        'brand_id': brandId,
        'model_id': modelId,
        'year': yearValue,
        'km': kmValue,
        'price': priceValue,
        'fuel': fuel,
        'phone': phoneValue,
        'matricula': matricula.text.trim().isEmpty ? null : matricula.text.trim().toUpperCase(),
        'cv': int.tryParse(cv.text.trim()),
        'cilindrada_cc': int.tryParse(cilindradaCc.text.trim()),
        'version': version.text.trim().isEmpty ? null : version.text.trim(),
        'transmission': transmission,
        'body_type': bodyType,
        'doors': int.tryParse(doors.text.trim()),
        'seats': int.tryParse(seats.text.trim()),
        'color': color.text.trim().isEmpty ? null : color.text.trim(),
        'emissions_standard': emissionsStandard.text.trim().isEmpty ? null : emissionsStandard.text.trim(),
        'length_mm': int.tryParse(lengthMm.text.trim()),
        'width_mm': int.tryParse(widthMm.text.trim()),
        'height_mm': int.tryParse(heightMm.text.trim()),
        'wheelbase_mm': int.tryParse(wheelbaseMm.text.trim()),
        'weight_kg': int.tryParse(weightKg.text.trim()),
        'trunk_liters': int.tryParse(trunkLiters.text.trim()),
        'tank_liters': int.tryParse(tankLiters.text.trim()),
        'equipment': selectedEquipment.toList(),
        'etiqueta_medioambiental': etiquetaMedioambiental,
        // El VIN se guarda, pero no se incluye en la consulta pública de anuncios.
        'vin': vin.text.trim().isEmpty ? null : vin.text.trim().toUpperCase(),
        'description': description.text.trim(),
        'owner_id': user.id,
        'status': 'draft',
      }).select('id').single();

      listingId = listing['id'].toString();
      final photoRows = <Map<String, dynamic>>[];

      for (var i = 0; i < photos.length; i++) {
        final photo = photos[i];
        final bytes = await photo.readAsBytes();
        final originalName = photo.name;
        final extension = originalName.contains('.')
            ? originalName.split('.').last.toLowerCase()
            : 'jpg';
        final storagePath = '${user.id}/$listingId/${i + 1}.$extension';

        await supabase.storage
            .from('vehicle-photos')
            .uploadBinary(storagePath, bytes);
        uploadedPaths.add(storagePath);
        photoRows.add({
          'listing_id': listingId,
          'storage_path': storagePath,
          'position': i,
          'is_primary': i == 0,
        });
      }

      await supabase.from('vehicle_photos').insert(photoRows);

      await supabase
          .from('vehicle_listings')
          .update({'status': 'published'})
          .eq('id', listingId)
          .eq('owner_id', user.id);

      final photoBytes = <Uint8List>[];
      for (final photo in photos) {
        photoBytes.add(await photo.readAsBytes());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Anuncio publicado correctamente!')),
      );
      Navigator.pop(
        context,
        Car(
          brand: selectedBrand['name'].toString(),
          model: selectedModel['name'].toString(),
          year: yearValue,
          km: kmValue,
          price: priceValue,
          fuel: fuel,
          description: description.text.trim(),
          phone: phoneValue,
          matricula: matricula.text.trim().isEmpty ? null : matricula.text.trim().toUpperCase(),
          cv: int.tryParse(cv.text.trim()),
          cilindradaCc: int.tryParse(cilindradaCc.text.trim()),
          etiquetaMedioambiental: etiquetaMedioambiental,
          // No se expone el VIN en el objeto que se muestra a visitantes.
          photos: photoBytes,
          listingId: listingId,
          ownerId: user.id,
        ),
      );
    } catch (error) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await supabase.storage.from('vehicle-photos').remove(uploadedPaths);
        } catch (_) {
          // Si falla la limpieza, revisar Storage manualmente.
        }
      }
      if (listingId != null) {
        try {
          await supabase
              .from('vehicle_listings')
              .delete()
              .eq('id', listingId)
              .eq('owner_id', user.id);
        } catch (_) {
          // Puede quedar un borrador si las políticas impiden borrarlo.
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo publicar el anuncio: $error'),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  @override
  void dispose() {
    year.dispose();
    km.dispose();
    price.dispose();
    phone.dispose();
    description.dispose();
    matricula.dispose();
    vin.dispose();
    cv.dispose();
    cilindradaCc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicar vehículo', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(tooltip: 'Planes y packs', onPressed: showPackages,
            icon: const Icon(Icons.workspace_premium_rounded, color: gold)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFF17191E),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: showPackages,
              icon: const Icon(Icons.workspace_premium_rounded, color: gold),
              label: const Text('Packs y suscripción'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: gold)),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(
              onPressed: publishing ? null : publishCar,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: Text(publishing ? 'Publicando…' : 'Publicar gratis'),
              style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black),
            )),
          ]),
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: gold.withValues(alpha: .35)),
              ),
              child: const Row(children: [
                Icon(Icons.directions_car_filled, color: gold, size: 30),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Publica tu vehículo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('Completa los datos y añade fotografías. Los planes y packs se consultan por separado.', style: TextStyle(color: Colors.white70, height: 1.35)),
                ])),
              ]),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: showPackages,
                icon: const Icon(Icons.workspace_premium, color: gold),
                label: const Text('Ver planes y packs', style: TextStyle(color: gold, fontWeight: FontWeight.w800)),
              ),
            ),
            const Divider(color: Color(0xFF5C4A22)),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: selectedBrandId,
              decoration: const InputDecoration(labelText: 'Marca'),
              hint: Text(loadingBrands ? 'Cargando marcas...' : 'Selecciona una marca'),
              items: brands.map((row) {
                final id = (row['id'] as num).toInt();
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(row['name'].toString()),
                );
              }).toList(),
              validator: (value) => value == null ? 'Selecciona una marca' : null,
              onChanged: loadingBrands ? null : (value) {
                if (value == null) return;
                setState(() => selectedBrandId = value);
                loadModels(value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('models-$selectedBrandId'),
              initialValue: selectedModelId,
              decoration: const InputDecoration(labelText: 'Modelo'),
              hint: Text(selectedBrandId == null
                  ? 'Primero selecciona una marca'
                  : loadingModels ? 'Cargando modelos...' : 'Selecciona un modelo'),
              items: models.map((row) {
                final id = (row['id'] as num).toInt();
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(row['name'].toString()),
                );
              }).toList(),
              validator: (value) => value == null ? 'Selecciona un modelo' : null,
              onChanged: selectedBrandId == null || loadingModels
                  ? null
                  : (value) => setState(() => selectedModelId = value),
            ),
            const SizedBox(height: 12),
            buildTextField('Año', year, numeric: true),
            buildTextField('Kilómetros', km, numeric: true),
            buildTextField('Precio en euros', price, numeric: true),
            buildTextField('Matrícula (opcional)', matricula, requiredField: false),
            buildTextField('VIN / número de bastidor (opcional)', vin, requiredField: false),
            buildTextField('Potencia en CV (opcional)', cv, numeric: true, requiredField: false),
            buildTextField('Cilindrada en cc (opcional)', cilindradaCc, numeric: true, requiredField: false),
            DropdownButtonFormField<String>(
              initialValue: etiquetaMedioambiental,
              decoration: const InputDecoration(labelText: 'Etiqueta medioambiental'),
              items: environmentalLabels.map((label) => DropdownMenuItem<String>(
                value: label,
                child: Row(children: [
                  Icon(environmentalLabelIcon(label), color: environmentalLabelColor(label), size: 22),
                  const SizedBox(width: 10),
                  Text(label),
                ]),
              )).toList(),
              onChanged: (value) => setState(() => etiquetaMedioambiental = value),
            ),
            const SizedBox(height: 20),
            const Text('Ficha técnica ampliada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            buildTextField('Versión / acabado (opcional)', version, requiredField: false),
            DropdownButtonFormField<String>(
              initialValue: transmission,
              decoration: const InputDecoration(labelText: 'Transmisión'),
              items: const [
                DropdownMenuItem(value: 'Manual', child: Text('Manual')),
                DropdownMenuItem(value: 'Automático', child: Text('Automático')),
                DropdownMenuItem(value: 'Automático (DSG)', child: Text('Automático (DSG)')),
              ],
              onChanged: (value) { if (value != null) setState(() => transmission = value); },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: fuel,
              decoration: const InputDecoration(labelText: 'Combustible'),
              items: const [
                DropdownMenuItem(value: 'Diésel', child: Text('Diésel')),
                DropdownMenuItem(value: 'Gasolina', child: Text('Gasolina')),
                DropdownMenuItem(value: 'Híbrido', child: Text('Híbrido')),
                DropdownMenuItem(value: 'Eléctrico', child: Text('Eléctrico')),
              ],
              onChanged: (value) { if (value != null) setState(() => fuel = value); },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: bodyType,
              decoration: const InputDecoration(labelText: 'Tipo de carrocería'),
              items: const [
                DropdownMenuItem(value: 'Berlina', child: Text('Berlina')),
                DropdownMenuItem(value: 'Compacto', child: Text('Compacto')),
                DropdownMenuItem(value: 'SUV', child: Text('SUV')),
                DropdownMenuItem(value: 'Familiar', child: Text('Familiar')),
                DropdownMenuItem(value: 'Coupé', child: Text('Coupé')),
                DropdownMenuItem(value: 'Cabrio', child: Text('Cabrio')),
                DropdownMenuItem(value: 'Monovolumen', child: Text('Monovolumen')),
                DropdownMenuItem(value: 'Furgoneta', child: Text('Furgoneta')),
                DropdownMenuItem(value: 'Pickup', child: Text('Pickup')),
              ],
              onChanged: (value) { if (value != null) setState(() => bodyType = value); },
            ),
            const SizedBox(height: 12),
            buildTextField('Puertas', doors, numeric: true, requiredField: false),
            buildTextField('Plazas', seats, numeric: true, requiredField: false),
            buildTextField('Color exterior', color, requiredField: false),
            buildTextField('Normativa de emisiones (opcional)', emissionsStandard, requiredField: false),
            const SizedBox(height: 8),
            const Text('Equipamiento confirmado', style: TextStyle(fontWeight: FontWeight.bold)),
            ...[
              'Asientos deportivos', 'Asientos calefactables', 'Asientos ventilados',
              'Volante multifunción', 'Climatizador bizona', 'Navegador',
              'Apple CarPlay / Android Auto', 'Sensores de aparcamiento',
              'Cámara trasera', 'Control de crucero', 'Control de crucero adaptativo',
              'Faros LED', 'Faros Matrix / adaptativos', 'Techo solar',
              'Tapicería de cuero', 'Portón eléctrico', 'Acceso y arranque sin llave',
              'Detector de ángulo muerto', 'Mantenimiento en servicio oficial',
            ].map((item) => CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item),
              value: selectedEquipment.contains(item),
              activeColor: gold,
              onChanged: (checked) => setState(() {
                if (checked == true) { selectedEquipment.add(item); }
                else { selectedEquipment.remove(item); }
              }),
            )),
            const SizedBox(height: 12),
            buildTextField('Teléfono (opcional; el chat funciona dentro de la app)', phone, numeric: true, requiredField: false),
            buildTextField('Descripción', description, requiredField: false),
            Text(
              'Fotografías del vehículo (${photos.length}/15)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: publishing ? null : pickPhotos,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Seleccionar fotografías'),
            ),
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'La primera fotografía será la principal. Puedes cambiar el orden eliminando y seleccionando las fotos de nuevo.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 145,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  itemBuilder: (context, index) => Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FutureBuilder<Uint8List>(
                            future: photos[index].readAsBytes(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              return Image.memory(snapshot.data!, fit: BoxFit.contain);
                            },
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            tooltip: 'Eliminar fotografía',
                            onPressed: publishing ? null : () => setState(() => photos.removeAt(index)),
                            icon: const Icon(Icons.cancel, color: Colors.red),
                          ),
                        ),
                        if (index == 0)
                          const Positioned(
                            left: 0,
                            bottom: 0,
                            child: Chip(label: Text('Principal')),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _ProBenefit extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProBenefit({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: gold, size: 25),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
    ],
  );
}

class _PublicationPackCard extends StatelessWidget {
  final String packName;
  final String listingCount;
  final String price;
  final String featuredCount;
  final VoidCallback onTap;

  const _PublicationPackCard({
    required this.packName,
    required this.listingCount,
    required this.price,
    required this.featuredCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF171717),
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFF47423A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.layers, color: gold, size: 25),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(packName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(listingCount, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(price, style: const TextStyle(color: gold, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            Container(width: 1, height: 38, color: const Color(0xFF5B4A26)),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  const Icon(Icons.star, color: gold, size: 16),
                  const SizedBox(width: 5),
                  Expanded(child: Text(featuredCount, style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.25))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: gold, size: 22),
          ],
        ),
      ),
    ),
  );
}
