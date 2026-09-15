/// A line of context for a passage: who it was revealed about, or when it
/// was said, in one sentence.
///
/// Kept to what is settled and well known — the occasion of revelation
/// where the books of tafsir agree, the narrator's own framing for a hadith
/// — and left out where it is not. A passage with no line here simply has
/// none shown; a guess would be worse than silence.
abstract final class MoodContext {
  static String? forReference(String reference) => _lines[reference];

  static const Map<String, String> _lines = <String, String>{
    'At-Tawbah 9:40':
        'Said in the cave outside Makkah, to Abu Bakr, with the men hunting '
        'them close enough to be heard.',
    "Ar-Ra'd 13:28":
        'Revealed in Makkah, to believers who at the time had little else to '
        'hold on to.',
    'Al-Baqarah 2:286':
        'The last verse of the longest surah. The Prophet ﷺ said its last two '
        'verses suffice whoever recites them at night.',
    'Yusuf 12:87':
        "Ya'qub to his sons, decades after losing Yusuf, sending them back to "
        'search.',
    'Yusuf 12:86':
        "Ya'qub's answer when his sons said he would grieve himself to death: "
        'I complain only to Allah.',
    'Az-Zumar 39:53':
        'Revealed about people who thought their sins had put them beyond '
        'forgiveness. It says: never.',
    'Ta-Ha 20:46':
        'To Musa and Harun, sent to Pharaoh and afraid: I am with you both; '
        'I hear and I see.',
    'Ad-Duha 93:7':
        'Revealed after a pause in revelation that had made the Prophet ﷺ '
        'fear he had been left.',
    'Ad-Duha 93:11':
        'The close of the surah that answered that fear: your Lord has not '
        'left you, nor does He hate you.',
    'Ad-Duha 93:5':
        'From the same surah: a promise made to a man who had just wondered '
        'whether he was forgotten.',
    'Al-Baqarah 2:155':
        'The words the Prophet ﷺ taught for every loss, with the promise that '
        'follows them.',
    'Al-Baqarah 2:156':
        'Umm Salamah said it as taught when her husband died, and was given, '
        'she said, better than him: the Prophet ﷺ.',
    'Luqman 31:12':
        'Luqman was given wisdom, and the first thing the Qur\'an names of it '
        'is gratitude.',
    'Ibrahim 14:7':
        'Musa reminding his people of the day they were delivered from '
        'Pharaoh.',
    'At-Talaq 65:2':
        'Revealed within a passage about divorce: the way out is promised in '
        'one of the hardest of settings.',
    'At-Talaq 65:3':
        'The same passage, one verse on: provision from where you did not '
        'expect.',
    'Al Imran 3:139':
        'Revealed after the defeat at Uhud, to believers who were wounded and '
        'grieving.',
    'Al Imran 3:173':
        "The Companions' words when told an army had gathered against them. "
        'They set out anyway.',
    'Al Imran 3:175':
        'The same passage: the devil frightens you with his allies. Do not '
        'fear them; fear Me.',
    'Al Imran 3:160':
        'Also after Uhud, when the believers had learned what a day without '
        'His aid looked like.',
    'Qaf 50:16':
        'Nearer than the vein in the neck: He knows what the soul whispers '
        'before it is a word.',
    'Al-Hadid 57:4': 'And He is with you wherever you are.',
    'Al-Baqarah 2:186':
        'Revealed when the Companions asked whether their Lord was near enough '
        'to hear them. I am near.',
    'Yunus 10:62':
        'The allies of Allah: those who believe and are mindful of Him. No '
        'fear for them, no grief.',
    'Al-Ankabut 29:2':
        'Revealed in Makkah, when the believers were being tested and asked '
        'why.',
    'Al-Baqarah 2:214':
        'Even the messengers, at the edge, asked when the help of Allah would '
        'come. Unquestionably, it is near.',
    'Ash-Sharh 94:5-6':
        'Revealed in Makkah in the years of hardship. The ease is promised '
        'twice.',
    'Al-Anbiya 21:88':
        'Yunus, in three darknesses — the night, the sea and the fish — and '
        'answered.',
    'Maryam 19:4':
        'Zakariyya, old and childless, calling in a low voice, and given '
        'Yahya.',
    'Al-Kahf 18:10':
        'The young men of the cave, with no way to live their faith in their '
        'city, asking only for mercy and a right way.',
    'Sahih Muslim 2999':
        "The believer's affair is all good: gratitude in ease, patience in "
        'hardship, and both are good for him.',
    'Al Imran 3:8':
        'A du\'a the Prophet ﷺ made often: O Turner of hearts, keep my heart '
        'firm on Your religion.',
  };
}
