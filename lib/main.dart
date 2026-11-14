import 'chat_market_page.dart';
import 'design/market_safety.dart';
import 'services/app_diagnostics.dart';
import 'design/launch_experience.dart';
import 'services/draft_photo_files.dart';
import 'design/listing_preparation.dart';
import 'design/seller_listing_metrics.dart';
import 'services/listing_links.dart';
import 'services/account_session_guard.dart';
import 'services/community_visibility.dart';
import 'terms_acceptance_field.dart';
import 'password_recovery_page.dart';
import 'services/password_recovery_service.dart';
import 'services/local_market_state.dart';
import 'design/market_chat_actions.dart';
import 'design/market_professional_header.dart';
import 'services/chat_participant_service.dart';
import 'package:app_links/app_links.dart';
import 'services/email_confirmation_service.dart';
import 'design/market_watchlists.dart';
import 'design/market_comparison.dart';
import 'design/market_search.dart';
import 'services/vehicle_search.dart';
import 'design/market_details.dart';
import 'design/market_vehicle_card.dart';
import 'design/market_theme.dart';
import 'services/listing_photo_loader.dart';
import 'services/content_publication_service.dart';
import 'community_moderation_page.dart';
import 'chat_safety_controls.dart';
import 'services/chat_safety_controller.dart';
import 'delete_account_page.dart';
import 'support_page.dart';
import 'services/store_product_presentation.dart';
import 'l10n/ui_text.dart';
import 'l10n/app_localizations.dart';
import 'services/automotors_locale_controller.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:automotors_base/services/store_purchase_service.dart';
import 'package:automotors_base/services/verified_store_plans.dart';
import 'package:automotors_base/sold_reviews_features.dart';
import 'package:automotors_base/vehicle_feature_control.dart';
import 'package:automotors_base/services/ios_push_service.dart';

Future<void> contactSharedListing(BuildContext context,Car car) async {
  if(!await requireAutomotorsLogin(context)||!context.mounted)return;
  final db=Supabase.instance.client; final user=db.auth.currentUser;
  if(user==null||car.ownerId==null||car.listingId==null)return;
  if(user.id==car.ownerId){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(uiText(context,'No puedes iniciar un chat contigo mismo.'))));return;}
  try {
    final conversation=await getOrCreateConversation(supabase:db,listingId:car.listingId!,buyerId:user.id,sellerId:car.ownerId!);
    if(context.mounted)await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>ChatPage(conversationId:conversation['id'].toString(),listingId:car.listingId,title:'${car.brand} ${car.model}')));
  }catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(uiText(context,'No se pudo abrir el anuncio. Comprueba la conexión e inténtalo de nuevo.'))));}
}

const automotorsSupabaseUrl=String.fromEnvironment('SUPABASE_URL',defaultValue:'https://ndicdhlpbyywqyjgxpnx.supabase.co');
const automotorsSupabaseKey=String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY',defaultValue:'sb_publishable_TBWahz_XJ9lcoBdSSxfpNQ_vhzdDTlu');
const gold = marketGold;
const black = marketPaper;
const panel = marketSurface;

const buyerListingProjection = 'id, created_at, status, year, km, price, fuel, description, phone, matricula, vin, show_matricula_publicly, show_vin_publicly, cv, cilindrada_cc, etiqueta_medioambiental, version, transmission, body_type, doors, seats, color, torque_nm, acceleration_0_100, max_speed_kmh, consumption_l_100, emissions_standard, equipment, owner_id, vehicle_brands(name), vehicle_models(name), vehicle_photos(storage_path, position)';

final _vehiclePhotoCache = ListingPhotoCache();
final _localMarketState = LocalMarketState();
final _publicationDraftPhotos = <String, List<XFile>>{};

Future<Uint8List> downloadVehiclePhoto(String path) {
  final client = Supabase.instance.client;
  return _vehiclePhotoCache.load(
    path,
    (photoPath) async {try{return await client.storage.from('vehicle-photos').download(photoPath);}catch(e){AppDiagnostics.record('photo',e);rethrow;}},
    scope: client.auth.currentSession?.accessToken ?? 'guest',
  );
}

final automotorsNavigatorKey = GlobalKey<NavigatorState>();
late final IosPushService automotorsPush;

Future<void> openAutomotorsPush(Map<String, dynamic> notification) async {
  final navigator = automotorsNavigatorKey.currentState;
  final context = automotorsNavigatorKey.currentContext;
  if (navigator == null || context == null) return;
  if (!await requireAutomotorsLogin(context)) return;
  final db = Supabase.instance.client;
  if (notification['user_id'] != db.auth.currentUser?.id) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text(uiText(context, "Este aviso pertenece a otra cuenta de AUTOMOTORS."))),
    );
    return;
  }
  try {
    if (notification['kind'] == 'review_requested') {
      final listingId = notification['listing_id']?.toString();
      if (listingId == null || listingId.isEmpty) return;
      await navigator.push<void>(MaterialPageRoute(
        builder: (_) => BuyerPurchaseReviewPage(listingId: listingId),
      ));
    } else if (['chat_message','chat_activity','visit_reminder'].contains(notification['kind'])) {
      final conversationId = notification['conversation_id']?.toString();
      if (conversationId == null || !RegExp(r'^[0-9]+$').hasMatch(conversationId)) return;
      // RLS verifies that the current user still belongs to this conversation.
      final conversation = await db.from('chat_conversations').select('id, listing_id')
          .eq('id', conversationId).maybeSingle();
      if (conversation == null) throw StateError('Conversation unavailable');
      if (!navigator.mounted) return;
      if(notification['kind']!='chat_message'){await navigator.push<void>(MaterialPageRoute(builder:(_)=>ChatMarketPage(conversationId:conversationId)));return;}
      await navigator.push<void>(MaterialPageRoute(builder: (_) => ChatPage(
        conversationId: conversationId,
        listingId: conversation['listing_id']?.toString(),
        title: uiText(context, "Mensajes"),
      )));
    } else if(['new_listing','price_drop'].contains(notification['kind'])) {
      final id=notification['listing_id']?.toString();if(id==null)return;
      final row=await db.from('vehicle_listings').select(buyerListingProjection).eq('id',id).inFilter('status',['published','reserved','sold']).maybeSingle();
      if(row==null)throw StateError('Listing unavailable');
      final car=await buyerCarFromListing(row);
      if(navigator.mounted)await navigator.push<void>(MaterialPageRoute(builder:(pageContext)=>CarDetailsPage(car:car,priceText:'${car.price.toStringAsFixed(0)} €',onContact:()=>contactSharedListing(pageContext,car))));
    }
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text(uiText(context, "Este aviso ya no está disponible."))),
    );
  }
}

const Map<String, String> automotorsCatalanText = {
  "Seleccionar idioma": "Seleccionar idioma",
  "Alertas de búsqueda": "Alertes de cerca",
  "VEHÍCULOS VERIFICADOS": "VEHICLES VERIFICATS",
  "Encuentra tu próximo coche.": "Troba el teu pròxim cotxe.",
  "Encuentra\ntu próximo coche.": "Troba\nel teu pròxim cotxe.",
  "Vehículos de particulares y profesionales.": "Vehicles de particulars i professionals.",
  "Ver vehículos": "Veure vehicles",
  "Escribe marca o modelo...": "Escriu marca o model...",
  "Borrar búsqueda": "Esborrar la cerca",
  "No se pudo consultar tu plan. Reintenta para comprobar el acceso.": "No s'ha pogut consultar el teu pla. Torna-ho a provar.",
  "El pago aún no está verificado o el plan ha caducado.": "El pagament encara no està verificat o el pla ha caducat.",
  "Has alcanzado el límite de anuncios activos de tu cuenta.": "Has arribat al límit d'anuncis actius del teu compte.",
  "Todo lo necesario para empezar": "Tot el que necessites per començar",
  "10 anuncios · 3 destacados": "10 anuncis · 3 destacats",
  "Más visibilidad para tu negocio": "Més visibilitat per al teu negoci",
  "15 anuncios · 5 destacados": "15 anuncis · 5 destacats",
  "Para concesionarios con más stock": "Per a concessionaris amb més estoc",
  "20 anuncios · 8 destacados": "20 anuncis · 8 destacats",
  "Para una venta profesional sin límites": "Per a una venda professional sense límits",
  "Anuncios ilimitados · hasta 15 destacados": "Anuncis il·limitats · fins a 15 destacats",
  "Publicar mi vehículo": "Publicar el meu vehicle",
  "PUBLICAR GRATIS  →": "PUBLICAR GRATIS  →",
  "LLEGA A MÁS COMPRADORES": "ARRIBA A MÉS COMPRADORS",
  "Elige la opción que mejor se adapte a ti.\nAumenta la visibilidad de tus anuncios con nuestros packs.": "Tria l'opció que s'adapti millor a tu.\nAugmenta la visibilitat dels anuncis amb els nostres paquets.",
  "Restaurar compras": "Restaurar compres",
  "Reintentar": "Torna-ho a provar",
  "El acceso se activa después de verificar el pago. Puedes restaurar tus compras con la misma cuenta.": "L'accés s'activa després de verificar el pagament. Pots restaurar les compres amb el mateix compte.",
  "Publicar vehículo": "Publicar vehicle",
};

String appText(String spanish, String english) {
  final language = AutomotorsLocaleController.instance.locale.languageCode;
  if (language == 'en') return english;
  if (language == 'ca') {
    if (spanish.endsWith(' vehículos anunciados')) {
      return spanish.replaceAll(' vehículos anunciados', ' vehicles anunciats');
    }
    if (spanish.startsWith('Elegir ')) return spanish.replaceFirst('Elegir ', 'Triar ');
    return automotorsCatalanText[spanish] ?? spanish;
  }
  return spanish;
}


class AutomotorsBrandMark extends StatelessWidget {
  final double size;
  const AutomotorsBrandMark({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) => Center(
    widthFactor: 1,
    heightFactor: 1,
    child: SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/automotors_app_icon.png',
        fit: BoxFit.contain,
        semanticLabel: 'AUTOMOTORS',
      ),
    ),
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
    if (!['CERO', 'ECO', 'C', 'B'].contains(value))
      return const SizedBox.shrink();
    final base = value == 'CERO'
        ? const Color(0xFF168FD0)
        : value == 'ECO'
        ? const Color(0xFF78C900)
        : value == 'C'
        ? const Color(0xFF63B900)
        : const Color(0xFFFFD400);
    return Semantics(
      label: uiText(context, 'Etiqueta medioambiental {0}', [value]),
      image: true,
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox(
            width: size,
            height: size,
            child: DecoratedBox(
              key: const Key('environmental-sticker-disc'),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: base,
                border: Border.all(color: marketInk, width: size * .025),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 5,
                    offset: Offset(1, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  children: [
                    Positioned(
                      left: size * .07,
                      top: size * .12,
                      child: Container(
                        width: size * .13,
                        height: size * .42,
                        color: marketInk,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            11,
                            (_) => Container(
                              height: size * .012,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: size * .13,
                      top: size * .16,
                      child: _StickerQr(size: size * .23),
                    ),
                    Positioned(
                      left:size*(value=='ECO' ? .23 : .20),
                      right:size*(value=='ECO' ? .12 : .28),
                      top:size*(value=='ECO' ? .40 : .24),
                      height:size*(value=='ECO' ? .27 : .44),
                      child:FittedBox(fit:BoxFit.scaleDown,child:Text(
                        value=='CERO' ? '0' : value,
                        textScaler:TextScaler.noScaling,maxLines:1,softWrap:false,
                        style:TextStyle(color:Colors.black,fontSize:size*.43,fontWeight:FontWeight.w700,height:1),
                      )),
                    ),
                    Positioned(
                      left: size * .24,
                      right: size * .22,
                      bottom: size * .15,
                      child: Container(
                        height: size * .14,
                        color: const Color(0xFFBFC0C0),
                        alignment: Alignment.center,
                        child: Text(
                          "DGT",
                          textScaler: TextScaler.noScaling,
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            fontSize: size * .13,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: size * .1,
                      right: size * .1,
                      bottom: size * .045,
                      child: Container(height: size * .025, color: marketMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickerQr extends StatelessWidget {
  final double size;
  const _StickerQr({required this.size});
  @override
  Widget build(BuildContext context) => Container(width:size,height:size,padding:EdgeInsets.all(size*.08),
    color:marketInk,child:CustomPaint(painter:_QrPatternPainter()));
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
    url: automotorsSupabaseUrl,
    publishableKey: automotorsSupabaseKey,
    authOptions: const FlutterAuthClientOptions(detectSessionInUriPredicate:automaticallyHandleAuthUri),
  );

  await AutomotorsLocaleController.instance.load();
  automotorsPush = IosPushService(db: Supabase.instance.client, onOpen: openAutomotorsPush);
  AppDiagnostics.install();
  runApp(const AutomotorsApp());
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(automotorsPush.start()));
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
  final loggedIn = await requireAutomotorsLogin(context);
  if (!loggedIn || !context.mounted) return;
  final digits = validWhatsAppDigits(car.phone);
  if (digits == null) return;
  final message = 'Hola, estoy interesado en tu ${car.brand} ${car.model} anunciado en AUTOMOTORS.';
  final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "No se pudo abrir WhatsApp en este dispositivo."))),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "No se pudo abrir WhatsApp. Comprueba que esté disponible."))),
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
  final String? initialMessage, initialEmail;
  final bool initialMessageIsError;
  const LoginPage({
    super.key,
    this.initialMessage,
    this.initialEmail,
    this.initialMessageIsError = false,
  });

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
  bool showVerificationResend = false;
  DateTime? lastVerificationResend;

  @override
  void initState() {
    super.initState();
    emailController.text = widget.initialEmail ?? '';
    message = widget.initialMessage;
    messageIsError = widget.initialMessageIsError;
    showVerificationResend = widget.initialMessageIsError;
  }

  String? get verificationRedirect =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? emailConfirmationRedirect
      : null;

  Future<void> resendVerification() async {
    if (loading) return;
    final email = emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        message = 'Introduce un correo válido';
        messageIsError = true;
      });
      return;
    }
    if (lastVerificationResend != null &&
        DateTime.now().difference(lastVerificationResend!) <
            const Duration(seconds: 60)) {
      setState(() {
        message = 'Espera un minuto antes de solicitar otro correo.';
        messageIsError = false;
      });
      return;
    }
    setState(() => loading = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: verificationRedirect,
      );
      lastVerificationResend = DateTime.now();
      if (mounted)
        setState(() {
          message = 'Si la cuenta está pendiente de verificar, recibirás un nuevo correo.';
          messageIsError = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          message = 'No se pudo reenviar el correo. Comprueba la conexión e inténtalo de nuevo.';
          messageIsError = true;
        });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

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
        final response = await auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: verificationRedirect,
        );
        if (!mounted) return;
        if (response.session != null) {
          if (mounted) Navigator.pop(context, true);
          return;
        }
        setState(() {
          message = verificationRedirect == null
              ? 'Cuenta creada. Revisa tu correo y confirma la dirección; después vuelve aquí para iniciar sesión.'
              : 'Cuenta creada. Abre el correo en este iPhone y pulsa el enlace para verificar tu cuenta y volver a AUTOMOTORS.';
          showVerificationResend = true;
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
          showVerificationResend = error.code == 'email_not_confirmed';
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
      appBar: AppBar(title: Text(uiText(context, "Cuenta AUTOMOTORS"))),
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
                  const AutomotorsBrandMark(size: 112),
                  const SizedBox(height: 12),
                  Text(
                    uiText(context, "AUTOMOTORS"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: marketAccent,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    creatingAccount
                        ? uiText(
                            context,
                            "Crea tu cuenta para publicar y contactar.",
                          )
                        : uiText(
                            context,
                            "Inicia sesión para publicar y contactar.",
                          ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: uiText(context, "Correo electrónico"),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty ||
                          !text.contains('@') ||
                          !text.contains('.'))
                        return uiText(context, 'Introduce un correo válido');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: hidePassword,
                    autofillHints: creatingAccount
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: uiText(context, "Contraseña"),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip:uiText(context,hidePassword?'Mostrar contraseña':'Ocultar contraseña'),
                        onPressed: () =>
                            setState(() => hidePassword = !hidePassword),
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final text = value ?? '';
                      if (text.length < 6)
                        return uiText(
                          context,
                          'La contraseña debe tener al menos 6 caracteres',
                        );
                      return null;
                    },
                  ),
                  if (!creatingAccount)
                    Align(alignment: Alignment.centerRight, child: TextButton(
                      onPressed: loading ? null : () async {
                        final recoveredEmail = await Navigator.push<String>(context, MaterialPageRoute(
                          builder: (_) => PasswordRecoveryPage(
                            initialEmail: emailController.text.trim(),
                            createService: () => PasswordRecoveryService(GoTrueClient(
                              url: '$automotorsSupabaseUrl/auth/v1',
                              headers: {'apikey': automotorsSupabaseKey},
                              autoRefreshToken: false,
                              flowType: AuthFlowType.pkce,
                              asyncStorage: RecoveryMemoryStorage(),
                            )),
                          ),
                        ));
                        if (!mounted || recoveredEmail == null) return;
                        setState(() {
                          emailController.text = recoveredEmail;
                          passwordController.clear();
                          message = 'Contraseña actualizada. Ya puedes iniciar sesión.';
                          messageIsError = false;
                          showVerificationResend = false;
                        });
                      },
                      child: Text(uiText(context, 'He olvidado mi contraseña')),
                    )),
                  if (message != null) ...[
                    const SizedBox(height: 14),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: marketTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              messageIsError
                                  ? Icons.info_outline
                                  : Icons.check_circle_outline,
                              color: messageIsError
                                  ? Colors.red.shade800
                                  : marketInk,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                uiText(context, message!),
                                style: TextStyle(
                                  color: messageIsError
                                      ? Colors.red.shade800
                                      : marketInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const TermsAcceptanceField(),
                  FilledButton(
                    onPressed: loading ? null : submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            creatingAccount
                                ? uiText(context, "Crear cuenta")
                                : uiText(context, "Iniciar sesión"),
                          ),
                  ),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => setState(() {
                            creatingAccount = !creatingAccount;
                            message = null;
                          }),
                    child: Text(
                      creatingAccount
                          ? uiText(
                              context,
                              "Ya tengo una cuenta · Iniciar sesión",
                            )
                          : uiText(context, "¿No tienes cuenta? Crear cuenta"),
                    ),
                  ),
                  if (showVerificationResend)
                    TextButton(
                      onPressed: loading ? null : resendVerification,
                      child: Text(
                        uiText(context, 'Reenviar correo de verificación'),
                      ),
                    ),
                  const SupportLinks(),
                  const SizedBox(height: 8),
                  Text(
                    uiText(
                      context,
                      "Puedes seguir viendo los anuncios sin registrarte.",
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: marketMuted, fontSize: 12),
                  ),
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
  final bool showMatriculaPublicly;
  final bool showVinPublicly;
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
  final List<String> photoPaths;
  final String? listingId;
  final String? ownerId;
  final String status;
  final bool isFeatured;
  final DateTime? listedAt;

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
    this.showMatriculaPublicly = false,
    this.showVinPublicly = false,
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
    this.photoPaths = const [],
    this.listingId,
    this.ownerId,
    this.status = 'published',
    this.isFeatured = false,
    this.listedAt,
  });
  int get photoCount => photoPaths.isNotEmpty ? photoPaths.length : photos.length;

  factory Car.fromListing(Map<String, dynamic> raw, {
    List<Uint8List> photos = const [], List<String> photoPaths = const [],
    bool isFeatured = false,
  }) {
    final brandData = raw['vehicle_brands'];
    final modelData = raw['vehicle_models'];
    return Car(
        brand: brandData is Map ? (brandData['name']?.toString() ?? 'Marca') : 'Marca',
        model: modelData is Map ? (modelData['name']?.toString() ?? 'Modelo') : 'Modelo',
        year: (raw['year'] as num?)?.toInt() ?? 0,
        km: (raw['km'] as num?)?.toInt() ?? 0,
        price: (raw['price'] as num?)?.toDouble() ?? 0,
        fuel: raw['fuel']?.toString() ?? '',
        description: raw['description']?.toString() ?? '',
        phone: raw['phone']?.toString() ?? '',
        matricula: raw['show_matricula_publicly'] == true ? raw['matricula']?.toString() : null,
        vin: raw['show_vin_publicly'] == true ? raw['vin']?.toString() : null,
        showMatriculaPublicly: raw['show_matricula_publicly'] == true,
        showVinPublicly: raw['show_vin_publicly'] == true,
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
        equipment: raw['equipment'] is List ? List<String>.from((raw['equipment'] as List).map((item) => item.toString())) : const <String>[],
        photos: photos,
        photoPaths: photoPaths,
        isFeatured: isFeatured,
        listedAt: DateTime.tryParse(raw['created_at']?.toString() ?? ''),
        listingId: raw['id']?.toString(),
        ownerId: raw['owner_id']?.toString(),
        status: raw['status']?.toString() ?? 'published',
      );
  }

}

Future<Map<String, dynamic>> getOrCreateConversation({
  required SupabaseClient supabase,
  required String listingId,
  required String buyerId,
  required String sellerId,
}) async {
  Future<Map<String, dynamic>?> findConversation() async {
    final row = await supabase
        .from('chat_conversations')
        .select('id')
        .eq('listing_id', listingId)
        .eq('buyer_id', buyerId)
        .eq('seller_id', sellerId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  final existing = await findConversation();
  if (existing != null) return existing;

  try {
    final inserted = await supabase
        .from('chat_conversations')
        .insert({
          'listing_id': listingId,
          'buyer_id': buyerId,
          'seller_id': sellerId,
        })
        .select('id')
        .single();
    return Map<String, dynamic>.from(inserted);
  } on PostgrestException catch (error) {
    // Reuse the row created by a simultaneous request for the same listing.
    if (error.code != '23505') rethrow;
    final concurrentInsert = await findConversation();
    if (concurrentInsert != null) return concurrentInsert;
    rethrow;
  }
}

class _CarFeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CarFeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: marketSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE4E5DF)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: marketAccent),
      const SizedBox(width: 5),
      Text(uiText(context, label), style: const TextStyle(color: marketMuted, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _VehicleStatusBadge extends StatelessWidget {
  final String status;
  const _VehicleStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final reserved = status.trim().toLowerCase() == 'reserved';
    final color = reserved ? const Color(0xFF168BFF) : const Color(0xFF238B57);
    final label = reserved ? 'RESERVADO' : 'DISPONIBLE';
    final icon = reserved ? Icons.lock_outline_rounded : Icons.check_circle_outline_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: .55)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 5),
        Text(uiText(context, label), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .5)),
      ]),
    );
  }
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
    child:  Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.lock_rounded, size: 13, color: Colors.white),
      SizedBox(width: 6),
      Text(uiText(context, "RESERVADO"), style: TextStyle(
        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700,
        letterSpacing: 1.1, shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
      )),
    ]),
  );
}

class VehicleSearchResultsPage extends StatefulWidget {
  final List<Car> cars;
  final void Function(Car) onOpenCar;
  const VehicleSearchResultsPage({super.key, required this.cars, required this.onOpenCar});

  @override
  State<VehicleSearchResultsPage> createState() => _VehicleSearchResultsPageState();
}

class _VehicleSearchResultsPageState extends State<VehicleSearchResultsPage> {
  final List<Car> _selectedForComparison = [];

  String priceText(double value) =>
      '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} €';

  void _toggleComparison(Car car) {
    setState(() {
      if (_selectedForComparison.contains(car)) {
        _selectedForComparison.remove(car);
      } else if (_selectedForComparison.length < 3) {
        _selectedForComparison.add(car);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(uiText(context, "Puedes comparar un máximo de 3 coches."))),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title:  Text(uiText(context, "Resultados de búsqueda")),
      actions: [
        if (_selectedForComparison.isNotEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text('${_selectedForComparison.length}/3', style: const TextStyle(color: marketAccent, fontWeight: FontWeight.w700)),
          )),
      ],
    ),
    bottomNavigationBar: _selectedForComparison.length >= 2
      ? SafeArea(child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: marketInk, padding: const EdgeInsets.symmetric(vertical: 15)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => VehicleComparisonPage(cars: List<Car>.from(_selectedForComparison), onOpenCar: widget.onOpenCar),
            )),
            icon: const Icon(Icons.compare_arrows_rounded),
            label: Text(uiText(context, "Comparar {0} coches", [_selectedForComparison.length])),
          ),
        ))
      : null,
    body: widget.cars.isEmpty
      ?  Center(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 54, color: marketAccent), SizedBox(height: 14),
          Text(uiText(context, "No hay vehículos con estos filtros"), textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          SizedBox(height: 8), Text(uiText(context, "Cambia o limpia alguno de los filtros e inténtalo de nuevo."), textAlign: TextAlign.center, style: TextStyle(color: marketMuted)),
        ])))
      : Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(children: [
              Expanded(child: Text(uiText(context, "{0} vehículos encontrados", [widget.cars.length]), style: const TextStyle(color: marketMuted))),
              const Icon(Icons.compare_arrows_rounded, color: marketAccent, size: 18),
              const SizedBox(width: 6),
               Flexible(child: Text(uiText(context, "Selecciona hasta 3 para comparar"), style: TextStyle(color: marketAccent, fontSize: 12))),
            ]),
          ),
          Expanded(child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: widget.cars.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final car = widget.cars[index];
              final isSelected = _selectedForComparison.contains(car);
              return Card(color: panel, clipBehavior: Clip.antiAlias, child: Row(children: [
                SizedBox(width: 112, height: 132, child: car.photos.isNotEmpty ? Image.memory(car.photos.first, fit: BoxFit.cover) : Container(color: marketSurface, child: const Icon(Icons.directions_car, size: 42, color: marketAccent))),
                Expanded(child: InkWell(
                  onTap: () => widget.onOpenCar(car),
                  child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (car.isFeatured)  Padding(padding: EdgeInsets.only(bottom: 5), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.star_rounded, color: marketAccent, size: 15), SizedBox(width: 4), Text(uiText(context, "DESTACADO"), style: TextStyle(color: marketAccent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .7))])),
                    Text('${car.brand} ${car.model}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(priceText(car.price), style: const TextStyle(color: marketAccent, fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(height: 6),
                    Text(uiText(context, "{0} · {1} km · {2}", [car.year, car.km, car.fuel]), style: const TextStyle(color: marketMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ])),
                )),
                Checkbox(value: isSelected, activeColor: gold, checkColor: black, onChanged: (_) => _toggleComparison(car)),
              ]));
            },
          )),
        ]),
  );
}

class VehicleComparisonPage extends StatelessWidget {
  final List<Car> cars;
  final ValueChanged<Car>? onOpenCar;
  const VehicleComparisonPage({super.key, required this.cars, this.onOpenCar});
  String _price(double value) => value <= 0 ? 'No indicado' : '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} €';
  String _value(Object? value, [String suffix = '']) => value == null || value.toString().trim().isEmpty ? 'No indicado' : '$value$suffix';
  @override
  Widget build(BuildContext context) {
    final rows = <List<String>>[
      ['Modelo', ...cars.map((c) => '${c.brand} ${c.model}')],
      ['Precio', ...cars.map((c) => _price(c.price))],
      ['Año', ...cars.map((c) => _value(c.year == 0 ? null : c.year))],
      ['Kilometraje', ...cars.map((c) => '${c.km.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} km')],
      ['Combustible', ...cars.map((c) => _value(c.fuel))],
      ['Potencia', ...cars.map((c) => _value(c.cv, ' CV'))],
      ['Cilindrada', ...cars.map((c) => c.cilindradaCc == null ? 'No indicado' : '${c.cilindradaCc} cc')],
      ['Par motor', ...cars.map((c) => _value(c.torqueNm, ' Nm'))],
      ['0–100 km/h', ...cars.map((c) => c.acceleration0100 == null ? 'No indicado' : '${c.acceleration0100!.toStringAsFixed(1)} s')],
      ['Velocidad máxima', ...cars.map((c) => _value(c.maxSpeedKmh, ' km/h'))],
      ['Consumo combinado', ...cars.map((c) => c.consumptionL100 == null ? 'No indicado' : '${c.consumptionL100!.toStringAsFixed(1)} l/100 km')],
      ['Normativa de emisiones', ...cars.map((c) => _value(c.emissionsStandard))],
      ['Cambio', ...cars.map((c) => _value(c.transmission))],
      ['Carrocería', ...cars.map((c) => _value(c.bodyType))],
      ['Etiqueta DGT', ...cars.map((c) => _value(c.etiquetaMedioambiental))],
      ['Color', ...cars.map((c) => _value(c.color))],
      ['Puertas', ...cars.map((c) => _value(c.doors))],
      ['Plazas', ...cars.map((c) => _value(c.seats))],
      ['Equipamiento', ...cars.map((c) => c.equipment.isEmpty ? 'No indicado' : c.equipment.map((item) => uiText(context, item)).join(', '))],
    ];
    final fields = rows.where((row) => row.first != 'Equipamiento').map((row) => MarketComparisonField(
      row.first, row.skip(1).map((value) => value == 'No indicado' ? null : value).toList())).toList();
    final equipmentNames = <String, String>{};
    for (final car in cars) {
      for (final item in car.equipment) {
        final normalized = normalizeVehicleSearch(item);
        if (normalized.isNotEmpty) equipmentNames.putIfAbsent(normalized, () => item.trim());
      }
    }
    fields.add(MarketComparisonField('Equipamiento anunciado', cars.map((car) => car.equipment.isEmpty ? null : uiText(context, '{0} elementos', [car.equipment.length])).toList()));
    final sortedEquipment = equipmentNames.keys.toList()..sort();
    for (final name in sortedEquipment) {
      fields.add(MarketComparisonField(equipmentNames[name]!, cars.map((car) => car.equipment.any((item) => normalizeVehicleSearch(item) == name) ? 'Anunciado' : null).toList(), equipment: true));
    }
    return MarketComparisonView(
      cars: cars.map((car) => MarketComparisonCar(title: '${car.brand} ${car.model}',
        price: _price(car.price) == 'No indicado' ? uiText(context, 'No indicado') : _price(car.price),
        year: car.year, photo: car.photos.isEmpty ? null : car.photos.first)).toList(),
      fields: fields,
      onOpen: onOpenCar == null ? null : (index) => onOpenCar!(cars[index]),
    );
  }
}

class AutomotorsApp extends StatefulWidget {
  const AutomotorsApp({super.key});

  @override
  State<AutomotorsApp> createState() => _AutomotorsAppState();
}

