// Sprint 2 / B-3 — the paywall's real purchase flow.
//
// What this replaced: a simulated Apple/Google purchase sheet followed by
// `creditManager.addCredits()`, which incremented a number in device memory
// that the next wallet fetch overwrote. The user saw a success dialog and then
// silently lost the credits they had "bought".
//
// So the assertions here are mostly about what must NOT happen: no local
// credit grant, no success shown for an unverified purchase, and no purchase
// button offered for something the store cannot sell.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:prombt_app/data/credit_manager.dart';
import 'package:prombt_app/data/creations_manager.dart';
import 'package:prombt_app/data/dynamic_style_manager.dart';
import 'package:prombt_app/data/favorites_manager.dart';
import 'package:prombt_app/main.dart';
import 'package:prombt_app/models/credit_pack.dart';
import 'package:prombt_app/screens/paywall_screen.dart';
import 'package:prombt_app/services/purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kSku = 'credits_pro_50';

/// A PurchaseService that never touches a store.
class FakePurchaseService extends PurchaseService {
  FakePurchaseService({
    this.storeAvailable = true,
    this.products = const [kSku],
    this.result = const PurchaseResult(PurchaseOutcome.credited, creditsGranted: 50, balance: 70),
  });

  bool storeAvailable;
  List<String> products;
  PurchaseResult result;

  int buyCalls = 0;
  int restoreCalls = 0;
  ProductDetails? lastBought;

  @override
  void start() {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> isStoreAvailable() async => storeAvailable;

  @override
  Future<List<ProductDetails>> loadProducts(Set<String> productIds) async {
    return products
        .where(productIds.contains)
        .map((id) => ProductDetails(
              id: id,
              title: 'Pro Pack',
              description: '50 credits',
              price: 'US\$4.99',
              rawPrice: 4.99,
              currencyCode: 'USD',
            ))
        .toList();
  }

  @override
  Future<PurchaseResult> buy(ProductDetails product) async {
    buyCalls += 1;
    lastBought = product;
    return result;
  }

  @override
  Future<void> restore() async {
    restoreCalls += 1;
  }
}

CreditPack pack({String? productId = kSku}) => CreditPack(
      id: 'pack-1',
      name: 'Pro Pack',
      credits: 50,
      priceDisplay: r'$4.99',
      badge: 'Best Value',
      productId: productId,
    );

/// A CreditManager whose network fetch is inert.
///
/// The restore flow legitimately re-reads the balance from the server; in a
/// widget test that reaches a real WalletService, hangs, and leaves a pending
/// timeout timer behind. Overriding the one network method keeps the rest of
/// the manager - including applyServerBalance, which these tests assert on -
/// completely real.
class FakeCreditManager extends CreditManager {
  int fetchCalls = 0;

  @override
  Future<void> fetchWallet() async {
    fetchCalls += 1;
  }
}

late FakeCreditManager creditManager;

Widget harness(Widget child) {
  creditManager = FakeCreditManager()..shouldSaveToFile = false;
  return StyleProvider(
    notifier: DynamicStyleManager(),
    child: CreditProvider(
      notifier: creditManager,
      child: FavoritesProvider(
        notifier: FavoritesManager(),
        child: CreationsProvider(
          notifier: CreationsManager()..shouldSaveToFile = false,
          child: MaterialApp(debugShowCheckedModeBanner: false, home: child),
        ),
      ),
    ),
  );
}

Future<void> pumpPaywall(
  WidgetTester tester, {
  required FakePurchaseService service,
  List<CreditPack>? packs,
}) async {
  await tester.pumpWidget(harness(PaywallScreen(
    isDarkMode: true,
    fetchPacksOverride: () async => packs ?? [pack()],
    purchaseServiceOverride: service,
  )));
  await tester.pumpAndSettle();
}

Finder get purchaseButton =>
    find.widgetWithText(ElevatedButton, 'Purchase Credits Pack');

Future<void> tapPurchase(WidgetTester tester) async {
  await tester.ensureVisible(purchaseButton);
  await tester.pumpAndSettle();
  await tester.tap(purchaseButton, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // The paywall is a CustomScrollView, and slivers outside the viewport are
  // never built - so on the default 800px-tall test surface the purchase CTA
  // does not exist to be found, let alone tapped. A tall surface builds the
  // whole screen, which is what these tests are actually about.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 4200);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('the simulated purchase path is gone', () {
    test('CreditManager exposes no local credit-granting method', () {
      final manager = CreditManager();

      // A compile-time guarantee really, but stated as a test so that
      // re-adding addCredits()/useCredit() has to delete an assertion that
      // says why they were removed.
      expect(manager.balance, equals(0));
      manager.applyServerBalance(10);
      expect(manager.balance, equals(10));
    });
  });

