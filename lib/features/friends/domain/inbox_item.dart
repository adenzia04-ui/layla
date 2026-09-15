import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'friend.dart';

/// The three things a friend can put in your inbox.
///
/// No fourth, and no free text on any of them. A verse is one of the app's
/// own passages, an Eid greeting is a fixed sentence, and a circle invitation
/// carries a code. The only typed words that ever travel between two people
/// are a masjid name, and that is on the Jumu'ah document, not here.
enum InboxType {
  verse,
  eid,
  circle;

  /// The stored form, which `firestore.rules` holds to exactly these three.
  String get key => name;

  static InboxType? fromKey(String? key) {
    for (final InboxType value in values) {
      if (value.key == key) return value;
    }
    return null;
  }
}

/// Something a friend sent: `inbox/{toUid}/items/{itemId}`.
///
/// Read and deleted by the owner, created by the friend, never edited. An
/// item exists until the owner dismisses it, so "unread" and "present" are the
/// same thing — there is no read flag to keep in step.
@immutable
class InboxItem {
  const InboxItem({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromName,
    required this.at,
    this.comfortId,
    this.circleId,
    this.circleCode,
  });

  /// The longest passage id the rules take. `Comfort.id` is a source and a
  /// reference, well inside this; the ceiling is against a raw SDK, not the
  /// app.
  static const int maxComfortIdLength = 80;

  /// The longest circle id the rules take; Firestore's own ids are twenty.
  static const int maxCircleIdLength = 40;

  final String id;
  final InboxType type;
  final String fromUid;

  /// The sender's name, copied at send time — their user document is private,
  /// so this is the only place the recipient can read it from.
  final String fromName;

  /// Server time of the send.
  final DateTime at;

  /// `Comfort.id` of the passage, for [InboxType.verse] only.
  final String? comfortId;

  /// The circle and the code that joins it, for [InboxType.circle] only.
  final String? circleId;
  final String? circleCode;

  /// The stored item read back, or null when it is not one this app could
  /// have sent.
  ///
  /// Tested rather than cast throughout: the document was written by somebody
  /// else, and anything off in it would otherwise throw inside the owner's
  /// inbox listener and take every other item down with it. A type a newer
  /// build added is skipped rather than shown as something it is not.
  static InboxItem? fromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    final Map<String, Object?> data = doc.data() ?? <String, Object?>{};
    final Object? type = data['type'];
    final Object? fromUid = data['fromUid'];
    final Object? at = data['at'];
    final InboxType? parsed = InboxType.fromKey(type is String ? type : null);
    if (parsed == null || fromUid is! String || fromUid.isEmpty) return null;
    if (at is! Timestamp) return null;
    return InboxItem(
      id: doc.id,
      type: parsed,
      fromUid: fromUid,
      fromName: FriendName.clean(
        data['fromName'] is String ? data['fromName'] as String : null,
      ),
      at: at.toDate(),
      comfortId: _string(data['comfortId']),
      circleId: _string(data['circleId']),
      circleCode: _string(data['circleCode']),
    );
  }

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  /// The document to create for one send, in exactly the shape the rules
  /// take for [type] and nothing else: the common four keys, plus the
  /// passage for a verse or the circle and its code for an invitation. The
  /// server stamps `at`.
  ///
  /// Takes its inputs as given. The repository is where a passage id or a
  /// code is checked before this is built, because that is where a refusal
  /// can be turned into a sentence for the sender.
  static Map<String, Object?> payload({
    required InboxType type,
    required String fromUid,
    required String fromName,
    String? comfortId,
    String? circleId,
    String? circleCode,
  }) => <String, Object?>{
    'type': type.key,
    'fromUid': fromUid,
    'fromName': FriendName.clean(fromName),
    'at': FieldValue.serverTimestamp(),
    if (type == InboxType.verse) 'comfortId': comfortId,
    if (type == InboxType.circle) ...<String, Object?>{
      'circleId': circleId,
      'circleCode': circleCode,
    },
  };

  @override
  bool operator ==(Object other) =>
      other is InboxItem &&
      other.id == id &&
      other.type == type &&
      other.fromUid == fromUid &&
      other.fromName == fromName &&
      other.at == at &&
      other.comfortId == comfortId &&
      other.circleId == circleId &&
      other.circleCode == circleCode;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    fromUid,
    fromName,
    at,
    comfortId,
    circleId,
    circleCode,
  );
}
