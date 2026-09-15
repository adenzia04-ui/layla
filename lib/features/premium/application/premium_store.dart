import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/prefs_service.dart';
import '../domain/premium_plan.dart';

/// Whether this phone has Layla Pro Premium.
///
/// UNLOCKED FOR TESTING: every feature is open to everyone until launch, and
/// the paywall stays reachable from Profile only as a preview. To switch the
/// gates back on, return `ref.watch(premiumProvider).isPro` here.
final Provider<bool> isProProvider = Provider<bool>((Ref ref) => true);

/// Whether the paid colour sets and counter faces can be chosen.
///
/// TESTING: true for everyone until launch, like the scan above. The locks
/// still show on the paid ones so the offer can be seen, but a tap goes
/// through. To switch the gate on, set [kStylesOpenForTesting] to false.
const bool kStylesOpenForTesting = true;

final Provider<bool> styleUnlockedProvider = Provider<bool>(
  (Ref ref) => kStylesOpenForTesting || ref.watch(premiumProvider).isPro,
);

/// Whether the lock badges are drawn on the paid colours and counters —
/// until Premium is actually bought or restored on this phone.
final Provider<bool> styleLocksShownProvider = Provider<bool>(
  (Ref ref) => !ref.watch(premiumProvider).isPro,
);

final NotifierProvider<PremiumStore, PremiumState> premiumProvider =
    NotifierProvider<PremiumStore, PremiumState>(PremiumStore.new);

@immutable
class PremiumState {
  const PremiumState({
    this.isPro = false,
    this.products = const <String, ProductDetails>{},
    this.storeReady = false,
    this.busy = false,
    this.error,
  });

  final bool isPro;

  /// Keyed by product id; empty until the store has answered.
  final Map<String, ProductDetails> products;
  final bool storeReady;
  final bool busy;
  final String? error;

  String priceFor(PremiumPlan plan) =>
      products[plan.id]?.price ?? '\$${plan.fallbackPrice}';

  PremiumState copyWith({
    bool? isPro,
    Map<String, ProductDetails>? products,
    bool? storeReady,
    bool? busy,
    String? error,
    bool clearError = false,
  }) => PremiumState(
    isPro: isPro ?? this.isPro,
    products: products ?? this.products,
    storeReady: storeReady ?? this.storeReady,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
  );
}

/// Premium, through StoreKit.
///
/// The entitlement is remembered on the phone the moment a purchase or a
/// restore succeeds, so the app never has to ask the store again just to
/// open the tasbih. "Restore purchases" is the way back after a reinstall.
///
/// Everything here fails quietly: a store that is unavailable, a product id
/// that does not exist yet in App Store Connect, or a test environment with no
/// StoreKit at all must never break a screen.
class PremiumStore extends Notifier<PremiumState> {
  static const String _key = 'premium_active';

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);
  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  PremiumState build() {
    ref.onDispose(() => _sub?.cancel());
    // The store is asked after the first frame, not during build.
    Future<void>.microtask(_connect);
    // Widget tests build screens without preferences or a store; Premium is
    // simply off there rather than an error.
    bool pro = false;
    try {
      pro = _prefs.getBool(_key) ?? false;
    } catch (_) {}
    return PremiumState(isPro: pro);
  }

  Future<void> _connect() async {
    try {
      final InAppPurchase iap = InAppPurchase.instance;
      _sub = iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) {
          debugPrint('Layla Pro: purchase stream error ($e)');
        },
      );
      if (!await iap.isAvailable()) return;
      final ProductDetailsResponse res = await iap.queryProductDetails(
        PremiumPlan.ids,
      );
      state = state.copyWith(
        storeReady: true,
        products: <String, ProductDetails>{
          for (final ProductDetails p in res.productDetails) p.id: p,
        },
      );
      if (res.notFoundIDs.isNotEmpty) {
        debugPrint(
          'Layla Pro: products not in the store yet: ${res.notFoundIDs}',
        );
      }
    } catch (e) {
      debugPrint('Layla Pro: store unavailable ($e)');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (PremiumPlan.ids.contains(p.productID)) await _grant();
          state = state.copyWith(busy: false, clearError: true);
        case PurchaseStatus.error:
          state = state.copyWith(
            busy: false,
            error: p.error?.message ?? 'The purchase did not go through.',
          );
        case PurchaseStatus.canceled:
          state = state.copyWith(busy: false, clearError: true);
        case PurchaseStatus.pending:
          state = state.copyWith(busy: true);
      }
      if (p.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(p);
        } catch (e) {
          debugPrint('Layla Pro: completePurchase failed ($e)');
        }
      }
    }
  }

  Future<void> _grant() async {
    state = state.copyWith(isPro: true);
    try {
      await _prefs.setBool(_key, true);
    } catch (_) {}
  }

  /// Starts the store's own purchase sheet for [plan].
  Future<void> buy(PremiumPlan plan) async {
    final ProductDetails? product = state.products[plan.id];
    if (product == null) {
      state = state.copyWith(
        error:
            'The store has not listed this plan yet. Try again in a moment, '
            'or restore a purchase you already made.',
      );
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final PurchaseParam param = PurchaseParam(productDetails: product);
      // Subscriptions and the lifetime unlock both go through the
      // non-consumable path on iOS; StoreKit knows which is which.
      final bool started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: param,
      );
      if (!started) state = state.copyWith(busy: false);
    } catch (e) {
      state = state.copyWith(
        busy: false,
        error: 'Could not start the purchase ($e).',
      );
    }
  }

  Future<void> restore() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Could not restore ($e).');
      return;
    }
    // The stream delivers restored purchases; if none arrive, stop waiting.
    await Future<void>.delayed(const Duration(seconds: 4));
    if (state.busy) {
      state = state.copyWith(
        busy: false,
        error: state.isPro ? null : 'No previous purchase was found.',
      );
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}
