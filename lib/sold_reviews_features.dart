import 'l10n/ui_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sale confirmation and verified buyer reviews for vehicle listings.
class AutomotorsSoldReviews {
  static final SupabaseClient _db = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> contactedBuyers(String listingId) async {
    final sellerId = _db.auth.currentUser?.id;
    if (sellerId == null) throw Exception('Inicia sesión para gestionar el anuncio.');
    final rows = await _db.from('chat_conversations')
        .select('buyer_id, updated_at')
        .eq('listing_id', listingId).eq('seller_id', sellerId)
        .order('updated_at', ascending: false);
    final seen = <String>{};
    final buyers = List<Map<String, dynamic>>.from(rows).where((row) {
      final id = row['buyer_id']?.toString() ?? '';
      return id.isNotEmpty && seen.add(id);
    }).toList();
    if (buyers.isNotEmpty) {
      try {
        final profiles = await _db.from('public_seller_profiles')
            .select('id, full_name').inFilter('id', buyers.map((b) => b['buyer_id'].toString()).toList());
        final names = {for (final row in List<Map<String, dynamic>>.from(profiles)) row['id'].toString(): row['full_name']?.toString()};
        for (final buyer in buyers) {
          buyer['display_name'] = names[buyer['buyer_id'].toString()];
        }
      } catch (_) {}
    }
    return buyers;
  }

  static Future<void> markSold({required String listingId, String? buyerId, required bool soldExternally}) async {
    await _db.rpc('mark_vehicle_sold', params: {
      'p_listing_id': listingId,
      'p_buyer_id': buyerId,
      'p_sold_externally': soldExternally,
    });
  }

  static Future<void> submitReview({
    required String listingId,
    required String sellerId,
    required int communication,
    required int trust,
    required int vehicleCondition,
    required String reviewText,
  }) async {
    final buyerId = _db.auth.currentUser?.id;
    if (buyerId == null) throw Exception('Inicia sesión para dejar una reseña.');
    if ([communication, trust, vehicleCondition].any((v) => v < 0 || v > 5)) {
      throw ArgumentError('Cada valoración debe estar entre 0 y 5 estrellas.');
    }
    final text = reviewText.trim();
    if (text.isEmpty || text.length > 2000) throw ArgumentError('Escribe una reseña de hasta 2.000 caracteres.');
    final average = (communication + trust + vehicleCondition) / 3;
    await _db.from('vehicle_reviews').insert({
      'listing_id': listingId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'rating': average.round().clamp(0, 5),
      'communication_rating': communication,
      'trust_rating': trust,
      'vehicle_condition_rating': vehicleCondition,
      'review_text': text,
    });
  }
}

class MarkVehicleSoldDialog extends StatefulWidget {
  final String listingId;
  const MarkVehicleSoldDialog({super.key, required this.listingId});
  @override
  State<MarkVehicleSoldDialog> createState() => _MarkVehicleSoldDialogState();
}

class _MarkVehicleSoldDialogState extends State<MarkVehicleSoldDialog> {
  List<Map<String, dynamic>> buyers = [];
  String? selectedBuyer;
  bool loading = true, saving = false, soldExternally = false;
  String? error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { buyers = await AutomotorsSoldReviews.contactedBuyers(widget.listingId); }
    catch (e) { error = uiText(context, 'No se pudieron cargar los compradores: {0}', [e]); }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await AutomotorsSoldReviews.markSold(
        listingId: widget.listingId,
        buyerId: soldExternally ? null : selectedBuyer,
        soldExternally: soldExternally,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() { saving = false; error = uiText(context, 'No se pudo marcar como vendido: {0}', [e]); });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title:  Text(uiText(context, "Marcar vehículo como vendido")),
    content: SizedBox(width: 360, child: loading
      ? const Center(child: CircularProgressIndicator())
      : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
           Text(uiText(context, "¿A quién has vendido este vehículo?")),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: soldExternally,
            title:  Text(uiText(context, "Lo he vendido fuera de AUTOMOTORS")),
            onChanged: saving ? null : (value) => setState(() { soldExternally = value ?? false; selectedBuyer = null; }),
          ),
          if (!soldExternally && buyers.isEmpty)  Text(uiText(context, "No hay conversaciones para este anuncio. Puedes indicar que la venta fue fuera de AUTOMOTORS.")),
          if (!soldExternally && buyers.isNotEmpty) DropdownButtonFormField<String>(
            value: selectedBuyer, isExpanded: true,
            decoration:  InputDecoration(labelText: uiText(context, "Comprador del chat")),
            items: buyers.map((b) {
              final id = b['buyer_id'].toString();
              final name = b['display_name']?.toString().trim() ?? '';
              return DropdownMenuItem(value: id, child: Text(name.isNotEmpty ? name : uiText(context, "Usuario {0}", [id.substring(0, id.length > 8 ? 8 : id.length)])));
            }).toList(),
            onChanged: saving ? null : (v) => setState(() => selectedBuyer = v),
          ),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(uiText(context, error!), style: const TextStyle(color: Colors.redAccent))),
        ])),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.of(context).pop(false), child:  Text(uiText(context, "Cancelar"))),
      FilledButton(onPressed: saving || (!soldExternally && selectedBuyer == null) ? null : _save, child: Text(saving ? uiText(context, "Guardando...") : uiText(context, "Confirmar venta"))),
    ],
  );
}

