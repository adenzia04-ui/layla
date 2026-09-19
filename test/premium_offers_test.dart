import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:noor/features/premium/application/premium_store.dart';

/// Google Play answers `queryProductDetails` once per *offer*, not once per
/// product: a subscription carrying an introductory price arrives twice under
/// the same id at two different prices. The App Store never does this, so it
/// is the kind of thing that looks fine for the whole of an iOS launch and
/// then quotes the wrong price on Android.
ProductDetails _p(String id, double price) => ProductDetails(
  id: id,
  title: id,
  description: id,
  price: '\$$price',
  rawPrice: price,
  currencyCode: 'USD',
);

void main() {
  group('Play sends one entry per offer', () {
    test('the cheaper offer is the one the paywall quotes', () {
      final Map<String, ProductDetails> kept = PremiumStore.cheapestPerPlan(
        <ProductDetails>[
          _p('layla_pro_yearly', 24.99),
          _p('layla_pro_yearly', 9.99),
        ],
      );
      expect(kept, hasLength(1));
      expect(kept['layla_pro_yearly']!.rawPrice, 9.99);
    });

    test('order does not decide it', () {
      final Map<String, ProductDetails> kept = PremiumStore.cheapestPerPlan(
        <ProductDetails>[
          _p('layla_pro_yearly', 9.99),
          _p('layla_pro_yearly', 24.99),
        ],
      );
      expect(kept['layla_pro_yearly']!.rawPrice, 9.99);
    });

    test('plans with one offer each are untouched', () {
      final Map<String, ProductDetails> kept = PremiumStore.cheapestPerPlan(
        <ProductDetails>[
          _p('layla_pro_monthly', 3.99),
          _p('layla_pro_yearly', 24.99),
          _p('layla_pro_lifetime', 59.99),
        ],
      );
      expect(kept.keys, hasLength(3));
      expect(kept['layla_pro_lifetime']!.rawPrice, 59.99);
    });

    test('an empty store is an empty map, not a crash', () {
      expect(PremiumStore.cheapestPerPlan(<ProductDetails>[]), isEmpty);
    });
  });
}
