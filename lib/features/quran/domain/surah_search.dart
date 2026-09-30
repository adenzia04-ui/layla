import 'quran_data.dart';

/// How well [surah] answers a search, 0 for not at all.
///
/// Typing is matched from the start of a name, the way a finger expects:
/// "d" brings Ad-Duha, Ad-Dukhan and Adh-Dhariyat, not every surah with a
/// d somewhere in it. The Arabic article is skipped, so "fat" finds
/// Al-Fatihah and "alf" does too, and a number finds its surah. The
/// meaning is searched only for three letters or more, as a fallback, so
/// "cow" still opens Al-Baqarah.
int surahMatch(Surah surah, String query) {
  final String q = _fold(query);
  if (q.isEmpty) return 1;
  if (surah.number.toString().startsWith(q)) return 4;
  final String name = _fold(surah.name);
  final String bare = _bare(name);
  final String joined = name.replaceAll(' ', '');
  if (bare.startsWith(q) || name.startsWith(q) || joined.startsWith(q)) {
    return 3;
  }
  if (name.split(' ').any((String w) => w.startsWith(q))) return 3;
  if (surah.arabicName.startsWith(query.trim())) return 3;
  if (q.length >= 3) {
    if (name.contains(q) || bare.replaceAll(' ', '').contains(q)) return 2;
    final String meaning = _fold(surah.meaning);
    if (meaning.split(' ').any((String w) => w.startsWith(q))) return 1;
    if (meaning.contains(q)) return 1;
  }
  return 0;
}

/// Lower case, letters and digits only: "Ash-Shu'ara" → "ash shuara". A
/// hyphen splits the article from the name; an apostrophe just goes, so
/// "Ar-Ra'd" is "ar rad" and not a word that starts with d.
String _fold(String s) => s
    .toLowerCase()
    .replaceAll('-', ' ')
    .replaceAll(RegExp(r"[’'`ʿʾ]"), '')
    .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
    .replaceAll(RegExp(r' +'), ' ')
    .trim();

/// Without the leading article: "al fatihah" → "fatihah".
String _bare(String folded) {
  const List<String> articles = <String>[
    'al',
    'an',
    'ad',
    'adh',
    'ar',
    'as',
    'ash',
    'at',
    'ath',
    'az',
  ];
  final int space = folded.indexOf(' ');
  if (space < 0) return folded;
  final String head = folded.substring(0, space);
  return articles.contains(head) ? folded.substring(space + 1) : folded;
}
