/// How an ayah's Arabic splits into the pieces the mushaf, the glyph boxes
/// and the word timings all count.
///
/// The Uthmani text is split on spaces. Most tokens are words; a few are
/// lone pause marks (ۖ ۗ ۚ ۛ ۜ ۞ …) that the mushaf sets with their own
/// glyph. The page boxes number every token, marks included; the timings
/// number only the words. [wordToken] bridges the two.
library;

final RegExp _markOnly = RegExp(r'^[؀-؟ۖ-ࣰٰۭ-ࣿ]+$');

/// Every token of [arabic], in reading order. 1-based positions in the
/// glyph boxes are indices into this list plus one.
List<String> ayahTokens(String arabic) =>
    arabic.split(' ').where((String t) => t.isNotEmpty).toList();

/// True for a token that is only a pause or sajdah mark, not a word.
bool isMarkToken(String token) => _markOnly.hasMatch(token);

/// The index into [tokens] of the [word]-th word (1-based, marks not
/// counted), or -1 when there is no such word.
int wordToken(List<String> tokens, int word) {
  if (word < 1) return -1;
  int seen = 0;
  for (int i = 0; i < tokens.length; i++) {
    if (isMarkToken(tokens[i])) continue;
    seen++;
    if (seen == word) return i;
  }
  return -1;
}

/// The word number (1-based, marks not counted) of the token at [index],
/// or 0 for a mark.
int tokenWord(List<String> tokens, int index) {
  if (index < 0 || index >= tokens.length || isMarkToken(tokens[index])) {
    return 0;
  }
  int seen = 0;
  for (int i = 0; i <= index; i++) {
    if (!isMarkToken(tokens[i])) seen++;
  }
  return seen;
}
