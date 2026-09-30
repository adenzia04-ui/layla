import 'package:flutter/foundation.dart';

import '../../../core/audio/recitation_handler.dart';
import '../domain/dua_text.dart';

/// One place in a section's queue: a dua, and how many times it is read.
@immutable
class DuaQueueItem {
  const DuaQueueItem({
    required this.number,
    required this.position,
    required this.passes,
  });

  /// The book's number, which is what the recording file is named after.
  final int number;

  /// The dua's place in its section, counting from 1 — the number shown.
  final int position;

  /// How many times it is read before the next dua.
  final int passes;

  @override
  bool operator ==(Object other) =>
      other is DuaQueueItem &&
      other.number == number &&
      other.position == position &&
      other.passes == passes;

  @override
  int get hashCode => Object.hash(number, position, passes);

  @override
  String toString() => 'Dua $position (#$number ×$passes)';
}

/// The queue a section plays as: every dua that has words to recite, in
/// order, each read [repeat] times (held to 1–10) before the next.
///
/// Repeating is a learning tool — hear it, say it with the reciter, hear it
/// again — so the repeats sit together rather than the whole section
/// looping. A dua the book marks as "×3" is still read once per pass here:
/// the count the person chose is the count they get, and the book's own
/// instruction is printed beside the text where it belongs.
List<DuaQueueItem> buildDuaQueue(List<DuaText> duas, {required int repeat}) {
  final int passes = repeat.clamp(1, 10);
  return <DuaQueueItem>[
    for (int i = 0; i < duas.length; i++)
      if (duas[i].hasArabic)
        DuaQueueItem(number: duas[i].number, position: i + 1, passes: passes),
  ];
}

/// The bundled recording of one dua. 267 duas of *Fortress of the Muslim*
/// read aloud, one file each, keyed by the same number the text and the
/// printed page use, so the audio can never drift from the words on the
/// screen.
String duaAssetFor(int number) => 'assets/duas/audio/$number.m4a';

/// The queue's owner key: one per section, so a section's list can tell
/// its own recitation from another section's.
String duaOwner(int section) => 'dua:$section';

/// The tracks the recitation player is handed for a section.
///
/// The lock screen reads "Dua 1 · Evening Adhkar", then "Layla Pro"; next
/// and previous move by dua.
List<RecitationTrack> duaTracks(
  DuaTextSection section, {
  required String heading,
  required int repeat,
}) => <RecitationTrack>[
  for (final DuaQueueItem item in buildDuaQueue(section.duas, repeat: repeat))
    RecitationTrack(
      id: '${item.number}',
      group: '${item.number}',
      title: 'Dua ${item.position} · $heading',
      subtitle: 'Layla Pro',
      album: heading,
      asset: duaAssetFor(item.number),
      passes: item.passes,
    ),
];