class _AutomotorsAppState extends State<AutomotorsApp> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? accountSubscription;
  late final AccountSessionGuard accountGuard;
  StreamSubscription<Uri>? confirmationSubscription;
  final confirmationLinks = AppLinks();
  late final EmailConfirmationHandler confirmationHandler =
      EmailConfirmationHandler(
        verify: (code) => exchangeEmailConfirmation(
          code,
          () => SupabaseClient(
            automotorsSupabaseUrl,
            automotorsSupabaseKey,
            authOptions: AuthClientOptions(
              autoRefreshToken: false,
              pkceAsyncStorage: SharedPreferencesGotrueAsyncStorage(),
            ),
          ),
        ),
      );

  String? _openingListing;
  Future<void> openListingLink(String id) async {
    if(_openingListing==id)return;
    _openingListing=id;
    try {
      final row=await Supabase.instance.client.from('vehicle_listings').select(buyerListingProjection).eq('id',id).inFilter('status',['published','reserved','sold']).maybeSingle();
      if(!mounted)return;
      final navigator=automotorsNavigatorKey.currentState;
      if(row==null) {
        final context=automotorsNavigatorKey.currentContext;
        if(context!=null&&context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(uiText(context,'Este anuncio ya no está disponible.'))));
        return;
      }
      final car=await buyerCarFromListing(row);
      if(mounted&&navigator!=null)await navigator.push<void>(MaterialPageRoute(builder:(pageContext)=>CarDetailsPage(car:car,priceText:'${car.price.toStringAsFixed(0)} €',onContact:()=>contactSharedListing(pageContext,car))));
    } catch(_) {
      final context=automotorsNavigatorKey.currentContext;
      if(context!=null&&context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(uiText(context,'No se pudo abrir el anuncio. Comprueba la conexión e inténtalo de nuevo.'))));
    } finally {_openingListing=null;}
  }

  Future<void> openConfirmation(Uri uri) async {
    final listingId=listingIdFromUri(uri);
    if(listingId!=null){await openListingLink(listingId);return;}
    final result = await confirmationHandler.handle(uri);
    if (result == null || !mounted) return;
    final navigator = automotorsNavigatorKey.currentState;
    if (navigator == null) return;
    unawaited(
      navigator.pushAndRemoveUntil<bool>(
        MaterialPageRoute(
          builder: (_) => LoginPage(
            initialMessage: result.message,
            initialEmail: result.email,
            initialMessageIsError: !result.verified,
          ),
        ),
        (route) => route.isFirst,
      ),
    );
  }

  Future<void> startConfirmationLinks() async {
    if (!mounted || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS)
      return;
    confirmationSubscription = confirmationLinks.uriLinkStream.listen(
      (uri) => unawaited(openConfirmation(uri)),
      onError: (_) {},
    );
    try {
      final initial = await confirmationLinks.getInitialLink();
      if (initial != null && mounted) await openConfirmation(initial);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    final db = Supabase.instance.client;
    accountGuard = AccountSessionGuard(
      sessionKey: () => db.auth.currentSession?.accessToken,
      isSuspended: () async {
        final status = await db.rpc('community_account_status');
        return status is Map && status['suspended'] == true;
      },
      signOut: () => db.auth.signOut(scope: SignOutScope.local),
      onSuspended: () {
        final navigator = automotorsNavigatorKey.currentState;
        if (!mounted || navigator == null) return;
        unawaited(navigator.pushAndRemoveUntil<void>(MaterialPageRoute(
          builder: (_) => const HomePage(initialNotice:
            'Tu cuenta está suspendida por moderación. Contacta con info@automotors.info.'),
        ), (_) => false));
      },
    );
    WidgetsBinding.instance.addObserver(this);
    accountSubscription = db.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn || state.event == AuthChangeEvent.tokenRefreshed) {
        unawaited(accountGuard.check());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(accountGuard.check()));
    AutomotorsLocaleController.instance.addListener(_refreshLocale);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(startConfirmationLinks()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(accountGuard.check());
  }

  void _refreshLocale() => setState(() {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    accountGuard.dispose();
    unawaited(accountSubscription?.cancel());
    unawaited(confirmationSubscription?.cancel());
    AutomotorsLocaleController.instance.removeListener(_refreshLocale);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: AutomotorsLocaleController.instance.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      navigatorKey: automotorsNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Automotors',
      theme: automotorsMarketTheme(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialNotice});
  final String? initialNotice;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with MarketRecentSearchState<HomePage> {
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();
  String selectedFuel = 'Todos';
  String selectedBrand = 'Todas';
  String selectedModel = 'Todos';
  double? minPrice;
  double? maxPrice;
  int? minYear;
  int? maxYear;
  int? minKm;
  int? maxKm;
  String selectedTransmission = 'Todas', selectedBodyType = 'Todos', selectedLabel = 'Todas', selectedColor = '';
  int? minCv, maxCv, minCc, maxDoors, minSeats;
  final Set<String> selectedEquipmentFilters = {};

  final List<Car> cars = [];
  bool loadingCars = true;
  bool catalogueFailed=false;
  int unreadChatsCount = 0;
  int unreadBuyerAlerts=0;
  Future<void> loadUnreadBuyerAlerts() async {
    final db=Supabase.instance.client;final uid=db.auth.currentUser?.id;
    if(uid==null){if(mounted)setState(()=>unreadBuyerAlerts=0);return;}
    try{final rows=await db.from('vehicle_search_alerts').select('id').eq('user_id',uid).isFilter('read_at',null).limit(100);if(mounted && db.auth.currentUser?.id==uid)setState(()=>unreadBuyerAlerts=rows.length);}catch(_){/* Keep search usable when alerts are offline. */}
  }
  RealtimeChannel? _chatUnreadChannel;

  @override
  void initState() {
    super.initState();
    if (widget.initialNotice != null) WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uiText(context, widget.initialNotice!)), duration: const Duration(seconds: 8)));
    });

    CommunityVisibility.instance.addListener(_communityVisibilityChanged);
    loadCars();
    loadUnreadChatsCount();
    _chatUnreadChannel = Supabase.instance.client
        .channel('home-unread-chats-${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => loadUnreadChatsCount(),
        )
        .subscribe();
  }

  Future<void> loadUnreadChatsCount() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted && unreadChatsCount != 0) {
        setState(() => unreadChatsCount = 0);
      }
      return;
    }

    try {
      // Consultar todos los mensajes pendientes en una sola petición y contar
      // los conversation_id distintos: varios mensajes en un chat cuentan como 1.
      final rows = await supabase
          .from('chat_messages')
          .select('conversation_id')
          .neq('sender_id', user.id)
          .isFilter('read_at', null);
      final unreadConversationIds = List<Map<String, dynamic>>.from(rows)
          .map((message) => message['conversation_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      if (mounted && unreadConversationIds.length != unreadChatsCount) {
        setState(() => unreadChatsCount = unreadConversationIds.length);
      }
    } catch (error) {
      // Mantener el contador visible con su último valor si falla la consulta.
      debugPrint('No se pudo actualizar el contador de chats no leídos: $error');
    }
  }

  Widget _chatNavigationIcon(IconData icon) {
    return Badge(
      isLabelVisible: unreadChatsCount > 0,
      alignment: AlignmentDirectional.topEnd,
      offset: const Offset(5, -5),
      backgroundColor: const Color(0xFFE53935),
      label: Text(
        unreadChatsCount > 99 ? '99+' : '$unreadChatsCount',
        style: const TextStyle(
          color: marketInk,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Icon(icon),
    );
  }

  void _communityVisibilityChanged() {
    if (!mounted) return;
    final viewer = Supabase.instance.client.auth.currentUser?.id;
    setState(() => cars.removeWhere((car) => CommunityVisibility.instance.hides(viewer, car.ownerId)));
    unawaited(loadCars());
  }

  int _carLoadGeneration = 0;
  Future<void> loadCars() async {
    final generation = ++_carLoadGeneration;
    unawaited(loadUnreadBuyerAlerts());
    try {
      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from('vehicle_listings')
          .select(buyerListingProjection)
          .inFilter('status', ['published', 'reserved'])
          .order('created_at', ascending: false);

      final loadedCars = <Car>[];
      final featuredIds = <String>{};
      try {
        final promotions = await supabase.rpc('get_featured_vehicle_ids');
        for (final promotion in List<Map<String, dynamic>>.from(promotions)) {
          final id = promotion['vehicle_id']?.toString();
          if (id != null && id.isNotEmpty) featuredIds.add(id);
        }
      } catch (_) {
        // Si las promociones no están disponibles, mostramos los anuncios con normalidad.
      }
      for (final raw in List<Map<String, dynamic>>.from(rows)) {
        final photoData = raw['vehicle_photos'];
        final photoRows = photoData is List
            ? List<Map<String, dynamic>>.from(photoData)
            : <Map<String, dynamic>>[];
        photoRows.sort((a, b) => ((a['position'] as num?)?.toInt() ?? 0)
            .compareTo((b['position'] as num?)?.toInt() ?? 0));

        final photoPaths = photoRows.map((p) => p['storage_path']?.toString() ?? '')
            .where((p) => p.isNotEmpty).toList();
        final photoBytes = await loadListingCover(photoPaths, downloadVehiclePhoto);

        loadedCars.add(Car.fromListing(raw, photos: photoBytes, photoPaths: photoPaths,
          isFeatured: featuredIds.contains(raw['id']?.toString())));
      }

      if (!mounted || generation != _carLoadGeneration) return;
      setState(() {
        cars
          ..clear()
          ..addAll(loadedCars);
        loadingCars = false;
        catalogueFailed=false;
      });
      final sharedListingId = Uri.base.queryParameters['listing'];
      if (sharedListingId != null && sharedListingId.isNotEmpty) {
        Car? sharedCar;
        for (final item in loadedCars) {
          if (item.listingId == sharedListingId) {
            sharedCar = item;
            break;
          }
        }
        if (sharedCar != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) openCarDetails(sharedCar!);
          });
        } else if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text(uiText(context, "Este anuncio ya no está disponible."))),
            );
          });
        }
      }
    } catch (error) {
      if (!mounted) return;
      AppDiagnostics.record('catalogue',error);
      setState(() {loadingCars=false;catalogueFailed=true;});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uiText(context, "No se pudieron cargar los anuncios desde Supabase: {0}", [error])), duration: const Duration(seconds: 8)),
      );
    }
  }

  List<Car> get filteredCars {
    final query = searchController.text.toLowerCase().trim();
    return cars.where((car) {
      final matchesSearch =
          matchesVehicleSearch(query, [car.brand, car.model, car.version, car.fuel, car.transmission, car.bodyType]);
      final matchesBrand = selectedBrand == 'Todas' || car.brand == selectedBrand;
      final matchesModel = selectedModel == 'Todos' || car.model == selectedModel;
      final matchesFuel =
          selectedFuel == 'Todos' || car.fuel == selectedFuel;
      final matchesMinPrice = minPrice == null || car.price >= minPrice!;
      final matchesMaxPrice = maxPrice == null || car.price <= maxPrice!;
      final matchesMinYear = minYear == null || car.year >= minYear!;
      final matchesMaxYear = maxYear == null || car.year <= maxYear!;
      final matchesMinKm = minKm == null || car.km >= minKm!;
      final matchesMaxKm = maxKm == null || car.km <= maxKm!;
      final matchesTransmission = matchesVehicleTransmission(car.transmission, selectedTransmission);
      final matchesBodyType = selectedBodyType == 'Todos' || car.bodyType == selectedBodyType;
      final matchesLabel = selectedLabel == 'Todas' || car.etiquetaMedioambiental == selectedLabel;
      final matchesColor = selectedColor.trim().isEmpty || (car.color ?? '').toLowerCase().contains(selectedColor.trim().toLowerCase());
      final matchesMinCv = minCv == null || (car.cv != null && car.cv! >= minCv!);
      final matchesMaxCv = maxCv == null || (car.cv != null && car.cv! <= maxCv!);
      final matchesMinCc = minCc == null || (car.cilindradaCc != null && car.cilindradaCc! >= minCc!);
      final matchesMaxDoors = maxDoors == null || (car.doors != null && car.doors! <= maxDoors!);
      final matchesMinSeats = minSeats == null || (car.seats != null && car.seats! >= minSeats!);
      final matchesEquipment = selectedEquipmentFilters.every((item) => car.equipment.contains(item));
      return matchesSearch &&
          matchesBrand &&
          matchesModel &&
          matchesFuel &&
          matchesMinPrice &&
          matchesMaxPrice &&
          matchesMinYear && matchesMaxYear && matchesMinKm && matchesMaxKm && matchesTransmission && matchesBodyType && matchesLabel && matchesColor && matchesMinCv && matchesMaxCv && matchesMinCc && matchesMaxDoors && matchesMinSeats && matchesEquipment;
    }).toList()..sort((a, b) => (b.isFeatured ? 1 : 0).compareTo(a.isFeatured ? 1 : 0));
  }

  Future<void> _openSavedSearches() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      final loggedIn = await requireAutomotorsLogin(context);
      if (!loggedIn || !mounted) return;
    }
    if (!mounted) return;
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => SavedSearchesPage(onApply: (criteria) {
      if (!mounted) return;
      num? numeric(String key) {
        final value = num.tryParse('${criteria[key] ?? ''}');
        return value != null && value.isFinite ? value : null;
      }
      setState(() {
        searchController.text = criteria['query']?.toString() ?? '';
        selectedBrand = criteria['brand']?.toString() ?? 'Todas';
        selectedModel = criteria['model']?.toString() ?? 'Todos';
        selectedFuel = criteria['fuel']?.toString() ?? 'Todos';
        minPrice = numeric('min_price')?.toDouble(); maxPrice = numeric('max_price')?.toDouble();
        minYear = numeric('min_year')?.toInt(); maxYear = numeric('max_year')?.toInt();
        minKm = numeric('min_km')?.toInt(); maxKm = numeric('max_km')?.toInt();
        minCv = numeric('min_cv')?.toInt(); maxCv = numeric('max_cv')?.toInt();
        minCc = numeric('min_cc')?.toInt(); maxDoors = numeric('max_doors')?.toInt(); minSeats = numeric('min_seats')?.toInt();
        selectedTransmission = criteria['transmission']?.toString() ?? 'Todas';
        selectedBodyType = criteria['body_type']?.toString() ?? 'Todos';
        selectedLabel = criteria['label']?.toString() ?? 'Todas'; selectedColor = criteria['color']?.toString() ?? '';
        selectedEquipmentFilters..clear()..addAll((criteria['equipment'] is List ? criteria['equipment'] as List : const []).whereType<String>());
      });
    })));
  }

  Future<void> saveCurrentSearch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final loggedIn = await requireAutomotorsLogin(context);
      if (!loggedIn || !mounted) return;
    }
    final initialName = [
      if (selectedBrand != 'Todas') selectedBrand,
      if (selectedModel != 'Todos') selectedModel,
      if (selectedFuel != 'Todos') selectedFuel,
    ].join(' ').trim();
    final name = await promptMarketSavedSearchName(context, initialName);
    if (name == null || !mounted) return;
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    try {
      await Supabase.instance.client.from('saved_vehicle_searches').insert({
        'user_id': currentUser.id,
        'name': name,
        'criteria': {
          'brand': selectedBrand,
          'model': selectedModel,
          'fuel': selectedFuel,
          'min_price': minPrice,
          'max_price': maxPrice,
          'min_year': minYear,
          'max_year': maxYear,
          'min_km': minKm,
          'max_km': maxKm,
          'transmission': selectedTransmission,
          'body_type': selectedBodyType,
          'label': selectedLabel,
          'color': selectedColor,
          'min_cv': minCv,
          'max_cv': maxCv,
          'min_cc': minCc,
          'max_doors': maxDoors,
          'min_seats': minSeats,
          'equipment': selectedEquipmentFilters.toList(),
          'query': searchController.text.trim(),
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "Búsqueda guardada en tu cuenta.")),action:SnackBarAction(label:uiText(context,'Ver búsquedas'),onPressed:_openSavedSearches)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "No se pudo guardar la búsqueda. Inténtalo de nuevo."))),
      );
    }
  }

  Future<void> openFilters() async {
    final minPriceController =
        TextEditingController(text: minPrice?.toStringAsFixed(0) ?? '');
    final maxPriceController =
        TextEditingController(text: maxPrice?.toStringAsFixed(0) ?? '');
    final minYearController =
        TextEditingController(text: minYear?.toString() ?? '');
    final maxYearController = TextEditingController(text: maxYear?.toString() ?? '');
    final minKmController = TextEditingController(text: minKm?.toString() ?? '');
    final maxKmController =
        TextEditingController(text: maxKm?.toString() ?? '');
    final minCvController = TextEditingController(text: minCv?.toString() ?? '');
    final maxCvController = TextEditingController(text: maxCv?.toString() ?? '');
    final minCcController = TextEditingController(text: minCc?.toString() ?? '');
    final doorsController = TextEditingController(text: maxDoors?.toString() ?? '');
    final seatsController = TextEditingController(text: minSeats?.toString() ?? '');
    final colorController = TextEditingController(text: selectedColor);
    var transmission = selectedTransmission, bodyType = selectedBodyType, label = selectedLabel;
    final equipmentFilters = Set<String>.from(selectedEquipmentFilters);
    var fuel = selectedFuel;
    var brand = selectedBrand;
    var model = selectedModel;
    final brands = ['Todas', ...{if (brand != 'Todas') brand, ...cars.map((car) => car.brand)}.toList()..sort()];
    final models = ['Todos', ...cars.where((car) => brand == 'Todas' || car.brand == brand).map((car) => car.model).toSet().toList()..sort()];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: marketSurface,
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
                        color: marketLine,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                   Text(uiText(context, "Filtrar vehículos"),
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                   Text(uiText(context, "Encuentra el coche que encaja contigo."),
                    style: TextStyle(color: marketMuted)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(isExpanded: true,
                    value: brands.contains(brand) ? brand : 'Todas',
                    decoration:  InputDecoration(labelText: uiText(context, "Marca")),
                    items: brands.map((value) => DropdownMenuItem(value: value, child: Text(value == 'Todas' || value == 'Todos' ? uiText(context, value) : value))).toList(),
                    onChanged: (value) {
                      if (value != null) setSheetState(() {
                        brand = value;
                        final available = cars.where((car) => brand == 'Todas' || car.brand == brand).map((car) => car.model).toSet();
                        if (model != 'Todos' && !available.contains(model)) model = 'Todos';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(isExpanded: true,
                    value: (brand == 'Todas' ? cars.map((car) => car.model).toSet() : cars.where((car) => car.brand == brand).map((car) => car.model).toSet()).contains(model) ? model : 'Todos',
                    decoration:  InputDecoration(labelText: uiText(context, "Modelo")),
                    items: ['Todos', ...cars.where((car) => brand == 'Todas' || car.brand == brand).map((car) => car.model).toSet().toList()..sort()].map((value) => DropdownMenuItem(value: value, child: Text(value == 'Todas' || value == 'Todos' ? uiText(context, value) : value))).toList(),
                    onChanged: (value) { if (value != null) setSheetState(() => model = value); },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(isExpanded: true,
                    value: fuel,
                    decoration:  InputDecoration(labelText: uiText(context, "Combustible")),
                    items:  [
                      DropdownMenuItem(value: 'Todos', child: Text(uiText(context, "Todos"))),
                      DropdownMenuItem(value: 'Diésel', child: Text(uiText(context, "Diésel"))),
                      DropdownMenuItem(value: 'Gasolina', child: Text(uiText(context, "Gasolina"))),
                      DropdownMenuItem(value: 'Híbrido', child: Text(uiText(context, "Híbrido"))),
                      DropdownMenuItem(value: 'Eléctrico', child: Text(uiText(context, "Eléctrico"))),
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
                      decoration:  InputDecoration(labelText: uiText(context, "Precio mínimo (€)")),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(
                      controller: maxPriceController,
                      keyboardType: TextInputType.number,
                      decoration:  InputDecoration(labelText: uiText(context, "Precio máximo (€)")),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: minYearController, keyboardType: TextInputType.number, decoration:  InputDecoration(labelText: uiText(context, "Año desde")))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: maxYearController, keyboardType: TextInputType.number, decoration:  InputDecoration(labelText: uiText(context, "Año hasta")))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: minKmController, keyboardType: TextInputType.number, decoration:  InputDecoration(labelText: uiText(context, "Km desde")))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: maxKmController, keyboardType: TextInputType.number, decoration:  InputDecoration(labelText: uiText(context, "Km hasta")))),
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(isExpanded: true, value: transmission, decoration:  InputDecoration(labelText: uiText(context, "Transmisión")), items: const ['Todas','Manual','Automático','Automático (DSG)'].map((v) => DropdownMenuItem(value: v, child: Text(uiText(context, v)))).toList(), onChanged: (v) { if (v != null) setSheetState(() => transmission = v); }),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(isExpanded: true, value: bodyType, decoration:  InputDecoration(labelText: uiText(context, "Tipo de carrocería")), items: const ['Todos','Berlina','Compacto','SUV','Familiar','Coupé','Cabrio','Monovolumen','Furgoneta','Pickup'].map((v) => DropdownMenuItem(value: v, child: Text(uiText(context, v)))).toList(), onChanged: (v) { if (v != null) setSheetState(() => bodyType = v); }),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(isExpanded: true, value: label, decoration:  InputDecoration(labelText: uiText(context, "Etiqueta medioambiental")), items: const ['Todas','Sin etiqueta','B','C','ECO','CERO'].map((v) => DropdownMenuItem(value: v, child: Text(uiText(context, v)))).toList(), onChanged: (v) { if (v != null) setSheetState(() => label = v); }),
                  const SizedBox(height: 12),
                  TextField(controller: colorController, decoration:  InputDecoration(labelText: uiText(context, "Color exterior"))),
                  const SizedBox(height: 12),
                  Row(children: [Expanded(child: TextField(controller: minCvController, keyboardType: TextInputType.number, decoration:  InputDecoration(labelText: uiText(context, "CV desde")))), const SizedBox(width: 12), Expanded(child: TextField(controller: maxCvController, keyboardType: TextInputType.number, decoration:  InputDecoration(labelText: uiText(context, "CV hasta"))))]),
                  const SizedBox(height: 12),
                  Row(children: [Expanded(child: TextField(controller: minCcController, keyboardType: TextInputType.number, decoration:  InputDecoration(labelText: uiText(context, "Cilindrada mínima (cc)")))), const SizedBox(width: 12), Expanded(child: TextField(controller: doorsController, keyboardType: TextInputType.number, decoration:  InputDecoration(labelText: uiText(context, "Máximo de puertas"))))]),
                  TextField(controller: seatsController, keyboardType: TextInputType.number, decoration:  InputDecoration(labelText: uiText(context, "Plazas mínimas"))),
                  const SizedBox(height: 8),
                   Text(uiText(context, "Equipamiento"), style: TextStyle(fontWeight: FontWeight.w700)),
                  ...['Asientos deportivos','Asientos calefactables','Asientos ventilados','Volante multifunción','Climatizador bizona','Navegador','Apple CarPlay / Android Auto','Sensores de aparcamiento','Cámara trasera','Control de crucero','Control de crucero adaptativo','Faros LED','Faros Matrix / adaptativos','Techo solar','Tapicería de cuero','Portón eléctrico','Acceso y arranque sin llave','Detector de ángulo muerto','Mantenimiento en servicio oficial'].map((item) => CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(uiText(context, item)), value: equipmentFilters.contains(item), activeColor: gold, onChanged: (checked) => setSheetState(() { if (checked == true) { equipmentFilters.add(item); } else { equipmentFilters.remove(item); } }))),
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
                          selectedTransmission = 'Todas'; selectedBodyType = 'Todos'; selectedLabel = 'Todas'; selectedColor = ''; minCv = null; maxCv = null; minCc = null; maxDoors = null; minSeats = null; selectedEquipmentFilters.clear();
                        });
                        Navigator.pop(sheetContext);
                      },
                      child:  Text(uiText(context, "Limpiar")),
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
                          maxYear = parseInt(maxYearController.text);
                          minKm = parseInt(minKmController.text);
                          maxKm = parseInt(maxKmController.text);
                          selectedTransmission = transmission; selectedBodyType = bodyType; selectedLabel = label; selectedColor = colorController.text; minCv = parseInt(minCvController.text); maxCv = parseInt(maxCvController.text); minCc = parseInt(minCcController.text); maxDoors = parseInt(doorsController.text); minSeats = parseInt(seatsController.text); selectedEquipmentFilters..clear()..addAll(equipmentFilters);
                        });
                        Navigator.pop(sheetContext);
                        Navigator.push<void>(context, MaterialPageRoute(builder: (_) => VehicleSearchResultsPage(cars: filteredCars, onOpenCar: openCarDetails)));
                      },
                      child:  Text(uiText(context, "Ver resultados")),
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
    maxYearController.dispose();
    minKmController.dispose();
    maxKmController.dispose(); minCvController.dispose(); maxCvController.dispose(); minCcController.dispose(); doorsController.dispose(); seatsController.dispose(); colorController.dispose();
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
         SnackBar(content: Text(uiText(context, "Este vehículo de demostración aún no tiene un chat disponible."))),
      );
      return;
    }
    if (car.ownerId == user.id) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "No puedes iniciar un chat contigo mismo."))),
      );
      return;
    }
    try {
      final supabase = Supabase.instance.client;
      final conversation = await getOrCreateConversation(
        supabase: supabase,
        listingId: car.listingId!,
        buyerId: user.id,
        sellerId: car.ownerId!,
      );
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
        SnackBar(content: Text(uiText(context, "No se pudo abrir el chat. Comprueba la configuración de Supabase. ({0})", [error])),
          duration: const Duration(seconds: 6)),
      );
    }
  }

  Future<void> openAddCar() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      final loggedIn = await requireAutomotorsLogin(context);
      if (!loggedIn || !mounted) return;
    }
    try {
      final allowed=await Supabase.instance.client.rpc('can_publish_vehicle_listing');
      if(!mounted)return;
      final car=await Navigator.push<Car>(context,MaterialPageRoute(builder:(_)=>allowed==true?const AddCarPage():const PublishOptionsPage()));
      if(car!=null && mounted)setState(()=>cars.insert(0,car));
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(uiText(context,'No se pudo comprobar el acceso a publicación. Reinténtalo.'))));}
  }

  Future<void> openCarDetails(Car car) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CarDetailsPage(
          car: car,
          priceText: euros(car.price),
          onContact: () => contact(car),
        ),
      ),
    );
    if (mounted) await loadCars();
  }

  @override
  void dispose() {
    CommunityVisibility.instance.removeListener(_communityVisibilityChanged);
    _chatUnreadChannel?.unsubscribe();
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
      minYear != null, maxYear != null,
      minKm != null, maxKm != null,
      selectedTransmission != 'Todas', selectedBodyType != 'Todos',
      selectedLabel != 'Todas', selectedColor.trim().isNotEmpty,
      minCv != null, maxCv != null, minCc != null,
      maxDoors != null, minSeats != null, selectedEquipmentFilters.isNotEmpty,
    ].where((active) => active).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: black,
        titleSpacing: 18,
        title: Row(
          children: [
            const AutomotorsBrandMark(size: 36),
            const SizedBox(width: 10),
             Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(uiText(context, "AUTOMOTORS"),
                    style: TextStyle(
                      fontSize: 17,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    )),
                Text(uiText(context, "MOTOR MARKET"),
                    style: TextStyle(
                      color: marketAccent, fontSize: 9, letterSpacing: 2.1,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ))),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: AppLocalizations.of(context).language,
            onSelected: (code) async {
              await AutomotorsLocaleController.instance.select(code);
            },
            itemBuilder: (_) =>  [
              PopupMenuItem(value: 'es', child: Text(uiText(context, "Español"))),
              PopupMenuItem(value: 'en', child: Text(uiText(context, "English"))),
              PopupMenuItem(value: 'ca', child: Text(uiText(context, "Català"))),
            ],
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.language, color: marketAccent, size: 19), const SizedBox(width: 4), Text(AutomotorsLocaleController.instance.locale.languageCode.toUpperCase(), style: const TextStyle(color: marketAccent, fontWeight: FontWeight.w700))])),
          ),
          IconButton(
            tooltip: appText('Alertas de búsqueda', 'Search alerts'),
            onPressed: () async {
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) {
                final loggedIn = await requireAutomotorsLogin(context);
                if (!loggedIn || !mounted) return;
              }
              if (!context.mounted) return;
              await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => VehicleSearchAlertsPage(onOpenCar: openCarDetails)));
              if(mounted)await loadUnreadBuyerAlerts();
            },
            icon: Badge(isLabelVisible:unreadBuyerAlerts>0,label:Text(unreadBuyerAlerts>=100 ? '99+' : '$unreadBuyerAlerts'),child:const Icon(Icons.notifications_active_outlined,color:marketAccent)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: marketAccent,
        onRefresh: loadCars,
        child: ListView(
          padding: EdgeInsets.fromLTRB(isWide ? 28 : 16, 10, isWide ? 28 : 16, 28),
          children: [
            Container(
              key: const Key('market-search-hero'),
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
              decoration: const BoxDecoration(color: Colors.transparent),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 22, height: 2, color: gold), const SizedBox(width: 9),
                  Expanded(child: Text(uiText(context, 'TU PRÓXIMO COCHE'),
                    style: const TextStyle(color: gold, letterSpacing: 1.6, fontSize: 10, fontWeight: FontWeight.w700))),
                ]),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(uiText(context, 'Encuentra el que\nva contigo.'),
                  style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(uiText(context, 'Particulares y profesionales. En un mismo lugar.'),
                  style: const TextStyle(color: marketMuted, fontSize: 13, height: 1.4)),
              ]),
            ),
            Row(
              children: [
                Expanded(
                  child: RawAutocomplete<String>(
                    textEditingController: searchController,
                    focusNode: searchFocusNode,
                    optionsBuilder: (value) {
                      final query = value.text.trim().toLowerCase();
                      if (query.isEmpty) return recentVehicleQueries;
                      final options = <String>{...recentVehicleQueries.where((item) => matchesVehicleSearch(query, [item]))};
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
                      rememberVehicleSearch(value);
                      setState(() {});
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) { rememberVehicleSearch(controller.text); onFieldSubmitted(); },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: appText('Escribe marca o modelo...', 'Search make or model...'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: controller.text.isEmpty ? IconButton(
                          tooltip: uiText(context, 'Búsquedas recientes'), icon: const Icon(Icons.history_rounded),
                          onPressed: () => openVehicleSearchHistory((query) { searchController.text = query; searchFocusNode.unfocus(); setState(() {}); }),
                        ) : IconButton(
                          tooltip: appText('Borrar búsqueda', 'Clear search'), icon: const Icon(Icons.close_rounded),
                          onPressed: () { controller.clear(); setState(() {}); },
                        ),
                        filled: true,
                        fillColor: marketSurface,
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
                        color: marketSurface,
                        elevation: 8,
                        borderRadius: BorderRadius.circular(14),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260, maxWidth: 420),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shrinkWrap: true,
                            children: options.map((option) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.search, color: marketAccent, size: 19),
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
                      side: BorderSide(color: activeFilterCount > 0 ? gold : marketLine),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Semantics(label: AppLocalizations.of(context).filters, child: const Icon(Icons.tune_rounded, color: marketInk)),
                        if (activeFilterCount > 0)
                          Positioned(
                            right: -9, top: -9,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: marketAccent, shape: BoxShape.circle),
                              child: Text('$activeFilterCount',
                                style: const TextStyle(color: Colors.black, fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
              ]),
            ),
            const SizedBox(height: 12),
            MarketQuickFilters(
              automatic: selectedTransmission == 'Automático', suv: selectedBodyType == 'SUV',
              electric: selectedFuel == 'Eléctrico', budget: maxPrice == 20000,
              onAutomatic: () => setState(() => selectedTransmission = selectedTransmission == 'Automático' ? 'Todas' : 'Automático'),
              onSuv: () => setState(() => selectedBodyType = selectedBodyType == 'SUV' ? 'Todos' : 'SUV'),
              onElectric: () => setState(() => selectedFuel = selectedFuel == 'Eléctrico' ? 'Todos' : 'Eléctrico'),
              onBudget: () => setState(() { maxPrice = maxPrice == 20000 ? null : 20000; if (maxPrice != null && minPrice != null && minPrice! > maxPrice!) minPrice = null; }),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                 Expanded(child: Text(searchController.text.trim().isNotEmpty || activeFilterCount > 0 ? AppLocalizations.of(context).vehiclesFound(filtered.length) : uiText(context, "Últimos vehículos"), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700))),
                TextButton(onPressed: () => Navigator.push<void>(context,
                  MaterialPageRoute(builder: (_) => AllVehiclesPage(
                    cars: List<Car>.from(filtered), onOpenCar: openCarDetails))),
                  child:  Text(uiText(context, "Ver todos  →"), style: TextStyle(color: marketAccent, fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 10),
            if (loadingCars)
              const MarketLoadingCard()
            else if (filtered.isNotEmpty) ...[
              Align(alignment:Alignment.centerLeft,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:540),child:SizedBox(height: (MediaQuery.sizeOf(context).width-32).clamp(288,540)*.75+185*MediaQuery.textScalerOf(context).scale(1),child:MarketVehicleCard(
                title:'${filtered.first.brand} ${filtered.first.model}',price:euros(filtered.first.price),details:'${filtered.first.year} · ${_formatCompactKm(filtered.first.km)} · ${uiText(context,filtered.first.fuel)}',
                version:filtered.first.version,photoCount:filtered.first.photoCount,photo:filtered.first.photos.firstOrNull,favorite:SaveVehicleButton(car:filtered.first),
                status:filtered.first.status=='reserved' ? _VehicleStatusBadge(status:filtered.first.status) : null,onTap:()=>openCarDetails(filtered.first),
              )))),
              for(final car in filtered.skip(1).take(3)) Padding(padding:const EdgeInsets.only(top:12),child:MarketEditorialCarRow(
                title:'${car.brand} ${car.model}',price:euros(car.price),details:'${car.year} · ${_formatCompactKm(car.km)} · ${uiText(context,car.fuel)}',version:car.version,photo:car.photos.firstOrNull,favorite:SaveVehicleButton(car:car),status:car.status=='reserved' ? _VehicleStatusBadge(status:car.status) : null,onTap:()=>openCarDetails(car),
              )),
            ],
            if(!loadingCars && catalogueFailed)MarketEmptyState(icon:Icons.wifi_off_outlined,title:'No se pudo cargar el catálogo',message:'Comprueba la conexión y vuelve a intentarlo.',actionLabel:'Reintentar',onAction:loadCars),
            if (!loadingCars && !catalogueFailed && cars.isEmpty) LaunchEmptyCatalogue(onPublish:openAddCar,onSaveSearch:saveCurrentSearch),
            if (!loadingCars && cars.isNotEmpty && filtered.isEmpty)
              MarketEmptyState(icon:Icons.search_off_rounded,title:AppLocalizations.of(context).noVehiclesFound,message:'Prueba otra marca o ajusta los filtros para ampliar tu búsqueda.',actionLabel:AppLocalizations.of(context).filters,onAction:openFilters),
            if(!loadingCars && cars.isNotEmpty && filtered.isEmpty) Wrap(spacing:8,runSpacing:8,children:[
              if(minPrice!=null || maxPrice!=null) OutlinedButton.icon(onPressed:()=>setState((){minPrice=null;maxPrice=null;}),icon:const Icon(Icons.euro),label:Text(uiText(context,'Ampliar rango de precio'))),
              if(searchController.text.trim().isNotEmpty) OutlinedButton.icon(onPressed:()=>setState(()=>searchController.clear()),icon:const Icon(Icons.search),label:Text(uiText(context,'Buscar sin estas palabras'))),
              OutlinedButton.icon(onPressed:()=>setState((){searchController.clear();selectedBrand='Todas';selectedModel='Todos';selectedFuel='Todos';minPrice=null;maxPrice=null;minYear=null;maxYear=null;minKm=null;maxKm=null;selectedTransmission='Todas';selectedBodyType='Todos';selectedLabel='Todas';selectedColor='';minCv=null;maxCv=null;minCc=null;maxDoors=null;minSeats=null;selectedEquipmentFilters.clear();}),icon:const Icon(Icons.filter_alt_off_outlined),label:Text(uiText(context,'Quitar todos los filtros'))),
              TextButton.icon(onPressed:saveCurrentSearch,icon:const Icon(Icons.notifications_none),label:Text(uiText(context,'Avisarme cuando haya resultados'))),
            ]),
            const SizedBox(height: 24),
            Text(uiText(context, 'Tu próxima búsqueda'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.5)),
            const SizedBox(height: 12),
            MarketQuickLink(title: 'Mis favoritos', subtitle: 'Sigue los coches que te interesan', icon: Icons.favorite_border_rounded,
              onTap: () async {if(!await requireAutomotorsLogin(context) || !context.mounted)return;await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>SavedVehiclesPage(cars:cars,onOpenCar:openCarDetails)));}),
            const SizedBox(height: 10),
            MarketQuickLink(title: 'Tus búsquedas', subtitle: 'Recupera tus filtros guardados',
              icon: Icons.bookmark_outline_rounded, onTap: _openSavedSearches),
            const SizedBox(height: 10),
            MarketQuickLink(title: 'Guardar esta búsqueda', subtitle: 'Vuelve a los coches que encajan contigo',
              icon: Icons.saved_search_rounded, onTap: saveCurrentSearch),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: marketAccent.withValues(alpha: .6)), gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFAF9F6)])),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text(uiText(context, "¿Tienes un vehículo?"), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                 Text(uiText(context, "Publica tu anuncio y conecta con compradores."), style: TextStyle(color: marketMuted)),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: openAddCar, icon: const Icon(Icons.arrow_forward_rounded), label:  Text(uiText(context, "Publicar mi vehículo")), style: OutlinedButton.styleFrom(foregroundColor: marketAccent, side: const BorderSide(color: marketAccent), padding: const EdgeInsets.symmetric(vertical: 13), textStyle: const TextStyle(fontWeight: FontWeight.w700)))),
              ]),
            ),
            const SizedBox(height: 12),
            Card(color: marketPaper, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: marketAccent.withValues(alpha: .35))), child: ListTile(
              leading: const Icon(Icons.diamond_outlined, color: marketAccent, size: 34),
              title:  Text(uiText(context, "Packs y suscripción"), style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle:  Text(uiText(context, "Destaca tus anuncios y consigue más visibilidad."), style: TextStyle(color: marketMuted)),
              trailing: const Icon(Icons.chevron_right_rounded, color: marketAccent),
              onTap: openAddCar,
            )),

          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: marketSurface,
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
            if (mounted) await loadUnreadChatsCount();
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
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: AppLocalizations.of(context).home),
          NavigationDestination(icon: _chatNavigationIcon(Icons.chat_bubble_outline), selectedIcon: _chatNavigationIcon(Icons.chat_bubble), label: AppLocalizations.of(context).chats),
          NavigationDestination(icon: const MarketPublishIcon(), selectedIcon: const MarketPublishIcon(), label: uiText(context,'Publicar')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: AppLocalizations.of(context).profile),
        ],
      ),
    );
  }

  Widget _carMeta(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: marketMuted),
      const SizedBox(width: 4),
      Text(uiText(context, label), style: const TextStyle(color: marketMuted, fontSize: 11)),
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
  final LocalMarketState? localState;
  const AllVehiclesPage({super.key, required this.cars, required this.onOpenCar, this.localState});
  @override
  State<AllVehiclesPage> createState() => _AllVehiclesPageState();
}

