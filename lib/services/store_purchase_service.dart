import 'app_diagnostics.dart';

import 'dart:async';

import 'store_verification_message.dart';
import 'store_product_presentation.dart';

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

  Future<void>? _initializing;
  bool _startingPurchase = false;
  bool _disposed = false;
  bool get isLoading => _initializing != null;
  bool get isStartingPurchase => _startingPurchase;
  void _notify() {
    if (!_disposed) _changes.add(null);
  }

  void _message(String text) {
    if (!_disposed) _messages.add(text);
  }

  Future<void> initialize() {
    if (_disposed) return Future.value();
    if (_initializing != null) return _initializing!;
    final future = _loadProducts();
    _initializing = future;
    _notify();
    return future.whenComplete(() {
      _initializing = null;
      _notify();
    });
  }

  Future<void> _loadProducts() async {
    if (!isSupportedPlatform) {
      _message(
        'Las compras solo están disponibles en las aplicaciones iOS y Android.',
      );
      return;
    }
    _purchaseSubscription ??= _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        AppDiagnostics.record('purchase', error);
        _message('No se pudo consultar el estado de la compra.');
      },
    );
    try {
      final available = await _store.isAvailable().timeout(
        const Duration(seconds: 15),
      );
      if (!available) {
        _products.clear();
        _message('La tienda no está disponible en este dispositivo.');
        return;
      }
      final response = await _store
          .queryProductDetails(productNames.keys.toSet())
          .timeout(const Duration(seconds: 20));
      if (_disposed) return;
      _products
        ..clear()
        ..addEntries(
          response.productDetails
              .where((p) => productNames.containsKey(p.id))
              .map((p) => MapEntry(p.id, p)),
        );
      if (response.error != null || response.notFoundIDs.isNotEmpty) {
        _message(
          'No se pudieron cargar todos los planes. Actualiza los productos de la tienda y vuelve a intentarlo.',
        );
      }
    } catch (error) {
      _products.clear();
      AppDiagnostics.record('purchase', error);
      _message(
        'No se pudo conectar con Apple. Actualiza los productos de la tienda y vuelve a intentarlo.',
      );
    }
  }

  /// One explicit user tap starts at most one store checkout. Server verification
  /// still decides entitlements; loading a price never grants access.
  Future<void> purchaseSubscription(String productId) async {
    if (_disposed || _startingPurchase) return;
    if (!checkoutEnabled) {
      _message(
        'Las compras están desactivadas hasta completar la verificación segura en servidor.',
      );
      return;
    }
    if (!isSupportedPlatform) {
      _message('Las compras deben realizarse desde la aplicación móvil.');
      return;
    }
    if (!productNames.containsKey(productId)) {
      _message('Este producto no está disponible en la tienda.');
      return;
    }
    final accountId = Supabase.instance.client.auth.currentUser?.id;
    if (accountId == null) {
      _message('Inicia sesión antes de contratar una suscripción.');
      return;
    }
    _startingPurchase = true;
    _notify();
    try {
      if (_initializing != null) await _initializing;
      if (!_products.containsKey(productId)) await initialize();
      if (_disposed) return;
      // The account may have changed while the store was loading.
      if (Supabase.instance.client.auth.currentUser?.id != accountId) {
        _message('La sesión ha cambiado. Abre de nuevo los planes.');
        return;
      }
      final product = _products[productId];
      if (product == null) {
        _message('Este producto no está disponible en la tienda.');
        return;
      }
      if (storePeriodMessage(product) == null ||
          (defaultTargetPlatform == TargetPlatform.iOS &&
              spanishStoreDisplayPrice(product) == null)) {
        _message(
          'No se pudieron confirmar los datos del plan. Actualiza los productos de la tienda y vuelve a intentarlo.',
        );
        return;
      }
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started)
        _message('Apple no ha iniciado el pago. Vuelve a intentarlo.');
    } catch (error) {
      AppDiagnostics.record('purchase', error);
      _message('No se pudo abrir el pago de Apple. Vuelve a intentarlo.');
    } finally {
      _startingPurchase = false;
      _notify();
    }
  }

  Future<void> restorePurchases() async {
    if (!checkoutEnabled) {
      _message(
        'La restauración estará disponible cuando se active la verificación de compras.',
      );
      return;
    }
    if (isSupportedPlatform) {
      await _store.restorePurchases();
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _message('La compra está pendiente de confirmación de la tienda.');
          break;
        case PurchaseStatus.error:
          AppDiagnostics.record('purchase', StateError('store_error'));
          _message('La tienda no ha completado la compra.');
          break;
        case PurchaseStatus.canceled:
          _message('Has cancelado la compra.');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Do not complete or unlock the purchase until a real server verifier
          // confirms the transaction with the corresponding store.
          if (!checkoutEnabled) {
            _message(
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
      _message('Inicia sesión para verificar la suscripción.');
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
          'verificationData': purchase.verificationData.serverVerificationData,
        },
      );
      final data = response.data;
      final verified =
          response.status == 200 && data is Map && data['verified'] == true;
      if (!verified) {
        _message(storeVerificationMessage(response.status, data));
        return;
      }

      // Notify screens only after the server has saved a verified purchase.
      // They re-read the subscription record rather than trusting StoreKit.
      _notify();
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      _message('Suscripción verificada por el servidor.');
    } on FunctionException catch (error) {
      AppDiagnostics.record('purchase', error);
      _message(storeVerificationMessage(error.status, error.details));
    } catch (error) {
      AppDiagnostics.record('purchase', error);
      _message(storeVerificationMessage(0, null));
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _purchaseSubscription?.cancel();
    await _changes.close();
    await _messages.close();
  }
}