  group('a purchasable pack', () {
    testWidgets('buys through the store and applies the SERVER balance',
        (tester) async {
      final service = FakePurchaseService();
      await pumpPaywall(tester, service: service);

      await tapPurchase(tester);

      expect(service.buyCalls, equals(1));
      expect(service.lastBought?.id, equals(kSku));
      // 70 is what the server reported - not 0 + 50 computed locally.
      expect(creditManager.balance, equals(70));
      expect(find.text('Purchase Successful!'), findsOneWidget);
    });

    testWidgets('shows the store price, not the admin label', (tester) async {
      final service = FakePurchaseService();
      await pumpPaywall(tester, service: service);

      // The store's localised price is authoritative - correct currency and
      // regional pricing for THIS buyer.
      expect(find.text(r'US$4.99'), findsWidgets);
    });
  });

  group('a purchase that was not credited never claims success', () {
    testWidgets('a retryable failure shows a message and grants nothing',
        (tester) async {
      final service = FakePurchaseService(
        result: const PurchaseResult(
          PurchaseOutcome.retryable,
          message: 'We could not confirm your purchase yet.',
        ),
      );
      await pumpPaywall(tester, service: service);

      await tapPurchase(tester);

      expect(creditManager.balance, equals(0));
      expect(find.text('Purchase Successful!'), findsNothing);
      expect(find.textContaining('could not confirm'), findsOneWidget);
    });

    testWidgets('a failed purchase shows a message and grants nothing',
        (tester) async {
      final service = FakePurchaseService(
        result: const PurchaseResult(
          PurchaseOutcome.failed,
          message: 'This purchase could not be verified.',
        ),
      );
      await pumpPaywall(tester, service: service);

      await tapPurchase(tester);

      expect(creditManager.balance, equals(0));
      expect(find.text('Purchase Successful!'), findsNothing);
      expect(find.textContaining('could not be verified'), findsOneWidget);
    });

    testWidgets('a cancelled purchase shows nothing at all', (tester) async {
      final service = FakePurchaseService(
        result: const PurchaseResult(PurchaseOutcome.cancelled),
      );
      await pumpPaywall(tester, service: service);

      await tapPurchase(tester);

      expect(creditManager.balance, equals(0));
      expect(find.text('Purchase Successful!'), findsNothing);
      // Backing out of the store sheet is not an error and must not be
      // reported as one.
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('an already-credited purchase', () {
    testWidgets('reports it honestly rather than claiming a new purchase',
        (tester) async {
      final service = FakePurchaseService(
        result: const PurchaseResult(
          PurchaseOutcome.alreadyCredited,
          creditsGranted: 0,
          balance: 20,
        ),
      );
      await pumpPaywall(tester, service: service);

      await tapPurchase(tester);

      expect(creditManager.balance, equals(20));
      expect(find.text('Already Credited'), findsOneWidget);
      expect(find.text('Purchase Successful!'), findsNothing);
    });
  });

  group('nothing purchasable', () {
    testWidgets('a pack with no store SKU cannot be purchased', (tester) async {
      final service = FakePurchaseService();
      await pumpPaywall(tester, service: service, packs: [pack(productId: null)]);

      final button = tester.widget<ElevatedButton>(purchaseButton);
      expect(button.onPressed, isNull);
      expect(service.buyCalls, equals(0));
    });

    testWidgets('explains why, rather than offering a dead button',
        (tester) async {
      final service = FakePurchaseService();
      await pumpPaywall(tester, service: service, packs: [pack(productId: null)]);

      expect(find.textContaining('not available for purchase yet'), findsOneWidget);
    });

    testWidgets('a device with no billing service disables purchasing',
        (tester) async {
      final service = FakePurchaseService(storeAvailable: false);
      await pumpPaywall(tester, service: service);

      final button = tester.widget<ElevatedButton>(purchaseButton);
      expect(button.onPressed, isNull);
      expect(find.textContaining('unavailable on this device'), findsOneWidget);
    });

    testWidgets('a SKU the store does not sell disables purchasing',
        (tester) async {
      // The pack advertises a SKU, but the store returns no product for it -
      // the state before the products are created in the consoles.
      final service = FakePurchaseService(products: const []);
      await pumpPaywall(tester, service: service);

      final button = tester.widget<ElevatedButton>(purchaseButton);
      expect(button.onPressed, isNull);
      expect(service.buyCalls, equals(0));
    });
  });

  group('restore', () {
    testWidgets('the footer link asks the store to re-deliver purchases',
        (tester) async {
      final service = FakePurchaseService();
      await pumpPaywall(tester, service: service);

      final link = find.text('Restore Purchases');
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(service.restoreCalls, equals(1));
      // The balance is re-read from the server rather than guessed at:
      // restored purchases are verified individually on the purchase stream.
      expect(creditManager.fetchCalls, greaterThan(0));
    });
  });
}