class _AllVehiclesPageState extends State<AllVehiclesPage> with MarketRecentSearchState<AllVehiclesPage> {
  final search = TextEditingController();
  String brand = 'Todas';
  String model = 'Todos';
  String fuel = 'Todos';
  String transmission = 'Todas';
  String bodyType = 'Todos';
  double minPrice = 0, maxPrice = 200000;
  int minKm = 0, maxKm = 300000, minCv = 0, maxCv = 1000;
  int minYear = 1990, maxYear = DateTime.now().year + 1;
  bool showFilters = false;
  String sortOrder = 'featured';
  final Set<String> _comparisonIds = <String>{};

  LocalMarketState get _catalogStorage => widget.localState ?? _localMarketState;
  Timer? _catalogSaveTimer;
  bool _catalogEdited = false;
  static const _catalogKey = 'automotors.catalog-filters.v1';

  @override
  void initState() {
    super.initState();
    _restoreCatalog();
  }

  void _updateCatalog(VoidCallback change) {
    _catalogEdited = true;
    setState(change);
    _catalogSaveTimer?.cancel();
    final snapshot = {...catalogCriteria, 'sort': sortOrder};
    _catalogSaveTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_catalogStorage.write(_catalogKey, snapshot).catchError((Object _) {}));
    });
  }

  Future<void> _restoreCatalog() async {
    final saved = await _catalogStorage.read(_catalogKey);
    if (!mounted || _catalogEdited || saved.isEmpty) return;
    int number(String key, int fallback, int maximum) {
      final value = saved[key];
      return value is num && value.isFinite ? value.toInt().clamp(0, maximum) : fallback;
    }
    setState(() {
      search.text = saved['query'] is String ? saved['query'] as String : '';
      brand = brands.contains(saved['brand']) ? saved['brand'] as String : 'Todas';
      model = models.contains(saved['model']) ? saved['model'] as String : 'Todos';
      fuel = ['Todos', 'Gasolina', 'Diésel', 'Híbrido', 'Eléctrico', 'GLP', 'GNC'].contains(saved['fuel']) ? saved['fuel'] as String : 'Todos';
      transmission = ['Todas', 'Automático', 'Manual', 'Automático (DSG)'].contains(saved['transmission']) ? saved['transmission'] as String : 'Todas';
      bodyType = {'Todos', 'SUV', ...widget.cars.map((car) => car.bodyType).whereType<String>()}.contains(saved['body_type']) ? saved['body_type'] as String : 'Todos';
      maxPrice = number('max_price', 200000, 200000).toDouble();
      minPrice = number('min_price', 0, maxPrice.toInt()).toDouble();
      maxKm = number('max_km', 300000, 300000); minKm = number('min_km', 0, maxKm);
      maxCv = number('max_cv', 1000, 1000); minCv = number('min_cv', 0, maxCv);
      maxYear = number('max_year', DateTime.now().year + 1, DateTime.now().year + 1).clamp(1990, DateTime.now().year + 1);
      minYear = number('min_year', 1990, maxYear).clamp(1990, maxYear);
      if (['featured', 'recent', 'price_asc', 'price_desc', 'year_desc', 'km_asc'].contains(saved['sort'])) sortOrder = saved['sort'] as String;
    });
  }

  bool savingSearch = false;
  Map<String, dynamic> get catalogCriteria => {
    'query': search.text.trim(),
    'brand': brand,
    'model': model,
    'fuel': fuel,
    'transmission': transmission,
    'body_type': bodyType,
    'min_price': minPrice,
    'max_price': maxPrice,
    'min_km': minKm,
    'max_km': maxKm,
    if (minCv != 0 || maxCv != 1000) ...{'min_cv': minCv, 'max_cv': maxCv},
    if (minYear != 1990 || maxYear != DateTime.now().year + 1) ...{
      'min_year': minYear,
      'max_year': maxYear,
    },
  };
  Future<void> saveCatalogSearch() async {
    if (savingSearch) return;
    final criteria = Map<String, dynamic>.from(catalogCriteria);
    final db = Supabase.instance.client;
    if (db.auth.currentUser == null) {
      if (!await requireAutomotorsLogin(context) || !mounted) return;
    }
    final uid = db.auth.currentUser?.id;
    if (uid == null) return;
    final suggested = [
      if (brand != 'Todas') brand,
      if (model != 'Todos') model,
      if (search.text.trim().isNotEmpty) search.text.trim(),
    ].join(' ');
    _updateCatalog(() => savingSearch = true);
    try {
      final name = await promptMarketSavedSearchName(context, suggested);
      if (name == null || !mounted || db.auth.currentUser?.id != uid) return;
      await db.from('saved_vehicle_searches').insert({
        'user_id': uid,
        'name': name,
        'criteria': criteria,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiText(context, 'Búsqueda guardada en tu cuenta.')),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                'No se pudo guardar la búsqueda. Inténtalo de nuevo.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) _updateCatalog(() => savingSearch = false);
    }
  }
  void _toggleCompare(Car car) {
    final id = car.listingId ?? '${car.brand}-${car.model}-${car.year}-${car.km}';
    _updateCatalog(() {
      if (_comparisonIds.contains(id)) {
        _comparisonIds.remove(id);
      } else if (_comparisonIds.length < 3) {
        _comparisonIds.add(id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).comparisonLimit)),
        );
      }
    });
  }

  void _clearComparison() => _updateCatalog(() => _comparisonIds.clear());

  void _resetFilters() {
    _updateCatalog(() {
      search.clear();
      brand = 'Todas';
      model = 'Todos';
      fuel = 'Todos';
      transmission = 'Todas'; bodyType = 'Todos';
      minPrice = 0;
      maxPrice = 200000;
      minKm = 0;
      maxKm = 300000;
      minCv = 0;
      maxCv = 1000;
      minYear = 1990;
      maxYear = DateTime.now().year + 1;
    });
  }

  @override
  void dispose() {
    _catalogSaveTimer?.cancel();
    if (_catalogEdited) unawaited(_catalogStorage.write(_catalogKey, {...catalogCriteria, 'sort': sortOrder}).catchError((Object _) {}));
    search.dispose(); super.dispose();
  }
  String euros(double price) => '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} €';
  String number(int value) => value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  List<String> get brands => ['Todas', ...widget.cars.map((c) => c.brand).toSet().toList()..sort()];
  List<String> get models => ['Todos', ...widget.cars.where((c) => brand == 'Todas' || c.brand == brand).map((c) => c.model).toSet().toList()..sort()];
  List<Car> get results => widget.cars.where((c) {
    final q = search.text.trim().toLowerCase();
    return matchesVehicleSearch(q, [c.brand, c.model, c.version, c.fuel, c.transmission, c.bodyType]) &&
      (brand == 'Todas' || c.brand == brand) && (model == 'Todos' || c.model == model) &&
      matchesVehicleTransmission(c.transmission, transmission) && (bodyType == 'Todos' || normalizeVehicleSearch(c.bodyType ?? '') == normalizeVehicleSearch(bodyType)) &&
      (fuel == 'Todos' || c.fuel.toLowerCase() == fuel.toLowerCase()) &&
      c.price >= minPrice && c.price <= maxPrice && c.km >= minKm && c.km <= maxKm &&
      ((minCv == 0 && maxCv == 1000) || (c.cv != null && c.cv! >= minCv && c.cv! <= maxCv)) &&
      ((minYear == 1990 && maxYear == DateTime.now().year + 1) || (c.year != 0 && c.year >= minYear && c.year <= maxYear));
  }).toList()..sort((a, b) {
    switch (sortOrder) {
      case 'recent':
        return (b.listedAt ?? DateTime(1970)).compareTo(a.listedAt ?? DateTime(1970));
      case 'price_asc':
        return a.price.compareTo(b.price);
      case 'price_desc':
        return b.price.compareTo(a.price);
      case 'year_desc':
        return b.year.compareTo(a.year);
      case 'km_asc':
        return a.km.compareTo(b.km);
      default:
        final featured = (b.isFeatured ? 1 : 0).compareTo(a.isFeatured ? 1 : 0);
        return featured != 0 ? featured : b.year.compareTo(a.year);
    }
  });

  Widget rangeField(String label, int value, int min, int max, ValueChanged<int> onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text(uiText(context, label))), Text(number(value), style: const TextStyle(color: marketAccent, fontWeight: FontWeight.bold))]),
    Slider(value: value.clamp(min, max).toDouble(), min: min.toDouble(), max: max.toDouble(), divisions: 100, activeColor: gold, onChanged: (v) => onChanged(v.round())),
  ]);
  Widget priceRange() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text(AppLocalizations.of(context).priceEuros)), Text('${euros(minPrice)} – ${euros(maxPrice)}', style: const TextStyle(color: marketAccent, fontSize: 12))]),
    RangeSlider(values: RangeValues(minPrice.clamp(0, 200000).toDouble(), maxPrice.clamp(0, 200000).toDouble()), min: 0, max: 200000, divisions: 200, activeColor: gold, onChanged: (v) => _updateCatalog(() { minPrice = v.start; maxPrice = v.end; })),
  ]);

  @override
  Widget build(BuildContext context) {
    final found = results;
    return Scaffold(
      backgroundColor: marketPaper,
      appBar: AppBar(
        backgroundColor: marketSurface,
        title: Text(AppLocalizations.of(context).viewVehicles, maxLines:1,overflow:TextOverflow.ellipsis,style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(tooltip:uiText(context,'Guardar búsqueda'),onPressed:savingSearch ? null : saveCatalogSearch,icon:const Icon(Icons.bookmark_add_outlined,color:marketAccent)),
          if (_comparisonIds.isNotEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text('${_comparisonIds.length}/3', style: const TextStyle(color: marketAccent, fontWeight: FontWeight.w700)),
            )),
          if (_comparisonIds.isNotEmpty)
            IconButton(
              tooltip: AppLocalizations.of(context).clearComparison,
              onPressed: _clearComparison,
              icon: const Icon(Icons.clear_all_rounded, color: marketAccent),
            ),
          IconButton(tooltip: AppLocalizations.of(context).resetFilters, onPressed: _resetFilters, icon: const Icon(Icons.restart_alt, color: marketAccent)),
        ],
      ),
      bottomNavigationBar: _comparisonIds.length >= 2
        ? SafeArea(child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: marketInk, padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: () {
                final selected = widget.cars.where((car) => _comparisonIds.contains(car.listingId ?? '${car.brand}-${car.model}-${car.year}-${car.km}')).toList();
                if (selected.length >= 2) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => VehicleComparisonPage(cars: selected, onOpenCar: widget.onOpenCar)));
                }
              },
              icon: const Icon(Icons.compare_arrows_rounded),
              label: Text(AppLocalizations.of(context).compareVehicles(_comparisonIds.length)),
            ),
          ))
        : null,
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: TextField(controller: search, onSubmitted: rememberVehicleSearch, onChanged: (_) => _updateCatalog(() {}), decoration: InputDecoration(hintText: AppLocalizations.of(context).searchVehicleHint, prefixIcon: const Icon(Icons.search), suffixIcon: search.text.isEmpty ? IconButton(tooltip: uiText(context, 'Búsquedas recientes'), icon: const Icon(Icons.history_rounded), onPressed: () => openVehicleSearchHistory((query) { search.text = query; FocusScope.of(context).unfocus(); _updateCatalog(() {}); })) : IconButton(tooltip:uiText(context,'Borrar búsqueda'),onPressed: () { search.clear(); _updateCatalog(() {}); }, icon: const Icon(Icons.close)), filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))))),
        if (!showFilters) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: MarketQuickFilters(
          automatic: transmission == 'Automático', suv: bodyType == 'SUV',
          electric: fuel == 'Eléctrico', budget: maxPrice == 20000,
          onAutomatic: () => _updateCatalog(() => transmission = transmission == 'Automático' ? 'Todas' : 'Automático'),
          onSuv: () => _updateCatalog(() => bodyType = bodyType == 'SUV' ? 'Todos' : 'SUV'),
          onElectric: () => _updateCatalog(() => fuel = fuel == 'Eléctrico' ? 'Todos' : 'Eléctrico'),
          onBudget: () => _updateCatalog(() { maxPrice = maxPrice == 20000 ? 200000 : 20000; if (minPrice > maxPrice) minPrice = 0; }),
        )),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12, runSpacing: 4, children: [
              Text(AppLocalizations.of(context).vehiclesFound(found.length), style: const TextStyle(color: marketMuted)),
              OutlinedButton.icon(onPressed: () {
                FocusScope.of(context).unfocus();
                _updateCatalog(() => showFilters = !showFilters);
              }, icon: const Icon(Icons.tune, color: marketAccent),
                label: Text(showFilters ? AppLocalizations.of(context).hideFilters : AppLocalizations.of(context).filters)),
            ])),
        if (!showFilters)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonFormField<String>(isExpanded: true,
            value: sortOrder,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).sortVehicles,
              prefixIcon: const Icon(Icons.sort_rounded, color: marketAccent),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(value: 'recent', child: Text(uiText(context, 'Anuncios más recientes'))),
              DropdownMenuItem(value: 'featured', child: Text(AppLocalizations.of(context).featuredFirst)),
              DropdownMenuItem(value: 'price_asc', child: Text(AppLocalizations.of(context).priceLowHigh)),
              DropdownMenuItem(value: 'price_desc', child: Text(AppLocalizations.of(context).priceHighLow)),
              DropdownMenuItem(value: 'year_desc', child: Text(AppLocalizations.of(context).newestFirst)),
              DropdownMenuItem(value: 'km_asc', child: Text(AppLocalizations.of(context).lowestMileage)),
            ],
            onChanged: (value) => _updateCatalog(() => sortOrder = value ?? 'featured'),
          ),
        ),
        if (!showFilters && (transmission != 'Todas' || bodyType != 'Todos' || brand != 'Todas' || model != 'Todos' || fuel != 'Todos' || minPrice != 0 || maxPrice != 200000 || minKm != 0 || maxKm != 300000 || minCv != 0 || maxCv != 1000 || minYear != 1990 || maxYear != DateTime.now().year + 1))
          SizedBox(height: 48, child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              if (transmission != 'Todas') Padding(padding: const EdgeInsets.only(right: 8), child: InputChip(label: Text(uiText(context, transmission)), onDeleted: () => _updateCatalog(() => transmission = 'Todas'))),
              if (bodyType != 'Todos') Padding(padding: const EdgeInsets.only(right: 8), child: InputChip(label: Text(uiText(context, bodyType)), onDeleted: () => _updateCatalog(() => bodyType = 'Todos'))),
              if (brand != 'Todas') Padding(padding: const EdgeInsets.only(right: 8), child: InputChip(label: Text(brand), onDeleted: () => _updateCatalog(() { brand = 'Todas'; model = 'Todos'; }))),
              if (model != 'Todos') Padding(padding: const EdgeInsets.only(right: 8), child: InputChip(label: Text(model), onDeleted: () => _updateCatalog(() => model = 'Todos'))),
              if (fuel != 'Todos') Padding(padding: const EdgeInsets.only(right: 8), child: InputChip(label: Text(uiText(context, fuel)), onDeleted: () => _updateCatalog(() => fuel = 'Todos'))),
              if (minPrice != 0 || maxPrice != 200000) Padding(padding: const EdgeInsets.only(right: 8), child: InputChip(label: Text('${euros(minPrice)} – ${euros(maxPrice)}'), onDeleted: () => _updateCatalog(() { minPrice = 0; maxPrice = 200000; }))),
              if (minKm != 0 || maxKm != 300000) Padding(padding: const EdgeInsets.only(right: 8), child: InputChip(label: Text('${number(minKm)} – ${number(maxKm)} km'), onDeleted: () => _updateCatalog(() { minKm = 0; maxKm = 300000; }))),
              if (minCv != 0 || maxCv != 1000) Padding(padding: const EdgeInsets.only(right: 8), child: InputChip(label: Text('$minCv – $maxCv ${uiText(context, "CV")}'), onDeleted: () => _updateCatalog(() { minCv = 0; maxCv = 1000; }))),
              if (minYear != 1990 || maxYear != DateTime.now().year + 1) InputChip(label: Text('$minYear – $maxYear'), onDeleted: () => _updateCatalog(() { minYear = 1990; maxYear = DateTime.now().year + 1; })),
            ],
          )),
        if (showFilters) Expanded(child: Column(children: [
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(children: [
          Row(children: [Expanded(child: DropdownButtonFormField<String>(isExpanded: true, value: brand, decoration: InputDecoration(labelText: AppLocalizations.of(context).brand), items: brands.map((v) => DropdownMenuItem(value:v, child:Text(v == 'Todas' || v == 'Todos' ? uiText(context, v) : v, overflow:TextOverflow.ellipsis))).toList(), onChanged: (v) => _updateCatalog(() { brand=v??'Todas'; if (!models.contains(model)) model='Todos'; }))), const SizedBox(width:10), Expanded(child: DropdownButtonFormField<String>(isExpanded: true, value: models.contains(model)?model:'Todos', decoration: InputDecoration(labelText: AppLocalizations.of(context).model), items: models.map((v)=>DropdownMenuItem(value:v,child:Text(v == 'Todas' || v == 'Todos' ? uiText(context, v) : v,overflow:TextOverflow.ellipsis))).toList(), onChanged:(v)=>_updateCatalog(()=>model=v??'Todos')))]),
          const SizedBox(height:8), DropdownButtonFormField<String>(isExpanded: true, value:fuel, decoration: InputDecoration(labelText: AppLocalizations.of(context).fuel), items: const ['Todos','Diésel','Gasolina','Híbrido','Eléctrico','GLP','GNC'].map((v)=>DropdownMenuItem(value:v,child:Text(uiText(context, v)))).toList(), onChanged:(v)=>_updateCatalog(()=>fuel=v??'Todos')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(key: ValueKey('catalog-transmission-$transmission'), isExpanded: true, initialValue: transmission,
            decoration: InputDecoration(labelText: uiText(context, 'Transmisión')),
            items: ['Todas', 'Manual', 'Automático', 'Automático (DSG)'].map((value) => DropdownMenuItem(value: value, child: Text(uiText(context, value)))).toList(),
            onChanged: (value) => _updateCatalog(() => transmission = value ?? 'Todas')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(key: ValueKey('catalog-body-$bodyType'), isExpanded: true, initialValue: bodyType,
            decoration: InputDecoration(labelText: uiText(context, 'Carrocería')),
            items: {'Todos', 'SUV', ...widget.cars.map((car) => car.bodyType).whereType<String>().where((value) => value.trim().isNotEmpty)}.map((value) => DropdownMenuItem(value: value, child: Text(uiText(context, value)))).toList(),
            onChanged: (value) => _updateCatalog(() => bodyType = value ?? 'Todos')),
          const SizedBox(height:8), priceRange(),
          rangeField(AppLocalizations.of(context).minMileage, minKm, 0, 300000, (v)=>_updateCatalog(() { minKm=v; if (maxKm < minKm) maxKm=minKm; })),
          rangeField(AppLocalizations.of(context).maxMileage, maxKm, 0, 300000, (v)=>_updateCatalog(() { maxKm=v; if (minKm > maxKm) minKm=maxKm; })),
          rangeField(AppLocalizations.of(context).minPower, minCv, 0, 1000, (v)=>_updateCatalog(() { minCv=v; if (maxCv < minCv) maxCv=minCv; })),
          rangeField(AppLocalizations.of(context).maxPower, maxCv, 0, 1000, (v)=>_updateCatalog(() { maxCv=v; if (minCv > maxCv) minCv=maxCv; })),
          rangeField(AppLocalizations.of(context).minYear, minYear, 1990, DateTime.now().year+1, (v)=>_updateCatalog(() { minYear=v; if (maxYear < minYear) maxYear=minYear; })),
          rangeField(AppLocalizations.of(context).maxYear, maxYear, 1990, DateTime.now().year+1, (v)=>_updateCatalog(() { maxYear=v; if (minYear > maxYear) minYear=maxYear; })),
            ]),
          )),
          SafeArea(top: false, child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(width: double.infinity, child: FilledButton(
              key: const Key('apply-catalog-filters'),
              onPressed: () => _updateCatalog(() => showFilters = false),
              child: Text('${AppLocalizations.of(context).viewResults} · ${found.length}'),
            )),
          )),
        ])),
        if (!showFilters)
        Expanded(child: found.isEmpty ? Center(
          child: SingleChildScrollView(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.search_off_rounded, color: marketAccent, size: 48),
              const SizedBox(height: 12),
              Text(AppLocalizations.of(context).noVehiclesFound, textAlign: TextAlign.center, style: const TextStyle(color: marketMuted)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.restart_alt),
                label: Text(AppLocalizations.of(context).resetFilters),
                style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: marketInk),
              ),
            ]),
          ),
        )) : LayoutBuilder(builder:(context, constraints) {
          final columns = constraints.maxWidth >= 1100 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: found.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              mainAxisExtent: ((constraints.maxWidth-28-(columns-1)*14)/columns)*.75+185*MediaQuery.textScalerOf(context).scale(1),
            ),
            itemBuilder: (context, index) {
              final car = found[index];
              final compareId = car.listingId ?? '${car.brand}-${car.model}-${car.year}-${car.km}';
              final isCompared = _comparisonIds.contains(compareId);
              return MarketVehicleCard(
                title: '${car.brand} ${car.model}', price: euros(car.price),
                details: '${car.year} · ${number(car.km)} km · ${uiText(context, car.fuel)}',
                version: car.version, photoCount: car.photoCount, photo: car.photos.isEmpty ? null : car.photos.first,
                favorite: SaveVehicleButton(car: car),
                comparison: Material(color: marketSurface, borderRadius: BorderRadius.circular(12),
                  child: IconButton(
                    tooltip: AppLocalizations.of(context).compare,
                    onPressed: () => _toggleCompare(car),
                    icon: Icon(isCompared ? Icons.check_box_rounded : Icons.add_box_outlined,
                      color: isCompared ? marketAccent : marketInk))),
                status: car.status == 'reserved' || car.status == 'sold' ? _VehicleStatusBadge(status: car.status) : null,
                onTap: () => widget.onOpenCar(car),
              );

            },
          );
        })),
      ]),
    );
  }
}

class VehicleSearchAlertsPage extends StatefulWidget {
  final ValueChanged<Car> onOpenCar;
  const VehicleSearchAlertsPage({super.key, required this.onOpenCar});
  @override
  State<VehicleSearchAlertsPage> createState() =>
      _VehicleSearchAlertsPageState();
}

class _VehicleSearchAlertsPageState extends State<VehicleSearchAlertsPage> {
  String alertFilter = 'all';
  List<Map<String, dynamic>> get visibleAlerts => alerts.where((alert) => alertFilter == 'all' || (alertFilter == 'unread' ? alert['read_at'] == null : alert['alert_type'] == alertFilter)).toList();
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> alerts = [];
  @override
  void initState() {
    super.initState();
    loadAlerts();
  }

  Future<void> loadAlerts() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          loading = false;
          error = 'Inicia sesión para consultar tus alertas.';
        });
        return;
      }
      final rows = await Supabase.instance.client
          .from('vehicle_search_alerts')
          .select(
            'id, search_id, listing_id, alert_type, title, message, created_at, read_at, previous_price, current_price',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() {
        alerts = List<Map<String, dynamic>>.from(rows);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'No se pudieron cargar las alertas. Comprueba la conexión e inténtalo de nuevo.';
      });
    }
  }

  Future<void> markRead(Map<String, dynamic> alert) async {
    if (alert['read_at'] != null) return;
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await Supabase.instance.client
          .from('vehicle_search_alerts')
          .update({'read_at': now})
          .eq('id', alert['id']);
      if (!mounted) return;
      setState(() => alert['read_at'] = now);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(context, "No se pudo marcar la alerta como leída."),
          ),
        ),
      );
    }
  }

  Future<void> openAlert(Map<String, dynamic> alert) async {
    await markRead(alert);
    if (!mounted) return;
    if (alert['alert_type'] != 'review_requested') {
      try {
        final raw = await Supabase.instance.client
            .from('vehicle_listings')
            .select(buyerListingProjection)
            .eq('id', alert['listing_id'])
            .maybeSingle();
        if (raw == null) throw StateError('unavailable');
        final car = await buyerCarFromListing(raw);
        if (mounted) widget.onOpenCar(car);
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                uiText(context, 'Este aviso ya no está disponible.'),
              ),
            ),
          );
      }
      return;
    }
    final listingId = alert['listing_id']?.toString();
    if (listingId == null || listingId.isEmpty) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BuyerPurchaseReviewPage(listingId: listingId),
      ),
    );
    if (mounted) await loadAlerts();
  }

  @override
  Widget build(BuildContext context) {
    final unread = alerts.where((a) => a['read_at'] == null).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, "Notificaciones")),
        actions: [
          IconButton(
            tooltip: uiText(context, "Actualizar"),
            onPressed: loadAlerts,
            icon: const Icon(Icons.refresh_rounded, color: marketAccent),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: marketAccent))
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.notifications_off_outlined,
                      color: marketAccent,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(uiText(context, error!), textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: loadAlerts,
                      child: Text(uiText(context, "Reintentar")),
                    ),
                  ],
                ),
              ),
            )
          : alerts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      size: 54,
                      color: marketAccent,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      uiText(context, "Todavía no tienes alertas"),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      uiText(
                        context,
                        "Aquí verás las invitaciones para valorar tus compras y las alertas de tus búsquedas guardadas.",
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: marketMuted),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  uiText(context, "{0} sin leer · {1} alertas", [
                    unread,
                    alerts.length,
                  ]),
                  style: const TextStyle(
                    color: marketAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  for (final entry in {'all':'Todas', 'unread':'Sin leer', 'price_drop':'Bajadas de precio', 'new_listing':'Anuncios nuevos', 'review_requested':'Valorar compra'}.entries)
                    ChoiceChip(label: Text(uiText(context, entry.value)), selected: alertFilter == entry.key,
                      onSelected: (_) => setState(() => alertFilter = entry.key)),
                ]),
                if (visibleAlerts.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(uiText(context, 'No hay alertas de este tipo.'))),
                for (final alert in visibleAlerts)
                  Card(
                    color: alert['read_at'] == null
                        ? marketSurface
                        : marketSurface,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(
                        alert['alert_type'] == 'review_requested'
                            ? Icons.rate_review_outlined
                            : alert['alert_type'] == 'price_drop'
                            ? Icons.trending_down_rounded
                            : Icons.directions_car_filled_rounded,
                        color: alert['read_at'] == null ? gold : marketMuted,
                      ),
                      title: Text(
                        alert['title']?.toString() ?? uiText(context, 'Alerta'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(alert['message']?.toString() ?? ''),
                            if (alert['previous_price'] is num &&
                                alert['current_price'] is num)
                              Text(
                                '${watchPrice(alert['previous_price'] as num)} → ${watchPrice(alert['current_price'] as num)}',
                                style: const TextStyle(
                                  color: marketAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      trailing: alert['read_at'] == null
                          ? IconButton(
                              tooltip: uiText(context, "Marcar como leída"),
                              onPressed: () => markRead(alert),
                              icon: const Icon(
                                Icons.mark_email_read_outlined,
                                color: marketAccent,
                              ),
                            )
                          : const Icon(
                              Icons.check_circle_outline,
                              color: marketMuted,
                            ),
                      onTap: () => openAlert(alert),
                    ),
                  ),
              ],
            ),
    );
  }
}

