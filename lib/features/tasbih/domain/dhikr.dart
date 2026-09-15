import 'package:flutter/foundation.dart';

/// The presets offered on the Tasbih screen. Custom targets are supported too;
/// these are just the common ones so the user rarely has to type a number.
@immutable
class Dhikr {
  const Dhikr({
    required this.name,
    required this.arabic,
    required this.meaning,
    required this.defaultTarget,
    this.transliteration,
    this.source,
  });

  final String name;
  final String arabic;
  final String meaning;
  final int defaultTarget;

  /// The full phrase in Latin letters, where [name] is only a short label for
  /// it. Set on anything long enough that the two differ.
  final String? transliteration;

  /// Where it is from, for anything quoted rather than remembered — a surah
  /// and ayah reference. Null for the dhikr phrases.
  final String? source;

  /// What to read aloud. Falls back to the label when they are the same.
  String get spoken => transliteration ?? name;

  /// Short counts are recited from the text rather than tapped out, so the
  /// screen shows the words and asks for a confirmation instead of a ring.
  bool get isRecited => defaultTarget <= 3;

  static const Dhikr subhanAllah = Dhikr(
    name: 'SubhanAllah',
    arabic: 'سُبْحَانَ ٱللَّٰه',
    meaning: 'Glory be to Allah',
    defaultTarget: 33,
  );

  static const Dhikr alhamdulillah = Dhikr(
    name: 'Alhamdulillah',
    arabic: 'ٱلْحَمْدُ لِلَّٰه',
    meaning: 'All praise is due to Allah',
    defaultTarget: 33,
  );

  static const Dhikr allahuAkbar = Dhikr(
    name: 'Allahu Akbar',
    arabic: 'ٱللَّٰهُ أَكْبَر',
    meaning: 'Allah is the greatest',
    defaultTarget: 34,
  );

  static const Dhikr laIlahaIllaAllah = Dhikr(
    name: 'La ilaha illa Allah',
    arabic: 'لَا إِلَٰهَ إِلَّا ٱللَّٰه',
    meaning: 'There is no god but Allah',
    defaultTarget: 100,
  );

  static const Dhikr astaghfirullah = Dhikr(
    name: 'Astaghfirullah',
    arabic: 'أَسْتَغْفِرُ ٱللَّٰه',
    meaning: 'I seek forgiveness from Allah',
    defaultTarget: 100,
  );

  static const Dhikr salawat = Dhikr(
    name: 'Salawat',
    arabic: 'ٱللَّٰهُمَّ صَلِّ عَلَىٰ مُحَمَّد',
    meaning: 'Blessings upon the Prophet \u{FDFA}',
    defaultTarget: 100,
  );

  static const Dhikr subhanAllahiWaBihamdihi = Dhikr(
    name: 'SubhanAllahi wa bihamdihi',
    arabic: 'سُبْحَانَ ٱللَّٰهِ وَبِحَمْدِهِ',
    meaning: 'Glory be to Allah, and praise be to Him',
    defaultTarget: 100,
  );

  /// The full tahlil, not the short 'La ilaha illa Allah'. Sahih al-Bukhari
  /// 6403 attaches its reward to this whole wording, so the shorter phrase is
  /// kept separate rather than reused here.
  static const Dhikr tahlil = Dhikr(
    name: 'La ilaha illallah wahdahu',
    transliteration:
        'La ilaha illallahu wahdahu la sharika lah, lahul-mulku '
        'wa lahul-hamdu, wa huwa \'ala kulli shay\'in qadir',
    arabic:
        'لَا إِلَٰهَ إِلَّا ٱللَّٰهُ وَحْدَهُ لَا شَرِيكَ لَهُ، '
        'لَهُ ٱلْمُلْكُ وَلَهُ ٱلْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ',
    meaning:
        'There is no god but Allah alone, with no partner. His is the '
        'dominion and His the praise, and He is able to do all things',
    defaultTarget: 100,
  );

  static const Dhikr juwayriyah = Dhikr(
    name: "SubhanAllahi wa bihamdihi 'adada khalqihi",
    transliteration:
        "SubhanAllahi wa bihamdihi 'adada khalqihi, wa rida "
        "nafsihi, wa zinata 'arshihi, wa midada kalimatihi",
    arabic:
        'سُبْحَانَ ٱللَّٰهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، '
        'وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ',
    meaning:
        'Glory and praise be to Allah, as many as His creation, as much '
        'as pleases Him, as the weight of His throne and the ink of His words',
    defaultTarget: 3,
  );

  static const Dhikr raditu = Dhikr(
    name: 'Raditu billahi rabban',
    transliteration:
        'Raditu billahi rabban, wa bil-islami dinan, wa bi '
        'Muhammadin nabiyyan',
    arabic:
        'رَضِيتُ بِٱللَّٰهِ رَبًّا، وَبِٱلْإِسْلَامِ دِينًا، '
        'وَبِمُحَمَّدٍ نَبِيًّا',
    meaning:
        'I am pleased with Allah as Lord, with Islam as religion and '
        'with Muhammad as Prophet',
    defaultTarget: 3,
  );

  /// No count comes with this one — Sahih al-Bukhari 6384 calls it a treasure
  /// of Paradise and sets no number. It is a Manual preset for that reason;
  /// the hundred here is a starting target, not a sunnah.
  static const Dhikr laHawla = Dhikr(
    name: 'La hawla wa la quwwata illa billah',
    arabic: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِٱللَّٰهِ',
    meaning: 'There is no power nor strength except by Allah',
    defaultTarget: 100,
  );

  static const List<Dhikr> presets = <Dhikr>[
    subhanAllah,
    alhamdulillah,
    allahuAkbar,
    laIlahaIllaAllah,
    astaghfirullah,
    salawat,
    laHawla,
    subhanAllahiWaBihamdihi,
  ];

  @override
  bool operator ==(Object other) =>
      other is Dhikr &&
      other.name == name &&
      other.defaultTarget == defaultTarget;

  @override
  int get hashCode => Object.hash(name, defaultTarget);

  static Dhikr byName(String name) => presets.firstWhere(
    (Dhikr d) => d.name == name,
    orElse: () => presets.first,
  );
}
