import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Native subscription catalog and purchase listener for AUTOMOTORS.
///
/// Checkout stays disabled in ordinary builds. A dedicated sandbox build can
/// opt in with `--dart-define=AUTOMOTORS_ENABLE_STORE_CHECKOUT=true` after its
/// backend has been configured. A successful local store callback never grants
/// entitlements by itself.
class StorePurchaseService {
  StorePurchaseService({InAppPurchase? store})
      : _store = store ?? InAppPurchase.instance;

  static const bool checkoutEnabled = bool.fromEnvironment(
    'AUTOMOTORS_ENABLE_STORE_CHECKOUT',
    defaultValue: false,
  );

  static const Map<String, String> productNames = {
    'automotors_pack_10': 'PACK 10',
    'automotors_pack_15': 'PACK 15',
    'automotors_pack_20': 'PACK 20',
    'automotors_pro_monthly_199': 'AUTOMOTORS PRO',
  };

  final InAppPurchase _store;
  final Map<String, ProductDetails> _products = {};
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final StreamController<String> _messages =
      StreamController<String>.broadcast();

  Stream<String> get messages => _messages.stream;
  Stream<void> get changes => _changes.stream;
  List<ProductDetails> get products => List.unmodifiable(_products.values);
  bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (!isSupportedPlatform) {
      _messages.add('Las compras solo están disponibles en las aplicaciones iOS y Android.');
      return;
    }

    _purchaseSubscription ??= _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        _messages.add('No se pudo consultar el estado de la compra.');
      },
    );

    final available = await _store.isAvailable();
    if (!available) {
      _messages.add('La tienda no está disponible en este dispositivo.');
      return;
    }

    final response = await _store.queryProductDetails(productNames.keys.toSet());
    if (response.error != null) {
      _messages.add('No se pudieron cargar los productos de la tienda.');
    }
    _products
      ..clear()
      ..addEntries(response.productDetails.map((product) =>
          MapEntry(product.id, product)));
    _changes.add(null);

    if (response.notFoundIDs.isNotEmpty) {
      _messages.add(
        'Hay productos pendientes de configurar en la tienda: '
        '${response.notFoundIDs.join(', ')}',
      );
    }
  }

  /// Starts no payment until backend verification has been enabled deliberately.
  Future<void> purchaseSubscription(String productId) async {
    if (!checkoutEnabled) {
      _messages.add(
        'Las compras están desactivadas hasta completar la verificación segura en servidor.',
      );
      return;
    }
    if (!isSupportedPlatform) {
      _messages.add('Las compras deben realizarse desde la aplicación móvil.');
      return;
    }
    if (Supabase.instance.client.auth.currentUser == null) {
      _messages.add('Inicia sesión antes de contratar una suscripción.');
      return;
    }
    final product = _products[productId];
    if (product == null) {
      _messages.add('Este producto no está disponible en la tienda.');
      return;
    }

    await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  Future<void> restorePurchases() async {
    if (!checkoutEnabled) {
      _messages.add(
        'La restauración estará disponible cuando se active la verificación de compras.',
      );
      return;
    }
    if (isSupportedPlatform) {
      await _store.restorePurchases();
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _messages.add('La compra está pendiente de confirmación de la tienda.');
          break;
        case PurchaseStatus.error:
          _messages.add('La tienda no ha completado la compra.');
          break;
        case PurchaseStatus.canceled:
          _messages.add('Has cancelado la compra.');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Do not complete or unlock the purchase until a real server verifier
          // confirms the transaction with the corresponding store.
          if (!checkoutEnabled) {
            _messages.add(
              'Compra recibida, pero el acceso sigue bloqueado hasta verificarla en servidor.',
            );
            break;
          }
          await _verifyWithServer(purchase);
          break;
      }
    }
  }

  Future<void> _verifyWithServer(PurchaseDetails purchase) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _messages.add('Inicia sesión para verificar la suscripción.');
      return;
    }

    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'apple'
        : 'google_play';
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-store-purchase',
        body: {
          'productId': purchase.productID,
          'platform': platform,
          'transactionId': purchase.purchaseID,
          'verificationData':
              purchase.verificationData.serverVerificationData,
        },
      );
      final data = response.data;
      final verified = response.status == 200 &&
          data is Map &&
          data['verified'] == true;
      if (!verified) {
        _messages.add(
          'La tienda recibió la compra, pero AUTOMOTORS aún no ha podido verificarla.',
        );
        return;
      }

      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      _messages.add('Suscripción verificada por el servidor.');
    } catch (_) {
      _messages.add(
        'No se ha podido verificar la compra. No se ha concedido acceso.',
      );
    }
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    await _changes.close();
    await _messages.close();
  }
}