class SavedSearchesPage extends StatefulWidget {
  final void Function(Map<String, dynamic>) onApply;
  const SavedSearchesPage({super.key, required this.onApply});

  @override
  State<SavedSearchesPage> createState() => _SavedSearchesPageState();
}

class _SavedSearchesPageState extends State<SavedSearchesPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> searches = [];

  @override
  void initState() {
    super.initState();
    loadSearches();
  }

  Future<void> loadSearches() async {
    setState(() { loading = true; error = null; });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() { loading = false; error = 'Inicia sesión para consultar tus búsquedas guardadas.'; });
        return;
      }
      final rows = await Supabase.instance.client
          .from('saved_vehicle_searches')
          .select('id, name, criteria, notify_new_listings, notify_price_drops, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        searches = List<Map<String, dynamic>>.from(rows);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; error = 'No se pudieron cargar tus búsquedas. Comprueba la conexión e inténtalo de nuevo.'; });
    }
  }

  Future<void> deleteSearch(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:  Text(uiText(context, "Eliminar búsqueda")),
        content: Text(uiText(context, "¿Quieres eliminar «{0}»?", [item['name']])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child:  Text(uiText(context, "Cancelar"))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child:  Text(uiText(context, "Eliminar"))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await Supabase.instance.client.from('saved_vehicle_searches').delete().eq('id', item['id']);
      if (!mounted) return;
      setState(() => searches.removeWhere((s) => s['id'] == item['id']));
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(uiText(context, "Búsqueda eliminada."))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(uiText(context, "No se pudo eliminar la búsqueda."))));
    }
  }

  final updatingSearches=<String>{};
  Future<void> updatePreference(Map<String,dynamic> item,String key,bool value) async {
    final db=Supabase.instance.client;final uid=db.auth.currentUser?.id;
    final id=item['id'].toString();if(uid==null || updatingSearches.contains(id))return;
    setState(()=>updatingSearches.add(id));
    try{
      final row=await db.from('saved_vehicle_searches').update({key:value}).eq('id',id).eq('user_id',uid).select('notify_new_listings,notify_price_drops').single();
      if(mounted && db.auth.currentUser?.id==uid)setState(()=>item.addAll(row));
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(uiText(context,'No se pudo guardar la preferencia. Inténtalo de nuevo.'))));}
    finally{if(mounted)setState(()=>updatingSearches.remove(id));}
  }

  String criteriaSummary(Map<String, dynamic> criteria) {
    final parts = <String>[];
    for (final key in ['brand', 'model', 'fuel', 'transmission', 'body_type']) {
      final value = criteria[key]?.toString();
      if (value != null && value.isNotEmpty &&
          !(key == 'brand' && value == 'Todas') &&
          !['Todos', 'Todas'].contains(value)) {
        parts.add(value);
      }
    }
    for (final entry in [
      ['min_price', 'Precio desde'], ['max_price', 'Precio hasta'],
      ['min_year', 'Año desde'], ['max_km', 'Km hasta'],
      ['min_cv', 'CV desde'], ['max_cv', 'CV hasta'],
    ]) {
      final value = criteria[entry[0]];
      if (value != null && value.toString().isNotEmpty) parts.add('${entry[1]}: $value');
    }
    final query = criteria['query']?.toString();
    if (query != null && query.isNotEmpty) parts.add('Texto: $query');
    return parts.isEmpty ? 'Sin filtros específicos' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:  Text(uiText(context, "Búsquedas guardadas")), actions: [
        IconButton(tooltip: uiText(context, "Actualizar"), onPressed: loadSearches, icon: const Icon(Icons.refresh_rounded, color: marketAccent)),
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: marketAccent))
          : error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_outline_rounded, color: marketAccent, size: 38),
                    const SizedBox(height: 12),
                    Text(uiText(context, error!), textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    FilledButton(onPressed: loadSearches, child:  Text(uiText(context, "Reintentar"))),
                  ]),
                ))
              : searches.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.bookmark_border_rounded, size: 52, color: marketAccent),
                        const SizedBox(height: 14),
                         Text(uiText(context, "Todavía no tienes búsquedas guardadas"), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                         Text(uiText(context, "Abre los filtros del buscador y pulsa «Guardar búsqueda» para tenerlos aquí."), textAlign: TextAlign.center),
                      ]),
                    ))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: searches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = searches[index];
                        final rawCriteria = item['criteria'];
                        final criteria = rawCriteria is Map ? Map<String, dynamic>.from(rawCriteria) : <String, dynamic>{};
                        return Container(
                          decoration: BoxDecoration(
                            color: marketSurface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: marketAccent.withValues(alpha: .35)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Icon(Icons.bookmark_rounded, color: marketAccent),
                                const SizedBox(width: 10),
                                Expanded(child: Text(item['name']?.toString() ?? uiText(context, 'Búsqueda guardada'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                                IconButton(tooltip: uiText(context, "Eliminar búsqueda"), onPressed: () => deleteSearch(item), icon: const Icon(Icons.delete_outline_rounded)),
                              ]),
                              const SizedBox(height: 6),
                              Text(criteriaSummary(criteria), style: TextStyle(color: marketInk.withValues(alpha: .72), height: 1.4)),
                              MarketAlertPreferences(newListings:item['notify_new_listings']==true,priceDrops:item['notify_price_drops']==true,busy:updatingSearches.contains(item['id'].toString()),onNewListings:(v)=>updatePreference(item,'notify_new_listings',v),onPriceDrops:(v)=>updatePreference(item,'notify_price_drops',v)),
                              Text(uiText(context,'Avisos en el buzón de la app'),style:const TextStyle(color:marketMuted,fontSize:12)),
                              const SizedBox(height: 12),
                              SizedBox(width: double.infinity, child: FilledButton.icon(
                                onPressed: () {
                                  widget.onApply(criteria);
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.filter_alt_rounded),
                                label:  Text(uiText(context, "Aplicar filtros")),
                              )),
                            ]),
                          ),
                        );
                      },
                    ),
    );
  }
}

class SaveVehicleButton extends StatefulWidget {
  final Car car;
  const SaveVehicleButton({super.key, required this.car});

  @override
  State<SaveVehicleButton> createState() => _SaveVehicleButtonState();
}

class _SaveVehicleButtonState extends State<SaveVehicleButton> {
  bool isSaved = false;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SaveVehicleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.car.listingId != widget.car.listingId) {
      isSaved = false;
      _load();
    }
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    final id = widget.car.listingId;
    if (user == null || id == null || id.isEmpty) {
      if (mounted) setState(() => isSaved = false);
      return;
    }
    try {
      final row = await Supabase.instance.client.from('saved_vehicles')
          .select('listing_id').eq('user_id', user.id).eq('listing_id', id).maybeSingle();
      if (mounted && widget.car.listingId == id) {
        setState(() => isSaved = row != null);
      }
    } catch (_) {
      // El anuncio sigue disponible aunque no se pueda consultar el estado del favorito.
    }
  }

  Future<void> _toggle() async {
    if (loading) return;
    var user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final loggedIn = await requireAutomotorsLogin(context);
      if (!loggedIn || !mounted) return;
      user = Supabase.instance.client.auth.currentUser;
    }
    final id = widget.car.listingId;
    if (user == null || id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(uiText(context, "Este anuncio no se puede guardar ahora mismo."))));
      return;
    }
    setState(() => loading = true);
    try {
      final db = Supabase.instance.client;
      if (isSaved) {
        await db.from('saved_vehicles').delete().eq('user_id', user.id).eq('listing_id', id);
      } else {
        await db.from('saved_vehicles').insert({'user_id': user.id, 'listing_id': id});
      }
      if (!mounted) return;
      setState(() => isSaved = !isSaved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isSaved ? uiText(context, "Vehículo guardado en favoritos.") : uiText(context, "Vehículo eliminado de favoritos.")),
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(
        content: Text(uiText(context, "No se pudo guardar el anuncio. Inténtalo de nuevo.")),
      ));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: marketSurface,
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: isSaved ? uiText(context, "Quitar de favoritos") : uiText(context, "Guardar en favoritos"),
      onPressed: loading ? null : _toggle,
      icon: loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: marketAccent))
          : AnimatedSwitcher(duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
              child: Icon(isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded, key: ValueKey(isSaved), color: isSaved ? Colors.redAccent : marketInk)),
    ),
  );
}

class SaveListingIdButton extends StatefulWidget {
  final String? listingId;
  const SaveListingIdButton({super.key, required this.listingId});

  @override
  State<SaveListingIdButton> createState() => _SaveListingIdButtonState();
}

class _SaveListingIdButtonState extends State<SaveListingIdButton> {
  bool isSaved = false;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SaveListingIdButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listingId != widget.listingId) {
      isSaved = false;
      _load();
    }
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    final id = widget.listingId;
    if (user == null || id == null || id.isEmpty) {
      if (mounted) setState(() => isSaved = false);
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('saved_vehicles')
          .select('listing_id')
          .eq('user_id', user.id)
          .eq('listing_id', id)
          .maybeSingle();
      if (mounted && widget.listingId == id) {
        setState(() => isSaved = row != null);
      }
    } catch (_) {
      // El perfil sigue funcionando si favoritos no está disponible.
    }
  }

  Future<void> _toggle() async {
    if (loading) return;
    var user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final loggedIn = await requireAutomotorsLogin(context);
      if (!loggedIn || !mounted) return;
      user = Supabase.instance.client.auth.currentUser;
    }
    final id = widget.listingId;
    if (user == null || id == null || id.isEmpty) return;
    setState(() => loading = true);
    try {
      final db = Supabase.instance.client;
      if (isSaved) {
        await db.from('saved_vehicles')
            .delete().eq('user_id', user.id).eq('listing_id', id);
      } else {
        await db.from('saved_vehicles').insert({
          'user_id': user.id,
          'listing_id': id,
        });
      }
      if (!mounted) return;
      setState(() => isSaved = !isSaved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isSaved
            ? uiText(context, "Vehículo guardado en favoritos.")
            : uiText(context, "Vehículo eliminado de favoritos.")),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(
          content: Text(uiText(context, "No se pudo actualizar favoritos. Inténtalo de nuevo.")),
        ));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: marketSurface,
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: isSaved ? uiText(context, "Quitar de favoritos") : uiText(context, "Guardar en favoritos"),
      visualDensity: VisualDensity.compact,
      onPressed: loading ? null : _toggle,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: marketAccent),
            )
          : Icon(
              isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isSaved ? Colors.redAccent : marketInk,
              size: 21,
            ),
    ),
  );
}

Future<Car> buyerCarFromListing(Map<String, dynamic> raw) async {
  final photoRows = raw['vehicle_photos'] is List
      ? List<Map<String, dynamic>>.from(raw['vehicle_photos'])
      : <Map<String, dynamic>>[];
  photoRows.sort(
    (a, b) => ((a['position'] as num?)?.toInt() ?? 0).compareTo(
      (b['position'] as num?)?.toInt() ?? 0,
    ),
  );
  final paths = photoRows
      .map((p) => p['storage_path']?.toString() ?? '')
      .where((p) => p.isNotEmpty)
      .toList();
  final photos = await loadListingCover(
    paths,
    downloadVehiclePhoto,
  );
  return Car.fromListing(raw, photos: photos, photoPaths: paths);
}

class SavedVehiclesPage extends StatefulWidget {
  final List<Car> cars;
  final void Function(Car) onOpenCar;

  const SavedVehiclesPage({
    super.key,
    required this.cars,
    required this.onOpenCar,
  });

  @override
  State<SavedVehiclesPage> createState() => _SavedVehiclesPageState();
}

class _SavedVehiclesPageState extends State<SavedVehiclesPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> favorites = [];
  Map<String, Car> cars = {};
  final busy = <String>{};
  String favoriteSort = 'recent';
  final selectedFavorites = <String>{};
  List<Map<String, dynamic>> get orderedFavorites {
    final rows = List<Map<String, dynamic>>.from(favorites);
    if (favoriteSort == 'drops') {
      return rows.where((row) {
        final car = cars[row['listing_id'].toString()];
        final reference = row['reference_price'];
        return car != null && ['published','reserved'].contains(car.status) && reference is num && car.price > 0 && car.price < reference;
      }).toList();
    }
    if (favoriteSort == 'recent') return rows;
    final positions = {
      for (var i = 0; i < favorites.length; i++)
        favorites[i]['listing_id'].toString(): i,
    };
    rows.sort((a, b) {
      final aId = a['listing_id'].toString(), bId = b['listing_id'].toString();
      final ca = cars[aId], cb = cars[bId];
      final aMissing =
          ca == null ||
          (favoriteSort == 'price_asc' ? ca.price <= 0 : ca.year <= 0);
      final bMissing =
          cb == null ||
          (favoriteSort == 'price_asc' ? cb.price <= 0 : cb.year <= 0);
      if (aMissing != bMissing) return aMissing ? 1 : -1;
      final difference = aMissing
          ? 0
          : favoriteSort == 'price_asc'
          ? ca.price.compareTo(cb!.price)
          : cb!.year.compareTo(ca.year);
      return difference != 0
          ? difference
          : positions[aId]!.compareTo(positions[bId]!);
    });
    return rows;
  }

  void toggleFavoriteComparison(String id) {
    setState(() {
      if (selectedFavorites.contains(id)) {
        selectedFavorites.remove(id);
      } else if (selectedFavorites.length < 3) {
        selectedFavorites.add(id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).comparisonLimit)),
        );
      }
    });
  }
  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final db = Supabase.instance.client;
      final uid = db.auth.currentUser?.id;
      if (uid == null) throw StateError('login');
      final rows = await db
          .from('saved_vehicles')
          .select('listing_id,reference_price,notify_price_drops')
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      final records = List<Map<String, dynamic>>.from(rows);
      final ids = records.map((f) => f['listing_id'].toString()).toList();
      final listings = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await db
                  .from('vehicle_listings')
                  .select(buyerListingProjection)
                  .inFilter('id', ids),
            );
      final fresh = await Future.wait(listings.map(buyerCarFromListing));
      if (!mounted || db.auth.currentUser?.id != uid) return;
      setState(() {
        favorites = records;
        cars = {for (final car in fresh) car.listingId!: car};
        selectedFavorites.removeWhere((id)=>!cars.containsKey(id) || !['published','reserved'].contains(cars[id]!.status));
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error =
              'No se pudieron cargar los favoritos. Desliza para reintentar.';
        });
      }
    }
  }

  Future<void> changeFavorite(
    Map<String, dynamic> item, {
    bool? watch,
    bool remove = false,
  }) async {
    final id = item['listing_id'].toString();
    if (busy.contains(id)) return;
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => busy.add(id));
    try {
      if (remove) {
        await db
            .from('saved_vehicles')
            .delete()
            .eq('user_id', uid)
            .eq('listing_id', id);
      } else {
        final updated = await db
            .from('saved_vehicles')
            .update({'notify_price_drops': watch})
            .eq('user_id', uid)
            .eq('listing_id', id)
            .select('reference_price,notify_price_drops')
            .single();
        item.addAll(updated);
      }
      if (mounted && db.auth.currentUser?.id == uid) {
        setState(() {
          if (remove) {favorites.remove(item);selectedFavorites.remove(id);}
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                'No se pudo actualizar favoritos. Inténtalo de nuevo.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(uiText(context, 'Mis favoritos')),
      actions: [
        IconButton(
          tooltip: uiText(context, 'Actualizar'),
          onPressed: loadFavorites,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    bottomNavigationBar:selectedFavorites.length<2 ? null : SafeArea(child:Padding(padding:const EdgeInsets.all(12),child:FilledButton.icon(
      onPressed:()=>Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>VehicleComparisonPage(cars:selectedFavorites.map((id)=>cars[id]!).toList(),onOpenCar:widget.onOpenCar))),
      icon:const Icon(Icons.compare_arrows_rounded),label:Text(AppLocalizations.of(context).compareVehicles(selectedFavorites.length)),
    ))),
    body: RefreshIndicator(
      onRefresh: loadFavorites,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(padding:const EdgeInsets.only(bottom:20,top:8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(uiText(context,'TU SELECCIÓN'),style:const TextStyle(color:marketAccent,fontSize:11,letterSpacing:1.6,fontWeight:FontWeight.w600)),
            const SizedBox(height:8),Text(uiText(context,'Los que te gustan.'),style:Theme.of(context).textTheme.headlineMedium),
          ])),
          if(!loading && error==null && favorites.isNotEmpty) ...[
            DropdownButtonFormField<String>(key:const Key('favorite-sort'),initialValue:favoriteSort,isExpanded:true,decoration:InputDecoration(labelText:uiText(context,'Ordenar favoritos')),
              items:[DropdownMenuItem(value:'drops',child:Text(uiText(context,'Solo bajadas de precio'))),DropdownMenuItem(value:'recent',child:Text(uiText(context,'Guardados más recientes'))),DropdownMenuItem(value:'price_asc',child:Text(AppLocalizations.of(context).priceLowHigh)),DropdownMenuItem(value:'year_desc',child:Text(AppLocalizations.of(context).newestFirst))],
              onChanged:(value)=>setState(()=>favoriteSort=value??'recent')),
            const SizedBox(height:12),
          ],

          if (loading)
            const Padding(
              padding: EdgeInsets.all(60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(uiText(context, error!), textAlign: TextAlign.center),
            )
          else if (favorites.isEmpty)
            MarketEmptyState(icon:Icons.favorite_border_rounded,title:'Aún no tienes coches favoritos.',message:'Guarda los coches que te gustan y compáralos aquí.',actionLabel:'Explorar vehículos',onAction:()=>Navigator.pop(context))
          else if (orderedFavorites.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(uiText(context, 'Tus favoritos todavía no han bajado de precio.')))
          else
            ...orderedFavorites.map((item) {
              final id = item['listing_id'].toString();
              final car = cars[id];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MarketFavoriteCard(
                  title: car == null
                      ? uiText(context, 'Anuncio no disponible')
                      : '${car.brand} ${car.model}',
                  details: car == null
                      ? ''
                      : '${car.year} · ${car.km} km · ${uiText(context, car.fuel)}',
                  price: car?.price ?? 0,
                  referencePrice: item['reference_price'] as num?,
                  photo: car?.photos.firstOrNull,
                  comparing:selectedFavorites.contains(id),
                  onCompare:car!=null && ['published','reserved'].contains(car.status) ? ()=>toggleFavoriteComparison(id) : null,
                  watching: item['notify_price_drops'] == true,
                  busy: busy.contains(id),
                  available:
                      car != null &&
                      ['published', 'reserved'].contains(car.status),
                  onOpen: () {
                    if (car != null) widget.onOpenCar(car);
                  },
                  onRemove: () => changeFavorite(item, remove: true),
                  onWatch: (value) => changeFavorite(item, watch: value),
                ),
              );
            }),
        ],
      ),
    ),
  );
}

class CarDetailsPage extends StatefulWidget {
  final Car car;
  final String priceText;
  final VoidCallback onContact;
  final ListingPhotoDownload? downloadPhoto;

  const CarDetailsPage({
    super.key,
    required this.car,
    required this.priceText,
    required this.onContact,
    this.downloadPhoto,
  });

  @override
  State<CarDetailsPage> createState() => _CarDetailsPageState();
}

