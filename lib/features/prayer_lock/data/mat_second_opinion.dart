import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/mat_check.dart';

final Provider<MatSecondOpinion> matSecondOpinionProvider =
    Provider<MatSecondOpinion>(
      (Ref ref) => MatSecondOpinion(ref.watch(firebaseAuthProvider)),
    );

/// Asks Claude about the photos the on-device check cannot settle.
///
/// Only the ambiguous ones — roughly 15% — ever leave the phone. That is not
/// only a cost decision: the Step 2 photo is the inside of someone's home, and
/// the fewer that travel, the better. When this is not configured, or the
/// network is down, or anything at all goes wrong, the answer is
/// [MatVerdict.unsure], which the caller treats as a pass. A prayer must never
/// go unconfirmed because a server had a bad day.
class MatSecondOpinion {
  const MatSecondOpinion(this._auth);

  final FirebaseAuth _auth;

  static const Duration _timeout = Duration(seconds: 12);

  bool get available => AppConfig.canAskClaudeAboutMat;

  /// [bytes] is the shrunk copy, not the capture — see `MatVision.inspect`.
  Future<MatVerdict> ask(Uint8List bytes, String mediaType) async {
    if (!available) return MatVerdict.unsure;
    try {
      final String? token = await _auth.currentUser?.getIdToken();
      if (token == null) return MatVerdict.unsure;

      // The Worker rejects anything much larger. A 640px JPEG lands around
      // 50KB, so this only ever catches the fallback path where the shrink
      // failed and the full capture is being sent instead.
      if (bytes.length > 280 * 1024) return MatVerdict.unsure;

      final http.Response res = await http
          .post(
            Uri.parse(AppConfig.matCheckEndpoint),
            headers: <String, String>{
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, Object?>{
              'image': base64Encode(bytes),
              'mediaType': mediaType,
            }),
          )
          .timeout(_timeout);

      if (res.statusCode != 200) {
        debugPrint('Layla Pro: mat second opinion ${res.statusCode}');
        return MatVerdict.unsure;
      }
      final Object? decoded = jsonDecode(res.body);
      if (decoded is! Map<String, Object?>) return MatVerdict.unsure;
      return switch (decoded['verdict']) {
        'mat' => MatVerdict.looksRight,
        'other' => MatVerdict.looksWrong,
        _ => MatVerdict.unsure,
      };
    } on Object catch (e) {
      debugPrint('Layla Pro: mat second opinion failed ($e)');
      return MatVerdict.unsure;
    }
  }
}
