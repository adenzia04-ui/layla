import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/routing/invite_link.dart';
import 'package:noor/core/routing/routes.dart';

/// The invite link, as the router reads it: which URIs count, what code they
/// carry, and where each one sends the app — warm, cold, and cold with the
/// splash still to play.
void main() {
  group('IncomingInvite', () {
    test('reads the code out of every shape the link arrives in', () {
      const Map<String, String> shapes = <String, String>{
        'the custom scheme': 'layla://add?code=ABC234',
        'the scheme after go_router folds its path onto the splash':
            '/?code=ABC234',
        'the scheme re-parsed warm, host kept and path folded':
            'layla://add/?code=ABC234',
        'the plain path': '/add?code=ABC234',
        'the launch site page, as a universal link would carry it':
            '/layla-pro/add.html?code=ABC234',
        'the full launch site address':
            'https://adenzia04-ui.github.io/layla-pro/add.html?code=ABC234',
      };
      for (final MapEntry<String, String> shape in shapes.entries) {
        final Uri uri = Uri.parse(shape.value);
        expect(IncomingInvite.matches(uri), isTrue, reason: shape.key);
        expect(IncomingInvite.codeIn(uri), 'ABC234', reason: shape.key);
      }
    });

    test('is as lenient as the field: case, hyphen, spaces, look-alikes', () {
      expect(IncomingInvite.codeIn(Uri.parse('/add?code=abc-234')), 'ABC234');
      expect(
        IncomingInvite.codeIn(Uri.parse('/add?code=abc%20234%20')),
        'ABC234',
      );
      // O and 1 are outside the alphabet; what remains is the code.
      expect(IncomingInvite.codeIn(Uri.parse('/add?code=ABC234O1')), 'ABC234');
    });

    test('a link with no whole code is still an invite, but carries none', () {
      for (final String location in <String>[
        '/add',
        '/add?code=',
        '/add?code=AB',
        '/add?code=O01',
        'layla://add',
      ]) {
        final Uri uri = Uri.parse(location);
        expect(IncomingInvite.matches(uri), isTrue, reason: location);
        expect(IncomingInvite.codeIn(uri), isNull, reason: location);
      }
    });

    test('a code on any other route is not an invite', () {
      for (final String location in <String>[
        '/',
        '/home',
        '/home?code=ABC234',
        '/tasbih/friends?code=ABC234',
        '/added?code=ABC234',
      ]) {
        final Uri uri = Uri.parse(location);
        expect(IncomingInvite.matches(uri), isFalse, reason: location);
        expect(IncomingInvite.codeIn(uri), isNull, reason: location);
      }
    });
  });

  group('InviteRouting', () {
    late List<String> remembered;
    late InviteRouting routing;

    setUp(() {
      remembered = <String>[];
      routing = InviteRouting(remember: remembered.add);
    });

    test('warm, a link goes straight to Friends with its code kept', () {
      final String next = routing.onInvite(
        Uri.parse('layla://add/?code=ABC234'),
        cold: false,
      );
      expect(next, Routes.friends);
      expect(remembered, <String>['ABC234']);
      // Nothing is pending afterwards: home is left alone.
      expect(routing.onNavigation(Routes.home), isNull);
    });

    test('cold, the splash plays first and the next home becomes Friends', () {
      final String next = routing.onInvite(
        Uri.parse('/?code=ABC234'),
        cold: true,
      );
      expect(next, Routes.splash);
      expect(remembered, <String>['ABC234']);

      // The splash may go through onboarding or the account screens first;
      // none of those is diverted.
      expect(routing.onNavigation(Routes.onboarding), isNull);
      expect(routing.onNavigation(Routes.welcome), isNull);
      expect(routing.onNavigation(Routes.tasbih), isNull);

      expect(routing.onNavigation(Routes.home), Routes.friends);
      expect(
        routing.onNavigation(Routes.home),
        isNull,
        reason: 'once; the person can go home afterwards',
      );
    });

    test('cold with no code, the splash plays and nothing is diverted', () {
      expect(routing.onInvite(Uri.parse('/add'), cold: true), Routes.splash);
      expect(remembered, isEmpty);
      expect(routing.onNavigation(Routes.home), isNull);
    });

    test('warm with no code still opens Friends, and remembers nothing', () {
      expect(routing.onInvite(Uri.parse('/add'), cold: false), Routes.friends);
      expect(remembered, isEmpty);
    });
  });

  test('the routes the links resolve to', () {
    expect(Routes.addFriend, '/add');
    expect(Routes.addFriendWeb, '/layla-pro/add.html');
    expect(Routes.circle('c1'), '/tasbih/friends/circles/c1');
    expect(Routes.circle('c1'), startsWith('${Routes.friends}/'));
  });
}