/// Opens a verified purchase from a review invitation in the in-app inbox.
class BuyerPurchaseReviewPage extends StatefulWidget {
  final String listingId;
  const BuyerPurchaseReviewPage({super.key, required this.listingId});
  @override
  State<BuyerPurchaseReviewPage> createState() => _BuyerPurchaseReviewPageState();
}

class _BuyerPurchaseReviewPageState extends State<BuyerPurchaseReviewPage> {
  late Future<Map<String, dynamic>?> purchase;
  @override
  void initState() { super.initState(); purchase = _load(); }

  Future<Map<String, dynamic>?> _load() async {
    final db = Supabase.instance.client;
    final buyerId = db.auth.currentUser?.id;
    if (buyerId == null) return null;
    final listing = await db.from('vehicle_listings')
        .select('id, owner_id')
        .eq('id', widget.listingId).eq('status', 'sold')
        .eq('sold_externally', false).eq('sold_to_buyer_id', buyerId)
        .maybeSingle();
    if (listing == null || listing['owner_id'] == null) return null;
    final prior = await db.from('vehicle_reviews').select('id')
        .eq('listing_id', widget.listingId).eq('buyer_id', buyerId).maybeSingle();
    return {...listing, 'already_reviewed': prior != null};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title:  Text(uiText(context, "Valora tu compra"))),
    body: FutureBuilder<Map<String, dynamic>?>(
      future: purchase,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
             Text(uiText(context, "No se pudo cargar la compra. Inténtalo de nuevo.")),
            TextButton(
              onPressed: () => setState(() => purchase = _load()),
              child:  Text(uiText(context, "Reintentar")),
            ),
          ]));
        }
        final listing = snapshot.data;
        if (listing == null) {
          return  Center(child: Padding(padding: EdgeInsets.all(24),
            child: Text(uiText(context, "Esta compra no está disponible para valorar con tu cuenta."))));
        }
        if (listing['already_reviewed'] == true) {
          return  Center(child: Text(uiText(context, "Ya has valorado esta compra. ¡Gracias!")));
        }
        return ListView(padding: const EdgeInsets.all(16), children: [
          VehicleReviewForm(listingId: widget.listingId, sellerId: listing['owner_id'].toString()),
        ]);
      },
    ),
  );
}

class VehicleReviewForm extends StatefulWidget {
  final String listingId;
  final String sellerId;
  const VehicleReviewForm({super.key, required this.listingId, required this.sellerId});
  @override
  State<VehicleReviewForm> createState() => _VehicleReviewFormState();
}

class _VehicleReviewFormState extends State<VehicleReviewForm> {
  final controller = TextEditingController();
  int communication = 0, trust = 0, vehicleCondition = 0;
  bool saving = false;
  bool submitted = false;
  String? message;
  late Future<bool> eligible;

  @override
  void initState() { super.initState(); eligible = _checkEligibility(); }

