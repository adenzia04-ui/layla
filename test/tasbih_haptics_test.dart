import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/services/prefs_service.dart';
import 'package:noor/features/tasbih/application/tasbih_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counting on a tasbih is done by thumb, with the eyes elsewhere. The tap has
/// to be felt, and it was not: this counter shipped on `selectionClick`, the
/// faintest haptic iOS has, which through a case reads as nothing at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each count is felt, not just hinted at', () async {
    final List<String> felt = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'HapticFeedback.vibrate') {
            felt.add(call.arguments as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        tasbihPaceProvider.overrideWithValue(false),
        prefsProvider.overrideWithValue(PrefsService(prefs)),
      ],
    );
    addTearDown(container.dispose);

    container.read(tasbihProvider.notifier).increment();

    expect(container.read(tasbihProvider).count, 1);
    expect(felt, <String>['HapticFeedbackType.mediumImpact']);
  });
}
