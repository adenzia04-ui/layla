import 'package:flutter/foundation.dart';

import 'mood_comfort.dart';

/// A supplication that fits a feeling.
///
/// Every one is either a verse of the Qur'an or a du'a the Prophet ﷺ taught,
/// with its collection and number, and nothing graded below hasan. The
/// transliteration is for the tongue; the meaning is for the heart.
@immutable
class MoodDua {
  const MoodDua({
    required this.arabic,
    required this.transliteration,
    required this.meaning,
    required this.reference,
  });

  final String arabic;
  final String transliteration;
  final String meaning;
  final String reference;
}

/// What a small step opens when tapped.
enum StepAction {
  /// The tasbih counter.
  tasbih,

  /// Home, where "I Have Prayed" lives.
  pray,

  /// Nothing to open — the step is done where you are.
  none,
}

/// One thing to do now, small enough to actually do.
@immutable
class MoodStep {
  const MoodStep({
    required this.title,
    required this.detail,
    required this.action,
    this.count,
  });

  final String title;
  final String detail;
  final StepAction action;

  /// How many times, when the step is a dhikr.
  final int? count;
}

/// A story from the Qur'an, told short, for the feelings it speaks to.
@immutable
class QuranStory {
  const QuranStory({
    required this.id,
    required this.title,
    required this.body,
    required this.reference,
    required this.moods,
  });

  final String id;
  final String title;
  final String body;
  final String reference;
  final Set<Mood> moods;
}

/// A hadith, told with its lesson, for the feelings it speaks to. Only from
/// the well-known collections, with the number, so it can be checked.
@immutable
class HadithStory {
  const HadithStory({
    required this.id,
    required this.title,
    required this.body,
    required this.lesson,
    required this.reference,
    required this.moods,
  });

  final String id;
  final String title;

  /// The hadith itself, in English.
  final String body;

  /// One or two lines on what it means for this feeling.
  final String lesson;

  /// "Sahih al-Bukhari 6114" — collection and number.
  final String reference;
  final Set<Mood> moods;
}

/// The extras for each feeling: a du'a, a step, the stories, the hadith.
abstract final class MoodExtras {
  static MoodDua duaFor(Mood mood) => _duas[mood]!;
  static List<HadithStory> hadithFor(Mood mood) =>
      hadith.where((HadithStory h) => h.moods.contains(mood)).toList();
  static MoodStep stepFor(Mood mood) => _steps[mood]!;
  static List<QuranStory> storiesFor(Mood mood) =>
      stories.where((QuranStory s) => s.moods.contains(mood)).toList();

