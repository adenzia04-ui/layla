/// What each of the Names says, a dua that calls by it, one small practice
/// for the day, and how often the Qur'an uses it as a name where that count is
/// well established. Names known from the Sunnah, or from Allah's actions
/// described in the Qur'an rather than as a word in the text, carry no count.
///
/// In the same order as [NamesOfAllah.all].
library;

class NameDetail {
  const NameDetail(this.about, this.mentions, this.dua, this.practice);

  final String about;

  /// Times the name appears in the Qur'an as a name, or null when the name is
  /// known from the Sunnah instead.
  final int? mentions;

  /// One line of supplication that calls on Allah by this name.
  final String dua;

  /// One thing to do today that lives the name.
  final String practice;
}

/// The hadith the whole list rests on.
const String kNamesHadith =
    'Allah has ninety-nine names, one hundred less one; whoever preserves '
    'them enters Paradise.';
const String kNamesHadithSource = 'Sahih al-Bukhari 2736 · Sahih Muslim 2677';

const List<NameDetail> kNameDetails = <NameDetail>[
  NameDetail(
    "Mercy that reaches everything that exists, believer and denier alike, before anyone has earned it. The name opens every surah but one.",
    57,
    "Ya Rahman, let Your mercy reach me before my deeds do.",
    "Be gentle with one person today who has not earned it.",
  ),
  NameDetail(
    "Mercy that is particular and lasting: the special care Allah keeps for those who turn to Him, in this life and the next.",
    114,
    "Ya Rahim, keep me close and do not leave me to myself.",
    "Return to someone you have been avoiding.",
  ),
  NameDetail(
    "The true King, whose sovereignty needs no army, no heir and no permission. Every other rule is borrowed.",
    5,
    "Ya Malik, I am Yours; rule my heart and settle my affairs.",
    "Give up one thing you are gripping too tightly.",
  ),
  NameDetail(
    "Utterly pure, free of every flaw, every partner and every likeness. Nothing about Him can be diminished.",
    2,
    "Ya Quddus, cleanse my heart of what does not belong in it.",
    "Leave one conversation that was turning ugly.",
  ),
  NameDetail(
    "The source of all peace and safety. He is free of every defect, and from Him comes the calm the heart looks for.",
    1,
    "Ya Salam, give me peace inside and make me a source of peace.",
    "Greet everyone you meet today with salam first.",
  ),
  NameDetail(
    "The giver of security and the One who keeps His promise. He confirms His truth and grants faith and safety to those who trust Him.",
    1,
    "Ya Mu'min, keep me safe and make my faith firm.",
    "Reassure someone who is afraid.",
  ),
  NameDetail(
    "The Guardian who watches over all creation, aware of every state and every need, and keeps it in His care.",
    1,
    "Ya Muhaymin, watch over me and those I love.",
    "Check on someone nobody is checking on.",
  ),
  NameDetail(
    "The Almighty, whose might is never overcome. Honour belongs to Him, and whoever holds to Him is not humbled.",
    92,
    "Ya Aziz, give me honour through obedience, not pride.",
    "Hold your head up in one place you usually shrink.",
  ),
  NameDetail(
    "The One who compels and restores: He mends what is broken, sets right what is bent, and no will overrides His.",
    1,
    "Ya Jabbar, mend what is broken in me.",
    "Repair one small thing you have been putting off.",
  ),
  NameDetail(
    "The One to whom greatness truly belongs. Pride is His alone; in anyone else it is a borrowed robe.",
    1,
    "Ya Mutakabbir, greatness is Yours; make me humble.",
    "Let someone else have the last word.",
  ),
  NameDetail(
    "The Creator, who brings everything into being from nothing, and measures it before it exists.",
    8,
    "Ya Khaliq, You made me; make me good.",
    "Notice one created thing today as if for the first time.",
  ),
  NameDetail(
    "The Maker who brings creation out into reality, free of flaw, each thing distinct from every other.",
    1,
    "Ya Bari, You shaped me without flaw; help me accept myself.",
    "Say one kind thing about your own body.",
  ),
  NameDetail(
    "The Shaper of forms: every face, every leaf and every fingerprint given its particular shape by Him.",
    1,
    "Ya Musawwir, You formed me; form my character too.",
    "Look at a face you love and thank Allah for it.",
  ),
  NameDetail(
    "The One who forgives again and again, covering sins so often that the sinner is never turned away.",
    5,
    "Ya Ghaffar, forgive me for what I keep returning to.",
    "Forgive one person today without telling them.",
  ),
  NameDetail(
    "The Subduer, before whom every tyrant and every stubborn heart is small. Nothing resists Him.",
    6,
    "Ya Qahhar, subdue what overpowers me.",
    "Say no once to a habit that usually wins.",
  ),
  NameDetail(
    "The Bestower who gives freely and without being asked, gift upon gift, expecting nothing in return.",
    3,
    "Ya Wahhab, give me from Your gifts and make me give.",
    "Give something away without being asked.",
  ),
  NameDetail(
    "The Provider of every sustenance, for bodies and for hearts, reaching each creature where it is.",
    1,
    "Ya Razzaq, provide for me from where I do not expect.",
    "Feed someone today, even a bird.",
  ),
  NameDetail(
    "The Opener of what is closed: doors, hearts, problems and judgement. He decides between people with truth.",
    1,
    "Ya Fattah, open for me the doors that are shut.",
    "Open one door for someone else.",
  ),
  NameDetail(
    "The All-Knowing, from whom nothing is hidden: what was, what is, what will be and what could have been.",
    157,
    "Ya Alim, You know what I hide; set it right.",
    "Learn one verse's meaning you never knew.",
  ),
  NameDetail(
    "The One who withholds and constricts, in provision and in the heart, by wisdom and in measure.",
    null,
    "Ya Qabid, when You withhold, keep my heart content.",
    "Go without one comfort today, on purpose.",
  ),
  NameDetail(
    "The One who expands and extends: provision, life, the chest that finds relief. Withholding and giving are both His.",
    null,
    "Ya Basit, expand my chest and my provision.",
    "Spend a little more generously than you planned.",
  ),
  NameDetail(
    "The One who lowers whom He wills; the proud are brought down by Him, not by their rivals.",
    null,
    "Ya Khafid, lower whatever in me is rising against You.",
    "Take the lower seat once today.",
  ),
  NameDetail(
    "The One who raises: in rank, in honour, in the sight of others. He lifts whom He wills.",
    null,
    "Ya Rafi, raise me in Your sight, not in people's.",
    "Lift someone up in front of others.",
  ),
  NameDetail(
    "The Giver of honour. Whoever seeks dignity finds that it is His to grant.",
    null,
    "Ya Mu'izz, give me honour through You alone.",
    "Treat someone below you with extra respect.",
  ),
  NameDetail(
    "The One who humbles. He lowers the arrogant and the oppressor with a justice no one escapes.",
    null,
    "Ya Mudhill, keep me from what humbles me before You.",
    "Catch yourself once before boasting.",
  ),
  NameDetail(
    "The All-Hearing, who hears every voice at once, the spoken and the silent, without the one drowning the other.",
    45,
    "Ya Sami, You hear me; hear this.",
    "Listen to someone today without interrupting.",
  ),
  NameDetail(
    "The All-Seeing, from whom no deed, and no ant on a black stone in a dark night, is hidden.",
    42,
    "Ya Basir, You see me; let what You see be good.",
    "Do one good deed no one will ever see.",
  ),
  NameDetail(
    "The Judge whose verdict is final and just. Whatever He decides is what stands.",
    1,
    "Ya Hakam, judge my affair in my favour.",
    "Be fair in a dispute even when it costs you.",
  ),
  NameDetail(
    "The Utterly Just, who never wrongs anyone by an atom's weight; His justice is part of His mercy.",
    null,
    "Ya Adl, make me just with those I have power over.",
    "Give someone their due that you have delayed.",
  ),
  NameDetail(
    "The Subtle and Kind, whose gentleness arrives in ways too fine to notice until later.",
    7,
    "Ya Latif, be gentle with me in what I cannot bear.",
    "Do something kind so quietly no one notices.",
  ),
  NameDetail(
    "The All-Aware, who knows the inner reality of things, what hearts hide and what the earth conceals.",
    45,
    "Ya Khabir, You know my inside; make it match my outside.",
    "Be honest about one thing you had hidden.",
  ),
  NameDetail(
    "The Forbearing, who sees disobedience and does not hasten to punish, giving time to return.",
    11,
    "Ya Halim, do not hasten against me; let me return.",
    "Do not react to one thing that provokes you.",
  ),
  NameDetail(
    "The Magnificent, whose greatness is beyond what any mind can hold; every other greatness is small beside it.",
    9,
    "Ya Azim, make everything else small before You.",
    "Say Allahu Akbar slowly, and mean it, in every prayer today.",
  ),
  NameDetail(
    "The All-Forgiving, whose forgiveness is complete and covers sins however great or many.",
    91,
    "Ya Ghafur, cover what I have done.",
    "Ask forgiveness seventy times before you sleep.",
  ),
  NameDetail(
    "The Appreciative, who rewards a little deed with much, and never lets any effort for Him go unrecognised.",
    4,
    "Ya Shakur, accept my little and multiply it.",
    "Thank someone you have never properly thanked.",
  ),
  NameDetail(
    "The Most High, above all creation in His essence, His rank and His power.",
    8,
    "Ya Ali, raise me from where I am.",
    "Rise above one petty argument.",
  ),
  NameDetail(
    "The Most Great, greater than anything that can be imagined; Allahu Akbar is the heart of every prayer.",
    6,
    "Ya Kabir, greater than my fears.",
    "Compare your worry to Allah, not to your strength.",
  ),
  NameDetail(
    "The Preserver, who protects His creation and guards His servants and His Book from loss.",
    3,
    "Ya Hafiz, protect me and those I cannot protect.",
    "Guard your tongue for one full hour.",
  ),
  NameDetail(
    "The Sustainer who gives each creature what keeps it alive, and who has power over everything.",
    1,
    "Ya Muqit, sustain me in body and heart.",
    "Eat less than you want at one meal.",
  ),
  NameDetail(
    "The Reckoner who suffices, and who takes account of every deed; whoever relies on Him has enough.",
    3,
    "Ya Hasib, You are enough for me.",
    "Say hasbiyallah when the next worry comes.",
  ),
  NameDetail(
    "The Majestic, whose attributes of grandeur inspire awe; splendour is His alone.",
    null,
    "Ya Jalil, fill my heart with awe of You.",
    "Stand in prayer as if you are seen.",
  ),
  NameDetail(
    "The Most Generous, who gives without being asked, forgives without being begged, and gives more than is hoped.",
    2,
    "Ya Karim, give me more than I deserve.",
    "Be generous with your time, not just your money.",
  ),
  NameDetail(
    "The Watchful, who observes every moment and every heart; nothing slips from His attention.",
    3,
    "Ya Raqib, You watch me; make my private self clean.",
    "Leave one thing you would not do if watched.",
  ),
  NameDetail(
    "The Responder, who answers the one who calls, whatever their state. No supplication reaches Him unheard.",
    1,
    "Ya Mujib, answer me, for You promised.",
    "Make one dua with your whole heart, and expect the answer.",
  ),
  NameDetail(
    "The All-Encompassing, whose mercy, knowledge and provision are vast enough for all creation.",
    9,
    "Ya Wasi, Your mercy is wide enough for me.",
    "Include someone who is usually left out.",
  ),
  NameDetail(
    "The All-Wise, who places everything in its proper place; nothing He decrees is without wisdom.",
    91,
    "Ya Hakim, there is wisdom in what I cannot see.",
    "Accept one thing today without asking why.",
  ),
  NameDetail(
    "The Loving, who loves His servants and makes His servants loved. His affection reaches before it is asked.",
    2,
    "Ya Wadud, make me loved among Your servants.",
    "Tell someone you love them, plainly.",
  ),
  NameDetail(
    "The Glorious, whose honour, generosity and greatness are perfect and complete.",
    2,
    "Ya Majid, honour is Yours; honour me with Your nearness.",
    "Praise Allah out loud when you see something beautiful.",
  ),
  NameDetail(
    "The Resurrector, who raises the dead and sends the messengers; He brings everyone back to stand before Him.",
    null,
    "Ya Ba'ith, raise me among the righteous.",
    "Do one deed you would want to be raised with.",
  ),
  NameDetail(
    "The Witness, present to everything; nothing happens outside His sight.",
    20,
    "Ya Shahid, be my witness on the Day.",
    "Speak the truth once when it is easier not to.",
  ),
  NameDetail(
    "The Truth, the one absolute reality; all else exists only by Him and passes.",
    10,
    "Ya Haqq, keep me on the truth.",
    "Correct one small lie you have let stand.",
  ),
  NameDetail(
    "The Trustee, who takes charge of the affairs of those who rely on Him and manages them better than they could.",
    14,
    "Ya Wakil, I hand it to You.",
    "Hand one worry to Allah and do not pick it back up.",
  ),
  NameDetail(
    "The All-Strong, whose strength never fails or tires; every strength in creation is lent from Him.",
    9,
    "Ya Qawi, strengthen me where I am weak.",
    "Do the hard thing first today.",
  ),
  NameDetail(
    "The Firm, whose power is unshakable and steady; nothing wears it down.",
    1,
    "Ya Matin, make me steady.",
    "Keep one promise exactly as you made it.",
  ),
  NameDetail(
    "The Protecting Friend, who supports and stands by those who believe.",
    15,
    "Ya Wali, be my protector and my friend.",
    "Stand by someone who is being talked about.",
  ),
  NameDetail(
    "The Praiseworthy, deserving of all praise, whether creation praises Him or not.",
    17,
    "Ya Hamid, all praise is Yours.",
    "Say alhamdulillah for something that went wrong.",
  ),
  NameDetail(
    "The Reckoner who counts everything: every breath, every leaf, every deed, none missed.",
    null,
    "Ya Muhsi, count me among the forgiven.",
    "Count your blessings, actually count them, to ten.",
  ),
  NameDetail(
    "The Originator, who began creation without any model to follow.",
    null,
    "Ya Mubdi, begin in me something good.",
    "Start the thing you have been meaning to start.",
  ),
  NameDetail(
    "The Restorer, who brings creation back after death as easily as He began it.",
    null,
    "Ya Mu'id, bring me back to You each time I stray.",
    "Return to a habit you dropped.",
  ),
  NameDetail(
    "The Giver of Life, to bodies, to hearts and to dead lands after rain.",
    null,
    "Ya Muhyi, give life to my heart.",
    "Revive one dead relationship with a message.",
  ),
  NameDetail(
    "The Bringer of Death, who ends every life at its appointed time; death is His command, not an accident.",
    null,
    "Ya Mumit, let my end be on good.",
    "Remember death once today, and pray as if it were near.",
  ),
  NameDetail(
    "The Ever-Living, whose life has no beginning, no end and no weakness; all other life depends on His.",
    5,
    "Ya Hayy, You never die; I rely on You.",
    "Rely on Allah for one thing you usually rely on people for.",
  ),
  NameDetail(
    "The Self-Subsisting Sustainer, who needs nothing and upholds everything. Al-Hayy al-Qayyum is the greatest of His names.",
    3,
    "Ya Qayyum, hold me up.",
    "Say Ya Hayyu Ya Qayyum in your hardest moment today.",
  ),
  NameDetail(
    "The Finder, who lacks nothing He wants and finds all He seeks; nothing is lost to Him.",
    null,
    "Ya Wajid, You lack nothing; give me contentment.",
    "Want nothing for one hour.",
  ),
  NameDetail(
    "The Noble, whose glory and generosity are boundless and whose rank is high.",
    2,
    "Ya Majid, let me see Your generosity in my life.",
    "Look for three gifts you did not ask for.",
  ),
  NameDetail(
    "The One, unique in His essence and attributes; He has no second.",
    22,
    "Ya Wahid, make my heart undivided.",
    "Give one task your whole attention.",
  ),
  NameDetail(
    "The Absolutely One, indivisible, without partner or equal, as Surah Al-Ikhlas declares.",
    1,
    "Ya Ahad, You alone.",
    "Recite Surah al-Ikhlas ten times today.",
  ),
  NameDetail(
    "The Eternal Refuge, on whom all depend and who depends on none; every need is brought to Him.",
    1,
    "Ya Samad, all need You; I need You most.",
    "Take one need only to Allah, not to anyone else.",
  ),
  NameDetail(
    "The All-Able, whose power reaches everything, with no effort and no limit.",
    12,
    "Ya Qadir, nothing is hard for You.",
    "Attempt the thing you thought you could not.",
  ),
  NameDetail(
    "The Omnipotent, whose might is complete and whose grip nothing escapes.",
    4,
    "Ya Muqtadir, Your power is complete; ease my affair.",
    "Trust Allah with a result you cannot control.",
  ),
  NameDetail(
    "The One who brings forward: He advances whom He wills, in rank, in time and in nearness.",
    null,
    "Ya Muqaddim, bring forward what is good for me.",
    "Do the good deed you were saving for later.",
  ),
  NameDetail(
    "The One who delays and puts back, by wisdom; what is late is late by His decree.",
    null,
    "Ya Mu'akhkhir, delay from me what would harm me.",
    "Be patient with one delay today.",
  ),
  NameDetail(
    "The First, before whom there was nothing.",
    1,
    "Ya Awwal, You were before everything.",
    "Make dhikr the first thing you do after waking.",
  ),
  NameDetail(
    "The Last, after whom there is nothing; when all else ends, He remains.",
    1,
    "Ya Akhir, You remain when all is gone.",
    "Make dhikr the last thing before sleep.",
  ),
  NameDetail(
    "The Manifest, evident through every sign in creation, above everything.",
    1,
    "Ya Zahir, show me Your signs.",
    "Look at the sky tonight and think of Him.",
  ),
  NameDetail(
    "The Hidden, whose essence no eye or mind can grasp, and who is nearer than the jugular vein.",
    1,
    "Ya Batin, You know what is within me.",
    "Fix one hidden intention.",
  ),
  NameDetail(
    "The Governor who runs all affairs of creation; nothing moves outside His management.",
    1,
    "Ya Wali, govern my affairs.",
    "Let go of managing one thing that is not yours.",
  ),
  NameDetail(
    "The Supremely Exalted, high above every imperfection and every description.",
    1,
    "Ya Muta'ali, You are above all this.",
    "Rise above one comparison.",
  ),
  NameDetail(
    "The Source of Goodness, kind to His creation, generous beyond what they deserve.",
    1,
    "Ya Barr, be good to me and make me good to my parents.",
    "Do one act of kindness for your parents, or in their memory.",
  ),
  NameDetail(
    "The Accepter of Repentance, who turns to His servant so the servant can turn to Him, and accepts again and again.",
    11,
    "Ya Tawwab, turn to me so I can turn to You.",
    "Repent for one thing specifically, by name.",
  ),
  NameDetail(
    "The Avenger, who takes just retribution from the obstinate wrongdoer after every warning.",
    null,
    "Ya Muntaqim, protect me from Your anger.",
    "Avoid one wrong you have grown used to.",
  ),
  NameDetail(
    "The Pardoner, who not only forgives but erases, leaving no trace of the sin.",
    5,
    "Ya Afuw, erase it as if it never was.",
    "Repeat Allahumma innaka Afuwwun tuhibbul afwa fa'fu anni.",
  ),
  NameDetail(
    "The Most Kind, whose tenderness towards His servants exceeds a mother's for her child.",
    10,
    "Ya Ra'uf, be tender with me.",
    "Be tender with a child today.",
  ),
  NameDetail(
    "Owner of all Sovereignty, who gives dominion to whom He wills and takes it away.",
    1,
    "Ya Malik al-Mulk, the kingdom is Yours; give me my share.",
    "Thank Allah for one thing you own.",
  ),
  NameDetail(
    "Lord of Majesty and Generosity, feared for His greatness and loved for His giving.",
    2,
    "Ya Dhal-Jalali wal-Ikram, honour me with Your face.",
    "Say this name after every prayer today.",
  ),
  NameDetail(
    "The Equitable, who establishes justice and gives every claimant their due.",
    null,
    "Ya Muqsit, be just to me and make me just.",
    "Settle one debt, however small.",
  ),
  NameDetail(
    "The Gatherer, who brings together the scattered, and will gather all people on the Day of Judgement.",
    1,
    "Ya Jami, gather me with those I love in Paradise.",
    "Bring two people together today.",
  ),
  NameDetail(
    "The Self-Sufficient, free of every need, while everything is in need of Him.",
    18,
    "Ya Ghani, I am poor before You; enrich me.",
    "Give charity from what you thought you needed.",
  ),
  NameDetail(
    "The Enricher, who makes free of need whom He wills, in wealth and in contentment.",
    null,
    "Ya Mughni, make me free of need of anyone but You.",
    "Do not ask anyone for anything today.",
  ),
  NameDetail(
    "The Withholder, who keeps back what would harm, and whose withholding is protection.",
    null,
    "Ya Mani, keep from me what would harm me.",
    "Accept one refusal as a protection.",
  ),
  NameDetail(
    "The One who brings harm, by justice and wisdom, and by whose leave alone harm reaches anyone.",
    null,
    "Ya Darr, harm reaches me only by Your leave; keep it far.",
    "Face one fear knowing only Allah decides.",
  ),
  NameDetail(
    "The One who brings benefit; every good that arrives, arrives from Him.",
    null,
    "Ya Nafi, let benefit come to me and through me.",
    "Be useful to one person today.",
  ),
  NameDetail(
    "The Light of the heavens and the earth, by whom hearts see and by whom guidance is lit.",
    1,
    "Ya Nur, light my heart and my grave.",
    "Read a page of Qur'an by the light of the morning.",
  ),
  NameDetail(
    "The Guide, who shows the way and leads hearts to Him.",
    2,
    "Ya Hadi, guide me and keep me guided.",
    "Show someone one good way.",
  ),
  NameDetail(
    "The Incomparable Originator, who created the heavens and the earth without precedent.",
    2,
    "Ya Badi, You made all this without a model; make me new.",
    "Try one thing you have never done for Allah.",
  ),
  NameDetail(
    "The Everlasting, who remains after all things perish.",
    null,
    "Ya Baqi, You remain; let me hold to You.",
    "Invest in one thing that will outlast you.",
  ),
  NameDetail(
    "The Inheritor, to whom everything returns when every owner has passed.",
    3,
    "Ya Warith, all returns to You; let me return well.",
    "Give away one thing you were keeping for no reason.",
  ),
  NameDetail(
    "The Guide to the Right Path, whose every decree is perfectly directed.",
    null,
    "Ya Rashid, direct me to what is right.",
    "Make istikharah about one decision.",
  ),
  NameDetail(
    "The Patient, who does not hurry to punish and gives the disobedient time to return.",
    null,
    "Ya Sabur, give me patience like Yours.",
    "Wait one moment before every reply today.",
  ),
];
