import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

/// Asks the Worker to send a welcome email to whoever just signed up.
///
/// Deliberately sends *only* the Firebase ID token. The Worker resolves the
/// address with Google itself, so this cannot be pointed at somebody else's
/// inbox even if the request were tampered with.
///
/// Every failure is swallowed. A greeting that does not arrive is a
/// disappointment; a sign-up that fails because of one is a bug.
class WelcomeEmail {
  const WelcomeEmail();

  Future<void> sendFor(User user) async {
    if (!AppConfig.canSendWelcomeEmail) return;
    if (user.isAnonymous || (user.email ?? '').isEmpty) return;

    try {
      final String? token = await user.getIdToken();
      if (token == null) return;

      final http.Response res = await http
          .post(
            Uri.parse(AppConfig.welcomeEmailEndpoint),
            headers: <String, String>{
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode(const <String, Object?>{}),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        debugPrint('Layla: welcome email refused (${res.statusCode})');
      }
    } on Object catch (error) {
      debugPrint('Layla: welcome email not sent — $error');
    }
  }
}
