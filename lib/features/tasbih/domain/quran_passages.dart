// GENERATED — do not hand-edit the Arabic.
//
// Edition: Uthmani Hafs, the Madinah mushaf convention — sukun as the small
// high head of khah, dotted final yaa, open tanwin at the points of idgham and
// iqlab.
//
// Cross-checked against the King Fahd Complex text that quran.com serves as
// `text_qpc_hafs`. Fifteen of the sixteen verses matched character for
// character. The sixteenth, Ayat al-Kursi, differs only in how the open tanwin
// is encoded: quran.com writes it U+065E (fatha with two dots), this edition
// writes it U+08F1/U+08F2, the codepoints Unicode added for exactly this mark.
// Same mark, two encodings — and the choice is not cosmetic, because Amiri
// Quran has no glyph for U+065E and would have dropped it mid-verse.
//
// None of this text was typed from memory, and none of it should be. If a
// passage needs changing, re-run the fetch and cross-check rather than editing
// a letter by hand — a single wrong harakah here is not a cosmetic bug, and
// quran_passages_test pins a checksum of every string below to catch it.
//
// Translation: Pickthall (public domain).
//
// Transliteration is quran.com's word-level romanisation, which carries the
// scholarly diacritics — ḥ, ṣ, ṭ, ḍ, ẓ, ʿ and the long vowels — rather than
// the flat ASCII of the verse-level editions. Each ayah is followed by its
// number, as a printed transliteration sets it. Inter was checked for every
// one of those characters and the circled numerals before this was adopted.

import 'dhikr.dart';

/// Qur'anic passages used by the sunnah routines.

abstract final class QuranPassages {
  static const Dhikr ikhlas = Dhikr(
    name: 'Al-Ikhlas',
    source: 'Qur\'an 112',
    arabic:
        'قُلۡ هُوَ ٱللَّهُ أَحَدٌ ٱللَّهُ ٱلصَّمَدُ لَمۡ يَلِدۡ وَلَمۡ يُولَدۡ وَلَمۡ يَكُن لَّهُۥ كُفُوًا أَحَدُۢ',
    transliteration:
        'qul huwa l-lahu aḥadun ① al-lahu l-ṣamadu ② lam yalid walam '
        'yūlad ③ walam yakun lahu kufuwan aḥadun ④',
    meaning:
        'Say: He is Allah, the One! Allah, the eternally Besought of all! '
        'He begetteth not nor was begotten. And there is none comparable '
        'unto Him.',
    defaultTarget: 3,
  );

  static const Dhikr falaq = Dhikr(
    name: 'Al-Falaq',
    source: 'Qur\'an 113',
    arabic:
        'قُلۡ أَعُوذُ بِرَبِّ ٱلۡفَلَقِ مِن شَرِّ مَا خَلَقَ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ وَمِن شَرِّ ٱلنَّفَّٰثَٰتِ فِي ٱلۡعُقَدِ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ',
    transliteration:
        'qul aʿūdhu birabbi l-falaqi ① min sharri mā khalaqa ② wamin '
        'sharri ghāsiqin idhā waqaba ③ wamin sharri l-nafāthāti fī '
        'l-ʿuqadi ④ wamin sharri ḥāsidin idhā ḥasada ⑤',
    meaning:
        'Say: I seek refuge in the Lord of the Daybreak From the evil of '
        'that which He created; From the evil of the darkness when it is '
        'intense, And from the evil of malignant witchcraft, And from the '
        'evil of the envier when he envieth.',
    defaultTarget: 3,
  );

  static const Dhikr nas = Dhikr(
    name: 'An-Nas',
    source: 'Qur\'an 114',
    arabic:
        'قُلۡ أَعُوذُ بِرَبِّ ٱلنَّاسِ مَلِكِ ٱلنَّاسِ إِلَٰهِ ٱلنَّاسِ مِن شَرِّ ٱلۡوَسۡوَاسِ ٱلۡخَنَّاسِ ٱلَّذِي يُوَسۡوِسُ فِي صُدُورِ ٱلنَّاسِ مِنَ ٱلۡجِنَّةِ وَٱلنَّاسِ',
    transliteration:
        'qul aʿūdhu birabbi l-nāsi ① maliki l-nāsi ② ilāhi l-nāsi ③ min '
        'sharri l-waswāsi l-khanāsi ④ alladhī yuwaswisu fī ṣudūri l-nāsi '
        '⑤ mina l-jinati wal-nāsi ⑥',
    meaning:
        'Say: I seek refuge in the Lord of mankind, The King of mankind, '
        'The god of mankind, From the evil of the sneaking whisperer, Who '
        'whispereth in the hearts of mankind, Of the jinn and of mankind.',
    defaultTarget: 3,
  );

  static const Dhikr ayatAlKursi = Dhikr(
    name: 'Ayat al-Kursi',
    source: 'Qur\'an 2:255',
    arabic:
        'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلۡحَيُّ ٱلۡقَيُّومُۚ لَا تَأۡخُذُهُۥ سِنَةࣱ وَلَا نَوۡمࣱۚ لَّهُۥ مَا فِي ٱلسَّمَٰوَٰتِ وَمَا فِي ٱلۡأَرۡضِۗ مَن ذَا ٱلَّذِي يَشۡفَعُ عِندَهُۥٓ إِلَّا بِإِذۡنِهِۦۚ يَعۡلَمُ مَا بَيۡنَ أَيۡدِيهِمۡ وَمَا خَلۡفَهُمۡۖ وَلَا يُحِيطُونَ بِشَيۡءࣲ مِّنۡ عِلۡمِهِۦٓ إِلَّا بِمَا شَآءَۚ وَسِعَ كُرۡسِيُّهُ ٱلسَّمَٰوَٰتِ وَٱلۡأَرۡضَۖ وَلَا يَـُٔودُهُۥ حِفۡظُهُمَاۚ وَهُوَ ٱلۡعَلِيُّ ٱلۡعَظِيمُ',
    transliteration:
        'al-lahu lā ilāha illā huwa l-ḥayu l-qayūmu lā takhudhuhu sinatun '
        'walā nawmun lahu mā fī l-samāwāti wamā fī l-arḍi man dhā alladhī '
        'yashfaʿu ʿindahu illā bi-idh\'nihi yaʿlamu mā bayna aydīhim wamā '
        'khalfahum walā yuḥīṭūna bishayin min ʿil\'mihi illā bimā shāa '
        'wasiʿa kur\'siyyuhu l-samāwāti wal-arḍa walā yaūduhu ḥif\'ẓuhumā '
        'wahuwa l-ʿaliyu l-ʿaẓīmu',
    meaning:
        'Allah! There is no deity save Him, the Alive, the Eternal. '
        'Neither slumber nor sleep overtaketh Him. Unto Him belongeth '
        'whatsoever is in the heavens and whatsoever is in the earth. Who '
        'is he that intercedeth with Him save by His leave? He knoweth '
        'that which is in front of them and that which is behind them, '
        'while they encompass nothing of His knowledge save what He will. '
        'His throne includeth the heavens and the earth, and He is never '
        'weary of preserving them. He is the Sublime, the Tremendous.',
    defaultTarget: 1,
  );
}
