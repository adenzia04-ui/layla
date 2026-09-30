import 'package:flutter/foundation.dart';

/// The four voices offered, chosen for being the ones most people already
/// know from the mushaf apps and the masjid: the easiest voices to
/// memorise with are the ones already in the ear.
///
/// Every recording is served one ayah at a time by everyayah.com, which is
/// what lets the reader move and repeat by ayah. A file is fetched once and
/// kept on the device after that.
@immutable
class Reciter {
  const Reciter({
    required this.id,
    required this.name,
    required this.detail,
    required this.folder,
  });

  final String id;
  final String name;
  final String detail;

  /// The directory on everyayah.com.
  final String folder;

  Uri url(int surah, int ayah) => Uri.parse(
    'https://everyayah.com/data/$folder/'
    '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3',
  );
}

const List<Reciter> reciters = <Reciter>[
  Reciter(
    id: 'alafasy',
    name: 'Mishary Rashid Alafasy',
    detail: 'Clear and measured — the most widely used voice',
    folder: 'Alafasy_128kbps',
  ),
  Reciter(
    id: 'abdulbasit',
    name: 'Abdul Basit Abdus Samad',
    detail: 'Murattal — steady, unhurried',
    folder: 'Abdul_Basit_Murattal_192kbps',
  ),
  Reciter(
    id: 'sudais',
    name: 'Abdur-Rahman As-Sudais',
    detail: 'Imam of the Haram in Makkah',
    folder: 'Abdurrahmaan_As-Sudais_192kbps',
  ),
  Reciter(
    id: 'husary',
    name: 'Mahmoud Khalil Al-Husary',
    detail: 'Precise tajweed — the teachers’ favourite',
    folder: 'Husary_128kbps',
  ),
];

Reciter reciterById(String id) => reciters.firstWhere(
  (Reciter r) => r.id == id,
  orElse: () => reciters.first,
);
