import 'package:flutter/foundation.dart';

/// A voice the Qur'an can be heard in.
///
/// Most are served one ayah at a time by everyayah.com, which is what lets
/// the reader move, highlight and repeat by ayah. One is not: Sheikh
/// Muhammad Al-Luhaidan's recordings exist only as whole surahs, so he is
/// offered as a whole-surah voice — the surah plays straight through and the
/// ayah-by-ayah tools stand down while he is chosen. A file is fetched once
/// and kept on the device after that.
@immutable
class Reciter {
  const Reciter._({
    required this.id,
    required this.name,
    required this.detail,
    required this.perAyah,
    this.folder,
    this.surahBase,
  });

  /// One file per ayah, at `everyayah.com/data/<folder>/SSSAAA.mp3`.
  const Reciter.ayah({
    required String id,
    required String name,
    required String detail,
    required String folder,
  }) : this._(
         id: id,
         name: name,
         detail: detail,
         perAyah: true,
         folder: folder,
       );

  /// One file per surah, at `<surahBase>/SSS.mp3`.
  const Reciter.surah({
    required String id,
    required String name,
    required String detail,
    required String surahBase,
  }) : this._(
         id: id,
         name: name,
         detail: detail,
         perAyah: false,
         surahBase: surahBase,
       );

  final String id;
  final String name;
  final String detail;

  /// True when the voice is available ayah by ayah.
  final bool perAyah;
  final String? folder;
  final String? surahBase;

  static String _pad3(int n) => n.toString().padLeft(3, '0');

  /// The recording of one ayah. Only for [perAyah] voices.
  Uri url(int surah, int ayah) => Uri.parse(
    'https://everyayah.com/data/$folder/${_pad3(surah)}${_pad3(ayah)}.mp3',
  );

  /// The recording of a whole surah. Only for whole-surah voices.
  Uri surahUrl(int surah) => Uri.parse('$surahBase/${_pad3(surah)}.mp3');

  /// The Bismillah read before [surah], in this voice — the voice's own
  /// Al-Fatihah 1:1, since the files for ayah 1 of the other surahs start
  /// with the ayah itself. Null where the mushaf prints none (Al-Fatihah,
  /// whose first ayah it is, and At-Tawbah) and for a whole-surah voice,
  /// whose surah files open with it.
  Uri? bismillahFor(int surah) =>
      perAyah && surah != 1 && surah != 9 ? url(1, 1) : null;

  /// Every file a surah needs in this voice — what "download" means.
  List<Uri> filesFor(int surah, int ayahCount) => perAyah
      ? <Uri>[for (int a = 1; a <= ayahCount; a++) url(surah, a)]
      : <Uri>[surahUrl(surah)];
}

/// The voices offered, the most listened-to first. The ones people already
/// know from the mushaf apps and the masjid are the easiest to memorise
/// with, because they are already in the ear.
const List<Reciter> reciters = <Reciter>[
  Reciter.ayah(
    id: 'alafasy',
    name: 'Mishary Rashid Alafasy',
    detail: 'Clear and measured — the most widely used voice',
    folder: 'Alafasy_128kbps',
  ),
  Reciter.ayah(
    id: 'abdulbasit',
    name: 'Abdul Basit Abdus Samad',
    detail: 'Murattal — steady, unhurried',
    folder: 'Abdul_Basit_Murattal_192kbps',
  ),
  Reciter.ayah(
    id: 'sudais',
    name: 'Abdur-Rahman As-Sudais',
    detail: 'Imam of the Haram in Makkah',
    folder: 'Abdurrahmaan_As-Sudais_192kbps',
  ),
  Reciter.ayah(
    id: 'husary',
    name: 'Mahmoud Khalil Al-Husary',
    detail: 'Precise tajweed — the teachers’ favourite',
    folder: 'Husary_128kbps',
  ),
  Reciter.surah(
    id: 'luhaidan',
    name: 'Muhammad Al-Luhaidan',
    detail: 'Riyadh — whole surah only, no ayah-by-ayah',
    surahBase: 'https://server8.mp3quran.net/lhdan',
  ),
  Reciter.ayah(
    id: 'shuraym',
    name: 'Saud Ash-Shuraym',
    detail: 'Imam of the Haram in Makkah',
    folder: 'Saood_ash-Shuraym_128kbps',
  ),
  Reciter.ayah(
    id: 'muaiqly',
    name: 'Maher Al-Muaiqly',
    detail: 'Imam of the Haram — warm and even',
    folder: 'MaherAlMuaiqly128kbps',
  ),
  Reciter.ayah(
    id: 'minshawi',
    name: 'Mohamed Siddiq Al-Minshawi',
    detail: 'Murattal — the classic Egyptian school',
    folder: 'Minshawy_Murattal_128kbps',
  ),
  Reciter.ayah(
    id: 'hudhaify',
    name: 'Ali Al-Hudhaify',
    detail: 'Imam of the Prophet’s Mosque in Madinah',
    folder: 'Hudhaify_128kbps',
  ),
  Reciter.ayah(
    id: 'shatri',
    name: 'Abu Bakr Ash-Shatri',
    detail: 'Bright and quick — good for pace',
    folder: 'Abu_Bakr_Ash-Shaatree_128kbps',
  ),
  Reciter.ayah(
    id: 'ayyoub',
    name: 'Muhammad Ayyoub',
    detail: 'Madinah — gentle and slow, for beginners',
    folder: 'Muhammad_Ayyoub_128kbps',
  ),
  Reciter.ayah(
    id: 'ghamdi',
    name: 'Saad Al-Ghamdi',
    detail: 'Soft and calm — small files',
    folder: 'Ghamadi_40kbps',
  ),
  Reciter.ayah(
    id: 'rifai',
    name: 'Hani Ar-Rifai',
    detail: 'Jeddah — melodic',
    folder: 'Hani_Rifai_192kbps',
  ),
  Reciter.ayah(
    id: 'basfar',
    name: 'Abdullah Basfar',
    detail: 'Jeddah — clear articulation',
    folder: 'Abdullah_Basfar_192kbps',
  ),
  Reciter.ayah(
    id: 'jibreel',
    name: 'Muhammad Jibreel',
    detail: 'Cairo — measured tajweed',
    folder: 'Muhammad_Jibreel_128kbps',
  ),
  Reciter.ayah(
    id: 'budair',
    name: 'Salah Al-Budair',
    detail: 'Imam of the Prophet’s Mosque in Madinah',
    folder: 'Salah_Al_Budair_128kbps',
  ),
  Reciter.ayah(
    id: 'qasim',
    name: 'Muhsin Al-Qasim',
    detail: 'Imam of the Prophet’s Mosque in Madinah',
    folder: 'Muhsin_Al_Qasim_192kbps',
  ),
  Reciter.ayah(
    id: 'juhany',
    name: 'Abdullah Al-Juhany',
    detail: 'Imam of the Haram in Makkah',
    folder: 'Abdullaah_3awwaad_Al-Juhaynee_128kbps',
  ),
];

Reciter reciterById(String id) => reciters.firstWhere(
  (Reciter r) => r.id == id,
  orElse: () => reciters.first,
);
