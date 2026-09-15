import 'package:flutter/foundation.dart';

/// One of the Names.
///
/// The Arabic is the name as written; the meaning is one line, the way it
/// is most commonly rendered in English; and where a verse is given it is
/// one in which that name appears, so the reader can meet it in its place.
/// Names whose Qur'anic occurrence is a matter of derivation rather than a
/// plain appearance carry no verse rather than a strained one.
@immutable
class DivineName {
  const DivineName(
    this.arabic,
    this.transliteration,
    this.meaning, [
    this.verse,
  ]);

  final String arabic;
  final String transliteration;
  final String meaning;

  /// "Al-Hashr 59:23", when the name appears there in so many words.
  final String? verse;
}

/// The ninety-nine, in the order of the well-known list from at-Tirmidhi.
abstract final class NamesOfAllah {
  /// The name for a day: the same one all day, the next one tomorrow, round
  /// the list in a hundred days and again.
  static DivineName forDay(DateTime day) {
    final int start = DateTime(
      day.year,
      1,
      1,
    ).difference(DateTime(2026)).inDays;
    final int ofYear = day.difference(DateTime(day.year, 1, 1)).inDays;
    return all[(start + ofYear) % all.length];
  }

  static int indexOf(DivineName n) => all.indexOf(n);

  static const List<DivineName> all = <DivineName>[
    DivineName(
      'الرَّحْمَنُ',
      'Ar-Rahman',
      'The Most Merciful',
      'Ar-Rahman 55:1',
    ),
    DivineName(
      'الرَّحِيمُ',
      'Ar-Rahim',
      'The Especially Merciful',
      'Al-Fatihah 1:3',
    ),
    DivineName('الْمَلِكُ', 'Al-Malik', 'The King', 'Al-Hashr 59:23'),
    DivineName('الْقُدُّوسُ', 'Al-Quddus', 'The Most Holy', 'Al-Hashr 59:23'),
    DivineName(
      'السَّلَامُ',
      'As-Salam',
      'The Source of Peace',
      'Al-Hashr 59:23',
    ),
    DivineName(
      'الْمُؤْمِنُ',
      "Al-Mu'min",
      'The Giver of Security',
      'Al-Hashr 59:23',
    ),
    DivineName(
      'الْمُهَيْمِنُ',
      'Al-Muhaymin',
      'The Guardian over all',
      'Al-Hashr 59:23',
    ),
    DivineName('الْعَزِيزُ', "Al-'Aziz", 'The Almighty', 'Al-Hashr 59:23'),
    DivineName(
      'الْجَبَّارُ',
      'Al-Jabbar',
      'The Compeller, the Restorer',
      'Al-Hashr 59:23',
    ),
    DivineName(
      'الْمُتَكَبِّرُ',
      'Al-Mutakabbir',
      'The Supreme in greatness',
      'Al-Hashr 59:23',
    ),
    DivineName('الْخَالِقُ', 'Al-Khaliq', 'The Creator', 'Al-Hashr 59:24'),
    DivineName(
      'الْبَارِئُ',
      "Al-Bari'",
      'The Maker from nothing',
      'Al-Hashr 59:24',
    ),
    DivineName(
      'الْمُصَوِّرُ',
      'Al-Musawwir',
      'The Fashioner of forms',
      'Al-Hashr 59:24',
    ),
    DivineName(
      'الْغَفَّارُ',
      'Al-Ghaffar',
      'The Ever-Forgiving',
      'Ta-Ha 20:82',
    ),
    DivineName('الْقَهَّارُ', 'Al-Qahhar', 'The Subduer', 'Yusuf 12:39'),
    DivineName('الْوَهَّابُ', 'Al-Wahhab', 'The Bestower', 'Aal Imran 3:8'),
    DivineName(
      'الرَّزَّاقُ',
      'Ar-Razzaq',
      'The Provider',
      'Adh-Dhariyat 51:58',
    ),
    DivineName(
      'الْفَتَّاحُ',
      'Al-Fattah',
      'The Opener, the Judge',
      "Saba' 34:26",
    ),
    DivineName('الْعَلِيمُ', "Al-'Alim", 'The All-Knowing', 'Al-Baqarah 2:32'),
    DivineName('الْقَابِضُ', 'Al-Qabid', 'The Withholder'),
    DivineName('الْبَاسِطُ', 'Al-Basit', 'The Extender'),
    DivineName('الْخَافِضُ', 'Al-Khafid', 'The Abaser'),
    DivineName('الرَّافِعُ', "Ar-Rafi'", 'The Exalter'),
    DivineName('الْمُعِزُّ', "Al-Mu'izz", 'The Giver of honour'),
    DivineName('الْمُذِلُّ', 'Al-Mudhill', 'The Giver of dishonour'),
    DivineName('السَّمِيعُ', "As-Sami'", 'The All-Hearing', 'Al-Baqarah 2:127'),
    DivineName('الْبَصِيرُ', 'Al-Basir', 'The All-Seeing', "An-Nisa' 4:58"),
    DivineName('الْحَكَمُ', 'Al-Hakam', 'The Judge', "Al-An'am 6:114"),
    DivineName('الْعَدْلُ', "Al-'Adl", 'The Utterly Just'),
    DivineName(
      'اللَّطِيفُ',
      'Al-Latif',
      'The Subtle, the Kind',
      "Al-An'am 6:103",
    ),
    DivineName('الْخَبِيرُ', 'Al-Khabir', 'The All-Aware', "Al-An'am 6:103"),
    DivineName('الْحَلِيمُ', 'Al-Halim', 'The Forbearing', 'Al-Baqarah 2:235'),
    DivineName('الْعَظِيمُ', "Al-'Azim", 'The Magnificent', 'Al-Baqarah 2:255'),
    DivineName(
      'الْغَفُورُ',
      'Al-Ghafur',
      'The All-Forgiving',
      'Al-Baqarah 2:173',
    ),
    DivineName('الشَّكُورُ', 'Ash-Shakur', 'The Appreciative', 'Fatir 35:30'),
    DivineName('الْعَلِيُّ', "Al-'Aliyy", 'The Most High', 'Al-Baqarah 2:255'),
    DivineName('الْكَبِيرُ', 'Al-Kabir', 'The Most Great', "Ar-Ra'd 13:9"),
    DivineName('الْحَفِيظُ', 'Al-Hafiz', 'The Preserver', 'Hud 11:57'),
    DivineName('الْمُقِيتُ', 'Al-Muqit', 'The Sustainer', "An-Nisa' 4:85"),
    DivineName('الْحَسِيبُ', 'Al-Hasib', 'The Reckoner', "An-Nisa' 4:6"),
    DivineName('الْجَلِيلُ', 'Al-Jalil', 'The Majestic'),
    DivineName('الْكَرِيمُ', 'Al-Karim', 'The Generous', 'An-Naml 27:40'),
    DivineName('الرَّقِيبُ', 'Ar-Raqib', 'The Watchful', "An-Nisa' 4:1"),
    DivineName('الْمُجِيبُ', 'Al-Mujib', 'The Responsive', 'Hud 11:61'),
    DivineName(
      'الْوَاسِعُ',
      "Al-Wasi'",
      'The All-Encompassing',
      'Al-Baqarah 2:115',
    ),
    DivineName('الْحَكِيمُ', 'Al-Hakim', 'The All-Wise', 'Al-Baqarah 2:129'),
    DivineName('الْوَدُودُ', 'Al-Wadud', 'The Loving', 'Hud 11:90'),
    DivineName('الْمَجِيدُ', 'Al-Majid', 'The Glorious', 'Hud 11:73'),
    DivineName('الْبَاعِثُ', "Al-Ba'ith", 'The Resurrector'),
    DivineName('الشَّهِيدُ', 'Ash-Shahid', 'The Witness', "An-Nisa' 4:79"),
    DivineName('الْحَقُّ', 'Al-Haqq', 'The Truth', 'Al-Hajj 22:6'),
    DivineName('الْوَكِيلُ', 'Al-Wakil', 'The Trustee', 'Aal Imran 3:173'),
    DivineName('الْقَوِيُّ', 'Al-Qawiyy', 'The All-Strong', 'Al-Hajj 22:40'),
    DivineName('الْمَتِينُ', 'Al-Matin', 'The Firm', 'Adh-Dhariyat 51:58'),
    DivineName(
      'الْوَلِيُّ',
      'Al-Waliyy',
      'The Protecting Friend',
      'Ash-Shura 42:9',
    ),
    DivineName('الْحَمِيدُ', 'Al-Hamid', 'The Praiseworthy', 'Ibrahim 14:8'),
    DivineName('الْمُحْصِي', 'Al-Muhsi', 'The Counter of all things'),
    DivineName('الْمُبْدِئُ', "Al-Mubdi'", 'The Originator'),
    DivineName('الْمُعِيدُ', "Al-Mu'id", 'The Restorer'),
    DivineName('الْمُحْيِي', 'Al-Muhyi', 'The Giver of life', 'Ar-Rum 30:50'),
    DivineName('الْمُمِيتُ', 'Al-Mumit', 'The Bringer of death'),
    DivineName('الْحَيُّ', 'Al-Hayy', 'The Ever-Living', 'Al-Baqarah 2:255'),
    DivineName(
      'الْقَيُّومُ',
      'Al-Qayyum',
      'The Sustainer of all',
      'Al-Baqarah 2:255',
    ),
    DivineName('الْوَاجِدُ', 'Al-Wajid', 'The Finder'),
    DivineName('الْمَاجِدُ', 'Al-Majid', 'The Noble'),
    DivineName('الْوَاحِدُ', 'Al-Wahid', 'The One', 'Yusuf 12:39'),
    DivineName('الْأَحَدُ', 'Al-Ahad', 'The Unique', 'Al-Ikhlas 112:1'),
    DivineName(
      'الصَّمَدُ',
      'As-Samad',
      'The Eternal Refuge',
      'Al-Ikhlas 112:2',
    ),
    DivineName('الْقَادِرُ', 'Al-Qadir', 'The Able', "Al-An'am 6:65"),
    DivineName(
      'الْمُقْتَدِرُ',
      'Al-Muqtadir',
      'The Omnipotent',
      'Al-Qamar 54:42',
    ),
    DivineName('الْمُقَدِّمُ', 'Al-Muqaddim', 'The Bringer forward'),
    DivineName('الْمُؤَخِّرُ', "Al-Mu'akhkhir", 'The Delayer'),
    DivineName('الْأَوَّلُ', 'Al-Awwal', 'The First', 'Al-Hadid 57:3'),
    DivineName('الْآخِرُ', 'Al-Akhir', 'The Last', 'Al-Hadid 57:3'),
    DivineName('الظَّاهِرُ', 'Az-Zahir', 'The Manifest', 'Al-Hadid 57:3'),
    DivineName('الْبَاطِنُ', 'Al-Batin', 'The Hidden', 'Al-Hadid 57:3'),
    DivineName('الْوَالِي', 'Al-Wali', 'The Governor'),
    DivineName(
      'الْمُتَعَالِي',
      "Al-Muta'ali",
      'The Supremely Exalted',
      "Ar-Ra'd 13:9",
    ),
    DivineName('الْبَرُّ', 'Al-Barr', 'The Source of goodness', 'At-Tur 52:28'),
    DivineName(
      'التَّوَّابُ',
      'At-Tawwab',
      'The Accepter of repentance',
      'Al-Baqarah 2:37',
    ),
    DivineName('الْمُنْتَقِمُ', 'Al-Muntaqim', 'The Avenger'),
    DivineName('الْعَفُوُّ', "Al-'Afuww", 'The Pardoner', "An-Nisa' 4:99"),
    DivineName('الرَّءُوفُ', "Ar-Ra'uf", 'The Kind', 'Al-Baqarah 2:143'),
    DivineName(
      'مَالِكُ الْمُلْكِ',
      'Malik al-Mulk',
      'Owner of all sovereignty',
      'Aal Imran 3:26',
    ),
    DivineName(
      'ذُو الْجَلَالِ وَالْإِكْرَامِ',
      'Dhul-Jalali wal-Ikram',
      'Lord of majesty and honour',
      'Ar-Rahman 55:27',
    ),
    DivineName('الْمُقْسِطُ', 'Al-Muqsit', 'The Equitable'),
    DivineName('الْجَامِعُ', "Al-Jami'", 'The Gatherer', 'Aal Imran 3:9'),
    DivineName(
      'الْغَنِيُّ',
      'Al-Ghaniyy',
      'The Self-Sufficient',
      'Al-Baqarah 2:263',
    ),
    DivineName('الْمُغْنِي', 'Al-Mughni', 'The Enricher'),
    DivineName('الْمَانِعُ', "Al-Mani'", 'The Preventer'),
    DivineName('الضَّارُّ', 'Ad-Darr', 'The Bringer of harm, by His wisdom'),
    DivineName('النَّافِعُ', "An-Nafi'", 'The Bringer of benefit'),
    DivineName('النُّورُ', 'An-Nur', 'The Light', 'An-Nur 24:35'),
    DivineName('الْهَادِي', 'Al-Hadi', 'The Guide', 'Al-Hajj 22:54'),
    DivineName(
      'الْبَدِيعُ',
      "Al-Badi'",
      'The Incomparable Originator',
      'Al-Baqarah 2:117',
    ),
    DivineName('الْبَاقِي', 'Al-Baqi', 'The Everlasting'),
    DivineName(
      'الْوَارِثُ',
      'Al-Warith',
      'The Inheritor of all',
      'Al-Hijr 15:23',
    ),
    DivineName('الرَّشِيدُ', 'Ar-Rashid', 'The Guide to the right way'),
    DivineName('الصَّبُورُ', 'As-Sabur', 'The Patient'),
  ];
}
