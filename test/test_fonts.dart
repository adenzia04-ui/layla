import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads Noor's bundled fonts into the test binding.
///
/// `flutter_test` substitutes a placeholder font for everything by default, so
/// without this every golden renders text as identical filled boxes — fine for
/// checking layout, useless for judging how something looks.
Future<void> loadNoorFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final ({String family, String path}) font
      in <({String family, String path})>[
        (family: 'Inter', path: 'assets/fonts/Inter.ttf'),
        (family: 'PlayfairDisplay', path: 'assets/fonts/PlayfairDisplay.ttf'),
        (family: 'Outfit', path: 'assets/fonts/Outfit.ttf'),
        // Without these the Arabic goldens are rows of identical boxes, which
        // hides the very thing they exist to show: whether the Uthmani marks
        // land where they should.
        (family: 'AmiriQuran', path: 'assets/fonts/AmiriQuran-Regular.ttf'),
        (family: 'Amiri', path: 'assets/fonts/Amiri-Regular.ttf'),
      ]) {
    final File file = File(font.path);
    if (!file.existsSync()) continue;
    final FontLoader loader = FontLoader(font.family)
      ..addFont(
        Future<ByteData>.value(ByteData.sublistView(await file.readAsBytes())),
      );
    await loader.load();
  }
}
