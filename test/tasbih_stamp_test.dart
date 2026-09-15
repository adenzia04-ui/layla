import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/tasbih/application/tasbih_view.dart';
import 'package:noor/features/tasbih/presentation/widgets/tasbih_strand.dart';

/// The mark belongs to the signet finish alone.
///
/// It leaked onto every other finish: `TasbihStrand` is stateful, switching
/// styles reuses the same State, and the decoded emblem was loaded on the way
/// in but never released on the way out. Gold beads came back stamped.
void main() {
  Widget strand(CounterStyle s) => MaterialApp(
    home: Scaffold(
      body: TasbihStrand(
        count: 0,
        target: 33,
        rounds: 1,
        colours: s.beadColours,
        signet: s.isSignet,
        onTap: () {},
      ),
    ),
  );

  testWidgets('leaving the signet finish takes the mark with it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(strand(CounterStyle.signet));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    // Same widget type in the same slot, so Flutter reuses the State — which
    // is the whole reason the leak was possible.
    await tester.pumpWidget(strand(CounterStyle.gold));
    await tester.pumpAndSettle();

    final TasbihStrand shown = tester.widget<TasbihStrand>(
      find.byType(TasbihStrand),
    );
    expect(shown.signet, isFalse);
    expect(tester.takeException(), isNull);
  });

  test('only the signet finish is stamped', () {
    for (final CounterStyle s in CounterStyle.values) {
      expect(
        s.isSignet,
        s == CounterStyle.signet,
        reason: '${s.name} must not carry the mark',
      );
    }
  });
}