  static QuranStory? storyById(String id) {
    for (final QuranStory s in stories) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ── Du'as ─────────────────────────────────────────────────────────────

  static const Map<Mood, MoodDua> _duas = <Mood, MoodDua>{
    Mood.anxious: MoodDua(
      arabic:
          'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ '
          'وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ',
      transliteration:
          "Allahumma inni a'udhu bika minal-hammi wal-hazan, wal-'ajzi "
          "wal-kasal, wal-bukhli wal-jubn, wa dala'id-dayni wa ghalabatir-rijal.",
      meaning:
          'O Allah, I seek refuge in You from worry and grief, from '
          'helplessness and laziness, from miserliness and cowardice, from '
          'the weight of debt and from being overpowered by men.',
      reference: 'Sahih al-Bukhari 6369',
    ),
    Mood.sad: MoodDua(
      arabic:
          'اللَّهُمَّ رَحْمَتَكَ أَرْجُو فَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ '
          'عَيْنٍ، وَأَصْلِحْ لِي شَأْنِي كُلَّهُ، لَا إِلَهَ إِلَّا أَنْتَ',
      transliteration:
          "Allahumma rahmataka arju, fala takilni ila nafsi tarfata 'ayn, "
          "wa aslih li sha'ni kullah, la ilaha illa ant.",
      meaning:
          'O Allah, it is Your mercy I hope for, so do not leave me to myself '
          'for the blink of an eye. Set right all my affairs. There is no god '
          'but You.',
      reference: 'Abu Dawud 5090 · hasan',
    ),
    Mood.fearful: MoodDua(
      arabic: 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
      transliteration: "Hasbunallahu wa ni'mal-wakil.",
      meaning:
          'Allah is enough for us, and He is the best Guardian of our affairs. '
          'Ibrahim said it as he was thrown into the fire, and the Companions '
          'said it when told an army had gathered against them.',
      reference: 'Aal Imran 3:173 · Sahih al-Bukhari 4563',
    ),
    Mood.lonely: MoodDua(
      arabic: 'رَبِّ لَا تَذَرْنِي فَرْدًا وَأَنتَ خَيْرُ الْوَارِثِينَ',
      transliteration: 'Rabbi la tadharni fardan wa anta khayrul-warithin.',
      meaning:
          'My Lord, do not leave me alone, and You are the best of '
          'inheritors. The call of Zakariyya, answered with a son.',
      reference: 'Al-Anbiya 21:89',
    ),
    Mood.angry: MoodDua(
      arabic: 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ',
      transliteration: "A'udhu billahi minash-shaytanir-rajim.",
      meaning:
          'I seek refuge in Allah from the accursed devil. Of a man red with '
          'anger the Prophet ﷺ said: I know a phrase which, if he said it, '
          'what he feels would leave him.',
      reference: 'Sahih al-Bukhari 3282 · Sahih Muslim 2610',
    ),
    Mood.hopeless: MoodDua(
      arabic: 'رَبِّ إِنِّي لِمَا أَنزَلْتَ إِلَيَّ مِنْ خَيْرٍ فَقِيرٌ',
      transliteration: 'Rabbi inni lima anzalta ilayya min khayrin faqir.',
      meaning:
          'My Lord, whatever good You send down to me, I am in need of it. '
          'Musa said it alone, penniless, in the shade of a tree in Madyan. '
          'Within the day he had a home, work, and a family.',
      reference: 'Al-Qasas 28:24',
    ),
    Mood.tired: MoodDua(
      arabic:
          'اللَّهُمَّ لَا سَهْلَ إِلَّا مَا جَعَلْتَهُ سَهْلًا، وَأَنْتَ تَجْعَلُ '
          'الْحَزْنَ إِذَا شِئْتَ سَهْلًا',
      transliteration:
          "Allahumma la sahla illa ma ja'altahu sahla, wa anta taj'alul-hazna "
          "idha shi'ta sahla.",
      meaning:
          'O Allah, nothing is easy except what You make easy, and You make '
          'the hard thing easy when You will.',
      reference: 'Sahih Ibn Hibban 974 · sahih',
    ),
    Mood.weary: MoodDua(
      arabic: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
      transliteration: 'La hawla wa la quwwata illa billah.',
      meaning:
          'There is no power and no strength except through Allah. The '
          'Prophet ﷺ called it a treasure from the treasures of Paradise.',
      reference: 'Sahih al-Bukhari 4205 · Sahih Muslim 2704',
    ),
    Mood.lost: MoodDua(
      arabic: 'اللَّهُمَّ اهْدِنِي وَسَدِّدْنِي',
      transliteration: 'Allahumma-hdini wa saddidni.',
      meaning:
          'O Allah, guide me, and keep me straight. Taught by the Prophet ﷺ '
          'to Ali, with the instruction to think, as he said it, of the road '
          'and of the arrow.',
      reference: 'Sahih Muslim 2725',
    ),
    Mood.doubtful: MoodDua(
      arabic:
          'رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِن '
          'لَّدُنكَ رَحْمَةً ۚ إِنَّكَ أَنتَ الْوَهَّابُ',
      transliteration:
          "Rabbana la tuzigh qulubana ba'da idh hadaytana wa hab lana min "
          'ladunka rahmah, innaka antal-Wahhab.',
      meaning:
          'Our Lord, do not let our hearts swerve after You have guided us, '
          'and grant us mercy from Yourself. You are the Bestower.',
      reference: 'Aal Imran 3:8',
    ),
    Mood.hardship: MoodDua(
      arabic:
          'لَّا إِلَٰهَ إِلَّا أَنتَ سُبْحَانَكَ إِنِّي كُنتُ مِنَ الظَّالِمِينَ',
      transliteration:
          'La ilaha illa anta, subhanaka, inni kuntu minaz-zalimin.',
      meaning:
          'There is no god but You; glory be to You; I have been among the '
          'wrongdoers. The call of Yunus from the dark. The Prophet ﷺ said no '
          'Muslim calls on his Lord with it except that He answers him.',
      reference: 'Al-Anbiya 21:87 · Tirmidhi 3505 · sahih',
    ),
    Mood.regretful: MoodDua(
      arabic:
          'رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ إِنَّكَ أَنْتَ التَّوَّابُ الرَّحِيمُ',
      transliteration:
          "Rabbighfir li wa tub 'alayya, innaka antat-Tawwabur-Rahim.",
      meaning:
          'My Lord, forgive me and accept my repentance. You are the One who '
          'accepts repentance, the Merciful. The Companions counted the '
          'Prophet ﷺ saying it a hundred times in one sitting.',
      reference: 'Abu Dawud 1516 · Tirmidhi 3434 · sahih',
    ),
    Mood.grateful: MoodDua(
      arabic:
          'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ',
      transliteration:
          "Allahumma a'inni 'ala dhikrika wa shukrika wa husni 'ibadatik.",
      meaning:
          'O Allah, help me to remember You, to thank You, and to worship You '
          'well. The Prophet ﷺ told Mu\'adh: by Allah, I love you, so never '
          'leave saying this after every prayer.',
      reference: 'Abu Dawud 1522 · sahih',
    ),
    Mood.joyful: MoodDua(
      arabic: 'الْحَمْدُ لِلَّهِ الَّذِي بِنِعْمَتِهِ تَتِمُّ الصَّالِحَاتُ',
      transliteration: "Alhamdu lillahil-ladhi bini'matihi tatimmus-salihat.",
      meaning:
          'All praise is for Allah, by whose favour good things are brought '
          'to completion. What the Prophet ﷺ said when something pleased him.',
      reference: 'Ibn Majah 3803 · hasan',
    ),
    Mood.hopeful: MoodDua(
      arabic:
          'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا '
          'عَذَابَ النَّارِ',
      transliteration:
          "Rabbana atina fid-dunya hasanah, wa fil-akhirati hasanah, wa qina "
          "'adhaban-nar.",
      meaning:
          'Our Lord, give us good in this world and good in the next, and '
          'protect us from the punishment of the Fire. The du\'a the Prophet ﷺ '
          'made most often.',
      reference: 'Al-Baqarah 2:201 · Sahih al-Bukhari 6389',
    ),
  };

  // ── Steps ─────────────────────────────────────────────────────────────

  static const Map<Mood, MoodStep> _steps = <Mood, MoodStep>{
    Mood.anxious: MoodStep(
      title: "Say Hasbunallahu wa ni'mal-wakil",
      detail: 'Thirty-three times, slowly, on your fingers.',
      action: StepAction.tasbih,
      count: 33,
    ),
    Mood.sad: MoodStep(
      title: "Pray two rak'ahs",
      detail: 'And in the prostration, tell Him everything.',
      action: StepAction.pray,
    ),
    Mood.fearful: MoodStep(
      title: 'Recite Ayat al-Kursi',
      detail: 'Once, then the last three surahs. Then breathe out.',
      action: StepAction.none,
    ),
    Mood.lonely: MoodStep(
      title: 'Say Ya Hayyu ya Qayyum',
      detail: 'Thirty-three times. He is nearer than the vein in your neck.',
      action: StepAction.tasbih,
      count: 33,
    ),
    Mood.angry: MoodStep(
      title: 'Say the ta\'awwudh, then sit down',
      detail:
          'The Prophet ﷺ said: if one of you is angry while standing, let '
          'him sit; and if it does not leave him, let him lie down.',
      action: StepAction.none,
    ),
    Mood.hopeless: MoodStep(
      title: "Say Yunus's du'a",
      detail:
          'La ilaha illa anta subhanaka inni kuntu minaz-zalimin, '
          'thirty-three times.',
      action: StepAction.tasbih,
      count: 33,
    ),
    Mood.tired: MoodStep(
      title: 'Say La hawla wa la quwwata illa billah',
      detail: 'Thirty-three times. Then do only the next small thing.',
      action: StepAction.tasbih,
      count: 33,
    ),
    Mood.weary: MoodStep(
      title: 'Rest, and then the tasbih of sleep',
      detail:
          'Subhanallah, Alhamdulillah and Allahu Akbar, thirty-three each, '
          'which the Prophet ﷺ gave Fatimah in place of a servant.',
      action: StepAction.tasbih,
      count: 99,
    ),
    Mood.lost: MoodStep(
      title: 'Pray Istikharah tonight',
      detail: "Two rak'ahs and the du'a, then let Him choose.",
      action: StepAction.pray,
    ),
    Mood.doubtful: MoodStep(
      title: 'Say Rabbi zidni \'ilma',
      detail: 'Thirty-three times. Certainty is asked for, then learned.',
      action: StepAction.tasbih,
      count: 33,
    ),
    Mood.hardship: MoodStep(
      title: 'Say Inna lillahi wa inna ilayhi raji\'un',
      detail:
          'Thirty-three times. Umm Salamah said it as she was taught, and '
          'was given better than what she lost.',
      action: StepAction.tasbih,
      count: 33,
    ),
    Mood.regretful: MoodStep(
      title: 'Astaghfirullah',
      detail: 'A hundred times, as the Prophet ﷺ did every day.',
      action: StepAction.tasbih,
      count: 100,
    ),
    Mood.grateful: MoodStep(
      title: 'Alhamdulillah',
      detail: 'A hundred times, one for each thing you can name.',
      action: StepAction.tasbih,
      count: 100,
    ),
    Mood.joyful: MoodStep(
      title: 'Give something today',
      detail: 'Joy shared is a sadaqah. Even a smile counts.',
      action: StepAction.none,
    ),
    Mood.hopeful: MoodStep(
      title: 'Bismillah, and one small task',
      detail: 'Begin with His name. Finish one thing before the next prayer.',
      action: StepAction.pray,
    ),
  };

  // ── Stories ───────────────────────────────────────────────────────────

  static const List<HadithStory> hadith = <HadithStory>[
    HadithStory(
      id: 'h_distress_dua',
      title: 'The words for worry',
      body:
          'The Prophet ﷺ said: No one is struck by worry or grief and says, '
          '"O Allah, I am Your servant, the son of Your servant, the son of '
          'Your maidservant; my forelock is in Your hand, Your judgement over '
          'me is carried out, Your decree upon me is just. I ask You by every '
          'name that is Yours … to make the Qur\'an the spring of my heart, '
          'the light of my chest, the clearing of my sorrow and the departure '
          'of my worry" — except that Allah removes his worry and grief and '
          'replaces it with relief.',
      lesson:
          'There is a du\'a made for exactly this. Say it slowly, and let '
          '"my forelock is in Your hand" do its work.',
      reference: 'Musnad Ahmad 3712 · graded sahih',
      moods: <Mood>{Mood.anxious, Mood.sad, Mood.tired},
    ),
    HadithStory(
      id: 'h_all_good',
      title: 'All of it is good',
      body:
          'The Prophet ﷺ said: How wonderful is the affair of the believer, '
          'for all of it is good, and that is for no one but the believer. If '
          'something glad reaches him he is grateful, and that is good for '
          'him; and if something hard reaches him he is patient, and that is '
          'good for him.',
      lesson:
          'Neither state is wasted. The hard hour is not outside the good; '
          'it is one of the two ways the good arrives.',
      reference: 'Sahih Muslim 2999',
      moods: <Mood>{Mood.hardship, Mood.anxious, Mood.joyful, Mood.grateful},
    ),
    HadithStory(
      id: 'h_ibrahim_wept',
      title: 'The eyes shed tears',
      body:
          'When his infant son Ibrahim was dying, the Prophet ﷺ took him in '
          'his arms and his eyes filled with tears. When asked about it, he '
          'said: The eyes shed tears and the heart grieves, but we say only '
          'what pleases our Lord. And we are grieved by your parting, O '
          'Ibrahim.',
      lesson:
          'Grief is not a failure of faith. He wept. What he guarded was his '
          'tongue, not his tears.',
      reference: 'Sahih al-Bukhari 1303',
      moods: <Mood>{Mood.sad},
    ),
    HadithStory(
      id: 'h_thorn',
      title: 'Even a thorn',
      body:
          'The Prophet ﷺ said: No fatigue, illness, worry, sorrow, harm or '
          'distress befalls a Muslim, not even the prick of a thorn, except '
          'that Allah wipes away some of his sins by it.',
      lesson:
          'Nothing you are carrying is being carried for nothing. The '
          'tiredness itself is doing something for you.',
      reference: 'Sahih al-Bukhari 5641',
      moods: <Mood>{Mood.sad, Mood.hardship, Mood.weary, Mood.tired},
    ),
    HadithStory(
      id: 'h_pens_lifted',
      title: 'The pens have been lifted',
      body:
          'The Prophet ﷺ said to Ibn Abbas: Know that if the whole nation '
          'gathered to benefit you, they could not benefit you except with '
          'what Allah has written for you; and if they gathered to harm you, '
          'they could not harm you except with what Allah has written against '
          'you. The pens have been lifted and the pages have dried.',
      lesson:
          'What you fear has a limit already set, and it is not set by the '
          'thing you fear.',
      reference: 'Jami\' at-Tirmidhi 2516 · sahih',
      moods: <Mood>{Mood.fearful, Mood.anxious},
    ),
    HadithStory(
      id: 'h_cave_two',
      title: 'Two, and Allah the third',
      body:
          'In the cave, with the enemy at its mouth, Abu Bakr said: If one of '
          'them looks down at his feet he will see us. The Prophet ﷺ said: '
          'What do you think, Abu Bakr, of two whose third is Allah?',
      lesson:
          'The count in the cave was never two. It is never only you in the '
          'room either.',
      reference: 'Sahih al-Bukhari 3653 · Sahih Muslim 2381',
      moods: <Mood>{Mood.fearful, Mood.lonely},
    ),
    HadithStory(
      id: 'h_as_he_thinks',
      title: 'As My servant thinks of Me',
      body:
          'The Prophet ﷺ said that Allah says: I am as My servant thinks I '
          'am, and I am with him when he remembers Me. If he remembers Me in '
          'himself, I remember him in Myself; if he draws near to Me a hand\'s '
          'span, I draw near to him an arm\'s length; if he comes to Me '
          'walking, I come to him running.',
      lesson:
          'Loneliness assumes distance. He answers a hand\'s span with an '
          'arm\'s length, and a walk with a run.',
      reference: 'Sahih al-Bukhari 7405 · Sahih Muslim 2675',
      moods: <Mood>{Mood.lonely, Mood.hopeless, Mood.hopeful},
    ),
    HadithStory(
      id: 'h_building',
      title: 'One building',
      body:
          'The Prophet ﷺ said: The believer to the believer is like a '
          'building, each part strengthening the other — and he interlaced '
          'his fingers.',
      lesson:
          'You were built into something. Find one brick near you today: a '
          'message, a visit, a prayer in a row with others.',
      reference: 'Sahih al-Bukhari 481',
      moods: <Mood>{Mood.lonely},
    ),
    HadithStory(
      id: 'h_strong',
      title: 'The truly strong',
      body:
          'The Prophet ﷺ said: The strong man is not the one who wrestles '
          'others down. The strong man is the one who controls himself when '
          'he is angry.',
      lesson:
          'Anger wants you to prove your strength. This is the proof: not '
          'acting on it.',
      reference: 'Sahih al-Bukhari 6114 · Sahih Muslim 2609',
      moods: <Mood>{Mood.angry},
    ),
    HadithStory(
      id: 'h_do_not_anger',
      title: 'Do not get angry',
      body:
          'A man said to the Prophet ﷺ: Advise me. He said: Do not get '
          'angry. The man asked again and again, and each time he said: Do '
          'not get angry. And he said elsewhere: If one of you is angry while '
          'standing, let him sit; if it does not leave him, let him lie down.',
      lesson:
          'The whole advice fitted in three words, and the method fits in '
          'one: sit down.',
      reference: 'Sahih al-Bukhari 6116 · Sunan Abi Dawud 4782 (sahih)',
      moods: <Mood>{Mood.angry},
    ),
    HadithStory(
      id: 'h_ninety_nine',
      title: 'The man who killed a hundred',
      body:
          'A man had killed ninety-nine people and asked a scholar whether he '
          'could repent. The scholar said no, and became the hundredth. He '
          'asked another, who said: Who can stand between you and repentance? '
          'Go to such a land where righteous people live. He set out and died '
          'on the way. The angels of mercy and the angels of punishment '
          'disputed over him, and Allah commanded the earth to draw the good '
          'land nearer — and he was found a hand-span closer to it, and mercy '
          'took him.',
      lesson:
          'A hundred, and he still turned, and the turning counted. There is '
          'no number after which the door is shut.',
      reference: 'Sahih al-Bukhari 3470 · Sahih Muslim 2766',
      moods: <Mood>{Mood.hopeless, Mood.regretful},
    ),
    HadithStory(
      id: 'h_mercy_prevails',
      title: 'My mercy prevails',
      body:
          'The Prophet ﷺ said: When Allah created the creation, He wrote in '
          'His Book, which is with Him above the Throne: My mercy prevails '
          'over My wrath.',
      lesson:
          'That sentence was written before you were. Despair is arguing '
          'with it.',
      reference: 'Sahih al-Bukhari 7553 · Sahih Muslim 2751',
      moods: <Mood>{Mood.hopeless, Mood.hopeful},
    ),
    HadithStory(
      id: 'h_camel',
      title: 'Happier than the man with the camel',
      body:
          'The Prophet ﷺ said: Allah is more pleased with the repentance of '
          'His servant than a man in a barren land whose camel, carrying his '
          'food and drink, wanders off. He gives up and lies down in the '
          'shade of a tree to die — and then finds it standing beside him. '
          'He grabs its halter and cries out, in his joy: O Allah, You are my '
          'servant and I am Your Lord — misspeaking from sheer joy.',
      lesson:
          'You imagine your return being received grudgingly. It is received '
          'like that.',
      reference: 'Sahih Muslim 2747 · Sahih al-Bukhari 6309',
      moods: <Mood>{Mood.regretful, Mood.hopeless},
    ),
    HadithStory(
      id: 'h_all_sin',
      title: 'The best of those who sin',
      body:
          'The Prophet ﷺ said: Every son of Adam sins, and the best of those '
          'who sin are those who repent.',
      lesson:
          'You are not disqualified by the sin. You are placed among the '
          'best by the return.',
      reference: 'Jami\' at-Tirmidhi 2499 · hasan',
      moods: <Mood>{Mood.regretful},
    ),
    HadithStory(
      id: 'h_take_what_you_can',
      title: 'Only what you can bear',
      body:
          'The Prophet ﷺ said: Take on only the deeds you can keep up, for '
          'Allah does not tire until you tire; and the most beloved deeds to '
          'Allah are those done regularly, even if small.',
      lesson:
          'You were never asked for everything at once. One small thing, '
          'kept up, is the whole instruction.',
      reference: 'Sahih al-Bukhari 5861 · Sahih Muslim 782',
      moods: <Mood>{Mood.tired, Mood.weary},
    ),
    HadithStory(
      id: 'h_hereafter_concern',
      title: 'One concern',
      body:
          'The Prophet ﷺ said: Whoever makes the Hereafter his concern, Allah '
          'puts richness in his heart and gathers his scattered affairs for '
          'him, and the world comes to him humbled. And whoever makes this '
          'world his concern, Allah puts poverty before his eyes and scatters '
          'his affairs, and nothing of the world comes to him except what '
          'was written.',
      lesson:
          'The scattered feeling has a cause named here, and a cure: one '
          'concern above the rest, and the rest gets gathered.',
      reference: 'Jami\' at-Tirmidhi 2465 · hasan',
      moods: <Mood>{Mood.tired, Mood.lost},
    ),
    HadithStory(
      id: 'h_body_right',
      title: 'Your body has a right over you',
      body:
          'The Prophet ﷺ said to Abdullah ibn Amr, who fasted every day and '
          'prayed every night: Do not do that. Fast and break your fast; pray '
          'and sleep. Your body has a right over you, your eyes have a right '
          'over you, and your wife has a right over you.',
      lesson:
          'Rest is not the opposite of devotion. It was commanded, in so many '
          'words, to the most devoted man in the room.',
      reference: 'Sahih al-Bukhari 1975',
      moods: <Mood>{Mood.weary, Mood.tired},
    ),
    HadithStory(
      id: 'h_bilal_rest',
      title: 'Give us rest by it',
      body:
          'The Prophet ﷺ would say: O Bilal, call the prayer — give us rest '
          'by it.',
      lesson:
          'He did not rest and then pray. The prayer was the rest. Try '
          'walking into the next one as a place to put things down.',
      reference: 'Sunan Abi Dawud 4985 · sahih',
      moods: <Mood>{Mood.weary, Mood.tired, Mood.anxious},
    ),
    HadithStory(
      id: 'h_path_knowledge',
      title: 'A path made easy',
      body:
          'The Prophet ﷺ said: Whoever travels a path in search of knowledge, '
          'Allah makes easy for him a path to Paradise.',
      lesson:
          'Being lost is the start of a search, and the search itself is '
          'already on a path.',
      reference: 'Sahih Muslim 2699',
      moods: <Mood>{Mood.lost, Mood.doubtful},
    ),
    HadithStory(
      id: 'h_istikharah',
      title: 'Ask Him to choose',
      body:
          'The Prophet ﷺ taught the istikharah to the Companions the way he '
          'taught a surah of the Qur\'an: pray two units, then say — O Allah, '
          'I seek Your choice by Your knowledge and Your power by Your might '
          '… if You know this matter is good for me in my religion, my life '
          'and my end, decree it for me and bless me in it; and if You know '
          'it is bad for me, turn it away from me and turn me away from it, '
          'and decree for me the good wherever it is, then make me pleased '
          'with it.',
      lesson:
          'You do not have to see the way. You have to ask the One who does, '
          'and then move.',
      reference: 'Sahih al-Bukhari 1162',
      moods: <Mood>{Mood.lost, Mood.doubtful},
    ),
    HadithStory(
      id: 'h_leave_doubt',
      title: 'Leave what makes you doubt',
      body:
          'The Prophet ﷺ said: Leave that which makes you doubt for that '
          'which does not make you doubt. Truth brings tranquillity, and '
          'falsehood brings doubt.',
      lesson:
          'Doubt is information. The thing that settles your chest is the '
          'thing to walk toward.',
      reference: 'Jami\' at-Tirmidhi 2518 · sahih',
      moods: <Mood>{Mood.doubtful, Mood.lost},
    ),
    HadithStory(
      id: 'h_pure_faith',
      title: 'That is pure faith',
      body:
          'Some Companions came to the Prophet ﷺ and said: We find in '
          'ourselves thoughts that any of us would find too grave to speak '
          'of. He said: Do you really find that? They said yes. He said: That '
          'is pure faith.',
      lesson:
          'The discomfort you feel at the doubt is the faith. A heart without '
          'faith would not flinch.',
      reference: 'Sahih Muslim 132',
      moods: <Mood>{Mood.doubtful},
    ),
    HadithStory(
      id: 'h_loved_tested',
      title: 'Whom He loves, He tests',
      body:
          'The Prophet ﷺ said: The greatest reward comes with the greatest '
          'trial. When Allah loves a people He tests them; whoever accepts it '
          'has His pleasure, and whoever resents it has His anger.',
      lesson:
          'The trial is not evidence of distance. In this hadith it is '
          'evidence of the opposite.',
      reference: 'Jami\' at-Tirmidhi 2396 · hasan',
      moods: <Mood>{Mood.hardship},
    ),
    HadithStory(
      id: 'h_thank_people',
      title: 'Thank the people',
      body:
          'The Prophet ﷺ said: Whoever does not thank people does not thank '
          'Allah.',
      lesson:
          'Gratitude to Him passes through the people He sent. Name one of '
          'them today, to their face.',
      reference: 'Jami\' at-Tirmidhi 1954 · sahih',
      moods: <Mood>{Mood.grateful, Mood.joyful},
    ),
    HadithStory(
      id: 'h_look_below',
      title: 'Look at those below you',
      body:
          'The Prophet ﷺ said: Look at those who are below you, and do not '
          'look at those above you; it is more likely that you will not '
          'belittle the favour of Allah upon you.',
      lesson:
          'Contentment has a direction. He gave it: look down the ladder, '
          'not up.',
      reference: 'Sahih Muslim 2963',
      moods: <Mood>{Mood.grateful, Mood.sad},
    ),
    HadithStory(
      id: 'h_smile',
      title: 'A smile is charity',
      body:
          'The Prophet ﷺ said: Your smile in the face of your brother is '
          'charity for you.',
      lesson:
          'The gladness you feel is a thing to give. It costs nothing and is '
          'written as sadaqah.',
      reference: 'Jami\' at-Tirmidhi 1956 · hasan',
      moods: <Mood>{Mood.joyful, Mood.grateful},
    ),
    HadithStory(
      id: 'h_cure',
      title: 'No disease without its cure',
      body:
          'The Prophet ﷺ said: Allah has not sent down any disease except '
          'that He has sent down its cure.',
      lesson:
          'Whatever the ailment, of body or of heart, the cure was sent '
          'down with it. Hope is not naive; it is accurate.',
      reference: 'Sahih al-Bukhari 5678',
      moods: <Mood>{Mood.hopeful, Mood.hardship, Mood.hopeless},
    ),
    HadithStory(
      id: 'h_musa_mother_calm',
      title: 'Allah is with the patient',
      body:
          'The Prophet ﷺ said: Whoever tries to be patient, Allah makes him '
          'patient; and no one has been given a gift better and wider than '
          'patience.',
      lesson:
          'Patience is not a trait you either have or lack. It is asked for, '
          'attempted, and given.',
      reference: 'Sahih al-Bukhari 1469 · Sahih Muslim 1053',
      moods: <Mood>{Mood.hardship, Mood.fearful, Mood.tired},
    ),
  ];

  static const List<QuranStory> stories = <QuranStory>[
    QuranStory(
      id: 'adam',
      title: 'Adam, and the first return',
      body:
          'The first human being was also the first to slip, and the first to '
          'be taught the way back. He and his wife ate from the tree, saw '
          'what they had done, and the Qur\'an gives their words: "Our Lord, '
          'we have wronged ourselves, and if You do not forgive us and have '
          'mercy on us we will surely be among the losers." Then Adam received '
          'words from his Lord, and He turned to him. Before there was a '
          'single sin in the world, there was already a way to return from '
          'one.',
      reference: "Al-A'raf 7:23 · Al-Baqarah 2:37",
      moods: <Mood>{Mood.regretful, Mood.hopeful},
    ),
    QuranStory(
      id: 'nuh',
      title: 'Nuh, nine hundred and fifty years',
      body:
          'He called his people night and day, in public and in private, for '
          'nine hundred and fifty years, and they put their fingers in their '
          'ears. He built a ship on dry land while they laughed. Nothing about '
          'it looked like success. When the rain came, the ones who had '
          'listened were on board with him. The Qur\'an does not measure his '
          'life by how many answered. It calls him a grateful servant, and '
          'sends peace upon him among all the worlds.',
      reference: "Nuh 71:5-9 · Hud 11:36-48 · Al-Isra 17:3",
      moods: <Mood>{Mood.tired, Mood.weary, Mood.hardship},
    ),
    QuranStory(
      id: 'hajar',
      title: 'Hajar, in the valley',
      body:
          'Ibrahim left her in a valley with no people and no water, with '
          'her infant son, and turned to go. She asked whether Allah had '
          'commanded it. He said yes. She said: Then He will not let us be '
          'lost. When the water ran out she ran between two hills, seven '
          'times, looking for anyone — and the water came up from under the '
          'child\'s feet. That valley is Makkah. Her running is the Sa\'i '
          'every pilgrim walks.',
      reference: "Ibrahim 14:37 · Sahih al-Bukhari 3364",
      moods: <Mood>{Mood.lonely, Mood.fearful, Mood.hopeful},
    ),
    QuranStory(
      id: 'musa_mother',
      title: 'The mother of Musa',
      body:
          'Pharaoh was killing the boys, and she had a newborn. She was told '
          'to put him in a chest and set him on the river — the very thing a '
          'mother\'s body refuses to do. The Qur\'an says her heart became '
          'empty, and she would have cried out had Allah not bound her heart. '
          'The river carried him to Pharaoh\'s own house, and Pharaoh\'s wife '
          'sent for a wet nurse, and the child would take no one — until his '
          'sister brought his own mother. "So We returned him to his mother, '
          'that her eye might be cooled, and that she might not grieve, and '
          'that she might know that the promise of Allah is true."',
      reference: "Al-Qasas 28:7-13",
      moods: <Mood>{Mood.anxious, Mood.fearful, Mood.sad},
    ),
    QuranStory(
      id: 'dawud',
      title: 'Dawud, and the two litigants',
      body:
          'Two men climbed over the wall of his private chamber with a '
          'dispute, and he judged between them — and in the judging saw '
          'something of himself, and understood that he had been tested. He '
          'asked his Lord for forgiveness, fell down in prostration, and '
          'turned. The Qur\'an says: So We forgave him that, and he has '
          'nearness to Us and a good place of return. A prophet, a king, and '
          'still the answer to being shown his own fault was the floor.',
      reference: "Sad 38:21-25",
      moods: <Mood>{Mood.regretful, Mood.angry},
    ),
    QuranStory(
      id: 'ahzab',
      title: 'The trench',
      body:
          'Ten thousand came against Madinah and the believers dug a trench '
          'in the cold with almost nothing to eat. The Qur\'an says eyes '
          'swerved and hearts reached the throats, and people thought all '
          'kinds of thoughts about Allah. Then a wind, and armies they never '
          'saw, and the enemy went home. When the believers saw the '
          'confederates they said: This is what Allah and His Messenger '
          'promised us. It only increased them in faith.',
      reference: "Al-Ahzab 33:9-22",
      moods: <Mood>{Mood.fearful, Mood.anxious, Mood.hopeful},
    ),
    QuranStory(
      id: 'ismail',
      title: 'Ismail, on the ground',
      body:
          'His father told him of a dream in which he sacrificed him, and '
          'asked what he thought. A boy, told that. He said: Father, do what '
          'you are commanded; you will find me, if Allah wills, among the '
          'patient. When they had both submitted and his father laid him on '
          'his forehead, the call came: You have fulfilled the vision. The '
          'Qur\'an calls it the clear trial, and it ended not in loss but in a '
          'ram, and in a house of the Ka\'bah the two of them would build.',
      reference: "As-Saffat 37:102-107",
      moods: <Mood>{Mood.doubtful, Mood.hardship, Mood.fearful},
    ),
    QuranStory(
      id: 'yunus',
      title: 'Yunus, in the dark',
      body:
          'Yunus left his people in anger before he was told to. On the ship '
          'the lots fell against him, and the sea took him, and a great fish '
          'took him from the sea. Three darknesses: the night, the water, the '
          'belly of the fish. There, with nothing left, he called: "There is '
          'no god but You, glory be to You, I have been among the '
          'wrongdoers." And the Qur\'an says: so We answered him, and We saved '
          'him from distress — and thus do We save the believers. He had not '
          'earned the rescue. He had only turned.',
      reference: "Al-Anbiya 21:87-88 · As-Saffat 37:139-148",
      moods: <Mood>{Mood.hopeless, Mood.hardship, Mood.regretful},
    ),
    QuranStory(
      id: 'yusuf',
      title: 'Yusuf, from the well',
      body:
          'His brothers threw him into a well. Travellers sold him for a few '
          'coins. A woman lied about him and he went to prison for years, '
          'forgotten by the one man who had promised to remember him. Every '
          'door that closed looked like the end. It was the way. From the '
          'prison he was called to the king, and from the king\'s side he fed '
          'a country through famine — and one day his brothers stood before '
          'him needing bread. He said: no blame on you today. Allah forgives '
          'you. The well was never the end of the story.',
      reference: 'Yusuf 12',
      moods: <Mood>{Mood.sad, Mood.lonely, Mood.hardship, Mood.hopeful},
    ),
    QuranStory(
      id: 'maryam',
      title: 'Maryam, beneath the palm',
      body:
          'She went far from her people, alone, and the pains of birth drove '
          'her to the trunk of a palm tree. She said: I wish I had died '
          'before this and been forgotten. Then a voice from below her: do '
          'not grieve; your Lord has placed a stream beneath you. Shake the '
          'trunk toward you and ripe dates will fall. Eat, and drink, and be '
          'at ease. She was not told to be strong. She was told where the '
          'water was, and to shake the tree.',
      reference: 'Maryam 19:22-26',
      moods: <Mood>{Mood.lonely, Mood.fearful, Mood.tired},
    ),
    QuranStory(
      id: 'sea',
      title: 'Musa at the sea',
      body:
          'The army was behind them, the sea in front. The people said: we '
          'are caught. Musa said: no — my Lord is with me; He will guide me. '
          'He did not know how. He only knew Who. Then the command came to '
          'strike the water with his staff, and it stood in walls like '
          'mountains, and a road opened where there had been no road. The '
          'way out was not visible until he was already at the edge.',
      reference: "Ash-Shu'ara 26:61-63",
      moods: <Mood>{Mood.fearful, Mood.anxious, Mood.lost},
    ),
    QuranStory(
      id: 'ayyub',
      title: 'Ayyub, and the years',
      body:
          'He lost his wealth, then his children, then his health, and it '
          'went on for years. He did not curse and he did not stop praying. '
          'At the end of it his whole complaint was one line: harm has '
          'touched me, and You are the most merciful of the merciful. That '
          'was enough. Strike the ground with your foot, he was told, and a '
          'spring came up — cool water to wash in and to drink. And his '
          'family were given back to him, and as many again with them. The '
          'Qur\'an says of him simply: We found him patient.',
      reference: 'Al-Anbiya 21:83-84 · Sad 38:41-44',
      moods: <Mood>{Mood.weary, Mood.hardship, Mood.tired},
    ),
    QuranStory(
      id: 'cave',
      title: 'Two in the cave',
      body:
          'Makkah had put a price on him. He and Abu Bakr hid in a cave in '
          'the mountain, and the men hunting them came so close that Abu Bakr '
          'whispered: if one of them looks down at his feet he will see us. '
          'The Prophet ﷺ answered: what do you think of two, when Allah is '
          'the third? Do not grieve; indeed Allah is with us. They did not '
          'look down. A spider, a nest, a turning away — and the two walked '
          'on to Madinah.',
      reference: 'At-Tawbah 9:40 · Sahih al-Bukhari 3653',
      moods: <Mood>{Mood.anxious, Mood.fearful},
    ),
    QuranStory(
      id: 'zakariyya',
      title: 'Zakariyya\'s quiet call',
      body:
          'He was old, his bones weak, his hair white, and his wife could not '
          'have children. He did not announce his need; the Qur\'an says he '
          'called on his Lord in a low voice. My Lord, I have never been '
          'disappointed in calling on You. And he was given Yahya — a name no '
          'one had been given before — and told the sign would be that he '
          'could not speak for three nights. A prayer whispered by an old man '
          'in an empty room, heard above the seven heavens.',
      reference: 'Maryam 19:2-11',
      moods: <Mood>{Mood.lonely, Mood.hopeless, Mood.hopeful},
    ),
    QuranStory(
      id: 'ibrahim',
      title: 'Ibrahim and the fire',
      body:
          'They built a fire so large they had to throw him in with a '
          'catapult. As he flew, he said: Allah is enough for me, and He is '
          'the best Guardian. And the command came to the fire itself: be '
          'cool, and safe, for Ibrahim. Not "put it out" — the fire stayed. '
          'It simply could not hurt him. Sometimes the trouble is not '
          'removed. Sometimes you are made safe inside it.',
      reference: 'Al-Anbiya 21:68-70 · Sahih al-Bukhari 4563',
      moods: <Mood>{Mood.fearful, Mood.doubtful},
    ),
    QuranStory(
      id: 'kahf',
      title: 'The young men in the cave',
      body:
          'A few young men in a city that worshipped idols could not find a '
          'way to live their faith and could not find anyone to tell them the '
          'way. So they went to a cave and said: our Lord, give us mercy from '
          'Yourself, and arrange our affair rightly for us. That was the '
          'whole plan — to withdraw and to ask. Allah put them to sleep for '
          'three hundred years and woke them in a city that believed. The '
          'Qur\'an calls them a sign: that when you are lost, turning to Him '
          'is itself the way.',
      reference: 'Al-Kahf 18:9-26',
      moods: <Mood>{Mood.lost, Mood.doubtful},
    ),
    QuranStory(
      id: 'ninety-nine',
      title: 'The man who killed a hundred',
      body:
          'He had killed ninety-nine people and asked a worshipper whether '
          'there was any repentance for him. The man said no, and he killed '
          'him too. Then a scholar told him: who stands between you and '
          'repentance? Go to such a land, where righteous people live. He set '
          'out and died on the road. The angels of mercy and the angels of '
          'punishment argued over him, and he was measured — and found a '
          'hand-span closer to the land he had been walking to. He was '
          'forgiven for the direction he was facing.',
      reference: 'Sahih al-Bukhari 3470 · Sahih Muslim 2766',
      moods: <Mood>{Mood.regretful, Mood.hopeless},
    ),
    QuranStory(
      id: 'sulayman',
      title: 'Sulayman hears an ant',
      body:
          'An army of men and jinn and birds marched at his word, and the '
          'wind carried him, and he understood the speech of birds. And on '
          'the road an ant warned the others to get into their homes before '
          'they were crushed. Sulayman heard it, and he smiled — and his '
          'first thought was not his power but this: my Lord, make me '
          'grateful for what You have given me. A king who could hear an ant '
          'asked only to be able to say thank you.',
      reference: 'An-Naml 27:15-19',
      moods: <Mood>{Mood.grateful, Mood.joyful},
    ),
    QuranStory(
      id: 'yaqub',
      title: 'Ya\'qub, still waiting',
      body:
          'He had lost Yusuf, and then Binyamin, and he had wept until his '
          'eyes went white. And when his sons said, you will never stop '
          'remembering Yusuf, he answered: I only complain of my grief to '
          'Allah. Then he sent them back to look again: go and search for '
          'Yusuf and his brother, and do not despair of the relief of Allah. '
          'Decades in, and he still would not call it over. And it was not.',
      reference: 'Yusuf 12:84-87',
      moods: <Mood>{Mood.sad, Mood.hopeless, Mood.weary},
    ),
  ];
}
