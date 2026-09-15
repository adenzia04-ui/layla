import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// How someone says they feel right now.
///
/// The label is the feeling; the hint is its other name, so "Doubtful" and
/// "Seeking certainty" are the same tile rather than two. Ordered so that the
/// heavier feelings come first — that is what most people open this for.
enum Mood {
  anxious('Anxious', 'Worried, restless', Icons.waves_rounded),
  sad('Sad', 'Grieving, heavy-hearted', Icons.water_drop_outlined),
  fearful('Fearful', 'Afraid, unsafe', Icons.shield_outlined),
  lonely('Lonely', 'Disconnected, on my own', Icons.nightlight_outlined),
  angry('Angry', 'Frustrated, provoked', Icons.local_fire_department_outlined),
  hopeless('Hopeless', 'Despairing', Icons.cloud_outlined),
  tired('Overwhelmed', 'Burdened, too much on', Icons.battery_2_bar_rounded),
  weary('Tired', 'Weary, worn out', Icons.bedtime_outlined),
  lost('Lost', 'Confused, unsure of the way', Icons.explore_outlined),
  doubtful('Doubtful', 'Seeking certainty', Icons.help_outline_rounded),
  hardship('In hardship', 'Being tried, tested', Icons.bolt_outlined),
  regretful('Regretful', 'Seeking forgiveness', Icons.refresh_rounded),
  grateful('Grateful', 'Happy, content', Icons.volunteer_activism_outlined),
  joyful('Joyful', 'Thankful, glad', Icons.wb_sunny_outlined),
  hopeful('Hopeful', 'Ready to begin again', Icons.north_east_rounded);

  const Mood(this.label, this.hint, this.icon);

  final String label;
  final String hint;
  final IconData icon;

  Color get tone => switch (this) {
    Mood.anxious => PrayerPalette.asr.end,
    Mood.sad => PrayerPalette.fajr.end,
    Mood.fearful => PrayerPalette.isha.end,
    Mood.lonely => AppColors.mist,
    Mood.angry => AppColors.ember,
    Mood.hopeless => AppColors.goldDim,
    Mood.tired => AppColors.amber,
    Mood.weary => PrayerPalette.asr.start,
    Mood.lost => PrayerPalette.maghrib.end,
    Mood.doubtful => PrayerPalette.sunrise.end,
    Mood.hardship => AppColors.rose,
    Mood.regretful => PrayerPalette.sunrise.start,
    Mood.grateful => AppColors.gold,
    Mood.joyful => PrayerPalette.dhuhr.end,
    Mood.hopeful => AppColors.emerald,
  };