class _CarDetailsPageState extends State<CarDetailsPage> {
  Car get car => widget.car;
  String get priceText => widget.priceText;
  VoidCallback get onContact => widget.onContact;
  bool isFavorite = false;
  bool favoriteLoading = false;
  bool reporting = false;
  int currentPhotoIndex = 0;
  late List<Uint8List> detailPhotos;
  late final Future<void> galleryReady;
  late final Future<Map<String, dynamic>?> sellerProfile;
  late Future<int?> listingFavoriteCount;
  late final PageController _photoController = PageController();

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_recordListingView());
    detailPhotos = List.of(car.photos);
    galleryReady = _loadGallery();
    sellerProfile = _loadPublicSeller();
    listingFavoriteCount = _loadListingFavoriteCount();
    _loadFavorite();
  }

  Future<void> _recordListingView() async {
    final db=Supabase.instance.client;
    final user=db.auth.currentUser;
    final id=car.listingId;
    if(user==null||id==null||car.ownerId==user.id)return;
    try {await db.from('listing_view_days').upsert({'listing_id':id,'viewer_id':user.id},onConflict:'listing_id,viewer_id,viewed_on',ignoreDuplicates:true);}catch(_){}
  }

  Future<int?> _loadListingFavoriteCount() async {
    if(car.listingId==null)return null;
    try {
      final value=await Supabase.instance.client.rpc('listing_favorite_count',params:{'p_listing_id':car.listingId});
      return value is num && value>=0 ? value.toInt() : null;
    } catch (_) {return null;}
  }

  Future<Map<String, dynamic>?> _loadPublicSeller() async {
    if (car.ownerId == null) return null;
    try {
      return await Supabase.instance.client.from('public_seller_profiles')
        .select('full_name,business_name,city,profile_photo_path').eq('id', car.ownerId!).maybeSingle();
    } catch (_) {
      return null; // Keep the existing profile action available on network failure.
    }
  }

  Future<void> _openSeller() async {
    if (car.ownerId == null) return;
    final loggedIn = await requireAutomotorsLogin(context);
    if (!loggedIn || !mounted) return;
    await Navigator.push<void>(context, MaterialPageRoute(
      builder: (_) => PublicSellerProfilePage(ownerId: car.ownerId!)));
  }

  Future<void> _loadGallery() async {
    if (car.photoPaths.isEmpty) return;
    final loaded = await loadListingGallery(car.photoPaths, car.photos,
      widget.downloadPhoto ?? downloadVehiclePhoto, onProgress:(loaded){if(mounted)setState(()=>detailPhotos=loaded);});
    if (mounted) setState(() => detailPhotos = loaded);
  }

  Future<void> _loadFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    final id = car.listingId;
    if (user == null || id == null || id.isEmpty) return;
    try {
      final row = await Supabase.instance.client
          .from('saved_vehicles')
          .select('listing_id')
          .eq('user_id', user.id)
          .eq('listing_id', id)
          .maybeSingle();
      if (mounted) setState(() => isFavorite = row != null);
    } catch (_) {
      // La ficha sigue disponible aunque no se pueda consultar favoritos.
    }
  }

  Future<void> _toggleFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final loggedIn = await requireAutomotorsLogin(context);
      if (!loggedIn || !mounted) return;
    }
    final currentUser = Supabase.instance.client.auth.currentUser;
    final id = car.listingId;
    if (currentUser == null || id == null || id.isEmpty || favoriteLoading) return;
    setState(() => favoriteLoading = true);
    try {
      final db = Supabase.instance.client;
      if (isFavorite) {
        await db.from('saved_vehicles').delete()
            .eq('user_id', currentUser.id).eq('listing_id', id);
      } else {
        await db.from('saved_vehicles').insert({
          'user_id': currentUser.id,
          'listing_id': id,
        });
      }
      if (mounted) {
        setState(() {isFavorite = !isFavorite; listingFavoriteCount=_loadListingFavoriteCount();});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isFavorite ? uiText(context, "Vehículo guardado en favoritos.") : uiText(context, "Vehículo eliminado de favoritos.")),
        ));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "No se pudo actualizar favoritos. Inténtalo de nuevo."))),
      );
    } finally {
      if (mounted) setState(() => favoriteLoading = false);
    }
  }

  Future<void> _reportListing() async {
    if (reporting) return;
    setState(() => reporting = true);
    try { await _showListingReport(); }
    finally { if (mounted) setState(() => reporting = false); }
  }

  Future<void> _showListingReport() async {
    final listingId = car.listingId;
    if (listingId == null || listingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "Este anuncio no se puede reportar desde esta ficha."))),
      );
      return;
    }
    final reasons = <String>[
      'Información falsa',
      'Precio sospechoso',
      'Anuncio duplicado',
      'Posible fraude',
      'Contenido inapropiado',
      'Otro',
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: Text(uiText(context, "Denunciar anuncio")),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Align(
              alignment: Alignment.centerLeft,
              child: Text(uiText(context, "¿Qué problema has detectado?")),
            ),
            const SizedBox(height: 10),
            ...reasons.map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined, color: marketAccent),
              title: Text(uiText(context, item)),
              onTap: () => Navigator.pop(dialogContext, item),
            )),
          ],
        ),
        actions: [
          IconButton(tooltip:uiText(context,'Consejos para una compraventa segura'),icon:const Icon(Icons.shield_outlined),onPressed:()=>showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(_)=>const SafeArea(child:SingleChildScrollView(child:MarketSafetyAdvice())))),TextButton(onPressed: () => Navigator.pop(dialogContext),
          child: Text(uiText(context, "Cancelar")))],
      ),
    );
    if (reason == null || !mounted) return;
    final loggedIn = await requireAutomotorsLogin(context);
    if (!loggedIn || !mounted) return;


    // Optional context helps the review team understand the report.
    final detailsController = TextEditingController();
    final detailsRoute = DialogRoute<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title:  Text(uiText(context, "Añadir detalles (opcional)")),
        content: TextField(
          controller: detailsController,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration:  InputDecoration(
            hintText: uiText(context, "Describe brevemente qué has observado…"),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(uiText(context, "Cancelar")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              detailsController.text.trim(),
            ),
            child:  Text(uiText(context, "Enviar reporte")),
          ),
        ],
      ),
    );
    final details = await Navigator.of(context, rootNavigator: true).push(detailsRoute);
    await detailsRoute.completed;
    detailsController.dispose();
    if (details == null || !mounted) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('vehicle_listing_reports').insert({
        'reporter_id': user.id,
        'listing_id': listingId,
        'reason': reason,
        'details': details,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(uiText(context, "Gracias. Hemos recibido tu reporte para revisión."))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(uiText(context, "No se pudo enviar. Es posible que ya hayas reportado este anuncio."))),
        );
      }
    }
  }

  Future<void> _shareListing(BuildContext context) async {
    final listingId = car.listingId;
    final hasListingId = listingId != null && listingId.isNotEmpty;
    final shareUri = listingShareUri(listingId);
    final title = '${car.brand} ${car.model}';
    final summary = <String>[
      title,
      if (car.version?.trim().isNotEmpty == true) car.version!.trim(),
      'Precio: $priceText',
      if (car.year > 0) 'Año: ${car.year}',
      'Kilómetros: ${_formatKm(car.km)} km',
      '',
      if (hasListingId)
        'Ver ficha completa en AUTOMOTORS: $shareUri'
      else
        'Encuentra más información en AUTOMOTORS: $shareUri',
    ].join('\n');

    // Mostrar siempre las opciones explícitas en web. No copiar automáticamente
    // si el anuncio no trae ID; en ese caso avisamos que el enlace no puede abrir
    // la ficha exacta hasta que el anuncio tenga un identificador.
    if (kIsWeb) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title:  Text(uiText(context, "Compartir anuncio")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!hasListingId)
                 Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    uiText(context, "Este anuncio no tiene identificador para crear un enlace directo a su ficha. Puedes compartir los datos, pero el enlace no abrirá este coche directamente."),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.chat_rounded),
                title:  Text(uiText(context, "WhatsApp")),
                onTap: () async {
                  final uri = Uri.parse(
                    'https://wa.me/?text=${Uri.encodeComponent(summary)}',
                  );
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.send_rounded),
                title:  Text(uiText(context, "Telegram")),
                onTap: () async {
                  final uri = Uri.parse(
                    'https://t.me/share/url?url=${Uri.encodeComponent(shareUri.toString())}&text=${Uri.encodeComponent(title)}',
                  );
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title:  Text(uiText(context, "Correo electrónico")),
                onTap: () async {
                  final uri = Uri(
                    scheme: 'mailto',
                    queryParameters: <String, String>{
                      'subject': 'Anuncio AUTOMOTORS: $title',
                      'body': summary,
                    },
                  );
                  await launchUrl(uri);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title:  Text(uiText(context, "Copiar enlace y datos")),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: summary));
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          hasListingId
                              ? uiText(context, "Enlace y datos del anuncio copiados.")
                              : uiText(context, "Datos copiados. Este anuncio aún no tiene enlace directo."),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child:  Text(uiText(context, "Cancelar")),
            ),
          ],
        ),
      );
      return;
    }

    if (!hasListingId) {
      await _copyListingSummary(context);
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(title: title, text: summary, uri: shareUri),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: summary));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(uiText(context, "Enlace del anuncio copiado. Ya puedes pegarlo para compartir la ficha."))),
        );
      }
    }
  }

  Future<void> _copyListingSummary(BuildContext context) async {
    final details = <String>[
      '${car.brand} ${car.model}',
      if (car.version?.trim().isNotEmpty == true) 'Versión: ${car.version}',
      'Precio: $priceText',
      if (car.year > 0) 'Año: ${car.year}',
      'Kilómetros: ${_formatKm(car.km)} km',
      if (car.cv != null) 'Potencia: ${car.cv} CV',
      if (car.cilindradaCc != null) 'Cilindrada: ${car.cilindradaCc} cc',
      if (car.transmission?.trim().isNotEmpty == true) 'Transmisión: ${car.transmission}',
      if (car.fuel.trim().isNotEmpty) 'Combustible: ${car.fuel}',
      if (car.bodyType?.trim().isNotEmpty == true) 'Carrocería: ${car.bodyType}',
      if (car.color?.trim().isNotEmpty == true) 'Color: ${car.color}',
      if (car.doors != null) 'Puertas: ${car.doors}',
      if (car.seats != null) 'Plazas: ${car.seats}',
      if (car.etiquetaMedioambiental?.trim().isNotEmpty == true) 'Etiqueta medioambiental: ${car.etiquetaMedioambiental}',
      if (car.equipment.isNotEmpty) 'Equipamiento: ${car.equipment.join(', ')}',
      if (car.description.trim().isNotEmpty) '',
      if (car.description.trim().isNotEmpty) car.description.trim(),
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: details));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "Ficha del vehículo copiada al portapapeles."))),
      );
    }
  }

  Future<void> _openFullScreenGallery(BuildContext context, int initialIndex) async {
    await galleryReady;
    if (!context.mounted || detailPhotos.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
        reverseTransitionDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 160),
        transitionsBuilder: (_, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
        pageBuilder: (_, animation, secondaryAnimation) => FullScreenGalleryPage(
          photos: detailPhotos,
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
          Icon(icon, color: marketAccent, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Text(uiText(context, label),
              style: const TextStyle(color: marketMuted, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: marketInk,
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
      key: const Key('vehicle-photo-gallery'),
      height: height,
      decoration: BoxDecoration(
        color: marketSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: marketLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: detailPhotos.isNotEmpty
          ? Stack(
              children: [
                PageView.builder(
                  controller: _photoController,
                  itemCount: detailPhotos.length,
                  onPageChanged: (index) {
                    if (mounted && currentPhotoIndex != index) {
                      setState(() => currentPhotoIndex = index);
                    }
                  },
                  itemBuilder: (context, index) => InkWell(
                    onTap: () => _openFullScreenGallery(context, index),
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Image.memory(
                        detailPhotos[index],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ),
                if (detailPhotos.length > 1)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Material(
                      color: marketSurface,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _openFullScreenGallery(context, currentPhotoIndex),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: marketAccent.withValues(alpha: 0.65)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_outlined, color: marketAccent, size: 16),
                              const SizedBox(width: 7),
                              Text(
                                uiText(context, "{0} / {1} fotos", [currentPhotoIndex + 1, detailPhotos.length]),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.open_in_full, color: marketMuted, size: 13),
                            ],
                          ),
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
              child: Icon(Icons.directions_car, size: 100, color: marketAccent),
            ),
    );
  }

  Widget _photoThumbnails() {
    if (detailPhotos.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 10),
        itemCount: detailPhotos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final selected = currentPhotoIndex == index;
          return Semantics(
            button: true,
            label: uiText(context, "Ver foto {0} de {1}", [index + 1, detailPhotos.length]),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                _photoController.animateToPage(
                  index,
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 92,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? gold : marketLine,
                    width: selected ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(detailPhotos[index], fit: BoxFit.cover, cacheWidth: 276),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _featureControl() {
    if (car.listingId == null ||
        car.ownerId != Supabase.instance.client.auth.currentUser?.id) {
      return const SizedBox.shrink();
    }
    return VehicleFeatureControl(

      manage: (enabled) async => Map<String, dynamic>.from(
        await Supabase.instance.client.rpc('manage_vehicle_feature', params: {
          'p_vehicle_id': car.listingId,
          'p_enabled': enabled,
        }) as Map,
      ),
    );
  }

  Widget _safetyTip(IconData icon, String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: marketAccent),
          const SizedBox(width: 10),
          Expanded(child: Text(uiText(context, message), style: TextStyle(color: marketInk.withValues(alpha: 0.88), fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }

  Widget _technicalSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        uiText(context, label).toUpperCase(),
        style: TextStyle(
          color: marketAccent,
          fontSize: 11,
          letterSpacing: 1.05,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _quickSpec(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: marketSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: marketLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: marketAccent),
          const SizedBox(width: 6),
          Flexible(child: Text(uiText(context, label),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: marketInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          )),
        ],
      ),
    );
  }

  Widget _listingStatusChip() {
    final status = car.status.toLowerCase().trim();
    if (status != 'reserved' && status != 'sold') {
      return const SizedBox.shrink();
    }
    final isSold = status == 'sold';
    final color = isSold ? const Color(0xFF9F2633) : const Color(0xFF155B91);
    final label = isSold ? 'VEHÍCULO VENDIDO' : 'VEHÍCULO RESERVADO';
    final icon = isSold ? Icons.check_circle_outline : Icons.lock_outline;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 7),
          Flexible(child:Text(uiText(context, label),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          )),
        ],
      ),
    );
  }

  Widget _editorialListingHeading(BuildContext context) => Column(
    key: const Key('editorial-listing-heading'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${car.brand} ${car.model}',
        style: const TextStyle(
          fontSize: 27,
          height: 1.15,
          fontWeight: FontWeight.w700,
        ),
      ),
      _listingStatusChip(),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: const Border(bottom: BorderSide(color: marketLine)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uiText(context, "PRECIO ANUNCIADO"),
              style: TextStyle(
                color: marketInk.withValues(alpha: 0.68),
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              priceText,
              style: const TextStyle(
                color: marketInk,
                fontSize: 34,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      if(car.listingId!=null) Padding(padding:const EdgeInsets.only(top:10),child:FutureBuilder<int?>(future:listingFavoriteCount,builder:(context,snapshot)=>Row(children:[
        const Icon(Icons.favorite_border_rounded,size:17,color:marketMuted),const SizedBox(width:6),
        Flexible(child:Text(snapshot.connectionState==ConnectionState.waiting ? uiText(context,'Cargando favoritos…') : snapshot.data==null ? uiText(context,'Favoritos no disponibles') : snapshot.data==1 ? uiText(context,'1 favorito') : uiText(context,'{0} favoritos',[snapshot.data]),style:const TextStyle(color:marketMuted,fontSize:13))),
      ]))),
    ],
  );

  Widget _vehicleInformation(BuildContext context, {bool showHeading=true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if(showHeading) _editorialListingHeading(context),
        if (car.ownerId != null) ...[
          const SizedBox(height: 16),
          MarketSellerSummary(profile: sellerProfile, onOpen: _openSeller, photoUrlForPath: (path) => Supabase.instance.client.storage.from('profile-photos').getPublicUrl(path)),
        ],
        const SizedBox(height: 18),
         Text(
          uiText(context, "DATOS PRINCIPALES"),
          key: const Key('vehicle-main-specs'),
          style: TextStyle(
            color: marketMuted,
            fontSize: 11,
            letterSpacing: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        // Spacious two-column overview, with all source values preserved.
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.4 / MediaQuery.textScalerOf(context).scale(1),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            if (car.year > 0)
              _quickSpec(Icons.calendar_today_outlined, '${car.year}'),
            _quickSpec(Icons.speed_rounded, uiText(context, "{0} km", [_formatKm(car.km)])),
            if (car.fuel.trim().isNotEmpty)
              _quickSpec(Icons.local_gas_station_outlined, car.fuel),
            if (car.cv != null)
              _quickSpec(Icons.bolt_outlined, uiText(context, "{0} CV", [car.cv])),
            if (car.transmission?.trim().isNotEmpty == true)
              _quickSpec(Icons.settings_outlined, car.transmission!.trim()),
          ],
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _shareListing(context),
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label:  Text(uiText(context, "Compartir anuncio")),
            style: OutlinedButton.styleFrom(
              foregroundColor: marketAccent,
              side: BorderSide(color: marketAccent.withValues(alpha: 0.65)),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            onPressed: favoriteLoading ? null : _toggleFavorite,
            icon: favoriteLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFavorite ? Colors.pinkAccent : gold, size: 18),
            label: Text(isFavorite ? AppLocalizations.of(context).saved : AppLocalizations.of(context).favorites),
            style: OutlinedButton.styleFrom(
              foregroundColor: marketInk,
              side: BorderSide(color: isFavorite ? Colors.pinkAccent : gold.withValues(alpha: .65)),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
        ]),
        if (car.listingId?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('report-listing-button'),
            onPressed: reporting ? null : _reportListing,
            icon: const Icon(Icons.flag_outlined),
            label: Text(uiText(context, "Denunciar anuncio")),
          ),
        ],
        const SizedBox(height: 18),
        if (car.description.trim().isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)]),
              borderRadius: BorderRadius.circular(18),
              border: const Border.fromBorderSide(BorderSide(color: marketLine)),

            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.notes_rounded, color: marketAccent, size: 21), const SizedBox(width: 9),  Expanded(child: Text(uiText(context, "Descripción"), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700))), const SizedBox(width: 8), Container(width: 26, height: 3, decoration: BoxDecoration(color: marketAccent, borderRadius: BorderRadius.circular(4)))]),
              const SizedBox(height: 12),
              SelectableText(car.description.trim(), style: TextStyle(fontSize: 15, height: 1.65, color: marketInk.withValues(alpha: 0.92))),
            ]),
          ),
          const SizedBox(height: 20),
        ],
        const SizedBox(height:20),
        MarketDetailSection(sectionKey:const Key('listing-technical-details'),title:'Ficha técnica',icon:Icons.tune_rounded,children:[
        Card(
          color: panel,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: marketLine),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 2),
                  child: Text(
                    uiText(context, "Características"),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _technicalRow(
                  Icons.directions_car_outlined,
                  uiText(context, "Marca y modelo"),
                  '${car.brand} ${car.model}',
                ),
                const Divider(height: 1, color: marketLine),
                _technicalRow(
                  Icons.calendar_today_outlined,
                  uiText(context, "Año"),
                  car.year > 0 ? '${car.year}' : uiText(context, "No indicado"),
                ),
                const Divider(height: 1, color: marketLine),
                _technicalRow(
                  Icons.speed,
                  uiText(context, "Kilómetros"),
                  uiText(context, "{0} km", [_formatKm(car.km)]),
                ),
                const Divider(height: 1, color: marketLine),
                _technicalRow(
                  Icons.local_gas_station_outlined,
                  uiText(context, "Combustible"),
                  car.fuel.isNotEmpty ? car.fuel : uiText(context, "No indicado"),
                ),
              ],
            ),
          ),
        ),
        if (car.version?.trim().isNotEmpty == true)
          _technicalRow(Icons.badge_outlined, uiText(context, "Versión"), car.version!),
        if (car.cv != null || car.cilindradaCc != null || car.transmission?.trim().isNotEmpty == true) ...[
          _technicalSectionLabel(uiText(context, "Motor y transmisión")),
          if (car.cv != null) _technicalRow(Icons.speed, uiText(context, "Potencia"), uiText(context, "{0} CV", [car.cv])),
          if (car.cilindradaCc != null) _technicalRow(Icons.settings, uiText(context, "Cilindrada"), uiText(context, "{0} cc", [car.cilindradaCc])),
          if (car.transmission?.trim().isNotEmpty == true) _technicalRow(Icons.settings_outlined, uiText(context, "Transmisión"), car.transmission!),
        ],
        if (car.etiquetaMedioambiental != null && car.etiquetaMedioambiental!.trim().isNotEmpty && car.etiquetaMedioambiental!.toLowerCase() != 'sin etiqueta') ...[
          _technicalSectionLabel(uiText(context, "Emisiones")),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: EnvironmentalSticker(label: car.etiquetaMedioambiental, size: 72),
          ),
        ],
        if (car.showMatriculaPublicly && car.matricula?.trim().isNotEmpty == true || car.showVinPublicly && car.vin?.trim().isNotEmpty == true) ...[
          _technicalSectionLabel(uiText(context, "Identificación del vehículo")),
          if (car.showMatriculaPublicly && car.matricula?.trim().isNotEmpty == true)
            _technicalRow(Icons.confirmation_number_outlined, uiText(context, "Matrícula"), car.matricula!),
          if (car.showVinPublicly && car.vin?.trim().isNotEmpty == true)
            _technicalRow(Icons.qr_code_2_outlined, uiText(context, "Número VIN / bastidor"), car.vin!),
        ],
        if (car.emissionsStandard?.trim().isNotEmpty == true)
          _technicalRow(Icons.eco_outlined, uiText(context, "Normativa de emisiones"), car.emissionsStandard!),
        if (car.bodyType?.trim().isNotEmpty == true || car.doors != null || car.seats != null || car.color?.trim().isNotEmpty == true) ...[
          _technicalSectionLabel(uiText(context, "Carrocería y habitáculo")),
          if (car.bodyType?.trim().isNotEmpty == true) _technicalRow(Icons.directions_car_outlined, uiText(context, "Carrocería"), car.bodyType!),
          if (car.doors != null) _technicalRow(Icons.door_front_door_outlined, uiText(context, "Puertas"), '${car.doors}'),
          if (car.seats != null) _technicalRow(Icons.event_seat_outlined, uiText(context, "Plazas"), '${car.seats}'),
          if (car.color?.trim().isNotEmpty == true) _technicalRow(Icons.palette_outlined, uiText(context, "Color"), car.color!),
        ],
        ]),
        if(car.equipment.isNotEmpty) ...[
          const SizedBox(height:12),
          MarketDetailSection(sectionKey:const Key('listing-equipment'),title:'Equipamiento',icon:Icons.checklist_rounded,children:[
          Text(
            uiText(context, "{0} elementos indicados en el anuncio", [car.equipment.length]),
            style: TextStyle(color: marketInk.withValues(alpha: 0.65), fontSize: 12),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: marketLine),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: car.equipment.map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: marketAccent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: marketAccent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 17, color: marketAccent),
                    const SizedBox(width: 7),
                    Flexible(child: Text(uiText(context, item), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  ],
                ),
              )).toList(),
            ),
          ),
          ]),
        ],
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: marketSurface,
            borderRadius: BorderRadius.circular(16),
            border: const Border.fromBorderSide(BorderSide(color: marketLine)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(children: [
                Icon(Icons.shield_outlined, color: marketAccent, size: 22),
                SizedBox(width: 9),
                Expanded(child: Text(uiText(context, "Consejos para comprar con seguridad"), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 12),
              _safetyTip(Icons.visibility_outlined, uiText(context, "Comprueba el vehículo en persona y revisa su estado antes de pagar.")),
              _safetyTip(Icons.description_outlined, uiText(context, "Verifica la documentación, el VIN/bastidor y que coincidan con el vehículo.")),
              _safetyTip(Icons.payments_outlined, uiText(context, "No envíes anticipos ni claves bancarias si no has comprobado al vendedor y la operación.")),
              _safetyTip(Icons.handshake_outlined, uiText(context, "Deja por escrito el precio, las condiciones y los datos de comprador y vendedor.")),
              const SizedBox(height: 4),
              Text(uiText(context, "AUTOMOTORS recomienda estas precauciones; no constituyen una verificación del vehículo ni del vendedor."), style: TextStyle(color: marketInk.withValues(alpha: 0.62), fontSize: 11, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 22),

      ],
    );
  }

  Widget _contactBar(BuildContext context) {
    return Container(
      key: const Key('vehicle-contact-bar'),
      decoration: BoxDecoration(color: panel,
        border: Border(top: BorderSide(color: marketInk.withValues(alpha: .10)))),
      child: SafeArea(top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: car.status.toLowerCase() == 'sold'
                  ? marketLine
                  : gold,
              foregroundColor: car.status.toLowerCase() == 'sold'
                  ? marketMuted
                  : Colors.black,
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: car.status.toLowerCase() == 'sold' ? null : onContact,
            icon: Icon(car.status.toLowerCase() == 'sold'
                ? Icons.check_circle_outline
                : Icons.chat),
            label: Text(car.status.toLowerCase() == 'sold'
                ? uiText(context, "Vehículo vendido")
                : car.status.toLowerCase() == 'reserved'
                    ? uiText(context, "Consultar disponibilidad")
                    : uiText(context, "Enviar mensaje al vendedor")),
          ),
        ),
        if (car.status.toLowerCase() != 'sold' &&
            validWhatsAppDigits(car.phone) != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1B7647),
                side: const BorderSide(color: Color(0xFF1B7647)),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => openWhatsAppForCar(context, car),
              icon: const Icon(Icons.phone),
              label:  Text(uiText(context, "Contactar por WhatsApp")),
            ),
          ),
        ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _contactBar(context),
      appBar: AppBar(
        title: Text('${car.brand} ${car.model}'),
        actions: [
          if (car.listingId?.isNotEmpty == true)
            IconButton(
              key: const Key('report-listing-action'),
              tooltip: uiText(context, "Denunciar anuncio"),
              onPressed: reporting ? null : _reportListing,
              icon: const Icon(Icons.flag_outlined, color: marketAccent),
            ),
          IconButton(
            tooltip: isFavorite ? uiText(context, "Quitar de favoritos") : uiText(context, "Guardar en favoritos"),
            onPressed: favoriteLoading ? null : _toggleFavorite,
            icon: favoriteLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: marketAccent),
                  )
                : Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFavorite ? Colors.redAccent : marketInk,
                  ),
          ),
        ],
      ),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _gallery(context, height: 430),
                              _photoThumbnails(),
                              _featureControl(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 5,
                          child: _vehicleInformation(context),
                        ),
                      ],
                    )
                  else ...[
                    _gallery(context, height: constraints.maxWidth < 500 ? constraints.maxWidth*.8 : 390),
                    _photoThumbnails(),
                    _featureControl(),
                    const SizedBox(height: 20),
                    _editorialListingHeading(context),
                    _vehicleInformation(context,showHeading:false),
                  ],
                  if (car.status == 'sold' && car.listingId != null && car.ownerId != null && car.ownerId != Supabase.instance.client.auth.currentUser?.id) ...[
                    const SizedBox(height: 12),
                    VehicleReviewForm(listingId: car.listingId!, sellerId: car.ownerId!),
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

  bool get isOwnProfile => supabase.auth.currentUser?.id == widget.ownerId;

  Future<void> refreshSeller() async {
    setState(() => dataFuture = loadSeller());
  }

  Future<void> updateProfileListingStatus(Map<String, dynamic> listing, String status) async {
    if (!isOwnProfile) return;
    try {
      if (status == 'sold') {
        final sold = await showDialog<bool>(context: context, builder: (_) => MarkVehicleSoldDialog(listingId: listing['id'].toString()));
        if (sold != true || !mounted) return;
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(uiText(context, "Anuncio marcado como vendido."))));
        await refreshSeller();
        return;
      }
      await supabase.from('vehicle_listings').update({'status': status})
        .eq('id', listing['id'].toString()).eq('owner_id', widget.ownerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'sold' ? uiText(context, "Anuncio marcado como vendido.") : status == 'reserved' ? uiText(context, "Anuncio marcado como reservado.") : uiText(context, "Reserva retirada."))));
      await refreshSeller();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uiText(context, "No se pudo actualizar el anuncio: {0}", [e]))));
    }
  }

  Future<void> editProfileListing(Map<String, dynamic> listing) async {
    if (!isOwnProfile || listing['status']?.toString() == 'sold') return;
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EditListingPage(listingId: listing['id'].toString())));
    if (changed == true && mounted) await refreshSeller();
  }

  Future<Map<String, dynamic>> loadSeller() async {
    Map<String, dynamic>? profile;
    try {
      profile = await supabase.from('public_seller_profiles')
          .select('id, full_name, account_type, city, province, business_name, phone, profile_photo_path, cover_photo_path, estado_verificacion')
          .eq('id', widget.ownerId)
          .maybeSingle();
    } catch (_) {
      // Un fallo al cargar datos públicos del perfil no debe ocultar sus anuncios.
      profile = null;
    }
    bool emailConfirmed=false;
    try{final trust=await supabase.rpc('seller_trust_summary',params:{'p_seller':widget.ownerId});emailConfirmed=trust is Map && trust['email_confirmed']==true;}catch(_){}
    String? memberSince;
    try {
      final month = await supabase.rpc('seller_member_since', params: {'p_seller_id': widget.ownerId});
      if (month is String && RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) memberSince = month;
    } catch (_) { /* Profile still works if membership is temporarily unavailable. */ }
    String aboutUs = '';
    try {
      final about = await supabase.from('seller_about_profiles').select('about_us').eq('user_id', widget.ownerId).maybeSingle();
      aboutUs = about?['about_us']?.toString() ?? '';
    } catch (_) {}
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
          firstPhoto = await downloadVehiclePhoto(path);
        } catch (_) {
          // Si no se puede descargar la imagen, se muestra el icono del vehículo.
        }
      }
      listing['_firstPhotoBytes'] = firstPhoto;
    }
    return {'profile': profile, 'listings': listingRows, 'soldListings': soldRows, 'aboutUs': aboutUs, 'memberSince': memberSince,'emailConfirmed':emailConfirmed};
  }

  String? publicPhotoUrl(dynamic path) {
    final value = path?.toString() ?? '';
    if (value.isEmpty) return null;
    return supabase.storage.from('profile-photos').getPublicUrl(value);
  }

  String displayName(Map<String, dynamic>? profile) {
    if (profile == null) return uiText(context, 'Vendedor AUTOMOTORS');
    final type = (profile['account_type'] ?? 'particular').toString().toLowerCase();
    if ((type == 'empresa' || type == 'autonomo') && (profile['business_name']?.toString().trim().isNotEmpty ?? false)) {
      return profile['business_name'].toString();
    }
    return (profile['full_name']?.toString().trim().isNotEmpty ?? false)
        ? profile!['full_name'].toString() : uiText(context, 'Vendedor AUTOMOTORS');
  }

  String euros(double price) =>
      '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} €';

  Future<void> openListingDetails(Map<String, dynamic> listing) async {
    final listingId = listing['id']?.toString();
    if (listingId == null || listingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "No se pudo identificar este anuncio."))),
      );
      return;
    }
    try {
      final raw = await supabase
          .from('vehicle_listings')
          .select('id, status, year, km, price, fuel, description, phone, matricula, vin, show_matricula_publicly, show_vin_publicly, cv, cilindrada_cc, etiqueta_medioambiental, version, transmission, body_type, doors, seats, color, torque_nm, acceleration_0_100, max_speed_kmh, consumption_l_100, emissions_standard, equipment, owner_id, vehicle_brands(name), vehicle_models(name), vehicle_photos(storage_path, position)')
          .eq('id', listingId)
          .inFilter('status', ['published', 'reserved', 'sold'])
          .maybeSingle();
      if (raw == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(uiText(context, "Este anuncio ya no está disponible."))),
        );
        return;
      }
      final car = await buyerCarFromListing(raw);
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
        SnackBar(content: Text(uiText(context, "No se pudo abrir el anuncio: {0}", [error]))),
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
         SnackBar(content: Text(uiText(context, "No puedes iniciar un chat contigo mismo."))),
      );
      return;
    }
    try {
      final conversation = await getOrCreateConversation(
        supabase: supabase,
        listingId: car.listingId!,
        buyerId: currentUser.id,
        sellerId: car.ownerId!,
      );
      if (!mounted) return;
      await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => ChatPage(
        conversationId: conversation['id'].toString(),
        title: '${car.brand} ${car.model}',
      )));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uiText(context, "No se pudo abrir el chat: {0}", [error]))),
      );
    }
  }

  int selectedProfileTab = 0;

  Widget profileStat(String value, String label) => Expanded(
    child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: marketInk)),
      const SizedBox(height: 3),
      Text(uiText(context, label), style: const TextStyle(fontSize: 12, color: marketMuted), textAlign: TextAlign.center),
    ]),
  );

  Widget profileStatWidget(Widget value, String label) => Expanded(
    child: Column(children: [value, const SizedBox(height: 3), Text(uiText(context, label), style: const TextStyle(fontSize: 12, color: marketMuted), textAlign: TextAlign.center)]),
  );

  Widget profileVehicleGrid(List<Map<String, dynamic>> rows, {required bool sold}) {
    if (rows.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          sold ? uiText(context, "Este vendedor todavía no tiene vehículos vendidos.") : uiText(context, "Este vendedor no tiene anuncios disponibles."),
          textAlign: TextAlign.center,
          style: const TextStyle(color: marketMuted, fontSize: 15),
        ),
      ));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth < 520 ? 1 : constraints.maxWidth < 900 ? 2 : 3;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
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
            color: marketSurface,
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE4E5DF)),
            ),
            child: InkWell(
              onTap: () => openListingDetails(listing),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: SizedBox(width: double.infinity, child: Stack(fit: StackFit.expand, children: [
                  photo is Uint8List
                      ? Image.memory(photo, fit: BoxFit.cover)
                      : const Center(child: Icon(Icons.directions_car, color: marketAccent, size: 42)),
                  if (sold) Positioned.fill(child: Container(color: Colors.black.withValues(alpha: .15))),
                  if ((label ?? '').isNotEmpty && label!.toLowerCase() != 'sin etiqueta' && !sold)
                    Positioned(left: 5, top: 5, child: EnvironmentalSticker(label: label, size: 34)),
                  if (!sold && !isOwnProfile)
                    Positioned(
                      right: 7,
                      top: 7,
                      child: SaveListingIdButton(listingId: listing['id']?.toString()),
                    ),
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
                        Text(sold ? uiText(context, "VENDIDO") : uiText(context, "RESERVADO"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: .8)),
                      ]),
                    ),
                  )),
                ]))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 9, 9, 11),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: marketInk)),
                    const SizedBox(height: 5),
                    Text(uiText(context, "{0} · {1} km", [listing['year'] ?? '', ((listing['km'] as num?)?.toInt() ?? 0)]), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: marketMuted, fontSize: 11)),
                    const SizedBox(height: 7),
                    Text(euros(price), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: marketAccent, fontSize: 15, fontWeight: FontWeight.w700)),
                    if (isOwnProfile && !sold) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(onPressed: () => editProfileListing(listing), icon: const Icon(Icons.edit_outlined, size: 16), label:  Text(uiText(context, "Editar")), style: OutlinedButton.styleFrom(foregroundColor: marketAccent, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8)))),
                        const SizedBox(width: 6),
                        Expanded(child: OutlinedButton.icon(onPressed: () => updateProfileListingStatus(listing, isReserved ? 'published' : 'reserved'), icon: Icon(isReserved ? Icons.event_available : Icons.bookmark_border, size: 16), label: Text(isReserved ? uiText(context, "Quitar reserva") : uiText(context, "Reservar"), maxLines: 1, overflow: TextOverflow.ellipsis), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF155B91), visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8)))),
                        const SizedBox(width: 6),
                        Expanded(child: OutlinedButton.icon(onPressed: () => updateProfileListingStatus(listing, 'sold'), icon: const Icon(Icons.check_circle_outline, size: 16), label:  Text(uiText(context, "Vendido")), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF216E39), visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8)))),
                      ]),
                    ],
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
    backgroundColor: marketPaper,
    appBar: AppBar(
      backgroundColor: marketPaper,
      foregroundColor: marketAccent,
      automaticallyImplyLeading: true,
      title: null,
      actions:[if(isOwnProfile) PopupMenuButton<String>(
        key:const Key('own-account-menu'),tooltip:uiText(context,'Configuración de cuenta'),icon:const Icon(Icons.settings_outlined),
        onSelected:(value) async {
          await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>value=='delete' ? const DeleteAccountPage() : const ProfilePage()));
          if (!mounted) return;
          setState(() => dataFuture = loadSeller());
        },
        itemBuilder:(context)=>[
          PopupMenuItem(value:'profile',child:Text(uiText(context,'Mi perfil'))),
          PopupMenuItem(value:'delete',child:Text(uiText(context,'Eliminar mi cuenta'))),
        ],
      )],
      centerTitle: false,
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: marketAccent));
        }
        if (snapshot.hasError) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(
            uiText(context, "No se pudo cargar este perfil ahora mismo. Recarga la página e inténtalo de nuevo."),
            textAlign: TextAlign.center,
          )));
        }
        final result = snapshot.data ?? {};
        final profile = result['profile'] as Map<String, dynamic>?;
        final listings = List<Map<String, dynamic>>.from(result['listings'] ?? []);
        final soldListings = List<Map<String, dynamic>>.from(result['soldListings'] ?? []);
        final aboutUs = result['aboutUs']?.toString() ?? '';
        final name = displayName(profile);
        final type = (profile?['account_type'] ?? 'particular').toString().toLowerCase();
        final isProfessional = type == 'empresa' || type == 'autonomo';
        final displayType = type == 'empresa' ? 'Empresa' : type == 'autonomo' ? 'Autónomo' : 'Particular';
        final profileTabs = <String>['Anuncios', 'Vendidos', if (isProfessional) 'Sobre nosotros', 'Valoraciones'];
        final profileTabChildren = <Widget>[
          Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 15, 16, 0), child: Row(children: [const Icon(Icons.directions_car_filled, color: Color(0xFF168BFF), size: 24), const SizedBox(width: 8),  Expanded(child: Text(uiText(context, "Vehículos disponibles"), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: marketInk))), Text('${listings.length}', style: const TextStyle(color: marketMuted, fontWeight: FontWeight.bold))])),
             Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: Align(alignment: Alignment.centerLeft, child: Text(uiText(context, "Anuncios publicados y reservados actualmente"), style: TextStyle(color: marketMuted, fontSize: 12)))),
            profileVehicleGrid(listings, sold: false),
          ]),
          Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 15, 16, 0), child: Row(children: [const Icon(Icons.verified_rounded, color: Color(0xFFFF424A), size: 24), const SizedBox(width: 8),  Expanded(child: Text(uiText(context, "Vehículos vendidos"), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: marketInk))), Text('${soldListings.length}', style: const TextStyle(color: marketMuted, fontWeight: FontWeight.bold))])),
             Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: Align(alignment: Alignment.centerLeft, child: Text(uiText(context, "Historial de vehículos vendidos por este vendedor"), style: TextStyle(color: marketMuted, fontSize: 12)))),
            profileVehicleGrid(soldListings, sold: true),
          ]),
          if (isProfessional) ListView(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.all(20), children: [
             Text(uiText(context, "Sobre nosotros"), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: marketInk)),
            const SizedBox(height: 12),
            if (aboutUs.trim().isNotEmpty) Text(aboutUs, style: const TextStyle(color: marketMuted, fontSize: 15, height: 1.5)),
            if (aboutUs.trim().isEmpty) Text('$displayType · ${uiText(context, "Vendedor profesional")}', style: const TextStyle(color: marketMuted, fontSize: 16)),
            finalCity(profile),
            if (isOwnProfile) Padding(padding: const EdgeInsets.only(top: 12), child: OutlinedButton.icon(onPressed: () async { await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const ProfilePage())); if (mounted) await refreshSeller(); }, icon: const Icon(Icons.edit), label:  Text(uiText(context, "Editar Sobre nosotros")))),
          ]),
          SellerReviewsSection(sellerId: widget.ownerId),
        ];
        if (selectedProfileTab >= profileTabs.length) selectedProfileTab = 0;
        final cover = publicPhotoUrl(profile?['cover_photo_path']);
        final avatar = publicPhotoUrl(profile?['profile_photo_path']);
        final phone = profile?['phone']?.toString() ?? '';
        final digits = validWhatsAppDigits(phone);
        return ScrollConfiguration(
          behavior: MaterialScrollBehavior().copyWith(
            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
          ),
          child: SingleChildScrollView(
            primary: true,
            physics: const ClampingScrollPhysics(),
            child: Column(children: [
          if (isProfessional)
            MarketProfessionalHeader(name: name, accountLabel: uiText(context, displayType), coverUrl: cover, avatarUrl: avatar,
              location: [profile?['city'], profile?['province']].where((v) => v != null && v.toString().trim().isNotEmpty).join(', ')),
          Padding(
            // Extra clearance prevents clipping under the iOS standalone
            // app's status/navigation area for personal seller profiles.
            padding: EdgeInsets.fromLTRB(18, isProfessional ? 16 : 36, 18, 14),
            child: Transform.translate(
              // Only business profiles overlap their cover image.
              offset: Offset.zero,
              child: Column(children: [
                if (!isProfessional) Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: marketAccent, boxShadow: [BoxShadow(color: marketAccent.withValues(alpha: .22), blurRadius: 14)]),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: marketSurface,
                      backgroundImage: avatar == null ? null : NetworkImage(avatar),
                      onBackgroundImageError: avatar == null ? null : (_, __) {},
                      child: avatar == null ? const Icon(Icons.person, color: marketAccent, size: 42) : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: marketInk))),
                    ]),
                    const SizedBox(height: 3),
                    Text(displayType, style: const TextStyle(color: marketMuted, fontSize: 14)),
                    finalCity(profile),
                  ])),

                ]),
                SellerTrustIndicators(professional:isProfessional,emailConfirmed:result['emailConfirmed']==true),
                if (snapshot.data?['memberSince'] is String) Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(uiText(context, 'En AUTOMOTORS desde {0}', [(snapshot.data!['memberSince'] as String).split('-').reversed.join('/')]), style: const TextStyle(color: marketMuted)),
                ),
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(uiText(context, 'Información facilitada por el vendedor. Consulta sus valoraciones y confirma los datos antes de comprar.'), style: const TextStyle(color: marketMuted, fontSize: 12))),
                if(aboutUs.trim().isNotEmpty) Padding(padding:const EdgeInsets.only(top:16),child:Text(aboutUs.trim(),maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:marketMuted,height:1.5))),
                const SizedBox(height: 19),
                Row(children: [
                  profileStat('${listings.length}', uiText(context, "Anuncios")),
                  Container(width: 1, height: 34, color: const Color(0xFFE4E5DF)),
                  profileStat('${soldListings.length}', uiText(context, "Vendidos")),
                  Container(width: 1, height: 34, color: const Color(0xFFE4E5DF)),
                  profileStatWidget(SellerTrustScore(sellerId: widget.ownerId), 'Confianza / 10'),
                ]),
                if (supabase.auth.currentUser?.id == widget.ownerId) ...[
                  const ModerationEntry(),
                ],
                if (supabase.auth.currentUser?.id != widget.ownerId) ...[
                const SizedBox(height: 17),
                Row(children: [
                  if (digits != null)
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B7647),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        tooltip: uiText(context, "Abrir WhatsApp"),
                        onPressed: () async {
                          final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent('Hola, te contacto desde tu perfil de AUTOMOTORS.')}');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.chat, color: marketInk, size: 25),
                        iconSize: 28,
                        padding: const EdgeInsets.all(13),
                      ),
                    ),
                  if (digits != null) const SizedBox(width: 10),
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
                        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(uiText(context, "Este es tu propio perfil."))));
                        return;
                      }
                      try {
                        final rows = await supabase.from('vehicle_listings').select('id')
                          .eq('owner_id', widget.ownerId).inFilter('status', ['published', 'reserved']).order('created_at', ascending: false).limit(1);
                        if (rows.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(uiText(context, "Este vendedor no tiene anuncios disponibles para iniciar un chat."))));
                          return;
                        }
                        final listingId = rows.first['id'].toString();
                        final conversation = await getOrCreateConversation(
                          supabase: supabase,
                          listingId: listingId,
                          buyerId: currentUser.id,
                          sellerId: widget.ownerId,
                        );
                        if (!context.mounted) return;
                        await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => ChatPage(
                          conversationId: conversation['id'].toString(), title: name,
                        )));
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uiText(context, "No se pudo abrir el chat: {0}", [e]))));
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 17),
                    label:  Text(uiText(context, "Enviar mensaje")),
                    style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                  )),
                ]),
                ],
              ]),
            ),
          ),
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E5DF)))),
            child: Row(children: [
              for (var i = 0; i < profileTabs.length; i++) _profileTabButton(profileTabs[i], i),
            ]),
          ),
          IndexedStack(
            index: selectedProfileTab,
            children: profileTabChildren,
          ),
          ]),
          ),
        );
      },
    ),
  );

  Widget _profileTabButton(String label, int index) => Expanded(
    child: InkWell(
      onTap: () => setState(() => selectedProfileTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 3),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selectedProfileTab == index ? const Color(0xFF168BFF) : Colors.transparent, width: 3))),
        child: Text(uiText(context, label), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: selectedProfileTab == index ? FontWeight.w700 : FontWeight.w500, color: selectedProfileTab == index ? marketInk : marketMuted)),
      ),
    ),
  );

  Widget finalCity(Map<String, dynamic>? profile) {
    final city = profile?['city']?.toString() ?? '';
    final province = profile?['province']?.toString() ?? '';
    final location = [city, province].where((v) => v.trim().isNotEmpty).join(', ');
    return location.isEmpty ? const SizedBox.shrink() : Text(location, style: const TextStyle(color: marketMuted));
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
    await automotorsPush.unregister();
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "Has cerrado sesión."))),
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
           Text(uiText(context, "Mi espacio")),
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
                colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
              ),
              border: Border.all(color: marketAccent.withValues(alpha: .48)),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Row(children: [
                Icon(Icons.workspace_premium, color: marketAccent),
                SizedBox(width: 8),
                Text(uiText(context, "TU ESPACIO AUTOMOTORS"), style: TextStyle(color: marketAccent, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
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
                     Text(uiText(context, "Bienvenido"), style: TextStyle(color: marketMuted, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -.4)),
                  ]);
                },
              ),
              const SizedBox(height: 8),
               Text(uiText(context, "Tu garaje, tus conversaciones y tus oportunidades, en un solo lugar."), style: TextStyle(color: marketMuted, height: 1.4)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _PersonalQuickStat(icon: Icons.directions_car_filled_rounded, label: uiText(context, "MI GARAJE"), value: 'Gestiona tus coches', onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const GaragePage())))),
                const SizedBox(width: 12),
                Expanded(child: _PersonalQuickStat(icon: Icons.manage_accounts_rounded, label: uiText(context, "TU CUENTA"), value: 'Tu perfil a medida', onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const ProfilePage())))),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          Card(color: panel, child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: marketAccent),
            title:  Text(uiText(context, "Mis mensajes")),
            subtitle:  Text(uiText(context, "Consulta tus conversaciones con compradores y vendedores")),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const InboxPage())),
          )),
          const ModerationEntry(),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.help_outline, color: marketAccent),
            title: Text(uiText(context, 'Ayuda y privacidad')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openAutomotorsSupport(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
            title: Text(uiText(context, 'Eliminar mi cuenta')),
            onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const DeleteAccountPage())),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label:  Text(uiText(context, "Cerrar sesión")),
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
  String statusFilter = 'Todos';
  String searchQuery = '';

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
      'id,status,year,km,price,fuel,phone,description,equipment,cv,cilindrada_cc,etiqueta_medioambiental,vin,owner_id,vehicle_brands(name),vehicle_models(name),vehicle_photos(storage_path,position)'
    ).eq('owner_id', user.id).order('created_at', ascending: false);
    final listings=List<Map<String,dynamic>>.from(rows);
    try {
      final states=await supabase.rpc('my_listing_content_checks') as List;
      final byId={for(final state in states) state['listing_id']:state};
      for(final listing in listings) {listing['content_check_state']=byId[listing['id']]?['state'];}
    } catch(_) {/* Listing management remains available if the status lookup fails. */}
    try {
      final result=await supabase.rpc('my_listing_metrics');
      final metrics={for(final item in List<Map<String,dynamic>>.from(result as List)) item['listing_id'].toString():item};
      for(final listing in listings){listing['metrics']=metrics[listing['id'].toString()];}
    } catch(_) {/* Unavailable is not zero activity. */}
    return listings;
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
         SnackBar(content: Text(uiText(context, "Inicia sesión para gestionar tus anuncios."))),
      );
      return;
    }
    // Estados admitidos en Supabase: draft, published, reserved y sold.
    // Pausar se representa como borrador para mantener compatibilidad.
    final normalizedStatus = status == 'paused' ? 'draft' : status;
    if (!['draft', 'published', 'reserved', 'sold'].contains(normalizedStatus)) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "Estado de anuncio no válido."))),
      );
      return;
    }

    setState(() => busy = true);
    try {
      if (normalizedStatus == 'sold') {
        setState(() => busy = false);
        final sold = await showDialog<bool>(context: context, builder: (_) => MarkVehicleSoldDialog(listingId: listing['id'].toString()));
        if (sold != true || !mounted) return;
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(uiText(context, "Anuncio marcado como vendido."))));
        refreshListings();
        return;
      }
      if (normalizedStatus=='published'||normalizedStatus=='reserved') {
        final result=await ContentPublicationService().publish(listing['id'].toString(),targetStatus:normalizedStatus);
        if(mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(uiText(context,result.message))));refreshListings();}
        return;
      }
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uiText(context, message))));
        refreshListings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uiText(context, "No se pudo actualizar el anuncio: {0}", [e]))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteListing(Map<String, dynamic> listing) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title:  Text(uiText(context, "Eliminar anuncio")),
      content:  Text(uiText(context, "¿Seguro que quieres eliminar este anuncio? Esta acción no se puede deshacer.")),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child:  Text(uiText(context, "Cancelar"))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child:  Text(uiText(context, "Eliminar"))),
      ],
    ));
    if (confirm != true) return;
    setState(() => busy = true);
    try {
      await supabase.from('vehicle_listings').delete().eq('id', listing['id'].toString()).eq('owner_id', supabase.auth.currentUser!.id);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(uiText(context, "Anuncio eliminado.")))); refreshListings(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uiText(context, "No se pudo eliminar el anuncio: {0}", [e]))));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> openDetails(Map<String, dynamic> listing) async {
    try {
      final car = await buyerCarFromListing(listing);
      if (!mounted) return;
      await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => CarDetailsPage(
        car: car,
        priceText: euros(car.price),
        onContact: () => ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(uiText(context, "Este es tu anuncio; no puedes contactar contigo mismo.")))),
      )));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uiText(context, "No se pudo abrir la ficha del vehículo: {0}", [e]))));
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
           SnackBar(content: Text(uiText(context, "Un vehículo vendido no se puede editar."))),
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
          SnackBar(content: Text(uiText(context, "No se pudo comprobar el estado del anuncio: {0}", [e]))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title:  Text(uiText(context, "Gestiona tu garaje")),
      actions: [IconButton(onPressed: refreshListings, tooltip: uiText(context, "Actualizar anuncios"), icon: const Icon(Icons.refresh_rounded, color: marketAccent))],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: listingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: marketAccent));
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(uiText(context, "No se pudieron cargar tus anuncios: {0}", [snapshot.error]))));
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return  Center(child: Padding(padding: EdgeInsets.all(24), child: Text(uiText(context, "Todavía no tienes anuncios. Publica tu primer vehículo para verlo aquí."))));
        final counts = <String, int>{
          'Todos': rows.length,
          'Publicados': rows.where((r) => r['status']?.toString() == 'published').length,
          'Pausados': rows.where((r) => ['draft', 'paused'].contains(r['status']?.toString())).length,
          'Reservados': rows.where((r) => r['status']?.toString() == 'reserved').length,
          'Vendidos': rows.where((r) => r['status']?.toString() == 'sold').length,
        };
        final normalizedQuery = searchQuery.trim().toLowerCase();
        final visibleRows = rows.where((listing) {
          final status = listing['status']?.toString() ?? 'published';
          final matchesStatus = statusFilter == 'Todos' ||
              (statusFilter == 'Publicados' && status == 'published') ||
              (statusFilter == 'Pausados' && ['draft', 'paused'].contains(status)) ||
              (statusFilter == 'Reservados' && status == 'reserved') ||
              (statusFilter == 'Vendidos' && status == 'sold');
          final searchable = '${listingName(listing)} ${listing['year'] ?? ''} ${listing['fuel'] ?? ''}'.toLowerCase();
          return matchesStatus && (normalizedQuery.isEmpty || searchable.contains(normalizedQuery));
        }).toList();
        return Stack(children: [
          ListView(padding: const EdgeInsets.all(16), children: [
             Text(uiText(context, "Tus vehículos"), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
             Text(uiText(context, "Filtra por estado o busca por marca, modelo, año y combustible.")),
            const SizedBox(height: 14),
            TextField(
              decoration: InputDecoration(
                hintText: uiText(context, "Buscar en mis anuncios…"),
                prefixIcon: const Icon(Icons.search, color: marketAccent),
                suffixIcon: searchQuery.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), tooltip: uiText(context, "Borrar búsqueda"), onPressed: () => setState(() => searchQuery = '')),
                filled: true,
                fillColor: panel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: counts.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${entry.key} (${entry.value})'),
                  selected: statusFilter == entry.key,
                  selectedColor: marketInk,
                  labelStyle: TextStyle(color: statusFilter == entry.key ? marketSurface : marketInk, fontWeight: FontWeight.w700),
                  onSelected: (_) => setState(() => statusFilter = entry.key),
                ),
              )).toList()),
            ),
            const SizedBox(height: 12),
            Text(uiText(context, "{0} de {1} anuncios", [visibleRows.length, rows.length]), style: const TextStyle(color: marketMuted, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (visibleRows.isEmpty)
               Padding(padding: EdgeInsets.symmetric(vertical: 36), child: Column(children: [Icon(Icons.search_off_rounded, size: 42, color: marketMuted), SizedBox(height: 10), Text(uiText(context, "No hay anuncios que coincidan con estos filtros."), textAlign: TextAlign.center, style: TextStyle(color: marketMuted))]))
            else ...visibleRows.map((listing) {
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
                        left: BorderSide(color: marketInk.withValues(alpha: .7), width: 1),
                      ),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                      boxShadow: [
                        BoxShadow(color: (isReserved ? const Color(0xFF168BFF) : const Color(0xFFFF2435)).withValues(alpha: .38), blurRadius: 14, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(isReserved ? Icons.lock_rounded : Icons.verified_rounded, size: 15, color: marketInk),
                      const SizedBox(width: 7),
                      Text(isReserved ? uiText(context, "RESERVADO") : uiText(context, "VENDIDO"), style: const TextStyle(
                        color: marketInk, fontWeight: FontWeight.w700, letterSpacing: 1.1,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
                      )),
                    ]),
                  )),
                ])),
                Padding(padding: const EdgeInsets.fromLTRB(16, 13, 8, 0), child: Row(children: [
                  Expanded(child: InkWell(onTap: () => openDetails(listing), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(listingName(listing), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text(uiText(context, "{0} · {1} km · {2}", [listing['year'] ?? '', ((listing['km'] as num?)?.toInt() ?? 0), euros(price)]), style: const TextStyle(color: marketMuted)),
                    const SizedBox(height: 5),
                    Text(uiText(context, "Estado: {0}", [uiText(context, isReserved ? 'Reservado' : isSold ? 'Vendido' : status == 'draft' || status == 'paused' ? 'Pausado' : status == 'published' ? 'Publicado' : status)]), style: TextStyle(color: isReserved ? const Color(0xFF155B91) : isSold ? const Color(0xFF216E39) : marketMuted)),
                    if(listingContentStateMessage(listing['content_check_state']?.toString()).isNotEmpty)
                      Text(uiText(context,listingContentStateMessage(listing['content_check_state']?.toString())),style:const TextStyle(color:Color(0xFF805200))),
                    const SizedBox(height: 8),
                  ]))),
                  PopupMenuButton<String>(enabled: !busy, tooltip: uiText(context, "Opciones del anuncio"), onSelected: (value) {
                    if (value == 'edit') editListing(listing);
                    if (value == 'pause' && status != 'reserved' && status != 'sold') setListingStatus(listing, status == 'published' ? 'paused' : 'published');
                    if (value == 'delete') deleteListing(listing);
                    if (value == 'publish') setListingStatus(listing, 'published');
                  }, itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', enabled: !isSold, child: ListTile(leading: Icon(Icons.edit_outlined), title: Text(isSold ? uiText(context, "No editable: vendido") : uiText(context, "Editar")))),
                    PopupMenuItem(value: 'pause', enabled: status != 'reserved' && status != 'sold', child: ListTile(leading: Icon(status == 'published' ? Icons.pause : Icons.play_arrow), title: Text(status == 'published' ? uiText(context, "Pausar") : uiText(context, "Activar")))),
                     PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text(uiText(context, "Eliminar")))),
                  ], icon: const Icon(Icons.more_vert, color: marketAccent)),
                ])),
                SellerListingMetrics(metrics:listing['metrics'] as Map<String,dynamic>?, listing:listing, onEdit:()=>editListing(listing)),
                Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 14), child: Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: busy || isSold ? null : () => setListingStatus(listing, 'sold'), icon: const Icon(Icons.check_circle_outline), label:  Text(uiText(context, "Vendido")))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: busy || isSold ? null : () => setListingStatus(listing, isReserved ? 'published' : 'reserved'), icon: Icon(isReserved ? Icons.event_available : Icons.bookmark_border), label: Text(isReserved ? uiText(context, "Quitar reserva") : uiText(context, "Reservar")))),
                ])),
              ]));
            }),
          ]),
          if (busy) const Align(alignment: Alignment.topCenter, child: LinearProgressIndicator(color: marketAccent)),
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
      final result = await downloadVehiclePhoto(path);
      if (mounted && widget.path == path) setState(() => bytes = result);
    } catch (_) { if (mounted && widget.path == path) setState(() => bytes = null); }
  }
  @override
  Widget build(BuildContext context) => Container(
    color: marketSurface, width: double.infinity,
    child: bytes == null
      ? const Center(child: Icon(Icons.directions_car_filled, color: marketAccent, size: 64))
      : Image.memory(bytes!, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.directions_car_filled, color: marketAccent, size: 64))),
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
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .22), borderRadius: BorderRadius.circular(14), border: Border.all(color: marketLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: marketAccent, size: 20), const SizedBox(height: 8),
          Text(uiText(context, label), style: const TextStyle(color: marketAccent, fontSize: 9, letterSpacing: .7, fontWeight: FontWeight.w700)),
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
  final aboutUs = TextEditingController();
  String accountType = 'particular';
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
    aboutUs.dispose();
    super.dispose();
  }

  Future<void> signOutFromProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:  Text(uiText(context, "Cerrar sesión")),
        content:  Text(uiText(context, "¿Quieres cerrar tu sesión de AUTOMOTORS?")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child:  Text(uiText(context, "Cancelar")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: Colors.black,
            ),
            child:  Text(uiText(context, "Cerrar sesión")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await automotorsPush.unregister();
      await supabase.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "Has cerrado sesión."))),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "No se pudo cerrar sesión. Inténtalo de nuevo."))),
      );
    }
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
        profilePhotoPath = row['profile_photo_path']?.toString();
        coverPhotoPath = row['cover_photo_path']?.toString();
        try {
          final about = await supabase.from('seller_about_profiles').select('about_us').eq('user_id', user.id).maybeSingle();
          aboutUs.text = about?['about_us']?.toString() ?? '';
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uiText(context, "No se pudo cargar el perfil. Comprueba que has aplicado el SQL de configuración. ({0})", [e]))),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> chooseProfileImage({required bool cover}) async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80,
        maxWidth: cover ? 1600 : 640, maxHeight: cover ? 1600 : 640);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (cover) { pickedCoverPhoto = file; pickedCoverPhotoBytes = bytes; }
        else { pickedProfilePhoto = file; pickedProfilePhotoBytes = bytes; }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uiText(context, "No se pudo seleccionar la imagen: {0}", [e]))));
    }
  }

  Future<String> uploadProfileImage(XFile file, Uint8List bytes, String kind, String userId) async {
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
    final path = '$userId/$kind-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('profile-photos').uploadBinary(path, bytes,
      fileOptions: FileOptions(upsert: true, contentType: ext == 'png' ? 'image/png' : 'image/jpeg'));
    return path;
  }

  Future<void> saveProfile() async {
    if (saving || !formKey.currentState!.validate()) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
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
        'business_name': isProfessional
            ? businessName.text.trim()
            : null,
        'address': isProfessional ? address.text.trim() : null,
        'profile_photo_path': profilePhotoPath,
        'cover_photo_path': isProfessional ? coverPhotoPath : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await supabase.from('user_profiles').upsert(data, onConflict: 'id');
      if (isProfessional) {
        await supabase.from('seller_about_profiles').upsert({
          'user_id': user.id,
          'about_us': aboutUs.text.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id');
      }
      if (!mounted) return;
      setState(() {
        pickedProfilePhoto = null;
        pickedCoverPhoto = null;
        pickedProfilePhotoBytes = null;
        pickedCoverPhotoBytes = null;
        editing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "Perfil guardado correctamente."))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uiText(context, "No se pudo guardar el perfil: {0}", [e]))),
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
        decoration: InputDecoration(labelText: uiText(context, label)),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (requiredField && text.isEmpty) {
            return uiText(context, 'Completa este campo');
          }
          if (text.isEmpty) return null;

          if (label.startsWith('Teléfono') && validWhatsAppDigits(text) == null) {
            return uiText(context, 'Introduce un teléfono válido, incluido el prefijo internacional si procede');
          }
          return null;
        },
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return ListTile(contentPadding: EdgeInsets.zero, title: Text(uiText(context, label), style: const TextStyle(color: marketMuted, fontSize: 13)), subtitle: Text(value, style: const TextStyle(fontSize: 16)));
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';
    final profileUrl = profilePhotoPath == null ? null : supabase.storage.from('profile-photos').getPublicUrl(profilePhotoPath!);
    final coverUrl = coverPhotoPath == null ? null : supabase.storage.from('profile-photos').getPublicUrl(coverPhotoPath!);
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [const AutomotorsBrandMark(size: 30), const SizedBox(width: 10),  Text(uiText(context, "Mi perfil"))]),
        actions: [if (!loading) IconButton(tooltip: editing ? uiText(context, "Cancelar edición") : uiText(context, "Editar perfil"), icon: Icon(editing ? Icons.close : Icons.edit_outlined, color: marketAccent), onPressed: () => setState(() => editing = !editing))],
      ),
      body: loading ? const Center(child: CircularProgressIndicator(color: marketAccent)) : editing
        ? Form(key: formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
            if (isProfessional) ...[
              GestureDetector(onTap: saving ? null : () => chooseProfileImage(cover: true), child: Container(height: 140, decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12), image: pickedCoverPhotoBytes != null ? DecorationImage(image: MemoryImage(pickedCoverPhotoBytes!), fit: BoxFit.cover) : (coverUrl != null ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover) : null)), child:  Center(child: Text(uiText(context, "Cambiar foto de portada"), style: TextStyle(color: Colors.white, backgroundColor: Colors.black54))))),
              const SizedBox(height: 12),
            ],
            Center(child: GestureDetector(onTap: saving ? null : () => chooseProfileImage(cover: false), child: CircleAvatar(radius: 48, backgroundColor: gold, backgroundImage: pickedProfilePhotoBytes != null ? MemoryImage(pickedProfilePhotoBytes!) : (profileUrl != null ? NetworkImage(profileUrl) : null) as ImageProvider?, child: (pickedProfilePhotoBytes == null && profileUrl == null) ? const Icon(Icons.add_a_photo, color: Colors.black, size: 28) : null))),
            const SizedBox(height: 8),  Center(child: Text(uiText(context, "Pulsa la foto para cambiarla"))),
            const SizedBox(height: 16),
             Text(uiText(context, "DATOS DE LA CUENTA"), style: TextStyle(color: marketAccent, fontWeight: FontWeight.bold)),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.email_outlined, color: marketAccent), title:  Text(uiText(context, "Correo electrónico")), subtitle: Text(email)),
            DropdownButtonFormField<String>(isExpanded: true, value: accountType, decoration:  InputDecoration(labelText: uiText(context, "Tipo de cuenta")), items:  [DropdownMenuItem(value: 'particular', child: Text(uiText(context, "Particular"))), DropdownMenuItem(value: 'autonomo', child: Text(uiText(context, "Autónomo"))), DropdownMenuItem(value: 'empresa', child: Text(uiText(context, "Empresa")))], onChanged: saving ? null : (value) { if (value != null) setState(() => accountType = value); }),
            const SizedBox(height: 16),  Text(uiText(context, "DATOS PERSONALES"), style: TextStyle(color: marketAccent, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
            field(accountType == 'empresa' ? 'Nombre y apellidos de la persona de contacto' : 'Nombre y apellidos', name, requiredField: true),
            if (isProfessional) field('Razón social', businessName, requiredField: true),
            if (isProfessional) field('CIF/NIF o identificación fiscal', fiscalId, requiredField: true) else field('DNI/NIE (opcional)', fiscalId),
            field('Teléfono', phone, requiredField: true, keyboard: TextInputType.phone), field('Ciudad', city, requiredField: true), field('Provincia', province, requiredField: true),
            if (isProfessional) ...[
              field(accountType == 'empresa' ? 'Dirección fiscal de la empresa' : 'Dirección fiscal o profesional', address, requiredField: true),
              Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: aboutUs, maxLines: 5, maxLength: 2000, decoration:  InputDecoration(labelText: uiText(context, "Sobre nosotros"), hintText: uiText(context, "Presenta tu negocio, experiencia y servicios.")))),
            ],
            const SizedBox(height: 24), FilledButton.icon(onPressed: saving ? null : saveProfile, style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)), icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: Text(saving ? uiText(context, "Guardando...") : uiText(context, "Guardar perfil"))),
          ]))
        : ListView(padding: const EdgeInsets.all(16), children: [
            if (isProfessional)
              MarketProfessionalHeader(name: businessName.text.trim().isNotEmpty ? businessName.text.trim() : name.text, accountLabel: uiText(context, accountType == 'autonomo' ? 'Autónomo' : 'Empresa'), coverUrl: coverUrl, avatarUrl: profileUrl, location: [city.text, province.text].where((v) => v.trim().isNotEmpty).join(', '))
            else
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: panel, border: Border.all(color: marketAccent.withValues(alpha: .35))),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                if (coverUrl != null) SizedBox(height: 145, width: double.infinity, child: Image.network(coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: marketSurface, alignment: Alignment.center, child: const Icon(Icons.landscape_outlined, color: marketAccent, size: 34)))),
                Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 20), child: Column(children: [
                  CircleAvatar(radius: 48, backgroundColor: gold, backgroundImage: profileUrl == null ? null : NetworkImage(profileUrl), child: profileUrl == null ? const Icon(Icons.person, color: Colors.black, size: 42) : null),
                  const SizedBox(height: 12),
                  Text(name.text.isEmpty ? email : name.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(accountType == 'autonomo' ? uiText(context, "AUTÓNOMO") : accountType == 'empresa' ? uiText(context, "EMPRESA") : uiText(context, "PARTICULAR"), style: const TextStyle(color: marketAccent, letterSpacing: 1.3, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                   Text(uiText(context, "Tu identidad en AUTOMOTORS"), style: TextStyle(color: marketMuted, fontSize: 12)),
                ])),
              ]),
            ),
            const SizedBox(height: 18),
             Text(uiText(context, "TU INFORMACIÓN"), style: TextStyle(color: marketAccent, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Divider(height: 28),  Text(uiText(context, "DATOS DE LA CUENTA"), style: TextStyle(color: marketAccent, fontWeight: FontWeight.bold)), _readOnlyRow(uiText(context, "Correo electrónico"), email),
             Text(uiText(context, "DATOS PERSONALES"), style: TextStyle(color: marketAccent, fontWeight: FontWeight.bold)), _readOnlyRow(uiText(context, "Nombre y apellidos"), name.text), _readOnlyRow(uiText(context, "Teléfono"), phone.text), _readOnlyRow(uiText(context, "Ciudad"), city.text), _readOnlyRow(uiText(context, "Provincia"), province.text),
            if (isProfessional) _readOnlyRow(uiText(context, "Razón social"), businessName.text),
            if (isProfessional) ...[_readOnlyRow(uiText(context, "Identificación fiscal"), fiscalId.text), _readOnlyRow(uiText(context, "Dirección fiscal"), address.text)],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GaragePage()),
                ),
                icon: const Icon(Icons.directions_car_outlined),
                label:  Text(uiText(context, "Mis anuncios")),
                style: OutlinedButton.styleFrom(
                  foregroundColor: marketAccent,
                  side: BorderSide(color: marketAccent.withValues(alpha: .65)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => setState(() => editing = true),
                icon: const Icon(Icons.edit),
                label:  Text(uiText(context, "Editar perfil")),
                style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const ModerationEntry(),
            const AccountDeletionEntry(),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: signOutFromProfile,
                icon: const Icon(Icons.logout_rounded),
                label:  Text(uiText(context, "Cerrar sesión")),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
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
  final version = TextEditingController();
  final transmission = TextEditingController();
  final bodyType = TextEditingController();
  final color = TextEditingController();
  final doors = TextEditingController();
  final seats = TextEditingController();
  final emissionsStandard = TextEditingController();
  final Set<String> selectedEquipment = {};
  bool showMatriculaPublicly = false;
  bool showVinPublicly = false;
  String fuel = 'Diésel';
  String? label;
  int existingPhotoCount=0;
  bool loading = true;
  bool saving = false;

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { year.dispose(); km.dispose(); price.dispose(); phone.dispose(); description.dispose(); matricula.dispose(); cv.dispose(); cilindrada.dispose(); vin.dispose(); version.dispose(); transmission.dispose(); bodyType.dispose(); color.dispose(); doors.dispose(); seats.dispose(); emissionsStandard.dispose(); super.dispose(); }

  Future<void> load() async {
    try {
      final row = await supabase.from('vehicle_listings').select('id,status,year,km,price,fuel,phone,description,matricula,show_matricula_publicly,cv,cilindrada_cc,etiqueta_medioambiental,vin,show_vin_publicly,version,transmission,body_type,color,doors,seats,emissions_standard,equipment,vehicle_photos(id)').eq('id', widget.listingId).eq('owner_id', supabase.auth.currentUser!.id).single();
      if (row['status']?.toString() == 'sold') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(uiText(context, "Un vehículo vendido no se puede editar."))));
        if (mounted) Navigator.pop(context, false);
        return;
      }
      existingPhotoCount=(row['vehicle_photos'] as List?)?.length??0;
      year.text = '${row['year'] ?? ''}'; km.text = '${row['km'] ?? ''}'; price.text = '${row['price'] ?? ''}'; phone.text = '${row['phone'] ?? ''}'; description.text = '${row['description'] ?? ''}'; matricula.text = '${row['matricula'] ?? ''}'; cv.text = '${row['cv'] ?? ''}'; cilindrada.text = '${row['cilindrada_cc'] ?? ''}'; vin.text = '${row['vin'] ?? ''}';
      version.text = '${row['version'] ?? ''}'; transmission.text = '${row['transmission'] ?? ''}'; bodyType.text = '${row['body_type'] ?? ''}'; color.text = '${row['color'] ?? ''}'; doors.text = '${row['doors'] ?? ''}'; seats.text = '${row['seats'] ?? ''}';
      emissionsStandard.text = '${row['emissions_standard'] ?? ''}';
      selectedEquipment
        ..clear()
        ..addAll(row['equipment'] is List ? List<String>.from((row['equipment'] as List).map((item) => item.toString())) : const <String>[]);
      showMatriculaPublicly = row['show_matricula_publicly'] == true;
      showVinPublicly = row['show_vin_publicly'] == true;
      fuel = row['fuel']?.toString() ?? 'Diésel'; label = row['etiqueta_medioambiental']?.toString();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uiText(context, "No se pudieron cargar los datos del anuncio: {0}", [e])))); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> save() async {
    final current = await supabase.from('vehicle_listings').select('status').eq('id', widget.listingId).eq('owner_id', supabase.auth.currentUser!.id).maybeSingle();
    if (current == null || current['status']?.toString() == 'sold') {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(uiText(context, "Un vehículo vendido no se puede editar."))));
      if (mounted) Navigator.pop(context, false);
      return;
    }
    if (!formKey.currentState!.validate()) return;
    final y = int.tryParse(year.text.trim()), k = int.tryParse(km.text.trim());
    final p = double.tryParse(price.text.trim().replaceAll('.', '').replaceAll(',', '.'));
    if (y == null || k == null || p == null || p <= 0) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(uiText(context, "Revisa año, kilómetros y precio.")))); return; }
    setState(() => saving = true);
    try {
      await supabase.from('vehicle_listings').update({'status':'draft','year': y, 'km': k, 'price': p, 'fuel': fuel, 'phone': phone.text.replaceAll(RegExp(r'[^0-9]'), ''), 'description': description.text.trim(), 'matricula': matricula.text.trim().isEmpty ? null : matricula.text.trim().toUpperCase(), 'show_matricula_publicly': showMatriculaPublicly, 'show_vin_publicly': showVinPublicly, 'cv': int.tryParse(cv.text.trim()), 'cilindrada_cc': int.tryParse(cilindrada.text.trim()), 'etiqueta_medioambiental': label, 'vin': vin.text.trim().isEmpty ? null : vin.text.trim().toUpperCase(), 'version': version.text.trim().isEmpty ? null : version.text.trim(), 'transmission': transmission.text.trim().isEmpty ? null : transmission.text.trim(), 'body_type': bodyType.text.trim().isEmpty ? null : bodyType.text.trim(), 'color': color.text.trim().isEmpty ? null : color.text.trim(), 'doors': int.tryParse(doors.text.trim()), 'seats': int.tryParse(seats.text.trim()), 'emissions_standard': emissionsStandard.text.trim().isEmpty ? null : emissionsStandard.text.trim(), 'equipment': selectedEquipment.toList()}).eq('id', widget.listingId).eq('owner_id', supabase.auth.currentUser!.id);
      var saveMessage='Anuncio actualizado.';
      final previousStatus=current['status']?.toString();
      if(previousStatus=='published'||previousStatus=='reserved') {
        final result=await ContentPublicationService().publish(widget.listingId,targetStatus:previousStatus!);
        saveMessage=result.published?'Anuncio actualizado.':result.message;
      }
      if(mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(uiText(context,saveMessage))));Navigator.pop(context,true);}

    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uiText(context, "No se pudo guardar el anuncio: {0}", [e])))); }
    finally { if (mounted) setState(() => saving = false); }
  }

  Widget textField(String label, TextEditingController controller, {bool numeric = false, bool required = false, bool multiline = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : (multiline ? TextInputType.multiline : TextInputType.text),
      minLines: multiline ? 4 : 1,
      maxLines: multiline ? 8 : 1,
      textInputAction: multiline ? TextInputAction.newline : TextInputAction.next,
      textAlignVertical: multiline ? TextAlignVertical.top : TextAlignVertical.center,
      decoration: InputDecoration(
        labelText: uiText(context, label),
        alignLabelWithHint: multiline,
        hintText: multiline
            ? uiText(context, "Puedes separar la información en líneas. Incluye estado, mantenimiento y extras.")
            : null,
      ),
      validator: (v) => required && (v == null || v.trim().isEmpty) ? uiText(context, 'Completa este campo') : null,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title:  Text(uiText(context, "Editar anuncio"))), body: loading ? const Center(child: CircularProgressIndicator(color: marketAccent)) : Form(key: formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
    textField('Año', year, numeric: true, required: true), textField('Kilómetros', km, numeric: true, required: true), textField('Precio (€)', price, numeric: true, required: true),
    DropdownButtonFormField<String>(isExpanded: true, value: ['Diésel','Gasolina','Híbrido','Eléctrico'].contains(fuel) ? fuel : 'Diésel', decoration:  InputDecoration(labelText: uiText(context, "Combustible")), items:  [DropdownMenuItem(value:'Diésel',child:Text(uiText(context, "Diésel"))),DropdownMenuItem(value:'Gasolina',child:Text(uiText(context, "Gasolina"))),DropdownMenuItem(value:'Híbrido',child:Text(uiText(context, "Híbrido"))),DropdownMenuItem(value:'Eléctrico',child:Text(uiText(context, "Eléctrico")))], onChanged: (v) { if (v != null) setState(() => fuel = v); }),
    textField('Teléfono de contacto', phone), textField('Versión', version), textField('Transmisión', transmission), textField('Carrocería', bodyType), textField('Color exterior', color), textField('Puertas', doors, numeric: true), textField('Plazas', seats, numeric: true), textField('Norma de emisiones', emissionsStandard), textField('Matrícula', matricula), textField('Potencia (CV)', cv, numeric: true), textField('Cilindrada (cc)', cilindrada, numeric: true), textField('VIN / número de bastidor', vin),
    CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title:  Text(uiText(context, "Mostrar matrícula en el anuncio público")), subtitle:  Text(uiText(context, "Si lo desactivas, solo se conservará para la gestión del anuncio.")), value: showMatriculaPublicly, activeColor: gold, onChanged: (value) => setState(() => showMatriculaPublicly = value ?? false)),
    CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title:  Text(uiText(context, "Mostrar VIN / bastidor en el anuncio público")), subtitle:  Text(uiText(context, "Es opcional; por privacidad se mantiene oculto si no lo activas.")), value: showVinPublicly, activeColor: gold, onChanged: (value) => setState(() => showVinPublicly = value ?? false)),
     Padding(padding: EdgeInsets.only(bottom: 8), child: Text(uiText(context, "Equipamiento"), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
    ...['Asientos deportivos','Asientos calefactables','Asientos ventilados','Volante multifunción','Climatizador bizona','Navegador','Apple CarPlay / Android Auto','Sensores de aparcamiento','Cámara trasera','Control de crucero','Control de crucero adaptativo','Faros LED','Faros Matrix / adaptativos','Techo solar','Tapicería de cuero','Portón eléctrico','Acceso y arranque sin llave','Detector de ángulo muerto','Mantenimiento en servicio oficial'].map((item) => CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(uiText(context, item)), value: selectedEquipment.contains(item), activeColor: gold, onChanged: (checked) => setState(() { if (checked == true) { selectedEquipment.add(item); } else { selectedEquipment.remove(item); } }))),
    DropdownButtonFormField<String>(isExpanded: true, value: environmentalLabels.contains(label) ? label : 'Sin etiqueta', decoration:  InputDecoration(labelText: uiText(context, "Etiqueta medioambiental")), items: environmentalLabels.map((v) => DropdownMenuItem(value: v, child: Text(uiText(context, v)))).toList(), onChanged: (v) => setState(() => label = v)),
    Text(uiText(context,'El texto y las fotografías del anuncio se analizarán con OpenAI para detectar contenido inapropiado antes de publicarlo. Si falla la comprobación, se conservará como borrador.')),
    const SupportLinks(),
    ListingPreparation(photoCount:existingPhotoCount,description:description,hasEquipment:selectedEquipment.isNotEmpty),
    textField('Descripción', description, multiline: true), const SizedBox(height: 12), FilledButton.icon(onPressed: saving ? null : save, style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black), icon: const Icon(Icons.save), label: Text(saving ? uiText(context, "Guardando...") : uiText(context, "Guardar cambios"))),
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
              row['vehicle_photo'] = await downloadVehiclePhoto(path);
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
        title:  Text(uiText(context, "Mis mensajes"), style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: uiText(context, "Actualizar mensajes"),
            onPressed: () => setState(() => future = loadConversations()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: marketAccent));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  uiText(context, "No se pudieron cargar los mensajes. Comprueba que has iniciado sesión y aplicado la migración de chat.\n\n{0}", [snapshot.error]),
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
                  children:  [
                    Icon(Icons.forum_outlined, size: 54, color: marketAccent),
                    SizedBox(height: 14),
                    Text(uiText(context, "Todavía no tienes conversaciones"),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text(uiText(context, "Cuando contactes con un vendedor, tus mensajes aparecerán aquí."),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: marketMuted)),
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
                color: marketSurface,
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                  side: BorderSide(color: marketInk.withValues(alpha: .08)),
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
                            color: marketSurface,
                            child: photo is Uint8List
                                ? Image.memory(photo, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.directions_car_filled, color: marketAccent, size: 34))
                                : const Icon(Icons.directions_car_filled, color: marketAccent, size: 34),
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
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(sellerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: marketAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(isBuyer ? uiText(context, "Vendedor") : uiText(context, "Comprador"),
                                style: const TextStyle(color: marketMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (unreadCount > 0)
                          Container(
                            constraints: const BoxConstraints(minWidth: 23),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: const BoxDecoration(color: marketAccent, shape: BoxShape.circle),
                            child: Text('$unreadCount', textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, color: marketAccent),
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

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  late final ChatSafetyController chatSafety;
  void _safetyChanged() { if (mounted) setState(() {}); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) chatSafety.load();
  }
  final controller = TextEditingController();
  bool sending = false;
  bool openingParticipant = false;
  bool? isChatBuyer;
  bool markingRead = false;
  late final Stream<List<Map<String, dynamic>>> messagesStream;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    chatSafety = ChatSafetyController(conversationId: widget.conversationId);
    chatSafety.addListener(_safetyChanged);
    chatSafety.load();
    _loadChatRole();
    messagesStream = supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .order('created_at');
  }

  Future<void> _loadChatRole() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final row = await supabase.from('chat_conversations')
          .select('buyer_id, seller_id')
          .eq('id', widget.conversationId).maybeSingle();
      if (!mounted || supabase.auth.currentUser?.id != userId || row == null) return;
      if (row['buyer_id'] == userId || row['seller_id'] == userId) {
        setState(() => isChatBuyer = row['buyer_id'] == userId);
      }
    } catch (_) {
      // Keep suggestions hidden when the participant role cannot be confirmed.
    }
  }

  Future<void> openParticipantProfile() async {
    if (openingParticipant) return;
    setState(() => openingParticipant = true);
    try {
      final participantId = await loadChatParticipantId(supabase, widget.conversationId);
      if (!mounted) return;
      await Navigator.push<void>(context, MaterialPageRoute(
        builder: (_) => PublicSellerProfilePage(ownerId: participantId),
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uiText(context, 'No se pudo abrir el perfil de esta persona. Inténtalo de nuevo.')),
      ));
    } finally {
      if (mounted) setState(() => openingParticipant = false);
    }
  }

  Future<void> openVehicleListing() async {
    final listingId = widget.listingId;
    if (listingId == null || listingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "No se ha podido identificar el anuncio de este chat."))),
      );
      return;
    }
    try {
      final raw = await supabase
          .from('vehicle_listings')
          .select('id, year, km, price, fuel, description, phone, matricula, vin, show_matricula_publicly, show_vin_publicly, cv, cilindrada_cc, etiqueta_medioambiental, owner_id, status, vehicle_brands(name), vehicle_models(name), vehicle_photos(storage_path, position)')
          .eq('id', listingId)
          .maybeSingle();
      if (raw == null || !['published', 'reserved'].contains(raw['status']?.toString())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(uiText(context, "Este anuncio ya no está disponible."))),
          );
        }
        return;
      }
      final car = await buyerCarFromListing(raw);
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
          SnackBar(content: Text(uiText(context, "No se pudo abrir el anuncio: {0}", [error]))),
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
    if (day == today) return uiText(context, 'HOY');
    if (day == today.subtract(const Duration(days: 1))) return uiText(context, 'AYER');
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

  void _composeSuggestion(String text) {
    if (sending || !chatSafety.canMessage) return;
    final draft = controller.text.trim();
    final combined = draft.isEmpty ? text : '$draft\n$text';
    if (combined.length > 5000) return;
    controller.value = TextEditingValue(text: combined, selection: TextSelection.collapsed(offset: combined.length));
  }

  Future<void> sendMessage() async {
    final text = controller.text.trim();
    final user = supabase.auth.currentUser;
    if (text.isEmpty || user == null || sending || !chatSafety.canMessage) return;
    setState(() => sending = true);
    try {
      await supabase.from('chat_messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': user.id,
        'body': text,
      });
      if (mounted && controller.text.trim() == text) controller.clear();
    } catch (error) {
      AppDiagnostics.record('chat',error);
      chatSafety.load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uiText(context, "No se pudo enviar el mensaje. Comprueba el acceso al chat y vuelve a intentarlo."))),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    chatSafety.removeListener(_safetyChanged);
    chatSafety.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(tooltip:uiText(context,'Ofertas y citas'),onPressed:!chatSafety.canMessage?null:()=>Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>ChatMarketPage(conversationId:widget.conversationId))),icon:const Icon(Icons.event_available_outlined)),
          IconButton(
            key: const Key('chat-participant-profile'),
            tooltip: uiText(context, 'Ver perfil de la otra persona'),
            onPressed: openingParticipant ? null : openParticipantProfile,
            icon: openingParticipant
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.person_outline),
          ),
          ChatSafetyControls(controller: chatSafety),
        ],
        titleSpacing: 0,
        title: Row(
          children: [
            Tooltip(
              message: uiText(context, 'Ver anuncio del vehículo'),
              child: InkWell(
                onTap: openVehicleListing,
                borderRadius: BorderRadius.circular(9),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: 42,
                    height: 42,
                    color: marketSurface,
                    child: widget.vehiclePhoto != null
                        ? Image.memory(widget.vehiclePhoto!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.directions_car_filled, color: marketAccent, size: 24))
                        : const Icon(Icons.directions_car_filled, color: marketAccent, size: 24),
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
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
              color: Color(0xFFFFFFFF),
              border: Border(bottom: BorderSide(color: marketLine)),
            ),
            child: Row(
              children:  [
                Icon(Icons.directions_car_outlined, color: marketAccent, size: 16),
                SizedBox(width: 7),
                Expanded(child: Text(uiText(context, "Conversación sobre este vehículo"),
                  style: TextStyle(color: marketMuted, fontSize: 12))),
              ],
            ),
          ),
          ChatSafetyBanner(controller: chatSafety),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.local_offer_outlined),
                label: Text(uiText(context, isChatBuyer == true
                    ? 'Hacer una oferta' : 'Ofertas y citas')),
                onPressed: !chatSafety.canMessage ? null : () => Navigator.push<void>(
                  context, MaterialPageRoute(builder: (_) => ChatMarketPage(
                    conversationId: widget.conversationId))),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return  Center(child: Text(uiText(context, "No se pueden cargar los mensajes.")));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: marketAccent));
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
                  return  Center(
                    child: Text(uiText(context, "Empieza la conversación sobre este vehículo."),
                      style: TextStyle(color: marketMuted)),
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
                            decoration: BoxDecoration(color: marketLine, borderRadius: BorderRadius.circular(20)),
                            child: Text(_dayLabel(sentAt), style: const TextStyle(color: marketMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .7)),
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
                                  style: TextStyle(color: mine ? Colors.black : marketInk, height: 1.35),
                                )),
                                const SizedBox(height: 4),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(_timeLabel(sentAt), style: TextStyle(color: mine ? Colors.black54 : marketMuted, fontSize: 10)),
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
          if (isChatBuyer != null)
            MarketChatActions(enabled: chatSafety.canMessage && !sending,
              isBuyer: isChatBuyer!, onCompose: _composeSuggestion),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                border: Border(top: BorderSide(color: marketLine)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: chatSafety.canMessage && !sending,
                      maxLength: 5000,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: uiText(context, "Escribe un mensaje..."),
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
                      onPressed: sending || !chatSafety.canMessage ? null : sendMessage,
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

class PublishOptionsPage extends StatefulWidget {
  const PublishOptionsPage({super.key,this.allowPublication=true});
  final bool allowPublication;

  @override
  State<PublishOptionsPage> createState() => _PublishOptionsPageState();
}

class _PublishOptionsPageState extends State<PublishOptionsPage> with WidgetsBindingObserver {
  late final StorePurchaseService _purchaseService;
  StreamSubscription<String>? _purchaseMessages;
  StreamSubscription<void>? _purchaseChanges;
  VerifiedStorePlans _verifiedPlans = VerifiedStorePlans.empty;
  Timer? _planExpiryTimer;
  String? _planAccessError;
  bool _openingPublication = false;
  int _planRead = 0;

  Future<void> _loadVerifiedPlans() async {
    final read = ++_planRead;
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    try {
      final rows = user == null ? <Map<String, dynamic>>[] : await db
        .from('user_subscriptions')
        .select('product_id, status, started_at, created_at, expires_at')
        .eq('user_id', user.id);
      if (!mounted || read != _planRead) return;
      final plans = VerifiedStorePlans.fromRows(List<Map<String, dynamic>>.from(rows));
      _planExpiryTimer?.cancel();
      setState(() { _verifiedPlans = plans; _planAccessError = null; });
      final expiry = plans.nextExpiry;
      if (expiry != null) {
        final remaining = expiry.difference(DateTime.now().toUtc());
        _planExpiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, _loadVerifiedPlans);
      }
    } catch (_) {
      if (!mounted || read != _planRead) return;
      _planExpiryTimer?.cancel();
      setState(() {
        _verifiedPlans = VerifiedStorePlans.empty;
        _planAccessError = appText('No se pudo consultar tu plan. Reintenta para comprobar el acceso.',
          'Could not load your plan. Retry to check access.');
      });
    }
  }

  Future<void> _openPublication([String? productId]) async {
    if (_openingPublication) return;
    setState(() => _openingPublication = true);
    try {
      if (Supabase.instance.client.auth.currentUser == null) {
        final loggedIn = await requireAutomotorsLogin(context);
        if (!loggedIn || !mounted) return;
      }
      if (productId != null) {
        await _loadVerifiedPlans();
        if (!mounted) return;
        if (!_verifiedPlans.isActive(productId)) {
          throw Exception(appText('El pago aún no está verificado o el plan ha caducado.',
            'Payment is not verified yet or the plan has expired.'));
        }
      }
      final allowed = await Supabase.instance.client.rpc('can_publish_vehicle_listing');
      if (!mounted) return;
      if (allowed != true) {
        throw Exception(appText('Has alcanzado el límite de anuncios activos de tu cuenta.',
          'You have reached your active listing limit.'));
      }
      final car = await Navigator.push<Car>(context, MaterialPageRoute(builder: (_) => const AddCarPage()));
      if (car != null && mounted) Navigator.pop(context, car);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _openingPublication = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadVerifiedPlans();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _purchaseService = StorePurchaseService();
    _purchaseMessages = _purchaseService.messages.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uiText(context, message))),
      );
    });
    _purchaseChanges = _purchaseService.changes.listen((_) {
      if (mounted) setState(() {});
      _loadVerifiedPlans();
    });
    _purchaseService.initialize();
    _loadVerifiedPlans();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _planExpiryTimer?.cancel();
    _purchaseMessages?.cancel();
    _purchaseChanges?.cancel();
    _purchaseService.dispose();
    super.dispose();
  }

  static const Color _gold = marketAccent;
  static const Color _bg = marketPaper;
  static const Color _panel = Color(0xFFFFFFFF);

  bool get _usesSpanishAppStoreCatalog => kIsWeb || defaultTargetPlatform == TargetPlatform.iOS;

  String _storePrice(String productId) {
    for (final product in _purchaseService.products) {
      if (product.id != productId) continue;
      final price = _usesSpanishAppStoreCatalog
          ? spanishStoreDisplayPrice(product)
          : storeDisplayPrice(product);
      if (price == null) return uiText(context, 'Precio no disponible');
      final period = storeSubscriptionPeriod(product);
      final message = storePeriodMessage(product);
      if (period != null && message != null) {
        return '$price / ${uiText(context, message, [period.count])}';
      }
      return price;
    }
    // Public Spanish catalog while StoreKit loads; checkout still requires a
    // real store product, billing metadata, authentication and verification.
    final configured = _usesSpanishAppStoreCatalog ? configuredSpanishSubscriptionPrice(productId) : null;
    if (configured != null) return '$configured / ${uiText(context, "mes")}';
    return uiText(context, 'Precio no disponible');
  }

  @override
  Widget build(BuildContext context) {
    final packs = <_PublishPackData>[
      _PublishPackData(
        title: uiText(context, "PACK 10"), price: _storePrice('automotors_pack_10'), icon: Icons.diamond_outlined,
        subtitle: appText('Todo lo necesario para empezar', 'Everything you need to get started'), cars: appText('10 anuncios · 3 destacados', '10 listings · 3 featured'),
        benefits: const ['Publica hasta 10 vehículos', 'Hasta 3 anuncios destacados', 'Visible en búsquedas', 'Gestión desde tu perfil'],
      ),
      _PublishPackData(
        title: uiText(context, "PACK 15"), price: _storePrice('automotors_pack_15'), icon: Icons.diamond_outlined,
        subtitle: appText('Más visibilidad para tu negocio', 'More visibility for your business'), cars: appText('15 anuncios · 5 destacados', '15 listings · 5 featured'), popular: true,
        benefits: const ['Publica hasta 15 vehículos', 'Hasta 5 anuncios destacados', 'Etiquetas destacadas', 'Prioridad en búsquedas', 'Estadísticas de visitas'],
      ),
      _PublishPackData(
        title: uiText(context, "PACK 20"), price: _storePrice('automotors_pack_20'), icon: Icons.diamond_outlined,
        subtitle: appText('Para concesionarios con más stock', 'For dealers with larger inventories'), cars: appText('20 anuncios · 8 destacados', '20 listings · 8 featured'),
        benefits: const ['Publica hasta 20 vehículos', 'Hasta 8 anuncios destacados', 'Mayor visibilidad', 'Prioridad en búsquedas', 'Estadísticas de visitas'],
      ),
      _PublishPackData(
        title: uiText(context, "AUTOMOTORS PRO"), price: _storePrice('automotors_pro_monthly_199'), icon: Icons.workspace_premium_rounded,
        subtitle: appText('Para una venta profesional sin límites', 'Professional selling without listing limits'), cars: appText('Anuncios ilimitados · hasta 15 destacados', 'Unlimited listings · up to 15 featured'),
        benefits: const ['Anuncios ilimitados mientras esté activa', 'Hasta 15 vehículos destacados', 'Máxima visibilidad', 'Prioridad en búsquedas', 'Estadísticas avanzadas', 'Soporte prioritario'],
      ),
    ];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0,
        leading: IconButton(tooltip:uiText(context,'Volver'),icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
        title: Text(appText('Publicar mi vehículo', 'List my vehicle'), style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      bottomNavigationBar: !widget.allowPublication?null:SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(color: _panel, border: Border(top: BorderSide(color: Color(0xFFE4E5DF)))),
          child: OutlinedButton.icon(
            onPressed: _openingPublication ? null : () => _openPublication(),
            icon: const Icon(Icons.sell_outlined), label: Text(appText('PUBLICAR GRATIS  →', 'LIST FOR FREE  →')),
            style: OutlinedButton.styleFrom(foregroundColor: _gold, side: const BorderSide(color: _gold, width: 1.6), padding: const EdgeInsets.symmetric(vertical: 15), textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        children: [
          const ListingContextHelp(plans:true),
          if(widget.allowPublication)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:FilledButton.icon(onPressed:_openingPublication?null:()=>_openPublication(),icon:const Icon(Icons.add),label:Text(uiText(context,'Empezar mi anuncio gratis')))),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold.withValues(alpha: .5)),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF)]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(appText('LLEGA A MÁS COMPRADORES', 'REACH MORE BUYERS'), style: const TextStyle(color: _gold, fontSize: 20, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text(appText('Elige la opción que mejor se adapte a ti.\nAumenta la visibilidad de tus anuncios con nuestros packs.', 'Choose the plan that suits you best.\nIncrease your listing visibility with our plans.'), style: TextStyle(color: marketInk, height: 1.4)),
            ]),
          ),
          const SizedBox(height: 16),
          for (final pack in packs) ...[
            _PublishPackCard(
              data: pack,
              onPublish: widget.allowPublication && _verifiedPlans.isActive(switch (pack.title) {
                'PACK 10' => 'automotors_pack_10', 'PACK 15' => 'automotors_pack_15',
                'PACK 20' => 'automotors_pack_20', _ => 'automotors_pro_monthly_199',
              }) && !_openingPublication
                ? () => _openPublication(switch (pack.title) {
                    'PACK 10' => 'automotors_pack_10', 'PACK 15' => 'automotors_pack_15',
                    'PACK 20' => 'automotors_pack_20', _ => 'automotors_pro_monthly_199',
                  }) : null,
              onSelect: StorePurchaseService.checkoutEnabled &&
                      _purchaseService.products.any((product) => storePeriodMessage(product) != null && (!_usesSpanishAppStoreCatalog || spanishStoreDisplayPrice(product) != null) && product.id == switch (pack.title) {
                        'PACK 10' => 'automotors_pack_10',
                        'PACK 15' => 'automotors_pack_15',
                        'PACK 20' => 'automotors_pack_20',
                        'AUTOMOTORS PRO' => 'automotors_pro_monthly_199',
                        _ => '',
                      })
                  ? () {
                final productId = switch (pack.title) {
                  'PACK 10' => 'automotors_pack_10',
                  'PACK 15' => 'automotors_pack_15',
                  'PACK 20' => 'automotors_pack_20',
                  'AUTOMOTORS PRO' => 'automotors_pro_monthly_199',
                  _ => '',
                };
                if (productId.isNotEmpty) {
                  _purchaseService.purchaseSubscription(productId);
                }
              }
                  : null,
            ),
            const SizedBox(height: 14),
          ],
          const SubscriptionDisclosure(),
          TextButton.icon(
            onPressed: _purchaseService.restorePurchases,
            icon: const Icon(Icons.restore_rounded),
            label: Text(appText('Restaurar compras', 'Restore purchases')),
          ),
          if (_planAccessError != null) ...[
            Text(uiText(context, _planAccessError!), style: const TextStyle(color: Color(0xFF805200))),
            TextButton(onPressed: _loadVerifiedPlans, child: Text(appText('Reintentar', 'Retry'))),
          ],
          Text(appText('El acceso se activa después de verificar el pago. Puedes restaurar tus compras con la misma cuenta.',
            'Access is enabled after payment verification. You can restore purchases with the same account.'),
            style: const TextStyle(color: marketMuted, fontSize: 12), textAlign: TextAlign.center),
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
  final VoidCallback? onSelect;
  final VoidCallback? onPublish;
  const _PublishPackCard({required this.data, required this.onSelect, this.onPublish});
  static const Color gold = Color(0xFFFFC447);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: marketPaper, borderRadius: BorderRadius.circular(19),
        border: Border.all(color: data.popular ? gold : const Color(0xFFE4E5DF), width: data.popular ? 2 : 1),
        boxShadow: data.popular ? [BoxShadow(color: marketAccent.withValues(alpha: .14), blurRadius: 16)] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (data.popular) Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: marketAccent, borderRadius: BorderRadius.circular(20)), child:  Text(uiText(context, "MÁS POPULAR"), style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(data.icon, color: marketAccent, size: 32), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data.title, style: TextStyle(color: data.popular ? marketAccent : marketInk, fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(data.subtitle, style: const TextStyle(color: marketMuted, fontSize: 12))]),),
        ]),
        const SizedBox(height: 10),
        Text(data.price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8), Padding(padding: const EdgeInsets.only(left: 44), child: Text(data.cars, style: const TextStyle(color: marketAccent, fontWeight: FontWeight.w700))),
        const SizedBox(height: 10),
        for (final benefit in data.benefits) Padding(padding: const EdgeInsets.only(left: 44, bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_rounded, color: marketAccent, size: 18), const SizedBox(width: 7), Expanded(child: Text(uiText(context, benefit), style: const TextStyle(color: marketMuted, fontSize: 13)))])),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: onSelect, style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 13)), child: Text(appText('Elegir ${data.title}', 'Choose ${data.title}'), style: const TextStyle(fontWeight: FontWeight.w700)))),
        if (onPublish != null) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: onPublish,
            icon: const Icon(Icons.add_circle_outline),
            label: Text(appText('Publicar vehículo', 'List vehicle')),
            style: OutlinedButton.styleFrom(foregroundColor: marketAccent, side: const BorderSide(color: marketAccent)),
          )),
        ],
      ]),
    );
  }
}