  Future<bool> _checkEligibility() async {
    final buyer = Supabase.instance.client.auth.currentUser?.id;
    if (buyer == null) return false;
    try {
      final listing = await Supabase.instance.client.from('vehicle_listings')
          .select('sold_to_buyer_id').eq('id', widget.listingId).maybeSingle();
      if (listing?['sold_to_buyer_id'] != buyer) return false;
      final prior = await Supabase.instance.client.from('vehicle_reviews')
          .select('id').eq('listing_id', widget.listingId).eq('buyer_id', buyer).maybeSingle();
      return prior == null;
    } catch (_) { return false; }
  }

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() { saving = true; message = null; });
    try {
      await AutomotorsSoldReviews.submitReview(
        listingId: widget.listingId, sellerId: widget.sellerId,
        communication: communication, trust: trust, vehicleCondition: vehicleCondition,
        reviewText: controller.text,
      );
      if (mounted) setState(() { saving = false; submitted = true; message = '¡Gracias! Tu valoración ya aparece en el perfil del vendedor.'; });
    } catch (e) {
      if (mounted) setState(() { saving = false; message = uiText(context, 'No se pudo publicar la valoración. {0}', [e]); });
    }
  }

  Widget _rating(String title, int value, ValueChanged<int> onChanged) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
    ...List.generate(5, (i) => IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: uiText(context, "{0} estrellas", [i + 1]),
      onPressed: saving ? null : () => onChanged(value == i + 1 ? 0 : i + 1),
      icon: Icon(i < value ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 26),
    )),
    SizedBox(width: 24, child: Text('$value', textAlign: TextAlign.end)),
  ]);

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: eligible,
    builder: (context, snapshot) {
      if (snapshot.data != true) return const SizedBox.shrink();
      if (submitted) return Card(child: Padding(
        padding: const EdgeInsets.all(16), child: Text(uiText(context, message!)),
      ));
      return Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
           Text(uiText(context, "Valora tu compra"), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _rating(uiText(context, "Comunicación"), communication, (v) => setState(() => communication = v)),
          _rating(uiText(context, "Confianza"), trust, (v) => setState(() => trust = v)),
          _rating(uiText(context, "Estado del vehículo"), vehicleCondition, (v) => setState(() => vehicleCondition = v)),
          TextField(controller: controller, maxLines: 4, maxLength: 2000, decoration:  InputDecoration(labelText: uiText(context, "Cuéntanos tu experiencia"))),
          if (message != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(uiText(context, message!))),
          FilledButton(onPressed: saving ? null : _submit, child: Text(saving ? uiText(context, "Enviando...") : uiText(context, "Publicar valoración"))),
        ]),
      ));
    },
  );
}

class SellerTrustScore extends StatelessWidget {
  final String sellerId;
  const SellerTrustScore({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: Supabase.instance.client.from('vehicle_reviews')
        .select('communication_rating, trust_rating, vehicle_condition_rating')
        .eq('seller_id', sellerId).then((rows) => List<Map<String, dynamic>>.from(rows)),
    builder: (context, snapshot) {
      final reviews = snapshot.data ?? const <Map<String, dynamic>>[];
      if (reviews.isEmpty) return const Text('—', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800));
      final stars = reviews.fold<double>(0, (sum, r) => sum + ((r['communication_rating'] as num).toDouble() + (r['trust_rating'] as num).toDouble() + (r['vehicle_condition_rating'] as num).toDouble()) / 3);
      final score = 1 + (stars / reviews.length) * 9 / 5;
      return Text(score.toStringAsFixed(1), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800));
    },
  );
}

class SellerReviewsSection extends StatelessWidget {
  final String sellerId;
  const SellerReviewsSection({super.key, required this.sellerId});

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client.from('vehicle_reviews')
      .select('id, listing_id, buyer_id, rating, review_text, communication_rating, trust_rating, vehicle_condition_rating, created_at')
      .eq('seller_id', sellerId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _load(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return  ListTile(title: Text(uiText(context, "No se pudieron cargar las valoraciones.")));
      final reviews = snapshot.data ?? [];
      final avgStars = reviews.isEmpty ? 0.0 : reviews.fold<double>(0, (sum, r) => sum + ((r['communication_rating'] as num).toDouble() + (r['trust_rating'] as num).toDouble() + (r['vehicle_condition_rating'] as num).toDouble()) / 3) / reviews.length;
      final confidence = reviews.isEmpty ? 0.0 : 1 + avgStars * 9 / 5;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(uiText(context, "Valoraciones del vendedor ({0})", [reviews.length]), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        if (reviews.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [const Icon(Icons.verified_user, color: Colors.amber), const SizedBox(width: 6), Text(uiText(context, "Confianza {0} / 10 · {1} valoraciones", [confidence.toStringAsFixed(1), reviews.length]))])),
        if (reviews.isEmpty)  Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text(uiText(context, "Este vendedor todavía no tiene valoraciones."))),
        ...reviews.map((r) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(uiText(context, "Comunicación {0}/5 · Confianza {1}/5 · Vehículo {2}/5", [r['communication_rating'], r['trust_rating'], r['vehicle_condition_rating']]), style: const TextStyle(color: Colors.amber)),
          const SizedBox(height: 6), Text(r['review_text'].toString()),
        ])))),
      ]);
    },
  );
}
