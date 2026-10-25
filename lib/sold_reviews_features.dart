import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Funciones de vendedor/comprador para integrar en las pantallas de anuncios.
/// Requiere la migración 202610230003_sold_vehicle_reviews.sql.
class AutomotorsSoldReviews {
  static final SupabaseClient _db = Supabase.instance.client;

  /// Lista los usuarios que han abierto un chat con el vendedor para este anuncio.
  static Future<List<Map<String, dynamic>>> contactedBuyers(String listingId) async {
    final sellerId = _db.auth.currentUser?.id;
    if (sellerId == null) throw Exception('Inicia sesión para gestionar el anuncio.');
    final rows = await _db
        .from('chat_conversations')
        .select('buyer_id, updated_at')
        .eq('listing_id', listingId)
        .eq('seller_id', sellerId)
        .order('updated_at', ascending: false);
    final seen = <String>{};
    return List<Map<String, dynamic>>.from(rows).where((row) {
      final id = row['buyer_id']?.toString() ?? '';
      return id.isNotEmpty && seen.add(id);
    }).toList();
  }

  /// Marca el anuncio como vendido. El servidor verifica que el comprador
  /// seleccionado tenga una conversación sobre ese anuncio.
  static Future<void> markSold({
    required String listingId,
    required String buyerId,
  }) async {
    await _db.rpc('mark_vehicle_sold', params: {
      'p_listing_id': listingId,
      'p_buyer_id': buyerId,
    });
  }

  /// Envía una reseña. RLS solo acepta al comprador que el vendedor seleccionó
  /// al marcar el anuncio como vendido; una reseña por comprador/anuncio.
  static Future<void> submitReview({
    required String listingId,
    required String sellerId,
    required int rating,
    required String reviewText,
  }) async {
    final buyerId = _db.auth.currentUser?.id;
    if (buyerId == null) throw Exception('Inicia sesión para dejar una reseña.');
    if (rating < 1 || rating > 5) throw ArgumentError('La valoración debe ser de 1 a 5 estrellas.');
    final text = reviewText.trim();
    if (text.isEmpty || text.length > 2000) throw ArgumentError('Escribe una reseña de hasta 2.000 caracteres.');
    await _db.from('vehicle_reviews').insert({
      'listing_id': listingId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'rating': rating,
      'review_text': text,
    });
  }
}

/// Diálogo para que el vendedor seleccione el comprador al marcar como vendido.
class MarkVehicleSoldDialog extends StatefulWidget {
  final String listingId;
  const MarkVehicleSoldDialog({super.key, required this.listingId});

  @override
  State<MarkVehicleSoldDialog> createState() => _MarkVehicleSoldDialogState();
}

class _MarkVehicleSoldDialogState extends State<MarkVehicleSoldDialog> {
  List<Map<String, dynamic>> buyers = [];
  String? selectedBuyer;
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      buyers = await AutomotorsSoldReviews.contactedBuyers(widget.listingId);
    } catch (e) {
      error = 'No se pudieron cargar los compradores: $e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    if (selectedBuyer == null) return;
    setState(() => saving = true);
    try {
      await AutomotorsSoldReviews.markSold(listingId: widget.listingId, buyerId: selectedBuyer!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() { saving = false; error = 'No se pudo marcar como vendido: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Marcar vehículo como vendido'),
    content: SizedBox(width: 360, child: loading
      ? const Center(child: CircularProgressIndicator())
      : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Selecciona al comprador que te contactó por el chat de este anuncio.'),
          const SizedBox(height: 12),
          if (buyers.isEmpty) const Text('Todavía no hay compradores con conversaciones para este anuncio.'),
          if (buyers.isNotEmpty) DropdownButtonFormField<String>(
            value: selectedBuyer,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Comprador'),
            items: buyers.map((b) {
              final id = b['buyer_id'].toString();
              return DropdownMenuItem(value: id, child: Text('Usuario ${id.substring(0, 8)}'));
            }).toList(),
            onChanged: saving ? null : (v) => setState(() => selectedBuyer = v),
          ),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
        ])),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
      FilledButton(onPressed: saving || selectedBuyer == null ? null : _save, child: Text(saving ? 'Guardando...' : 'Confirmar venta')),
    ],
  );
}

/// Formulario de reseña que puede mostrarse al comprador seleccionado.
class VehicleReviewForm extends StatefulWidget {
  final String listingId;
  final String sellerId;
  const VehicleReviewForm({super.key, required this.listingId, required this.sellerId});

  @override
  State<VehicleReviewForm> createState() => _VehicleReviewFormState();
}

class _VehicleReviewFormState extends State<VehicleReviewForm> {
  final controller = TextEditingController();
  int rating = 5;
  bool saving = false;
  String? message;

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() { saving = true; message = null; });
    try {
      await AutomotorsSoldReviews.submitReview(
        listingId: widget.listingId, sellerId: widget.sellerId,
        rating: rating, reviewText: controller.text,
      );
      if (mounted) setState(() { saving = false; message = '¡Gracias! Tu reseña se ha publicado en el perfil del vendedor.'; });
    } catch (e) {
      if (mounted) setState(() { saving = false; message = 'No se pudo publicar. Solo el comprador confirmado puede reseñar y una vez por vehículo. ($e)'; });
    }
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Valora tu compra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Row(children: List.generate(5, (i) => IconButton(
        tooltip: '${i + 1} estrellas',
        onPressed: saving ? null : () => setState(() => rating = i + 1),
        icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber),
      ))),
      TextField(controller: controller, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(labelText: 'Cuéntanos cómo fue la compra')),
      if (message != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(message!)),
      FilledButton(onPressed: saving ? null : _submit, child: Text(saving ? 'Enviando...' : 'Publicar reseña')),
    ]),
  ));
}

/// Sección para añadir dentro del perfil público del vendedor.
class SellerReviewsSection extends StatelessWidget {
  final String sellerId;
  const SellerReviewsSection({super.key, required this.sellerId});

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client
      .from('vehicle_reviews')
      .select('id, listing_id, buyer_id, rating, review_text, created_at')
      .eq('seller_id', sellerId)
      .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _load(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return const ListTile(title: Text('No se pudieron cargar las reseñas.'));
      final reviews = snapshot.data ?? [];
      final average = reviews.isEmpty ? 0.0 : reviews.map((r) => (r['rating'] as num).toDouble()).reduce((a, b) => a + b) / reviews.length;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reseñas del vendedor (${reviews.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        if (reviews.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [const Icon(Icons.star, color: Colors.amber), const SizedBox(width: 6), Text('${average.toStringAsFixed(1)} / 5 · ${reviews.length} reseñas')])),
        if (reviews.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Este vendedor todavía no tiene reseñas.')),
        ...reviews.map((r) => Card(child: ListTile(
          leading: const Icon(Icons.verified_user, color: Colors.amber),
          title: Row(children: [Text('${r['rating']} / 5'), const SizedBox(width: 6), const Icon(Icons.star, color: Colors.amber, size: 18)]),
          subtitle: Text(r['review_text'].toString()),
        ))),
      ]);
    },
  );
}
