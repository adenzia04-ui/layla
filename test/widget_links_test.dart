import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/routing/routes.dart';
import 'package:noor/core/routing/widget_links.dart';

/// Eleven widgets across two phones send these, and every one of them was
/// arriving nowhere: a `layla://` url has no path, go_router folds it onto
/// the splash, and the tap read as "opens the app". Nothing logs a link that
/// was simply never claimed, so the only thing that can hold this still is a
/// test that names each one.
void main() {
  group('Widget links', () {
    test('every link a widget sends has a destination', () {
      // These are the exact strings in the Swift and the Kotlin. If one is
      // renamed on one side, this is where it shows up.
      const Map<String, String> sent = <String, String>{
        'layla://pray': Routes.home,
        'layla://qibla': Routes.qibla,
        'layla://tasbih': Routes.tasbihCounter,
        'layla://names': Routes.soulNames,
        'layla://verse': Routes.mood,
        'layla://duas': Routes.tasbih,
        'layla://duas/morning': Routes.tasbih,
        'layla://duas/praise': Routes.tasbih,
      };

      sent.forEach((String link, String expected) {
        expect(
          widgetLinkTarget(Uri.parse(link)),
          expected,
          reason: '$link goes nowhere',
        );
      });
    });

    test('every destination is a route the app actually has', () {
      const Set<String> real = <String>{
        Routes.home,
        Routes.qibla,
        Routes.tasbih,
        Routes.tasbihCounter,
        Routes.soulNames,
        Routes.mood,
      };
      for (final String link in <String>[
        'layla://pray',
        'layla://qibla',
        'layla://tasbih',
        'layla://names',
        'layla://verse',
        'layla://duas',
      ]) {
        expect(real, contains(widgetLinkTarget(Uri.parse(link))));
      }
    });

    test('the invite link is left alone', () {
      // It has its own handling, and catching it here would swallow the code.
      expect(widgetLinkTarget(Uri.parse('layla://add?code=ABC123')), isNull);
    });

    test('a link we do not know is not guessed at', () {
      expect(widgetLinkTarget(Uri.parse('layla://somethingelse')), isNull);
    });

    test('another app\'s scheme is never ours', () {
      expect(widgetLinkTarget(Uri.parse('https://layla.app/qibla')), isNull);
      expect(widgetLinkTarget(Uri.parse('otherapp://qibla')), isNull);
    });

    test('ordinary in-app navigation is not a widget link', () {
      expect(widgetLinkTarget(Uri.parse('/home/qibla')), isNull);
      expect(widgetLinkTarget(Uri.parse('/tasbih')), isNull);
    });
  });
}