class AddCarPage extends StatefulWidget {
  final LocalMarketState? localState;
  const AddCarPage({super.key, this.localState});

  @override
  State<AddCarPage> createState() => _AddCarPageState();
}

class _AddCarPageState extends State<AddCarPage> with WidgetsBindingObserver {
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
  String transmission = 'Automático';
  String bodyType = 'Berlina';
  final Set<String> selectedEquipment = {};
  bool showMatriculaPublicly = false;
  bool showVinPublicly = false;

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
  bool _previewingPublication=false;
  bool vehicleLookupBusy = false;
  bool loadingVehicleLookupAccess = true;
  bool canLookupVehicle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draftOwner = Supabase.instance.client.auth.currentUser?.id;
    for (final controller in _draftFields.values) { controller.addListener(_scheduleDraft); }
    _initializeDraft();
    loadVehicleLookupAccess();
  }

  LocalMarketState get _draftStorage => widget.localState ?? _localMarketState;
  Timer? _draftTimer;
  Future<void> _draftWrites = Future.value();
  List<String> _persistedPhotoPaths = [];
  List<String> _photoSources = [];
  Future<void> _persistDraft() {
    final owner=_draftOwner; if(owner==null || _draftCompleted)return Future.value();
    final snapshot=_draftSnapshot(); final selected=List<XFile>.of(photos);
    final work=_draftWrites.then((_) async {
      final sources=selected.map((p)=>p.path).toList();
      if(!listEquals(sources,_photoSources)) {
        _persistedPhotoPaths=await persistDraftPhotos(owner,selected);
        _photoSources=sources;
      }
      snapshot['photoPaths']=_persistedPhotoPaths;
      await _draftStorage.write(_draftKey,snapshot);
    });
    _draftWrites=work.catchError((Object _){});return work;
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.inactive || state==AppLifecycleState.paused) {
      _draftTimer?.cancel(); if(!_restoringDraft && !_draftCompleted)unawaited(_persistDraft().catchError((Object _){}));
    }
  }
  bool _restoringDraft = true;
  bool _draftCompleted = false;
  late final String? _draftOwner;
  String get _draftKey => 'automotors.publication-draft.v1.$_draftOwner';
  Map<String, TextEditingController> get _draftFields => {
    'year': year, 'km': km, 'price': price, 'phone': phone,
    'description': description, 'matricula': matricula, 'vin': vin,
    'cv': cv, 'cilindradaCc': cilindradaCc, 'version': version,
    'doors': doors, 'seats': seats, 'color': color, 'emissionsStandard': emissionsStandard,
  };
  Map<String, dynamic> _draftSnapshot() => {
    'fields': _draftFields.map((key, value) => MapEntry(key, value.text)),
    'brand': selectedBrandId, 'model': selectedModelId,
    'fuel': fuel, 'transmission': transmission, 'body': bodyType,
    'label': etiquetaMedioambiental, 'equipment': selectedEquipment.toList(),
    'showPlate': showMatriculaPublicly, 'showVin': showVinPublicly,
    'photoCount': photos.length,
  };
  void _updatePublication(VoidCallback change) {
    setState(change);
    _scheduleDraft();
  }
  void _scheduleDraft() {
    if (_restoringDraft || publishing || _draftCompleted || _draftOwner == null ||
        Supabase.instance.client.auth.currentUser?.id != _draftOwner) return;
    _draftTimer?.cancel();
    _publicationDraftPhotos[_draftOwner] = List.of(photos);
    _draftTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_persistDraft().catchError((Object _) {}));
    });
  }
  Future<void> _saveDraft() async {
    if (_restoringDraft || publishing || _draftOwner == null ||
        Supabase.instance.client.auth.currentUser?.id != _draftOwner) return;
    _draftTimer?.cancel();
    try {
      await _persistDraft();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uiText(context, 'Borrador guardado en este dispositivo.'))));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uiText(context, 'No se pudo guardar el borrador. Inténtalo de nuevo.'))));
    }
  }
  Future<void> _initializeDraft() async {
    await loadBrands();
    final saved = _draftOwner == null ? <String, dynamic>{} : await _draftStorage.read(_draftKey);
    if (!mounted || Supabase.instance.client.auth.currentUser?.id != _draftOwner) return;
    if (saved.isNotEmpty) {
      final fields = saved['fields'];
      if (fields is Map) {
        for (final entry in _draftFields.entries) {
          if (fields[entry.key] is String) entry.value.text = fields[entry.key] as String;
        }
      }
      if (saved['brand'] is int && brands.any((brand) => brand['id'] == saved['brand'])) {
        selectedBrandId = saved['brand'] as int;
        await loadModels(selectedBrandId!);
        if (!mounted) return;
        if (saved['model'] is int && models.any((model) => model['id'] == saved['model'])) selectedModelId = saved['model'] as int;
      }
      final allowedFuel = ['Diésel', 'Gasolina', 'Híbrido', 'Eléctrico', 'GLP', 'GNC'];
      if (allowedFuel.contains(saved['fuel'])) fuel = saved['fuel'] as String;
      if (['Manual', 'Automático', 'Automático (DSG)'].contains(saved['transmission'])) transmission = saved['transmission'] as String;
      if (['Berlina','Compacto','SUV','Familiar','Coupé','Cabrio','Monovolumen','Furgoneta','Pickup'].contains(saved['body'])) bodyType = saved['body'] as String;
      if (['Sin etiqueta','B','C','ECO','0'].contains(saved['label'])) etiquetaMedioambiental = saved['label'] as String;
      if (saved['equipment'] is List) selectedEquipment.addAll((saved['equipment'] as List).whereType<String>());
      showMatriculaPublicly = saved['showPlate'] == true;
      showVinPublicly = saved['showVin'] == true;
      if(_draftOwner!=null && saved['photoPaths'] is List) {
        List<XFile> restored=[];
        try {restored=await restoreDraftPhotos(_draftOwner!,List<String>.from(saved['photoPaths']));}catch(_) {/* Retain text if local photos are unavailable. */}
        if(!mounted)return;
        photos.addAll(restored);_persistedPhotoPaths=List<String>.from(saved['photoPaths']);_photoSources=restored.map((p)=>p.path).toList();
      }
      if(photos.isEmpty)photos.addAll(_publicationDraftPhotos[_draftOwner] ?? []);
    }
    setState(() => _restoringDraft = false);
    if (saved.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uiText(context, photos.isEmpty && saved['photoCount'] is num && (saved['photoCount'] as num) > 0
      ? 'Borrador recuperado. Vuelve a seleccionar las fotografías.' : 'Borrador recuperado. Puedes continuar donde lo dejaste.'))));
  }
  void _completeDraft() {
    _draftCompleted = true;
    _draftTimer?.cancel();
    _publicationDraftPhotos.remove(_draftOwner);
    unawaited(_draftWrites.then((_) async {await _draftStorage.remove(_draftKey);if(_draftOwner!=null)await clearDraftPhotos(_draftOwner!);}).catchError((Object _) {}));
  }

  Future<void> loadVehicleLookupAccess() async {
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) {
      if (mounted) _updatePublication(() {
        loadingVehicleLookupAccess = false;
        canLookupVehicle = false;
      });
      return;
    }
    try {
      final response = await supabase.functions.invoke(
        'lookup-vehicle',
        body: {'access_only': true},
      );
      final allowed = response.status >= 200 &&
          response.status < 300 &&
          response.data is Map &&
          response.data['allowed'] == true;
      if (!mounted) return;
      _updatePublication(() {
        canLookupVehicle = allowed;
        loadingVehicleLookupAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      _updatePublication(() {
        canLookupVehicle = false;
        loadingVehicleLookupAccess = false;
      });
    }
  }

  Future<void> showPackages() async {
    if(!mounted)return;
    await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>const PublishOptionsPage(allowPublication:false)));
  }

  Future<void> showSubscriptionInfo() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:  Text(uiText(context, "AUTOMOTORS PRO")),
        content:  Text(
          uiText(context, "199 €/mes. Publicaciones ilimitadas y prioridad para todos tus anuncios mientras la suscripción esté activa. La compra y renovación se gestionarán mediante la tienda del dispositivo. Las suscripciones aún no están activadas y no se realizará ningún cobro."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:  Text(uiText(context, "Cerrar")),
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
      _updatePublication(() {
        brands
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(rows));
        loadingBrands = false;
      });
    } catch (error) {
      if (!mounted) return;
      _updatePublication(() => loadingBrands = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uiText(context, "No se pudieron cargar las marcas: {0}", [error]))),
      );
    }
  }

  Future<void> loadModels(int brandId) async {
    _updatePublication(() {
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
      if (!mounted || selectedBrandId != brandId) return;
      _updatePublication(() {
        models.addAll(List<Map<String, dynamic>>.from(rows));
        loadingModels = false;
      });
    } catch (error) {
      if (!mounted || selectedBrandId != brandId) return;
      _updatePublication(() => loadingModels = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uiText(context, "No se pudieron cargar los modelos: {0}", [error]))),
      );
    }
  }

  String _normalizeCatalogName(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]'), '');

  int? _readVehicleNumber(dynamic value) {
    if (value == null) return null;
    final match = RegExp(r'\d+').firstMatch(value.toString());
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  Future<void> lookupVehicle() async {
    if (vehicleLookupBusy) return;
    if (!canLookupVehicle) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "Esta función requiere PACK 20 o una suscripción AUTOMOTORS PRO activa."))),
      );
      return;
    }
    final plate = matricula.text.trim().toUpperCase();
    final chassis = vin.text.trim().toUpperCase();
    if (plate.isEmpty == chassis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "Introduce una matrícula o un VIN, pero no ambos para la misma búsqueda."))),
      );
      return;
    }
    if (chassis.isNotEmpty && chassis.length != 17) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "El VIN debe tener 17 caracteres."))),
      );
      return;
    }
    _updatePublication(() => vehicleLookupBusy = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'lookup-vehicle',
        body: plate.isNotEmpty ? {'plate': plate} : {'vin': chassis},
      );
      final payload = response.data;
      if (response.status < 200 || response.status >= 300) {
        final message = payload is Map ? payload['error']?.toString() : null;
        throw Exception(message?.isNotEmpty == true ? message : 'No se pudo consultar el vehículo.');
      }
      if (payload is! Map || payload['data'] is! Map) {
        throw Exception('La respuesta del proveedor no contiene una ficha válida.');
      }
      final data = Map<String, dynamic>.from(payload['data'] as Map);
      String valueOf(List<String> keys) {
        for (final key in keys) {
          final value = data[key];
          if (value != null && value.toString().trim().isNotEmpty) return value.toString().trim();
        }
        return '';
      }
      final brandName = valueOf(['brand', 'make']);
      final modelName = valueOf(['model', 'modelName']);
      final versionName = valueOf(['version', 'trim', 'variant']);
      final firstDate = valueOf(['firstRegistrationDate', 'registrationDate', 'year']);
      final power = _readVehicleNumber(data['powerHP'] ?? data['powerHp'] ?? data['powerCV']);
      final displacement = _readVehicleNumber(data['displacementCcm'] ?? data['displacementCC'] ?? data['engineDisplacement']);
      final gearbox = valueOf(['gearboxType', 'transmission']).toLowerCase();
      final fuelValue = valueOf(['fuelType', 'fuel']).toLowerCase();
      final bodyValue = valueOf(['bodyType', 'bodyStyle']).toLowerCase();
      final environmentalValue = valueOf(['environmentalLabel', 'dgtLabel', 'environmentalSticker']).toUpperCase();
      final apiVin = valueOf(['vin', 'chassisNumber']);
      final apiPlate = valueOf(['plate', 'registrationNumber']);

      if (brandName.isNotEmpty) {
        final wantedBrand = _normalizeCatalogName(brandName);
        final brand = brands.where((row) => _normalizeCatalogName(row['name'].toString()) == wantedBrand).firstOrNull;
        if (brand != null) {
          final brandId = (brand['id'] as num).toInt();
          _updatePublication(() => selectedBrandId = brandId);
          await loadModels(brandId);
          if (!mounted) return;
          final wantedModel = _normalizeCatalogName(modelName);
          final model = models.where((row) => _normalizeCatalogName(row['name'].toString()) == wantedModel).firstOrNull;
          if (model != null) _updatePublication(() => selectedModelId = (model['id'] as num).toInt());
        }
      }

      _updatePublication(() {
        if (firstDate.length >= 4) {
          final yearMatch = RegExp(r'^(\d{4})').firstMatch(firstDate);
          if (yearMatch != null) year.text = yearMatch.group(1)!;
        }
        if (power != null) cv.text = '$power';
        if (displacement != null) cilindradaCc.text = '$displacement';
        if (versionName.isNotEmpty) version.text = versionName;
        if (apiVin.isNotEmpty) vin.text = apiVin.toUpperCase();
        if (apiPlate.isNotEmpty) matricula.text = apiPlate.toUpperCase();
        if (gearbox.contains('manual')) {
          transmission = 'Manual';
        } else if (gearbox.contains('dsg')) {
          transmission = 'Automático (DSG)';
        } else if (gearbox.contains('auto')) {
          transmission = 'Automático';
        }
        if (fuelValue.contains('diesel') || fuelValue.contains('diésel')) {
          fuel = 'Diésel';
        } else if (fuelValue.contains('petrol') || fuelValue.contains('gasoline') || fuelValue.contains('gasolina')) {
          fuel = 'Gasolina';
        } else if (fuelValue.contains('electric') || fuelValue.contains('eléctrico')) {
          fuel = 'Eléctrico';
        } else if (fuelValue.contains('hybrid') || fuelValue.contains('híbrido')) {
          fuel = 'Híbrido';
        }
        if (bodyValue.contains('suv')) {
          bodyType = 'SUV';
        } else if (bodyValue.contains('hatch') || bodyValue.contains('compact')) {
          bodyType = 'Compacto';
        } else if (bodyValue.contains('estate') || bodyValue.contains('wagon') || bodyValue.contains('familiar')) {
          bodyType = 'Familiar';
        } else if (bodyValue.contains('coupe') || bodyValue.contains('coupé')) {
          bodyType = 'Coupé';
        } else if (bodyValue.contains('convertible') || bodyValue.contains('cabrio')) {
          bodyType = 'Cabrio';
        } else if (bodyValue.contains('van') || bodyValue.contains('furgoneta')) {
          bodyType = 'Furgoneta';
        } else if (bodyValue.contains('pickup')) {
          bodyType = 'Pickup';
        } else if (bodyValue.contains('sedan') || bodyValue.contains('saloon') || bodyValue.contains('berlina')) {
          bodyType = 'Berlina';
        }
        if (environmentalLabels.contains(environmentalValue)) etiquetaMedioambiental = environmentalValue;
        final doorCount = _readVehicleNumber(data['doors']);
        final seatCount = _readVehicleNumber(data['seats'] ?? data['seatingCapacity']);
        if (doorCount != null) doors.text = '$doorCount';
        if (seatCount != null) seats.text = '$seatCount';
        final exteriorColor = valueOf(['color', 'exteriorColor']);
        if (exteriorColor.isNotEmpty) color.text = exteriorColor;
        final emissions = valueOf(['emissionsStandard', 'emissionStandard']);
        if (emissions.isNotEmpty) emissionsStandard.text = emissions;
      });
      final brandMatched = selectedBrandId != null;
      final modelMatched = selectedModelId != null;
      final missing = <String>[];
      if (brandName.isNotEmpty && !brandMatched) missing.add('selecciona la marca');
      if (modelName.isNotEmpty && !modelMatched) missing.add('selecciona el modelo del catálogo');
      final note = missing.isEmpty
          ? uiText(context, 'Datos técnicos encontrados. Revisa la ficha antes de publicar.')
          : uiText(context, 'Datos encontrados. Además, revisa la marca y el modelo del catálogo antes de publicar.');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(note), duration: const Duration(seconds: 6)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo rellenar el vehículo: ' + error.toString().replaceFirst('Exception: ', '')), duration: const Duration(seconds: 7)),
      );
    } finally {
      if (mounted) _updatePublication(() => vehicleLookupBusy = false);
    }
  }

  Future<void> pickPhotos() async {
    final remaining = 15 - photos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "Máximo 15 fotografías por vehículo."))),
      );
      return;
    }
    try {
      final selected = await imagePicker.pickMultiImage(
        limit: remaining,
        imageQuality: 72,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (!mounted || selected.isEmpty) return;
      final accepted=<XFile>[];
      for(final photo in selected.take(15-photos.length)) {
        if(await photo.length()<=6*1024*1024)accepted.add(photo);
      }
      if(!mounted)return;
      _updatePublication(() => photos.addAll(accepted));
      await _persistDraft();
      if(mounted && accepted.length<selected.length)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(uiText(context,'Alguna foto supera 6 MB. Elige una versión más pequeña.'))));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uiText(context, "No se pudieron seleccionar las fotos: {0}", [error]))),
      );
    }
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    bool numeric = false,
    bool requiredField = true,
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : (multiline ? TextInputType.multiline : TextInputType.text),
        minLines: multiline ? 4 : 1,
        maxLines: multiline ? 8 : 1,
        textInputAction: multiline ? TextInputAction.newline : TextInputAction.next,
        textAlignVertical: multiline ? TextAlignVertical.top : TextAlignVertical.center,
        decoration: InputDecoration(
          labelText: uiText(context, label),
          alignLabelWithHint: multiline,
          hintText: multiline
              ? uiText(context, "Puedes separar la información en líneas. Incluye estado, mantenimiento y extras.")
              : null,
        ),
        onChanged: (_) {
          if (mounted) _updatePublication(() {});
        },
        validator: (value) {
          final text = value?.trim() ?? '';
          if (requiredField && text.isEmpty) {
            return uiText(context, 'Completa este campo');
          }
          if (text.isEmpty) return null;

          if (numeric) {
            if (label.startsWith('Precio')) {
              final parsedPrice = double.tryParse(
                text.replaceAll('.', '').replaceAll(',', '.'),
              );
              if (parsedPrice == null) return uiText(context, 'Introduce un precio válido');
              if (parsedPrice <= 0) return uiText(context, 'El precio debe ser mayor que cero');
            } else {
              final parsedNumber = int.tryParse(text);
              if (parsedNumber == null) return uiText(context, 'Introduce un número entero válido');
              if (parsedNumber < 0) return uiText(context, 'El valor no puede ser negativo');
            }
          }

          if (label.startsWith('Teléfono')) {
            final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
            if (digits.length < 9 || digits.length > 15) {
              return uiText(context, 'Introduce un teléfono válido (9–15 cifras)');
            }
          }
          return null;
        },
      ),
    );
  }

  List<MapEntry<String, bool>> get listingQualityChecks {
    final yearValue = int.tryParse(year.text.trim());
    final kmValue = int.tryParse(km.text.trim());
    final priceValue = double.tryParse(
      price.text.trim().replaceAll('.', '').replaceAll(',', '.'),
    );
    return [
      MapEntry('Marca y modelo seleccionados', selectedBrandId != null && selectedModelId != null),
      MapEntry('Año válido', yearValue != null && yearValue >= 1886 && yearValue <= DateTime.now().year + 1),
      MapEntry('Kilometraje válido', kmValue != null && kmValue >= 0),
      MapEntry('Precio válido', priceValue != null && priceValue > 0),
      MapEntry('Al menos 3 fotografías', photos.length >= 3),
      MapEntry('Descripción detallada', description.text.trim().length >= 40),
      MapEntry('Datos técnicos adicionales', cv.text.trim().isNotEmpty || cilindradaCc.text.trim().isNotEmpty || version.text.trim().isNotEmpty),
    ];
  }

  Widget buildListingQualityCard() {
    final checks = listingQualityChecks;
    final completed = checks.where((item) => item.value).length;
    final progress = completed / checks.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: marketAccent.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: marketAccent),
              const SizedBox(width: 8),
               Expanded(
                child: Text(uiText(context, "Calidad de tu anuncio"), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Text('$completed/${checks.length}', style: const TextStyle(color: marketAccent, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: marketLine,
              valueColor: const AlwaysStoppedAnimation<Color>(gold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            completed == checks.length
                ? uiText(context, "¡Excelente! Tu anuncio incluye la información clave para generar confianza.")
                : uiText(context, "Completa estas recomendaciones para que los compradores conozcan mejor el vehículo."),
            style: const TextStyle(color: marketMuted, height: 1.35, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...checks.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  item.value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 17,
                  color: item.value ? gold : marketMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    uiText(context, item.key),
                    style: TextStyle(
                      fontSize: 12,
                      color: item.value ? marketInk : marketMuted,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Future<void> publishCar() async {
    if (publishing || _previewingPublication || vehicleLookupBusy || !formKey.currentState!.validate()) return;

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
         SnackBar(
          content: Text(uiText(context, "Revisa año, kilómetros y precio.")),
        ),
      );
      return;
    }

    final brandId = selectedBrandId;
    final modelId = selectedModelId;
    if (brandId == null || modelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "Selecciona una marca y un modelo."))),
      );
      return;
    }
    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "Añade al menos una fotografía."))),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "Debes iniciar sesión para publicar."))),
      );
      return;
    }

    final selectedBrand = brands.firstWhere(
      (row) => (row['id'] as num).toInt() == brandId,
    );
    final selectedModel = models.firstWhere(
      (row) => (row['id'] as num).toInt() == modelId,
    );

    _updatePublication(()=>_previewingPublication=true);
    bool? accepted;
    try {accepted=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>PublicationPreviewPage(
      title:'${selectedBrand['name']} ${selectedModel['name']} ${version.text.trim()}'.trim(),price:'${priceValue.toStringAsFixed(priceValue==priceValue.roundToDouble()?0:2).replaceAll('.',',')} €',
      details:{'Año':'$yearValue','Kilómetros':'$kmValue','Combustible':fuel,'Cambio':transmission,'Carrocería':bodyType,'Etiqueta medioambiental':etiquetaMedioambiental??'',
        'Color':color.text.trim(),'CV':cv.text.trim(),'Cilindrada (cc)':cilindradaCc.text.trim(),'Puertas':doors.text.trim(),'Plazas':seats.text.trim(),'Normativa de emisiones':emissionsStandard.text.trim(),
        ...publicationIdentifiers(showPlate:showMatriculaPublicly,showVin:showVinPublicly,plate:matricula.text,vin:vin.text),if(phoneValue.isNotEmpty)'Teléfono':phoneValue},
      description:description.text.trim(),photos:List.of(photos),equipment:selectedEquipment.toList(),
    )));
    }finally{if(mounted)_updatePublication(()=>_previewingPublication=false);}
    if(accepted!=true || !mounted)return;
    if(supabase.auth.currentUser?.id!=user.id){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(uiText(context,'La sesión ha cambiado. Abre de nuevo el formulario.'))));return;}
    _updatePublication(() => publishing = true);
    final uploadedPaths = <String>[];
    final uploadedPhotoBytes=<Uint8List>[];
    bool publishedOnServer=false;
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
        'show_matricula_publicly': showMatriculaPublicly,
        'show_vin_publicly': showVinPublicly,
        'cv': int.tryParse(cv.text.trim()),
        'cilindrada_cc': int.tryParse(cilindradaCc.text.trim()),
        'version': version.text.trim().isEmpty ? null : version.text.trim(),
        'transmission': transmission,
        'body_type': bodyType,
        'doors': int.tryParse(doors.text.trim()),
        'seats': int.tryParse(seats.text.trim()),
        'color': color.text.trim().isEmpty ? null : color.text.trim(),
        'emissions_standard': emissionsStandard.text.trim().isEmpty ? null : emissionsStandard.text.trim(),
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
        uploadedPhotoBytes.add(bytes);
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

      final approval=await ContentPublicationService().publish(listingId);
      _completeDraft();
      if(!approval.published) {
        if(mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(uiText(context,approval.message)),duration:const Duration(seconds:8)));Navigator.pop(context);}
        return; // Preserve the draft and photographs on rejection or provider failure.
      }

      publishedOnServer=true;
      final photoBytes=uploadedPhotoBytes;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(uiText(context, "¡Anuncio publicado correctamente!"))),
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
          vin: showVinPublicly ? vin.text.trim().toUpperCase() : null,
          showMatriculaPublicly: showMatriculaPublicly,
          showVinPublicly: showVinPublicly,
          photos: photoBytes,
          listingId: listingId,
          ownerId: user.id,
        ),
      );
    } catch (error) {
      AppDiagnostics.record('publication',error);
      if(publishedOnServer) {
        if(mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(uiText(context,'Tu anuncio se ha publicado. Actualiza el catálogo para verlo.'))));Navigator.pop(context);}
        return; // A local display failure must never delete an approved publication.
      }
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
      if (error is PostgrestException && error.code == 'P0001') {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(uiText(context, "Has alcanzado el límite de publicaciones de tu plan."))),
        );
        await showPackages();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiText(context, "No se pudo publicar el anuncio: {0}", [error])),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) _updatePublication(() => publishing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    if (!_restoringDraft && !_draftCompleted && _draftOwner != null && Supabase.instance.client.auth.currentUser?.id == _draftOwner) {
      unawaited(_persistDraft().catchError((Object _) {}));
    }
    for (final controller in _draftFields.values) { controller.removeListener(_scheduleDraft); }
    year.dispose();
    km.dispose();
    price.dispose();
    phone.dispose();
    description.dispose();
    matricula.dispose();
    vin.dispose();
    cv.dispose();
    cilindradaCc.dispose();
    version.dispose();
    doors.dispose();
    seats.dispose();
    color.dispose();
    emissionsStandard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).publishVehicle, style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(tooltip: uiText(context, 'Guardar borrador'), onPressed: publishing || _restoringDraft ? null : _saveDraft, icon: const Icon(Icons.save_outlined)),
          IconButton(tooltip: uiText(context, "Planes y packs"), onPressed: showPackages,
            icon: const Icon(Icons.workspace_premium_rounded, color: marketAccent)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            border: Border(top: BorderSide(color: marketLine)),
          ),
          child: Row(children: [
            Expanded(child: FilledButton.icon(
              onPressed: publishing || _previewingPublication || _restoringDraft || vehicleLookupBusy ? null : publishCar,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: Text(publishing ? uiText(context, "Comprobando y publicando…") : uiText(context, "Revisar mi anuncio")),
              style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black),
            )),
          ]),
        ),
      ),
      body: _draftOwner != Supabase.instance.client.auth.currentUser?.id ? Center(child: Text(uiText(context, 'La sesión ha cambiado. Abre de nuevo el formulario.'))) : _restoringDraft ? const Center(child: CircularProgressIndicator()) : Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: marketAccent.withValues(alpha: .35)),
              ),
              child:  Row(children: [
                Icon(Icons.directions_car_filled, color: marketAccent, size: 30),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(uiText(context, "Publica tu vehículo"), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text(uiText(context, "Completa los datos y añade fotografías. Los planes y packs se consultan por separado."), style: TextStyle(color: marketMuted, height: 1.35)),
                ])),
              ]),
            ),
            const SizedBox(height: 14),
            Text(uiText(context,'El texto y las fotografías del anuncio se analizarán con OpenAI para detectar contenido inapropiado antes de publicarlo. Si falla la comprobación, se conservará como borrador.')),
            const SupportLinks(),
            const ListingContextHelp(),
            buildListingQualityCard(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: showPackages,
                icon: const Icon(Icons.workspace_premium, color: marketAccent),
                label:  Text(uiText(context, "Ver planes y packs"), style: TextStyle(color: marketAccent, fontWeight: FontWeight.w700)),
              ),
            ),
            const Divider(color: Color(0xFFE4E5DF)),
            const SizedBox(height: 12),
            if (loadingVehicleLookupAccess)
               Card(
                color: panel,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Expanded(child: Text(uiText(context, "Comprobando acceso al autocompletado…"), style: TextStyle(color: marketMuted))),
                  ]),
                ),
              )
            else if (canLookupVehicle)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: marketAccent.withValues(alpha: .45)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                   Row(children: [
                    Icon(Icons.manage_search_rounded, color: marketAccent),
                    SizedBox(width: 8),
                    Expanded(child: Text(uiText(context, "Rellenar ficha automáticamente"), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  ]),
                  const SizedBox(height: 6),
                   Text(uiText(context, "Función exclusiva de PACK 20 y AUTOMOTORS PRO. Introduce la matrícula o el VIN y revisa los datos técnicos antes de publicar."), style: TextStyle(color: marketMuted, height: 1.35, fontSize: 12)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: matricula,
                      textCapitalization: TextCapitalization.characters,
                      decoration:  InputDecoration(labelText: uiText(context, "Matrícula"), hintText: uiText(context, "1234 ABC")),
                      onChanged: (_) => _updatePublication(() {}),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: vin,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 17,
                      decoration:  InputDecoration(labelText: uiText(context, "VIN / bastidor"), hintText: uiText(context, "17 caracteres"), counterText: ''),
                      onChanged: (_) => _updatePublication(() {}),
                    )),
                  ]),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: FilledButton.icon(
                    onPressed: vehicleLookupBusy || (matricula.text.trim().isEmpty == vin.text.trim().isEmpty) ? null : lookupVehicle,
                    icon: vehicleLookupBusy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.auto_fix_high_rounded),
                    label: Text(vehicleLookupBusy ? uiText(context, "Buscando datos…") : uiText(context, "Buscar y rellenar ficha")),
                    style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black),
                  )),
                ]),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: marketAccent.withValues(alpha: .4)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                   Row(children: [
                    Icon(Icons.lock_outline_rounded, color: marketAccent),
                    SizedBox(width: 8),
                    Expanded(child: Text(uiText(context, "Autocompletado exclusivo"), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  ]),
                  const SizedBox(height: 6),
                   Text(uiText(context, "La búsqueda por matrícula o VIN solo está disponible para clientes con PACK 20 activo o suscripción AUTOMOTORS PRO vigente. Puedes completar la ficha manualmente."), style: TextStyle(color: marketMuted, height: 1.4, fontSize: 12)),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: showPackages,
                    icon: const Icon(Icons.workspace_premium_rounded, color: marketAccent),
                    label:  Text(uiText(context, "Ver packs y suscripción")),
                    style: OutlinedButton.styleFrom(foregroundColor: marketAccent, side: const BorderSide(color: marketAccent)),
                  )),
                ]),
              ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(isExpanded: true,
              initialValue: selectedBrandId,
              decoration:  InputDecoration(labelText: uiText(context, "Marca")),
              hint: Text(loadingBrands ? uiText(context, "Cargando marcas...") : uiText(context, "Selecciona una marca")),
              items: brands.map((row) {
                final id = (row['id'] as num).toInt();
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(row['name'].toString()),
                );
              }).toList(),
              validator: (value) => value == null ? uiText(context, 'Selecciona una marca') : null,
              onChanged: loadingBrands ? null : (value) {
                if (value == null) return;
                _updatePublication(() => selectedBrandId = value);
                loadModels(value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(isExpanded: true,
              key: ValueKey('models-$selectedBrandId'),
              initialValue: selectedModelId,
              decoration:  InputDecoration(labelText: uiText(context, "Modelo")),
              hint: Text(selectedBrandId == null
                  ? uiText(context, "Primero selecciona una marca")
                  : loadingModels ? uiText(context, "Cargando modelos...") : uiText(context, "Selecciona un modelo")),
              items: models.map((row) {
                final id = (row['id'] as num).toInt();
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(row['name'].toString()),
                );
              }).toList(),
              validator: (value) => value == null ? uiText(context, 'Selecciona un modelo') : null,
              onChanged: selectedBrandId == null || loadingModels
                  ? null
                  : (value) => _updatePublication(() => selectedModelId = value),
            ),
            const SizedBox(height: 12),
            buildTextField('Año', year, numeric: true),
            buildTextField('Kilómetros', km, numeric: true),
            buildTextField('Precio en euros', price, numeric: true),
            DropdownButtonFormField<String>(isExpanded: true,
              initialValue: fuel,
              decoration:  InputDecoration(labelText: uiText(context, "Combustible")),
              items:  [
                DropdownMenuItem(value: 'Diésel', child: Text(uiText(context, "Diésel"))),
                DropdownMenuItem(value: 'Gasolina', child: Text(uiText(context, "Gasolina"))),
                DropdownMenuItem(value: 'Híbrido', child: Text(uiText(context, "Híbrido"))),
                DropdownMenuItem(value: 'Eléctrico', child: Text(uiText(context, "Eléctrico"))),
              ],
              onChanged: (value) { if (value != null) _updatePublication(() => fuel = value); },
            ),
            const SizedBox(height: 12),
            buildTextField('Matrícula (opcional)', matricula, requiredField: false),
            buildTextField('VIN / número de bastidor (opcional)', vin, requiredField: false),
            CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title:  Text(uiText(context, "Mostrar matrícula en el anuncio público")), subtitle:  Text(uiText(context, "Si no lo marcas, la matrícula quedará oculta a los visitantes.")), value: showMatriculaPublicly, activeColor: gold, onChanged: (value) => _updatePublication(() => showMatriculaPublicly = value ?? false)),
            CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title:  Text(uiText(context, "Mostrar VIN / bastidor en el anuncio público")), subtitle:  Text(uiText(context, "Opcional. Por privacidad, estará oculto si no lo activas.")), value: showVinPublicly, activeColor: gold, onChanged: (value) => _updatePublication(() => showVinPublicly = value ?? false)),
            buildTextField('Potencia en CV (opcional)', cv, numeric: true, requiredField: false),
            buildTextField('Cilindrada en cc (opcional)', cilindradaCc, numeric: true, requiredField: false),
            DropdownButtonFormField<String>(isExpanded: true,
              initialValue: etiquetaMedioambiental,
              decoration:  InputDecoration(labelText: uiText(context, "Etiqueta medioambiental")),
              items: environmentalLabels.map((label) => DropdownMenuItem<String>(
                value: label,
                child: Row(children: [
                  Icon(environmentalLabelIcon(label), color: environmentalLabelColor(label), size: 22),
                  const SizedBox(width: 10),
                  Text(uiText(context, label)),
                ]),
              )).toList(),
              onChanged: (value) => _updatePublication(() => etiquetaMedioambiental = value),
            ),
            const SizedBox(height: 20),
            ExpansionTile(
              key: const Key('optional-vehicle-specifications'),
              maintainState: true,
              tilePadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune_rounded, color: marketAccent),
              title: Text(uiText(context, "Ficha técnica ampliada")),
              subtitle: Text(uiText(context, "Opcional")),
              children: [
            buildTextField('Versión / acabado (opcional)', version, requiredField: false),
            DropdownButtonFormField<String>(isExpanded: true,
              initialValue: transmission,
              decoration:  InputDecoration(labelText: uiText(context, "Transmisión")),
              items:  [
                DropdownMenuItem(value: 'Manual', child: Text(uiText(context, "Manual"))),
                DropdownMenuItem(value: 'Automático', child: Text(uiText(context, "Automático"))),
                DropdownMenuItem(value: 'Automático (DSG)', child: Text(uiText(context, "Automático (DSG)"))),
              ],
              onChanged: (value) { if (value != null) _updatePublication(() => transmission = value); },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(isExpanded: true,
              initialValue: bodyType,
              decoration:  InputDecoration(labelText: uiText(context, "Tipo de carrocería")),
              items:  [
                DropdownMenuItem(value: 'Berlina', child: Text(uiText(context, "Berlina"))),
                DropdownMenuItem(value: 'Compacto', child: Text(uiText(context, "Compacto"))),
                DropdownMenuItem(value: 'SUV', child: Text(uiText(context, "SUV"))),
                DropdownMenuItem(value: 'Familiar', child: Text(uiText(context, "Familiar"))),
                DropdownMenuItem(value: 'Coupé', child: Text(uiText(context, "Coupé"))),
                DropdownMenuItem(value: 'Cabrio', child: Text(uiText(context, "Cabrio"))),
                DropdownMenuItem(value: 'Monovolumen', child: Text(uiText(context, "Monovolumen"))),
                DropdownMenuItem(value: 'Furgoneta', child: Text(uiText(context, "Furgoneta"))),
                DropdownMenuItem(value: 'Pickup', child: Text(uiText(context, "Pickup"))),
              ],
              onChanged: (value) { if (value != null) _updatePublication(() => bodyType = value); },
            ),
            const SizedBox(height: 12),
            buildTextField('Puertas', doors, numeric: true, requiredField: false),
            buildTextField('Plazas', seats, numeric: true, requiredField: false),
            buildTextField('Color exterior', color, requiredField: false),
            buildTextField('Normativa de emisiones (opcional)', emissionsStandard, requiredField: false),
            const SizedBox(height: 8),
             Text(uiText(context, "Equipamiento confirmado"), style: TextStyle(fontWeight: FontWeight.bold)),
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
              title: Text(uiText(context, item)),
              value: selectedEquipment.contains(item),
              activeColor: gold,
              onChanged: (checked) => _updatePublication(() {
                if (checked == true) { selectedEquipment.add(item); }
                else { selectedEquipment.remove(item); }
              }),
            )),
            const SizedBox(height: 12),
              ],
            ),
            const SizedBox(height: 16),
            buildTextField('Teléfono (opcional; el chat funciona dentro de la app)', phone, numeric: true, requiredField: false),
            ListingPreparation(photoCount:photos.length,description:description,hasEquipment:selectedEquipment.isNotEmpty),
            buildTextField('Descripción', description, requiredField: false, multiline: true),
            Text(
              uiText(context, "Fotografías del vehículo ({0}/15)", [photos.length]),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: publishing ? null : pickPhotos,
              icon: const Icon(Icons.add_photo_alternate),
              label:  Text(uiText(context, "Seleccionar fotografías")),
            ),
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 8),
               Text(
                uiText(context, "La primera fotografía será la principal. Puedes elegir otra sin volver a subir las fotos."),
                style: TextStyle(color: marketMuted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 145+48*(MediaQuery.textScalerOf(context).scale(1)-1),
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
                              return Image.memory(snapshot.data!, fit: BoxFit.contain,semanticLabel:uiText(context,'Fotografía {0} de {1}',[index+1,photos.length]));
                            },
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            tooltip: uiText(context, "Eliminar fotografía {0}",[index+1]),
                            onPressed: publishing ? null : () => _updatePublication(() => photos.removeAt(index)),
                            icon: const Icon(Icons.cancel, color: Colors.red),
                          ),
                        ),
                        if (index > 0)
                          Positioned(left: 0, bottom: 0,
                            child: FilledButton.tonalIcon(
                              onPressed: publishing ? null : () => _updatePublication(() {
                                final selected = photos.removeAt(index);
                                photos.insert(0, selected);
                              }),
                              icon: const Icon(Icons.star_outline_rounded, size: 18),
                              label: Text(uiText(context, "Usar fotografía {0} como principal",[index+1])),
                            )),
                        if (index == 0)
                           Positioned(
                            left: 0,
                            bottom: 0,
                            child: Chip(label: Text(uiText(context, "Principal"))),
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
      Icon(icon, color: marketAccent, size: 25),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(color: marketInk, fontSize: 13, fontWeight: FontWeight.w500))),
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
    color: marketSurface,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFE4E5DF)),
        ),
        child: Row(
          children: [
            const Icon(Icons.layers, color: marketAccent, size: 25),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(packName, style: const TextStyle(color: marketInk, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(listingCount, style: const TextStyle(color: marketMuted, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(price, style: const TextStyle(color: marketAccent, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(width: 1, height: 38, color: const Color(0xFFE4E5DF)),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  const Icon(Icons.star, color: marketAccent, size: 16),
                  const SizedBox(width: 5),
                  Expanded(child: Text(featuredCount, style: const TextStyle(color: marketInk, fontSize: 11, height: 1.25))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: marketAccent, size: 22),
          ],
        ),
      ),
    ),
  );
}
