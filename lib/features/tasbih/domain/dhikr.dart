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
  });

  final String name;
  final String arabic;
  final String meaning;
  final int defaultTarget;

  static const List<Dhikr> presets = <Dhikr>[
    Dhikr(
      name: 'SubhanAllah',
      arabic: 'سُبْحَانَ ٱللَّٰه',
      meaning: 'Glory be to Allah',
      defaultTarget: 33,
    ),
    Dhikr(
      name: 'Alhamdulillah',
      arabic: 'ٱلْحَمْدُ لِلَّٰه',
      meaning: 'All praise is due to Allah',
      defaultTarget: 33,
    ),
    Dhikr(
      name: 'Allahu Akbar',
      arabic: 'ٱللَّٰهُ أَكْبَر',
      meaning: 'Allah is the greatest',
      defaultTarget: 34,
    ),
    Dhikr(
      name: 'La ilaha illa Allah',
      arabic: 'لَا إِلَٰهَ إِلَّا ٱللَّٰه',
      meaning: 'There is no god but Allah',
      defaultTarget: 100,
    ),
    Dhikr(
      name: 'Astaghfirullah',
      arabic: 'أَسْتَغْفِرُ ٱللَّٰه',
      meaning: 'I seek forgiveness from Allah',
      defaultTarget: 100,
    ),
    Dhikr(
      name: 'Salawat',
      arabic: 'ٱللَّٰهُمَّ صَلِّ عَلَىٰ مُحَمَّد',
      meaning: 'Blessings upon the Prophet ﷺ',
      defaultTarget: 100,
    ),
  ];

  static Dhikr byName(String name) => presets.firstWhere(
        (Dhikr d) => d.name == name,
        orElse: () => presets.first,
      );
}