  /// Round-trips through the route parameter.
  static Mood? byName(String? name) {
    for (final Mood m in Mood.values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// Where a passage comes from — it changes how it is typeset and cited.
enum ComfortSource { quran, hadith }

/// One verse or hadith offered for a mood.
///
/// Only the Qur'an carries Arabic here. The verses are short, famous, and
/// easily verified against any mushaf; a hadith's Arabic is longer and
/// varies by narration, and a wrong letter in a hadith is worse than none.
/// Every entry names its collection and number so it can be checked.
@immutable
class Comfort {
  const Comfort({
    required this.source,
    required this.english,
    required this.reference,
    this.arabic,
    this.grade,
  });

  final ComfortSource source;
  final String? arabic;
  final String english;

  /// "Al-Baqarah 2:286" or "Sahih Muslim 2999".
  final String reference;

  /// Only for hadith outside the two Sahihs — "hasan", "sahih".
  final String? grade;

  /// Stable across launches, so a saved card can be found again. The same
  /// passage offered under two moods shares one id, which is right: it is
  /// one passage.
  String get id => '${source.name}:$reference';

  /// Chapter and first verse, for recitation — null for hadith.
  ({int chapter, int verse})? get ayah {
    if (source != ComfortSource.quran) return null;
    final RegExpMatch? m = RegExp(r'(\d+):(\d+)').firstMatch(reference);
    if (m == null) return null;
    return (chapter: int.parse(m.group(1)!), verse: int.parse(m.group(2)!));
  }
}

/// The passages, by mood.
///
/// Chosen for being well known and unambiguous rather than obscure: the point
/// is a line the person may half-remember, met at the moment it lands, not a
/// discovery. Translations of the Qur'an follow Sahih International; clauses
/// are excerpted where the full verse runs long, and the reference always
/// points at the whole verse. Hadith from outside Bukhari and Muslim carry
/// their grading, and nothing graded below hasan is included.
abstract final class MoodComfort {
  static List<Comfort> forMood(Mood mood) => _library[mood]!;

  /// Finds a passage by its [Comfort.id], for the saved list.
  static Comfort? byId(String id) {
    for (final List<Comfort> list in _library.values) {
      for (final Comfort c in list) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  /// The moods a passage is offered under.
  static List<Mood> moodsFor(Comfort c) => <Mood>[
    for (final MapEntry<Mood, List<Comfort>> e in _library.entries)
      if (e.value.any((Comfort x) => x.id == c.id)) e.key,
  ];

  static Comfort _q(String ar, String en, String ref) => Comfort(
    source: ComfortSource.quran,
    arabic: ar,
    english: en,
    reference: ref,
  );

  static Comfort _h(String en, String ref, [String? grade]) => Comfort(
    source: ComfortSource.hadith,
    english: en,
    reference: ref,
    grade: grade,
  );

  static final Map<Mood, List<Comfort>> _library = <Mood, List<Comfort>>{
    // ── Anxious ───────────────────────────────────────────────────────────
    Mood.anxious: <Comfort>[
      _q(
        'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
        'Unquestionably, by the remembrance of Allah hearts are assured.',
        'Ar-Ra\'d 13:28',
      ),
      _q(
        'يَا أَيُّهَا الَّذِينَ آمَنُوا اسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ ۚ '
            'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
        'O you who have believed, seek help through patience and prayer. '
            'Indeed, Allah is with the patient.',
        'Al-Baqarah 2:153',
      ),
      _q(
        'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
        'Sufficient for us is Allah, and He is the best Disposer of affairs.',
        'Al Imran 3:173',
      ),
      _q(
        'أَلَا إِنَّ أَوْلِيَاءَ اللَّهِ لَا خَوْفٌ عَلَيْهِمْ وَلَا هُمْ يَحْزَنُونَ',
        'Unquestionably, for the allies of Allah there will be no fear '
            'concerning them, nor will they grieve.',
        'Yunus 10:62',
      ),
      _q(
        'وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ',
        'And whoever relies upon Allah — then He is sufficient for him.',
        'At-Talaq 65:3',
      ),
      _h(
        'Amazing is the affair of the believer, for all of it is good — and '
            'that is for no one but the believer. If something good reaches '
            'him he is thankful, and that is good for him; and if something '
            'harmful reaches him he is patient, and that is good for him.',
        'Sahih Muslim 2999',
      ),
      _h(
        'The Prophet ﷺ used to say: O Allah, I seek refuge in You from '
            'anxiety and grief, from weakness and laziness, from cowardice '
            'and miserliness, and from being overcome by debt and overpowered '
            'by men.',
        'Sahih al-Bukhari 6369',
      ),
      _q(
        'وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا',
        'And whoever fears Allah — He will make for him a way out.',
        'At-Talaq 65:2',
      ),
      _q(
        'قَالَ رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي',
        'My Lord, expand for me my breast [with assurance] and ease for '
            'me my task.',
        'Ta-Ha 20:25–26',
      ),
      _q(
        'حَسْبِيَ اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ ۖ عَلَيْهِ '
            'تَوَكَّلْتُ ۖ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
        'Sufficient for me is Allah; there is no deity except Him. On '
            'Him I have relied, and He is the Lord of the Great Throne.',
        'At-Tawbah 9:129',
      ),
      _q(
        'رَبَّنَا أَفْرِغْ عَلَيْنَا صَبْرًا وَثَبِّتْ أَقْدَامَنَا',
        'Our Lord, pour upon us patience and plant firmly our feet.',
        'Al-Baqarah 2:250',
      ),
      _h(
        'The Prophet ﷺ said: Shall I not tell you of a word that is one '
            'of the treasures of Paradise? La hawla wa la quwwata illa '
            'billah — there is no power and no strength except with Allah.',
        'Sahih al-Bukhari 6384 · Sahih Muslim 2704',
      ),
      _h(
        'When something distressed the Prophet ﷺ, he would say: O '
            'Ever-Living, O Sustainer, by Your mercy I seek relief.',
        'Jami\' at-Tirmidhi 3524',
        'hasan',
      ),
    ],

    // ── Sad ───────────────────────────────────────────────────────────────
    Mood.sad: <Comfort>[
      _q(
        'لَا تَحْزَنْ إِنَّ اللَّهَ مَعَنَا',
        'Do not grieve; indeed Allah is with us.',
        'At-Tawbah 9:40',
      ),
      _q(
        'مَا وَدَّعَكَ رَبُّكَ وَمَا قَلَىٰ ۝ وَلَلْآخِرَةُ خَيْرٌ لَّكَ مِنَ '
            'الْأُولَىٰ ۝ وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ',
        'Your Lord has not taken leave of you, nor has He detested you. And '
            'the Hereafter is better for you than the first. And your Lord is '
            'going to give you, and you will be satisfied.',
        'Ad-Duha 93:3–5',
      ),
      _q(
        'إِنَّمَا أَشْكُو بَثِّي وَحُزْنِي إِلَى اللَّهِ',
        'I only complain of my suffering and my grief to Allah.',
        'Yusuf 12:86',
      ),
      _q(
        'وَلَا تَيْأَسُوا مِن رَّوْحِ اللَّهِ',
        'And do not despair of relief from Allah.',
        'Yusuf 12:87',
      ),
      _q(
        'إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ',
        'Indeed we belong to Allah, and indeed to Him we will return.',
        'Al-Baqarah 2:156',
      ),
      _h(
        'No fatigue, nor disease, nor sorrow, nor sadness, nor hurt, nor '
            'distress befalls a Muslim — even if it were the prick of a '
            'thorn — but that Allah expiates some of his sins for it.',
        'Sahih al-Bukhari 5641 · Sahih Muslim 2573',
      ),
      _h(
        'There is no Muslim who is stricken with a calamity and says what '
            'Allah has commanded — "Indeed we belong to Allah and to Him we '
            'return; O Allah, reward me in my affliction and give me something '
            'better in its place" — but that Allah gives him something better.',
        'Sahih Muslim 918',
      ),
      _h(
        'If Allah intends good for someone, He afflicts him with trials.',
        'Sahih al-Bukhari 5645',
      ),
      _q(
        'يَا أَيُّهَا النَّاسُ قَدْ جَاءَتْكُم مَّوْعِظَةٌ مِّن رَّبِّكُمْ وَشِفَاءٌ لِّمَا فِي الصُّدُورِ',
        'O mankind, there has come to you instruction from your Lord and healing for what is in the breasts.',
        'Yunus 10:57',
      ),
      _q(
        'فَصَبْرٌ جَمِيلٌ ۖ وَاللَّهُ الْمُسْتَعَانُ',
        'So patience is most fitting. And Allah is the one sought for '
            'help.',
        'Yusuf 12:18',
      ),
      _q(
        'وَاصْبِرْ وَمَا صَبْرُكَ إِلَّا بِاللَّهِ ۚ وَلَا تَحْزَنْ '
            'عَلَيْهِمْ وَلَا تَكُ فِي ضَيْقٍ مِّمَّا يَمْكُرُونَ',
        'And be patient, [O Muhammad], and your patience is not but '
            'through Allah. And do not grieve over them and do not be in '
            'distress over what they conspire.',
        'An-Nahl 16:127',
      ),
      _q(
        'أُولَٰئِكَ عَلَيْهِمْ صَلَوَاتٌ مِّن رَّبِّهِمْ وَرَحْمَةٌ ۖ '
            'وَأُولَٰئِكَ هُمُ الْمُهْتَدُونَ',
        'Those are the ones upon whom are blessings from their Lord and '
            'mercy. And it is those who are the [rightly] guided.',
        'Al-Baqarah 2:157',
      ),
      _h(
        'At the death of his son Ibrahim, the Prophet ﷺ wept and said: '
            'The eyes shed tears and the heart grieves, but we say only '
            'what pleases our Lord. And we are grieved by your parting, O '
            'Ibrahim.',
        'Sahih al-Bukhari 1303',
      ),
      _h(
        'The Prophet ﷺ said that Allah says: When I take away the two '
            'beloved things of My servant — his eyes — and he bears it '
            'patiently, I compensate him with Paradise.',
        'Sahih al-Bukhari 5653',
      ),
    ],

    // ── Fearful ───────────────────────────────────────────────────────────
    Mood.fearful: <Comfort>[
      _q(
        'لَا تَخَافَا ۖ إِنَّنِي مَعَكُمَا أَسْمَعُ وَأَرَىٰ',
        'Fear not. Indeed, I am with you both; I hear and I see.',
        'Ta-Ha 20:46',
      ),
      _q(
        'قُل لَّن يُصِيبَنَا إِلَّا مَا كَتَبَ اللَّهُ لَنَا هُوَ مَوْلَانَا ۚ '
            'وَعَلَى اللَّهِ فَلْيَتَوَكَّلِ الْمُؤْمِنُونَ',
        'Say: Never will we be struck except by what Allah has decreed for '
            'us; He is our protector. And upon Allah let the believers rely.',
        'At-Tawbah 9:51',
      ),
      _q(
        'قُلْ حَسْبِيَ اللَّهُ ۖ عَلَيْهِ يَتَوَكَّلُ الْمُتَوَكِّلُونَ',
        'Say: Sufficient for me is Allah; upon Him rely the reliers.',
        'Az-Zumar 39:38',
      ),
      _q(
        'فَلَا تَخَافُوهُمْ وَخَافُونِ إِن كُنتُم مُّؤْمِنِينَ',
        'So fear them not, but fear Me, if you are believers.',
        'Al Imran 3:175',
      ),
      _q(
        'وَتَوَكَّلْ عَلَى اللَّهِ ۚ وَكَفَىٰ بِاللَّهِ وَكِيلًا',
        'And rely upon Allah; and sufficient is Allah as Disposer of affairs.',
        'Al-Ahzab 33:3',
      ),
      _q(
        'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ',
        'Say: I seek refuge in the Lord of daybreak. — The Prophet ﷺ recited '
            'this surah and An-Nas over himself every night before sleeping.',
        'Al-Falaq 113:1 · Sahih al-Bukhari 5017',
      ),
      _h(
        'Know that if the whole nation gathered to harm you, they could only '
            'harm you with what Allah has already written against you. The '
            'pens have been lifted and the pages have dried.',
        'Jami\' at-Tirmidhi 2516',
        'hasan sahih',
      ),
      _q(
        'أَلَّا تَخَافُوا وَلَا تَحْزَنُوا وَأَبْشِرُوا بِالْجَنَّةِ الَّتِي كُنتُمْ تُوعَدُونَ',
        'Do not fear and do not grieve, but receive good tidings of Paradise, which you were promised.',
        'Fussilat 41:30',
      ),
      _q(
        'إِن يَنصُرْكُمُ اللَّهُ فَلَا غَالِبَ لَكُمْ',
        'If Allah should aid you, no one can overcome you.',
        'Al Imran 3:160',
      ),
      _q(
        'قُلْنَا لَا تَخَفْ إِنَّكَ أَنتَ الْأَعْلَىٰ',
        'We [i.e., Allah] said, "Fear not. Indeed, it is you who are '
            'superior.',
        'Ta-Ha 20:68',
      ),
      _q(
        'يَا مُوسَىٰ أَقْبِلْ وَلَا تَخَفْ ۖ إِنَّكَ مِنَ الْآمِنِينَ',
        'O Musa, approach and fear not. Indeed, you are of the secure.',
        'Al-Qasas 28:31',
      ),
      _q(
        'فَمَن تَبِعَ هُدَايَ فَلَا خَوْفٌ عَلَيْهِمْ وَلَا هُمْ '
            'يَحْزَنُونَ',
        'Whoever follows My guidance — there will be no fear concerning '
            'them, nor will they grieve.',
        'Al-Baqarah 2:38',
      ),
      _h(
        'The Prophet ﷺ said: Be mindful of Allah and He will protect '
            'you. Be mindful of Allah and you will find Him before you. If '
            'you ask, ask Allah; if you seek help, seek help from Allah. '
            'Know that if the whole nation gathered to harm you, they could '
            'not harm you except with what Allah had already written '
            'against you.',
        'Jami\' at-Tirmidhi 2516',
        'hasan sahih',
      ),
      _h(
        'The Prophet ﷺ said: Whoever says in the evening, "I seek '
            'refuge in the perfect words of Allah from the evil of what He '
            'has created" three times, nothing will harm him that night.',
        'Sahih Muslim 2709',
      ),
    ],

    // ── Lonely ────────────────────────────────────────────────────────────
    Mood.lonely: <Comfort>[
      _q(
        'وَإِذَا سَأَلَكَ عِبَادِي عَنِّي فَإِنِّي قَرِيبٌ',
        'And when My servants ask you concerning Me — indeed I am near. I '
            'respond to the invocation of the supplicant when he calls upon '
            'Me.',
        'Al-Baqarah 2:186',
      ),
      _q(
        'وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ',
        'And He is with you wherever you are.',
        'Al-Hadid 57:4',
      ),
      _q(
        'وَنَحْنُ أَقْرَبُ إِلَيْهِ مِنْ حَبْلِ الْوَرِيدِ',
        'And We are closer to him than his jugular vein.',
        'Qaf 50:16',
      ),
      _q(
        'فَاذْكُرُونِي أَذْكُرْكُمْ',
        'So remember Me; I will remember you.',
        'Al-Baqarah 2:152',
      ),
      _q(
        'أَلَيْسَ اللَّهُ بِكَافٍ عَبْدَهُ',
        'Is not Allah sufficient for His servant?',
        'Az-Zumar 39:36',
      ),
      _h(
        'Allah says: I am as My servant thinks I am, and I am with him when '
            'he remembers Me.',
        'Sahih al-Bukhari 7405 · Sahih Muslim 2675',
      ),
      _h(
        'Allah says: If he draws near to Me a hand\'s span, I draw near to '
            'him an arm\'s length; and if he draws near to Me an arm\'s '
            'length, I draw near to him a fathom; and if he comes to Me '
            'walking, I come to him running.',
        'Sahih al-Bukhari 7405 · Sahih Muslim 2675',
      ),
      _h(
        'Be mindful of Allah and He will protect you. Be mindful of Allah '
            'and you will find Him before you. If you ask, ask of Allah; if '
            'you seek help, seek help from Allah.',
        'Jami\' at-Tirmidhi 2516',
        'hasan sahih',
      ),
      _q(
        'اللَّهُ وَلِيُّ الَّذِينَ آمَنُوا يُخْرِجُهُم مِّنَ الظُّلُمَاتِ إِلَى النُّورِ',
        'Allah is the ally of those who believe. He brings them out from darknesses into the light.',
        'Al-Baqarah 2:257',
      ),
      _q(
        'وَلَمْ أَكُن بِدُعَائِكَ رَبِّ شَقِيًّا',
        'And never have I been in my supplication to You, my Lord, unhappy.',
        'Maryam 19:4',
      ),
      _q(
        'فَأَيْنَمَا تُوَلُّوا فَثَمَّ وَجْهُ اللَّهِ',
        'So wherever you turn, there is the Face of Allah.',
        'Al-Baqarah 2:115',
      ),
      _q(
        'بَلِ اللَّهُ مَوْلَاكُمْ ۖ وَهُوَ خَيْرُ النَّاصِرِينَ',
        'But Allah is your protector, and He is the best of helpers.',
        'Ali \'Imran 3:150',
      ),
      _q(
        'وَكَفَىٰ بِاللَّهِ وَلِيًّا وَكَفَىٰ بِاللَّهِ نَصِيرًا',
        'And sufficient is Allah as an ally, and sufficient is Allah as '
            'a helper.',
        'An-Nisa 4:45',
      ),
      _h(
        'The Prophet ﷺ said: When Allah loves a servant, He calls '
            'Jibril and says, "I love so-and-so, so love him." Jibril loves '
            'him and calls out in the heavens, "Allah loves so-and-so, so '
            'love him," and the people of the heavens love him. Then '
            'acceptance is placed for him on the earth.',
        'Sahih al-Bukhari 3209 · Sahih Muslim 2637',
      ),
      _h(
        'The Prophet ﷺ said: Allah is in the aid of His servant so long '
            'as the servant is in the aid of his brother.',
        'Sahih Muslim 2699',
      ),
    ],

    // ── Angry ─────────────────────────────────────────────────────────────
    Mood.angry: <Comfort>[
      _h(
        'The strong man is not the one who overpowers others; the strong '
            'man is the one who controls himself when he is angry.',
        'Sahih al-Bukhari 6114 · Sahih Muslim 2609',
      ),
      _h(
        'A man said to the Prophet ﷺ, "Advise me." He said, "Do not become '
            'angry." The man repeated his request several times, and each '
            'time he said, "Do not become angry."',
        'Sahih al-Bukhari 6116',
      ),
      _q(
        'وَالْكَاظِمِينَ الْغَيْظَ وَالْعَافِينَ عَنِ النَّاسِ ۗ وَاللَّهُ '
            'يُحِبُّ الْمُحْسِنِينَ',
        '…who restrain anger and who pardon the people — and Allah loves the '
            'doers of good.',
        'Al Imran 3:134',
      ),
      _h(
        'Two men were trading insults in front of the Prophet ﷺ, and one '
            'grew red with rage. He said: "I know a phrase which, if he said '
            'it, what he feels would leave him — I seek refuge in Allah from '
            'the accursed devil."',
        'Sahih al-Bukhari 3282 · Sahih Muslim 2610',
      ),
      _h(
        'If one of you becomes angry while standing, let him sit down; if '
            'the anger leaves him, good — otherwise let him lie down.',
        'Sunan Abi Dawud 4782',
        'sahih',
      ),
      _q(
        'ادْفَعْ بِالَّتِي هِيَ أَحْسَنُ فَإِذَا الَّذِي بَيْنَكَ وَبَيْنَهُ '
            'عَدَاوَةٌ كَأَنَّهُ وَلِيٌّ حَمِيمٌ',
        'Repel evil by that which is better; and thereupon the one whom '
            'between you and him is enmity will become as though he was a '
            'devoted friend.',
        'Fussilat 41:34',
      ),
      _q(
        'وَإِذَا مَا غَضِبُوا هُمْ يَغْفِرُونَ',
        '…and when they are angry, they forgive.',
        'Ash-Shura 42:37',
      ),
      _q(
        'خُذِ الْعَفْوَ وَأْمُرْ بِالْعُرْفِ وَأَعْرِضْ عَنِ الْجَاهِلِينَ',
        'Take what is given freely, enjoin what is good, and turn away from '
            'the ignorant.',
        'Al-A\'raf 7:199',
      ),
      _h(
        'Charity does not decrease wealth. No one forgives another but that '
            'Allah increases him in honour. And no one humbles himself for '
            'Allah but that Allah raises him.',
        'Sahih Muslim 2588',
      ),
      _q(
        'وَلْيَعْفُوا وَلْيَصْفَحُوا ۗ أَلَا تُحِبُّونَ أَن يَغْفِرَ اللَّهُ لَكُمْ',
        'And let them pardon and overlook. Would you not like that Allah should forgive you?',
        'An-Nur 24:22',
      ),
      _q(
        'وَإِنْ عَاقَبْتُمْ فَعَاقِبُوا بِمِثْلِ مَا عُوقِبْتُم بِهِ ۖ '
            'وَلَئِن صَبَرْتُمْ لَهُوَ خَيْرٌ لِّلصَّابِرِينَ',
        'And if you punish [an enemy, O believers], punish with an '
            'equivalent of that with which you were harmed. But if you are '
            'patient - it is better for those who are patient.',
        'An-Nahl 16:126',
      ),
      _q(
        'وَعِبَادُ الرَّحْمَٰنِ الَّذِينَ يَمْشُونَ عَلَى الْأَرْضِ '
            'هَوْنًا وَإِذَا خَاطَبَهُمُ الْجَاهِلُونَ قَالُوا سَلَامًا',
        'And the servants of the Most Merciful are those who walk upon '
            'the earth easily, and when the ignorant address them '
            '[harshly], they say [words of] peace.',
        'Al-Furqan 25:63',
      ),
      _q(
        'وَجَزَاءُ سَيِّئَةٍ سَيِّئَةٌ مِّثْلُهَا ۖ فَمَنْ عَفَا '
            'وَأَصْلَحَ فَأَجْرُهُ عَلَى اللَّهِ ۚ إِنَّهُ لَا يُحِبُّ '
            'الظَّالِمِينَ',
        'And the retribution for an evil act is an evil one like it, '
            'but whoever pardons and makes reconciliation - his reward is '
            '[due] from Allah. Indeed, He does not like wrongdoers.',
        'Ash-Shura 42:40',
      ),
      _h(
        'The Prophet ﷺ said: Whoever holds back his anger when he is '
            'able to act on it, Allah will call him before all creation on '
            'the Day of Resurrection and let him choose whichever of the '
            'maidens of Paradise he wishes.',
        'Sunan Abi Dawud 4777 · Jami\' at-Tirmidhi 2021',
        'hasan',
      ),
      _h(
        'The Prophet ﷺ said: I guarantee a house on the edge of '
            'Paradise for the one who gives up arguing even when he is in '
            'the right.',
        'Sunan Abi Dawud 4800',
        'hasan',
      ),
    ],

    // ── Hopeless ──────────────────────────────────────────────────────────
    Mood.hopeless: <Comfort>[
      _q(
        'وَمَن يَقْنَطُ مِن رَّحْمَةِ رَبِّهِ إِلَّا الضَّالُّونَ',
        'And who despairs of the mercy of his Lord except for those astray?',
        'Al-Hijr 15:56',
      ),
      _q(
        'أَلَا إِنَّ نَصْرَ اللَّهِ قَرِيبٌ',
        'Unquestionably, the help of Allah is near.',
        'Al-Baqarah 2:214',
      ),
      _q(
        'أَنِّي مَسَّنِيَ الضُّرُّ وَأَنتَ أَرْحَمُ الرَّاحِمِينَ',
        'Indeed, adversity has touched me, and You are the most merciful of '
            'the merciful. — So We responded to him and removed what '
            'afflicted him of adversity.',
        'Al-Anbiya 21:83–84',
      ),
      _q(
        'فَاصْبِرْ إِنَّ وَعْدَ اللَّهِ حَقٌّ',
        'So be patient. Indeed, the promise of Allah is truth.',
        'Ar-Rum 30:60',
      ),
      _q(
        'وَأُفَوِّضُ أَمْرِي إِلَى اللَّهِ ۚ إِنَّ اللَّهَ بَصِيرٌ بِالْعِبَادِ',
        'And I entrust my affair to Allah. Indeed, Allah is Seeing of His '
            'servants.',
        'Ghafir 40:44',
      ),
      _h(
        'Know that victory comes with patience, relief comes with '
            'affliction, and with hardship comes ease.',
        'Jami\' at-Tirmidhi 2516',
        'hasan sahih',
      ),
      _q(
        'فَاسْتَجَبْنَا لَهُ وَنَجَّيْنَاهُ مِنَ الْغَمِّ ۚ وَكَذَٰلِكَ نُنجِي الْمُؤْمِنِينَ',
        'So We responded to him and saved him from the distress. And thus do We save the believers.',
        'Al-Anbiya 21:88',
      ),
      _q(
        'كَتَبَ رَبُّكُمْ عَلَىٰ نَفْسِهِ الرَّحْمَةَ',
        'Your Lord has decreed upon Himself mercy.',
        'Al-An\'am 6:54',
      ),
      _q(
        'وَرَحْمَتِي وَسِعَتْ كُلَّ شَيْءٍ',
        'And My mercy encompasses all things.',
        'Al-A\'raf 7:156',
      ),
      _q(
        'وَنُنَزِّلُ مِنَ الْقُرْآنِ مَا هُوَ شِفَاءٌ وَرَحْمَةٌ '
            'لِّلْمُؤْمِنِينَ ۙ وَلَا يَزِيدُ الظَّالِمِينَ إِلَّا خَسَارًا',
        'And We send down of the Qur\'an that which is healing and mercy '
            'for the believers, but it does not increase the wrongdoers '
            'except in loss.',
        'Al-Isra 17:82',
      ),
      _h(
        'The Prophet ﷺ said: Allah made mercy into a hundred parts. He '
            'kept ninety-nine with Him and sent one part down to the earth '
            '— and from that one part all creatures show mercy to one '
            'another, so that a mare lifts her hoof over her foal for fear '
            'of hurting it.',
        'Sahih al-Bukhari 6000 · Sahih Muslim 2752',
      ),
      _h(
        'The Prophet ﷺ said that Allah says: O son of Adam, so long as '
            'you call upon Me and hope in Me, I will forgive you for what '
            'you have done, and I do not mind. O son of Adam, if your sins '
            'reached the clouds of the sky and you then asked My '
            'forgiveness, I would forgive you.',
        'Jami\' at-Tirmidhi 3540',
        'hasan',
      ),
    ],

    // ── Overwhelmed ───────────────────────────────────────────────────────
    Mood.tired: <Comfort>[
      _q(
        'لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا',
        'Allah does not charge a soul except with that within its capacity.',
        'Al-Baqarah 2:286',
      ),
      _q(
        'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا ۝ إِنَّ مَعَ الْعُسْرِ يُسْرًا',
        'For indeed, with hardship will be ease. Indeed, with hardship will '
            'be ease.',
        'Ash-Sharh 94:5–6',
      ),
      _q(
        'سَيَجْعَلُ اللَّهُ بَعْدَ عُسْرٍ يُسْرًا',
        'Allah will bring about, after hardship, ease.',
        'At-Talaq 65:7',
      ),
      _q(
        'وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ ۚ وَإِنَّهَا لَكَبِيرَةٌ إِلَّا '
            'عَلَى الْخَاشِعِينَ',
        'And seek help through patience and prayer; and indeed, it is '
            'difficult except for the humbly submissive.',
        'Al-Baqarah 2:45',
      ),
      _q(
        'وَمَن يُؤْمِن بِاللَّهِ يَهْدِ قَلْبَهُ',
        'And whoever believes in Allah — He will guide his heart.',
        'At-Taghabun 64:11',
      ),
      _q(
        'فَإِذَا فَرَغْتَ فَانصَبْ ۝ وَإِلَىٰ رَبِّكَ فَارْغَب',
        'So when you have finished, then stand up for worship. And to your '
            'Lord direct your longing.',
        'Ash-Sharh 94:7–8',
      ),
      _q(
        'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا ۝ إِنَّ مَعَ الْعُسْرِ يُسْرًا',
        'For indeed, with hardship will be ease. Indeed, with hardship will be ease.',
        'Ash-Sharh 94:5-6',
      ),
      _q(
        'وَلَا نُكَلِّفُ نَفْسًا إِلَّا وُسْعَهَا ۖ وَلَدَيْنَا كِتَابٌ '
            'يَنطِقُ بِالْحَقِّ ۚ وَهُمْ لَا يُظْلَمُونَ',
        'And We charge no soul except [with that within] its capacity, '
            'and with Us is a record which speaks with truth; and they will '
            'not be wronged.',
        'Al-Mu\'minun 23:62',
      ),
      _q(
        'فَإِذَا عَزَمْتَ فَتَوَكَّلْ عَلَى اللَّهِ ۚ إِنَّ اللَّهَ '
            'يُحِبُّ الْمُتَوَكِّلِينَ',
        'And when you have decided, then rely upon Allah. Indeed, Allah '
            'loves those who rely [upon Him].',
        'Ali \'Imran 3:159',
      ),
      _q(
        'فَاعْبُدْهُ وَتَوَكَّلْ عَلَيْهِ',
        'So worship Him and rely upon Him.',
        'Hud 11:123',
      ),
      _h(
        'The Prophet ﷺ said: Whoever makes the Hereafter his concern, '
            'Allah puts richness in his heart and gathers his scattered '
            'affairs for him, and the world comes to him humbled.',
        'Jami\' at-Tirmidhi 2465',
        'hasan',
      ),
      _h(
        'The Prophet ﷺ would say: O Bilal, call the prayer — give us '
            'rest by it.',
        'Sunan Abi Dawud 4985',
        'sahih',
      ),
    ],

    // ── Tired / Weary ─────────────────────────────────────────────────────
    Mood.weary: <Comfort>[
      _q(
        'وَجَعَلْنَا نَوْمَكُمْ سُبَاتًا',
        'And We made your sleep a means for rest.',
        'An-Naba 78:9',
      ),
      _q(
        'وَهُوَ الَّذِي جَعَلَ لَكُمُ اللَّيْلَ لِبَاسًا وَالنَّوْمَ سُبَاتًا',
        'And it is He who has made the night for you as clothing and sleep '
            'as rest.',
        'Al-Furqan 25:47',
      ),
      _q(
        'رَبَّنَا وَلَا تُحَمِّلْنَا مَا لَا طَاقَةَ لَنَا بِهِ',
        'Our Lord, and burden us not with that which we have no ability to '
            'bear.',
        'Al-Baqarah 2:286',
      ),
      _h(
        'Religion is easy, and no one makes it hard on himself but that it '
            'overwhelms him. So be moderate, aim for what is near, and be '
            'glad.',
        'Sahih al-Bukhari 39',
      ),
      _h(
        'The most beloved deeds to Allah are those done most consistently, '
            'even if they are small.',
        'Sahih al-Bukhari 6464 · Sahih Muslim 783',
      ),
      _h(
        'Take on only as much as you can manage, for Allah does not grow '
            'weary until you grow weary.',
        'Sahih al-Bukhari 1151 · Sahih Muslim 785',
      ),
      _h(
        'Your body has a right over you, your eyes have a right over you, '
            'and your family has a right over you.',
        'Sahih al-Bukhari 1975',
      ),
      _q(
        'يَا أَيُّهَا الَّذِينَ آمَنُوا اصْبِرُوا وَصَابِرُوا وَرَابِطُوا وَاتَّقُوا اللَّهَ لَعَلَّكُمْ تُفْلِحُونَ',
        'O you who have believed, persevere and endure and remain stationed and fear Allah that you may be successful.',
        'Al Imran 3:200',
      ),
      _q(
        'وَمِن رَّحْمَتِهِ جَعَلَ لَكُمُ اللَّيْلَ وَالنَّهَارَ '
            'لِتَسْكُنُوا فِيهِ وَلِتَبْتَغُوا مِن فَضْلِهِ وَلَعَلَّكُمْ '
            'تَشْكُرُونَ',
        'And out of His mercy He made for you the night and the day '
            'that you may rest therein and [by day] seek from His bounty '
            'and [that] perhaps you will be grateful.',
        'Al-Qasas 28:73',
      ),
      _q(
        'وَجَعَلَ اللَّيْلَ سَكَنًا',
        'And [He] has made the night for rest.',
        'Al-An\'am 6:96',
      ),
      _q(
        'وَمِنْ آيَاتِهِ مَنَامُكُم بِاللَّيْلِ وَالنَّهَارِ '
            'وَابْتِغَاؤُكُم مِّن فَضْلِهِ ۚ إِنَّ فِي ذَٰلِكَ لَآيَاتٍ '
            'لِّقَوْمٍ يَسْمَعُونَ',
        'And of His signs is your sleep by night and day and your '
            'seeking of His bounty. Indeed in that are signs for a people '
            'who listen.',
        'Ar-Rum 30:23',
      ),
      _h(
        'The Prophet ﷺ said: The most beloved prayer to Allah is the '
            'prayer of Dawud, and the most beloved fasting to Allah is the '
            'fasting of Dawud. He would sleep half the night, stand a third '
            'of it, and sleep a sixth of it.',
        'Sahih al-Bukhari 1131 · Sahih Muslim 1159',
      ),
      _h(
        'The Prophet ﷺ said: Do not do that. Fast and break your fast; '
            'pray and sleep. Your body has a right over you, your eyes have '
            'a right over you, and your family has a right over you.',
        'Sahih al-Bukhari 1975',
      ),
    ],

    // ── Lost ──────────────────────────────────────────────────────────────
    Mood.lost: <Comfort>[
      _q(
        'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
        'Guide us to the straight path.',
        'Al-Fatihah 1:6',
      ),
      _q(
        'وَوَجَدَكَ ضَالًّا فَهَدَىٰ',
        'And He found you lost and guided you.',
        'Ad-Duha 93:7',
      ),
      _q(
        'وَالَّذِينَ جَاهَدُوا فِينَا لَنَهْدِيَنَّهُمْ سُبُلَنَا',
        'And those who strive for Us — We will surely guide them to Our ways.',
        'Al-Ankabut 29:69',
      ),
      _q(
        'فَمَن يُرِدِ اللَّهُ أَن يَهْدِيَهُ يَشْرَحْ صَدْرَهُ لِلْإِسْلَامِ',
        'So whoever Allah wants to guide — He expands his breast to Islam.',
        'Al-An\'am 6:125',
      ),
      _q(
        'وَقُل رَّبِّ زِدْنِي عِلْمًا',
        'And say: My Lord, increase me in knowledge.',
        'Ta-Ha 20:114',
      ),
      _h(
        'The Prophet ﷺ used to teach us to seek Allah\'s guidance in all our '
            'affairs, just as he taught us a surah of the Qur\'an: "O Allah, I '
            'seek Your guidance through Your knowledge, and I seek Your help '
            'through Your power, and I ask You from Your great bounty…"',
        'Sahih al-Bukhari 1162',
      ),
      _h(
        'The Prophet ﷺ used to say: O Allah, I ask You for guidance, piety, '
            'chastity and self-sufficiency.',
        'Sahih Muslim 2721',
      ),
      _q(
        'رَبَّنَا آتِنَا مِن لَّدُنكَ رَحْمَةً وَهَيِّئْ لَنَا مِنْ أَمْرِنَا رَشَدًا',
        'Our Lord, grant us from Yourself mercy and prepare for us from our affair right guidance.',
        'Al-Kahf 18:10',
      ),
      _q(
        'يَهْدِي مَن يَشَاءُ إِلَىٰ صِرَاطٍ مُّسْتَقِيمٍ',
        'He guides whom He wills to a straight path.',
        'Al-Baqarah 2:142',
      ),
      _q(
        'يَهْدِي اللَّهُ لِنُورِهِ مَن يَشَاءُ',
        'Allah guides to His light whom He wills.',
        'An-Nur 24:35',
      ),
      _q(
        'وَعَلَى اللَّهِ قَصْدُ السَّبِيلِ',
        'And upon Allah is the direction of the [right] way.',
        'An-Nahl 16:9',
      ),
      _h(
        'The Prophet ﷺ said that Allah says: O My servants, all of you '
            'are astray except those whom I guide, so seek guidance from Me '
            'and I shall guide you.',
        'Sahih Muslim 2577',
      ),
      _h(
        'The Prophet ﷺ said: Whoever travels a path in search of '
            'knowledge, Allah makes easy for him a path to Paradise.',
        'Sahih Muslim 2699',
      ),
    ],

    // ── Doubtful ──────────────────────────────────────────────────────────
    Mood.doubtful: <Comfort>[
      _q(
        'ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِّلْمُتَّقِينَ',
        'This is the Book about which there is no doubt, a guidance for '
            'those conscious of Allah.',
        'Al-Baqarah 2:2',
      ),
      _q(
        'قَالَ أَوَلَمْ تُؤْمِن ۖ قَالَ بَلَىٰ وَلَٰكِن لِّيَطْمَئِنَّ قَلْبِي',
        'He said: Have you not believed? He said: Yes, but I ask only that '
            'my heart may be satisfied.',
        'Al-Baqarah 2:260',
      ),
      _q(
        'سَنُرِيهِمْ آيَاتِنَا فِي الْآفَاقِ وَفِي أَنفُسِهِمْ حَتَّىٰ '
            'يَتَبَيَّنَ لَهُمْ أَنَّهُ الْحَقُّ',
        'We will show them Our signs in the horizons and within themselves '
            'until it becomes clear to them that it is the truth.',
        'Fussilat 41:53',
      ),
      _q(
        'رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا',
        'Our Lord, let not our hearts deviate after You have guided us.',
        'Al Imran 3:8',
      ),
      _q(
        'وَاعْبُدْ رَبَّكَ حَتَّىٰ يَأْتِيَكَ الْيَقِينُ',
        'And worship your Lord until there comes to you the certainty.',
        'Al-Hijr 15:99',
      ),
      _h(
        'Some companions came to the Prophet ﷺ and said, "We find in '
            'ourselves thoughts too terrible to speak of." He asked, "Do you '
            'really find that?" They said yes. He said: "That is clear faith."',
        'Sahih Muslim 132',
      ),
      _h(
        'The Prophet ﷺ would often say: O Turner of hearts, make my heart '
            'firm upon Your religion.',
        'Jami\' at-Tirmidhi 2140',
        'hasan',
      ),
      _h(
        'Leave that which makes you doubt for that which does not make you '
            'doubt.',
        'Jami\' at-Tirmidhi 2518',
        'hasan sahih',
      ),
      _q(
        'الْحَقُّ مِن رَّبِّكَ ۖ فَلَا تَكُونَنَّ مِنَ الْمُمْتَرِينَ',
        'The truth is from your Lord, so never be among the doubters.',
        'Al-Baqarah 2:147',
      ),
      _q(
        'هَٰذَا بَصَائِرُ لِلنَّاسِ وَهُدًى وَرَحْمَةٌ لِّقَوْمٍ '
            'يُوقِنُونَ',
        'This [Qur\'an] is enlightenment for mankind and guidance and '
            'mercy for a people who are certain [in faith].',
        'Al-Jathiyah 45:20',
      ),
      _q(
        'وَفِي الْأَرْضِ آيَاتٌ لِّلْمُوقِنِينَ وَفِي أَنفُسِكُمْ ۚ '
            'أَفَلَا تُبْصِرُونَ',
        'And on the earth are signs for the certain [in faith] — and in '
            'yourselves. Then will you not see?',
        'Adh-Dhariyat 51:20–21',
      ),
      _q(
        'قَدْ بَيَّنَّا الْآيَاتِ لِقَوْمٍ يُوقِنُونَ',
        'We have shown clearly the signs to a people who are certain '
            '[in faith].',
        'Al-Baqarah 2:118',
      ),
      _h(
        'The Prophet ﷺ said: Leave that which makes you doubt for that '
            'which does not make you doubt.',
        'Jami\' at-Tirmidhi 2518',
        'sahih',
      ),
      _h(
        'The Prophet ﷺ said: Satan comes to one of you and says, "Who '
            'created this? Who created that?" until he says, "Who created '
            'your Lord?" When it reaches that, let him seek refuge in Allah '
            'and stop.',
        'Sahih al-Bukhari 3276 · Sahih Muslim 134',
      ),
    ],

    // ── In hardship ───────────────────────────────────────────────────────
    Mood.hardship: <Comfort>[
      _q(
        'وَلَنَبْلُوَنَّكُم بِشَيْءٍ مِّنَ الْخَوْفِ وَالْجُوعِ وَنَقْصٍ مِّنَ '
            'الْأَمْوَالِ وَالْأَنفُسِ وَالثَّمَرَاتِ ۗ وَبَشِّرِ الصَّابِرِينَ',
        'And We will surely test you with something of fear and hunger and '
            'a loss of wealth and lives and fruits — but give good tidings to '
            'the patient.',
        'Al-Baqarah 2:155',
      ),
      _q(
        'أَحَسِبَ النَّاسُ أَن يُتْرَكُوا أَن يَقُولُوا آمَنَّا وَهُمْ لَا '
            'يُفْتَنُونَ',
        'Do the people think that they will be left to say, "We believe," '
            'and they will not be tried?',
        'Al-Ankabut 29:2',
      ),
      _q(
        'إِنَّمَا يُوَفَّى الصَّابِرُونَ أَجْرَهُم بِغَيْرِ حِسَابٍ',
        'Indeed, the patient will be given their reward without account.',
        'Az-Zumar 39:10',
      ),
      _q(
        'وَإِن تَصْبِرُوا وَتَتَّقُوا فَإِنَّ ذَٰلِكَ مِنْ عَزْمِ الْأُمُورِ',
        'But if you are patient and fear Allah — indeed, that is of the '
            'matters worthy of determination.',
        'Al Imran 3:186',
      ),
      _h(
        'The greatest reward comes with the greatest trial. When Allah loves '
            'a people, He tests them; whoever is content receives His '
            'pleasure, and whoever is displeased receives His displeasure.',
        'Jami\' at-Tirmidhi 2396',
        'hasan',
      ),
      _h(
        'The people most severely tested are the prophets, then the next '
            'best, then the next best. A person is tested according to his '
            'religion.',
        'Jami\' at-Tirmidhi 2398',
        'hasan sahih',
      ),
      _h(
        'A woman with seizures came to the Prophet ﷺ and asked him to pray '
            'for her. He said: "If you wish, be patient and Paradise is yours; '
            'and if you wish, I will pray to Allah to cure you." She said, '
            '"I will be patient."',
        'Sahih al-Bukhari 5652',
      ),
      _q(
        'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا ۝ إِنَّ مَعَ الْعُسْرِ يُسْرًا',
        'For indeed, with hardship will be ease. Indeed, with hardship will be ease.',
        'Ash-Sharh 94:5-6',
      ),
      _q(
        'وَلَنَبْلُوَنَّكُمْ حَتَّىٰ نَعْلَمَ الْمُجَاهِدِينَ مِنكُمْ '
            'وَالصَّابِرِينَ',
        'And We will surely test you until We make evident those who '
            'strive among you and the patient.',
        'Muhammad 47:31',
      ),
      _q(
        'الَّذِي خَلَقَ الْمَوْتَ وَالْحَيَاةَ لِيَبْلُوَكُمْ أَيُّكُمْ '
            'أَحْسَنُ عَمَلًا',
        '[He] who created death and life to test you [as to] which of '
            'you is best in deed.',
        'Al-Mulk 67:2',
      ),
      _q(
        'وَاصْبِرْ عَلَىٰ مَا أَصَابَكَ ۖ إِنَّ ذَٰلِكَ مِنْ عَزْمِ '
            'الْأُمُورِ',
        'And be patient over what befalls you. Indeed, that is of the '
            'matters [requiring] determination.',
        'Luqman 31:17',
      ),
      _h(
        'The Prophet ﷺ said: Paradise is surrounded by hardships, and '
            'the Fire is surrounded by desires.',
        'Sahih al-Bukhari 6487 · Sahih Muslim 2822',
      ),
      _h(
        'The Prophet ﷺ said: The greatest reward comes with the '
            'greatest trial. When Allah loves a people, He tests them; '
            'whoever accepts it has His pleasure, and whoever resents it '
            'has His anger.',
        'Jami\' at-Tirmidhi 2396',
        'hasan',
      ),
    ],

    // ── Regretful ─────────────────────────────────────────────────────────
    Mood.regretful: <Comfort>[
      _q(
        'قُلْ يَا عِبَادِيَ الَّذِينَ أَسْرَفُوا عَلَىٰ أَنفُسِهِمْ لَا '
            'تَقْنَطُوا مِن رَّحْمَةِ اللَّهِ ۚ إِنَّ اللَّهَ يَغْفِرُ الذُّنُوبَ '
            'جَمِيعًا',
        'Say: O My servants who have transgressed against themselves, do not '
            'despair of the mercy of Allah. Indeed, Allah forgives all sins.',
        'Az-Zumar 39:53',
      ),
      _q(
        'وَمَن يَعْمَلْ سُوءًا أَوْ يَظْلِمْ نَفْسَهُ ثُمَّ يَسْتَغْفِرِ اللَّهَ '
            'يَجِدِ اللَّهَ غَفُورًا رَّحِيمًا',
        'And whoever does a wrong or wrongs himself but then seeks '
            'forgiveness of Allah will find Allah Forgiving and Merciful.',
        'An-Nisa 4:110',
      ),
      _q(
        'إِلَّا مَن تَابَ وَآمَنَ وَعَمِلَ عَمَلًا صَالِحًا فَأُولَٰئِكَ يُبَدِّلُ '
            'اللَّهُ سَيِّئَاتِهِمْ حَسَنَاتٍ',
        'Except for those who repent, believe and do righteous work. For '
            'them Allah will replace their evil deeds with good.',
        'Al-Furqan 25:70',
      ),
      _q(
        'إِنَّ الْحَسَنَاتِ يُذْهِبْنَ السَّيِّئَاتِ',
        'Indeed, good deeds do away with misdeeds.',
        'Hud 11:114',
      ),
      _q(
        'إِنَّ اللَّهَ يُحِبُّ التَّوَّابِينَ',
        'Indeed, Allah loves those who are constantly repentant.',
        'Al-Baqarah 2:222',
      ),
      _h(
        'Every son of Adam sins, and the best of those who sin are those '
            'who repent.',
        'Jami\' at-Tirmidhi 2499',
        'hasan',
      ),
      _h(
        'Allah says: O son of Adam, so long as you call upon Me and hope in '
            'Me, I will forgive you for what you have done, and I do not '
            'mind.',
        'Jami\' at-Tirmidhi 3540',
        'hasan',
      ),
      _h(
        'Allah is more pleased with the repentance of His servant than one '
            'of you would be on finding his lost camel in the desert.',
        'Sahih al-Bukhari 6309 · Sahih Muslim 2747',
      ),
      _h(
        'Allah extends His hand by night to accept the repentance of the one '
            'who sinned by day, and extends His hand by day to accept the '
            'repentance of the one who sinned by night.',
        'Sahih Muslim 2759',
      ),
      _h(
        'Fear Allah wherever you are; follow a bad deed with a good one and '
            'it will wipe it out; and treat people with good character.',
        'Jami\' at-Tirmidhi 1987',
        'hasan',
      ),
      _q(
        'وَقُل رَّبِّ اغْفِرْ وَارْحَمْ وَأَنتَ خَيْرُ الرَّاحِمِينَ',
        'And say: My Lord, forgive and have mercy, and You are the best of the merciful.',
        "Al-Mu'minun 23:118",
      ),
      _q(
        'وَالَّذِينَ إِذَا فَعَلُوا فَاحِشَةً أَوْ ظَلَمُوا أَنفُسَهُمْ '
            'ذَكَرُوا اللَّهَ فَاسْتَغْفَرُوا لِذُنُوبِهِمْ وَمَن يَغْفِرُ '
            'الذُّنُوبَ إِلَّا اللَّهُ وَلَمْ يُصِرُّوا عَلَىٰ مَا فَعَلُوا '
            'وَهُمْ يَعْلَمُونَ',
        'And those who, when they commit an immorality or wrong '
            'themselves [by transgression], remember Allah and seek '
            'forgiveness for their sins - and who can forgive sins except '
            'Allah? - and [who] do not persist in what they have done while '
            'they know.',
        'Ali \'Imran 3:135',
      ),
      _q(
        'وَهُوَ الَّذِي يَقْبَلُ التَّوْبَةَ عَنْ عِبَادِهِ وَيَعْفُو '
            'عَنِ السَّيِّئَاتِ وَيَعْلَمُ مَا تَفْعَلُونَ',
        'And it is He who accepts repentance from His servants and '
            'pardons misdeeds, and He knows what you do.',
        'Ash-Shura 42:25',
      ),
      _q(
        'رَبَّنَا ظَلَمْنَا أَنفُسَنَا وَإِن لَّمْ تَغْفِرْ لَنَا '
            'وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ الْخَاسِرِينَ',
        'Our Lord, we have wronged ourselves, and if You do not forgive '
            'us and have mercy upon us, we will surely be among the losers.',
        'Al-A\'raf 7:23',
      ),
      _h(
        'The Prophet ﷺ said: Every son of Adam sins, and the best of '
            'those who sin are those who repent.',
        'Jami\' at-Tirmidhi 2499',
        'hasan',
      ),
      _h(
        'The Prophet ﷺ said: By Him in whose hand is my soul, if you '
            'did not sin, Allah would remove you and bring a people who sin '
            'and seek Allah\'s forgiveness, and He would forgive them.',
        'Sahih Muslim 2749',
      ),
    ],

    // ── Grateful ──────────────────────────────────────────────────────────
    Mood.grateful: <Comfort>[
      _q(
        'لَئِن شَكَرْتُمْ لَأَزِيدَنَّكُمْ',
        'If you are grateful, I will surely increase you.',
        'Ibrahim 14:7',
      ),
      _q(
        'وَأَمَّا بِنِعْمَةِ رَبِّكَ فَحَدِّثْ',
        'But as for the favour of your Lord, report it.',
        'Ad-Duha 93:11',
      ),
      _q(
        'وَإِن تَعُدُّوا نِعْمَةَ اللَّهِ لَا تُحْصُوهَا',
        'And if you should count the favours of Allah, you could not '
            'enumerate them.',
        'An-Nahl 16:18',
      ),
      _q(
        'فَبِأَيِّ آلَاءِ رَبِّكُمَا تُكَذِّبَانِ',
        'So which of the favours of your Lord would you deny?',
        'Ar-Rahman 55:13',
      ),
      _q(
        'وَمَن يَشْكُرْ فَإِنَّمَا يَشْكُرُ لِنَفْسِهِ',
        'And whoever is grateful is grateful for the benefit of himself.',
        'Luqman 31:12',
      ),
      _h(
        'Whoever does not thank people has not thanked Allah.',
        'Jami\' at-Tirmidhi 1954 · Sunan Abi Dawud 4811',
        'sahih',
      ),
      _h(
        'Allah is pleased with a servant who eats a morsel and praises Him '
            'for it, or drinks a sip and praises Him for it.',
        'Sahih Muslim 2734',
      ),
      _h(
        'There are two blessings which many people are deceived about: '
            'health and free time.',
        'Sahih al-Bukhari 6412',
      ),
      _h(
        'Look at those below you and not at those above you; it is more '
            'fitting that you do not belittle the blessing of Allah upon you.',
        'Sahih al-Bukhari 6490 · Sahih Muslim 2963',
      ),
      _q(
        'هَلْ جَزَاءُ الْإِحْسَانِ إِلَّا الْإِحْسَانُ',
        'Is the reward for good anything but good?',
        'Ar-Rahman 55:60',
      ),
      _q(
        'وَاشْكُرُوا لِلَّهِ إِن كُنتُمْ إِيَّاهُ تَعْبُدُونَ',
        'And be grateful to Allah if it is [indeed] Him that you '
            'worship.',
        'Al-Baqarah 2:172',
      ),
      _q(
        'بَلِ اللَّهَ فَاعْبُدْ وَكُن مِّنَ الشَّاكِرِينَ',
        'Rather, worship [only] Allah and be among the grateful.',
        'Az-Zumar 39:66',
      ),
      _q(
        'وَمَا بِكُم مِّن نِّعْمَةٍ فَمِنَ اللَّهِ ۖ ثُمَّ إِذَا '
            'مَسَّكُمُ الضُّرُّ فَإِلَيْهِ تَجْأَرُونَ',
        'And whatever you have of favor - it is from Allah. Then when '
            'adversity touches you, to Him you cry for help.',
        'An-Nahl 16:53',
      ),
      _h(
        'The Prophet ﷺ stood in prayer until his feet swelled. He was '
            'asked, "Why, when Allah has forgiven you what came before and '
            'what comes after?" He said: Shall I not be a grateful servant?',
        'Sahih al-Bukhari 4837 · Sahih Muslim 2820',
      ),
      _h(
        'The Prophet ﷺ said: Whoever does not thank people does not '
            'thank Allah.',
        'Jami\' at-Tirmidhi 1954',
        'sahih',
      ),
    ],

    // ── Joyful ────────────────────────────────────────────────────────────
    Mood.joyful: <Comfort>[
      _q(
        'قُلْ بِفَضْلِ اللَّهِ وَبِرَحْمَتِهِ فَبِذَٰلِكَ فَلْيَفْرَحُوا هُوَ '
            'خَيْرٌ مِّمَّا يَجْمَعُونَ',
        'Say: In the bounty of Allah and in His mercy — in that let them '
            'rejoice; it is better than what they accumulate.',
        'Yunus 10:58',
      ),
      _q(
        'الْحَمْدُ لِلَّهِ الَّذِي هَدَانَا لِهَٰذَا',
        'Praise to Allah, who has guided us to this.',
        'Al-A\'raf 7:43',
      ),
      _q(
        'رَبِّ أَوْزِعْنِي أَنْ أَشْكُرَ نِعْمَتَكَ الَّتِي أَنْعَمْتَ عَلَيَّ',
        'My Lord, enable me to be grateful for Your favour which You have '
            'bestowed upon me.',
        'An-Naml 27:19',
      ),
      _q(
        'اعْمَلُوا آلَ دَاوُودَ شُكْرًا ۚ وَقَلِيلٌ مِّنْ عِبَادِيَ الشَّكُورُ',
        'Work, O family of David, in gratitude. And few of My servants are '
            'grateful.',
        'Saba 34:13',
      ),
      _h(
        'Do not belittle any good deed, even meeting your brother with a '
            'cheerful face.',
        'Sahih Muslim 2626',
      ),
      _h(
        'Your smiling in the face of your brother is charity.',
        'Jami\' at-Tirmidhi 1956',
        'hasan',
      ),
      _h(
        'Whoever says in the morning: "O Allah, whatever blessing I or any '
            'of Your creation have received this morning is from You alone, '
            'without partner; so to You is all praise and thanks" — has given '
            'thanks for that day.',
        'Sunan Abi Dawud 5073',
        'hasan',
      ),
      _q(
        'وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ',
        'And your Lord is going to give you, and you will be satisfied.',
        'Ad-Duha 93:5',
      ),
      _q(
        'فَرِحِينَ بِمَا آتَاهُمُ اللَّهُ مِن فَضْلِهِ',
        'Rejoicing in what Allah has bestowed upon them of His bounty.',
        'Ali \'Imran 3:170',
      ),
      _q(
        'وَيَوْمَئِذٍ يَفْرَحُ الْمُؤْمِنُونَ بِنَصْرِ اللَّهِ',
        'And that day the believers will rejoice in the victory of '
            'Allah.',
        'Ar-Rum 30:4–5',
      ),
      _q(
        'مَن جَاءَ بِالْحَسَنَةِ فَلَهُ عَشْرُ أَمْثَالِهَا',
        'Whoever comes with a good deed will have ten times the like '
            'thereof.',
        'Al-An\'am 6:160',
      ),
      _h(
        'The Prophet ﷺ said: Your smile in the face of your brother is '
            'charity for you.',
        'Jami\' at-Tirmidhi 1956',
        'hasan',
      ),
      _h(
        'The Prophet ﷺ said: Every good deed is charity.',
        'Sahih al-Bukhari 6021',
      ),
    ],

    // ── Hopeful ───────────────────────────────────────────────────────────
    Mood.hopeful: <Comfort>[
      _q(
        'وَلَا تَهِنُوا وَلَا تَحْزَنُوا وَأَنتُمُ الْأَعْلَوْنَ إِن كُنتُم '
            'مُّؤْمِنِينَ',
        'So do not weaken and do not grieve, and you will be superior if you '
            'are true believers.',
        'Al Imran 3:139',
      ),
      _q(
        'ادْعُونِي أَسْتَجِبْ لَكُمْ',
        'Call upon Me; I will respond to you.',
        'Ghafir 40:60',
      ),
      _q(
        'وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا ۝ وَيَرْزُقْهُ مِنْ '
            'حَيْثُ لَا يَحْتَسِبُ',
        'And whoever fears Allah — He will make for him a way out, and will '
            'provide for him from where he does not expect.',
        'At-Talaq 65:2–3',
      ),
      _q(
        'وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ',
        'But perhaps you hate a thing and it is good for you… And Allah '
            'knows, while you know not.',
        'Al-Baqarah 2:216',
      ),
      _q(
        'لَّا إِلَٰهَ إِلَّا أَنتَ سُبْحَانَكَ إِنِّي كُنتُ مِنَ الظَّالِمِينَ',
        'There is no deity except You; exalted are You. Indeed, I have been '
            'of the wrongdoers. — So We responded to him and saved him from '
            'the distress. And thus do We save the believers.',
        'Al-Anbiya 21:87–88',
      ),
      _h(
        'The strong believer is better and more beloved to Allah than the '
            'weak believer, though there is good in both. Strive for what '
            'benefits you, seek Allah\'s help, and do not give up.',
        'Sahih Muslim 2664',
      ),
      _h(
        'Allah has not sent down a disease without also sending down its '
            'cure.',
        'Sahih al-Bukhari 5678',
      ),
      _h(
        'If you were to rely upon Allah with the reliance He is due, He '
            'would provide for you as He provides for the birds: they go out '
            'hungry in the morning and return full in the evening.',
        'Jami\' at-Tirmidhi 2344',
        'hasan sahih',
      ),
      _q(
        'وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ',
        'And your Lord is going to give you, and you will be satisfied.',
        'Ad-Duha 93:5',
      ),
      _q(
        'أُولَٰئِكَ يَرْجُونَ رَحْمَتَ اللَّهِ ۚ وَاللَّهُ غَفُورٌ '
            'رَّحِيمٌ',
        'Those expect the mercy of Allah. And Allah is Forgiving and '
            'Merciful.',
        'Al-Baqarah 2:218',
      ),
      _q(
        'وَاللَّهُ يَخْتَصُّ بِرَحْمَتِهِ مَن يَشَاءُ ۚ وَاللَّهُ ذُو '
            'الْفَضْلِ الْعَظِيمِ',
        'But Allah selects for His mercy whom He wills, and Allah is '
            'the possessor of great bounty.',
        'Al-Baqarah 2:105',
      ),
      _q(
        'وَمَا أَرْسَلْنَاكَ إِلَّا رَحْمَةً لِّلْعَالَمِينَ',
        'And We have not sent you, [O Muhammad], except as a mercy to '
            'the worlds.',
        'Al-Anbiya 21:107',
      ),
      _h(
        'The Prophet ﷺ said: Allah has not sent down any disease except '
            'that He has sent down its cure.',
        'Sahih al-Bukhari 5678',
      ),
      _h(
        'The Prophet ﷺ said that Allah says: I am as My servant thinks '
            'I am, and I am with him when he remembers Me. If he draws near '
            'to Me a hand\'s span, I draw near to him an arm\'s length; if he '
            'comes to Me walking, I come to him running.',
        'Sahih al-Bukhari 7405 · Sahih Muslim 2675',
      ),
    ],
  };
}
