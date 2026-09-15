import SwiftUI
import WidgetKit

/// A short verse, in Arabic with its translation, changing every twelve hours.
///
/// Bundled here rather than fetched: a widget that needs the network to say
/// something true is a widget that is sometimes blank. Every line is a verse
/// short enough to be read whole at a glance, with its reference so the
/// reader can open a mushaf and find it.
struct Verse {
    let arabic: String
    let english: String
    let reference: String

    static let all: [Verse] = [
        Verse(arabic: "لَا تَحْزَنْ إِنَّ اللَّهَ مَعَنَا",
              english: "Do not grieve; indeed Allah is with us.",
              reference: "At-Tawbah 9:40"),
        Verse(arabic: "فَإِنَّ مَعَ الْعُسْرِ يُسْرًا",
              english: "For indeed, with hardship comes ease.",
              reference: "Ash-Sharh 94:5"),
        Verse(arabic: "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ",
              english: "Truly, in the remembrance of Allah do hearts find rest.",
              reference: "Ar-Ra'd 13:28"),
        Verse(arabic: "وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ",
              english: "And He is with you wherever you are.",
              reference: "Al-Hadid 57:4"),
        Verse(arabic: "إِنَّ اللَّهَ مَعَ الصَّابِرِينَ",
              english: "Indeed, Allah is with the patient.",
              reference: "Al-Baqarah 2:153"),
        Verse(arabic: "وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ",
              english: "And whoever relies upon Allah, He is enough for him.",
              reference: "At-Talaq 65:3"),
        Verse(arabic: "رَّبِّ زِدْنِي عِلْمًا",
              english: "My Lord, increase me in knowledge.",
              reference: "Ta-Ha 20:114"),
        Verse(arabic: "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ",
              english: "Allah is sufficient for us, and He is the best Guardian.",
              reference: "Aal 'Imran 3:173"),
        Verse(arabic: "إِنَّ رَحْمَتَ اللَّهِ قَرِيبٌ مِّنَ الْمُحْسِنِينَ",
              english: "Indeed, the mercy of Allah is near to those who do good.",
              reference: "Al-A'raf 7:56"),
        Verse(arabic: "فَاذْكُرُونِي أَذْكُرْكُمْ",
              english: "So remember Me; I will remember you.",
              reference: "Al-Baqarah 2:152"),
        Verse(arabic: "لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا",
              english: "Allah does not burden a soul beyond what it can bear.",
              reference: "Al-Baqarah 2:286"),
        Verse(arabic: "وَقُل رَّبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا",
              english: "And say: My Lord, have mercy upon them as they raised me when I was small.",
              reference: "Al-Isra 17:24"),
        Verse(arabic: "إِنَّ اللَّهَ لَا يُضِيعُ أَجْرَ الْمُحْسِنِينَ",
              english: "Indeed, Allah does not let the reward of those who do good be lost.",
              reference: "At-Tawbah 9:120"),
        Verse(arabic: "وَبَشِّرِ الصَّابِرِينَ",
              english: "And give good tidings to the patient.",
              reference: "Al-Baqarah 2:155"),
        Verse(arabic: "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ",
              english: "Sufficient for us is Allah, and He is the best Disposer of affairs.",
              reference: "Al Imran 3:173"),
        Verse(arabic: "وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا",
              english: "And whoever fears Allah — He will make for him a way out.",
              reference: "At-Talaq 65:2"),
        Verse(arabic: "إِنَّمَا أَشْكُو بَثِّي وَحُزْنِي إِلَى اللَّهِ",
              english: "I only complain of my suffering and my grief to Allah.",
              reference: "Yusuf 12:86"),
        Verse(arabic: "وَلَا تَيْأَسُوا مِن رَّوْحِ اللَّهِ",
              english: "And do not despair of relief from Allah.",
              reference: "Yusuf 12:87"),
        Verse(arabic: "إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ",
              english: "Indeed we belong to Allah, and indeed to Him we will return.",
              reference: "Al-Baqarah 2:156"),
        Verse(arabic: "يَا أَيُّهَا النَّاسُ قَدْ جَاءَتْكُم مَّوْعِظَةٌ مِّن رَّبِّكُمْ وَشِفَاءٌ لِّمَا فِي الصُّدُورِ",
              english: "O mankind, there has come to you instruction from your Lord and healing for what is in the breasts.",
              reference: "Yunus 10:57"),
        Verse(arabic: "لَا تَخَافَا ۖ إِنَّنِي مَعَكُمَا أَسْمَعُ وَأَرَىٰ",
              english: "Fear not. Indeed, I am with you both; I hear and I see.",
              reference: "Ta-Ha 20:46"),
        Verse(arabic: "قُلْ حَسْبِيَ اللَّهُ ۖ عَلَيْهِ يَتَوَكَّلُ الْمُتَوَكِّلُونَ",
              english: "Say: Sufficient for me is Allah; upon Him rely the reliers.",
              reference: "Az-Zumar 39:38"),
        Verse(arabic: "فَلَا تَخَافُوهُمْ وَخَافُونِ إِن كُنتُم مُّؤْمِنِينَ",
              english: "So fear them not, but fear Me, if you are believers.",
              reference: "Al Imran 3:175"),
        Verse(arabic: "وَتَوَكَّلْ عَلَى اللَّهِ ۚ وَكَفَىٰ بِاللَّهِ وَكِيلًا",
              english: "And rely upon Allah; and sufficient is Allah as Disposer of affairs.",
              reference: "Al-Ahzab 33:3"),
        Verse(arabic: "أَلَّا تَخَافُوا وَلَا تَحْزَنُوا وَأَبْشِرُوا بِالْجَنَّةِ الَّتِي كُنتُمْ تُوعَدُونَ",
              english: "Do not fear and do not grieve, but receive good tidings of Paradise, which you were promised.",
              reference: "Fussilat 41:30"),
        Verse(arabic: "إِن يَنصُرْكُمُ اللَّهُ فَلَا غَالِبَ لَكُمْ",
              english: "If Allah should aid you, no one can overcome you.",
              reference: "Al Imran 3:160"),
        Verse(arabic: "وَنَحْنُ أَقْرَبُ إِلَيْهِ مِنْ حَبْلِ الْوَرِيدِ",
              english: "And We are closer to him than his jugular vein.",
              reference: "Qaf 50:16"),
        Verse(arabic: "أَلَيْسَ اللَّهُ بِكَافٍ عَبْدَهُ",
              english: "Is not Allah sufficient for His servant?",
              reference: "Az-Zumar 39:36"),
        Verse(arabic: "اللَّهُ وَلِيُّ الَّذِينَ آمَنُوا يُخْرِجُهُم مِّنَ الظُّلُمَاتِ إِلَى النُّورِ",
              english: "Allah is the ally of those who believe. He brings them out from darknesses into the light.",
              reference: "Al-Baqarah 2:257"),
        Verse(arabic: "وَلَمْ أَكُن بِدُعَائِكَ رَبِّ شَقِيًّا",
              english: "And never have I been in my supplication to You, my Lord, unhappy.",
              reference: "Maryam 19:4"),
        Verse(arabic: "وَإِذَا مَا غَضِبُوا هُمْ يَغْفِرُونَ",
              english: "…and when they are angry, they forgive.",
              reference: "Ash-Shura 42:37"),
        Verse(arabic: "وَلْيَعْفُوا وَلْيَصْفَحُوا ۗ أَلَا تُحِبُّونَ أَن يَغْفِرَ اللَّهُ لَكُمْ",
              english: "And let them pardon and overlook. Would you not like that Allah should forgive you?",
              reference: "An-Nur 24:22"),
        Verse(arabic: "وَمَن يَقْنَطُ مِن رَّحْمَةِ رَبِّهِ إِلَّا الضَّالُّونَ",
              english: "And who despairs of the mercy of his Lord except for those astray?",
              reference: "Al-Hijr 15:56"),
        Verse(arabic: "أَلَا إِنَّ نَصْرَ اللَّهِ قَرِيبٌ",
              english: "Unquestionably, the help of Allah is near.",
              reference: "Al-Baqarah 2:214"),
        Verse(arabic: "فَاصْبِرْ إِنَّ وَعْدَ اللَّهِ حَقٌّ",
              english: "So be patient. Indeed, the promise of Allah is truth.",
              reference: "Ar-Rum 30:60"),
        Verse(arabic: "فَاسْتَجَبْنَا لَهُ وَنَجَّيْنَاهُ مِنَ الْغَمِّ ۚ وَكَذَٰلِكَ نُنجِي الْمُؤْمِنِينَ",
              english: "So We responded to him and saved him from the distress. And thus do We save the believers.",
              reference: "Al-Anbiya 21:88"),
        Verse(arabic: "سَيَجْعَلُ اللَّهُ بَعْدَ عُسْرٍ يُسْرًا",
              english: "Allah will bring about, after hardship, ease.",
              reference: "At-Talaq 65:7"),
        Verse(arabic: "وَمَن يُؤْمِن بِاللَّهِ يَهْدِ قَلْبَهُ",
              english: "And whoever believes in Allah — He will guide his heart.",
              reference: "At-Taghabun 64:11"),
        Verse(arabic: "فَإِنَّ مَعَ الْعُسْرِ يُسْرًا ۝ إِنَّ مَعَ الْعُسْرِ يُسْرًا",
              english: "For indeed, with hardship will be ease. Indeed, with hardship will be ease.",
              reference: "Ash-Sharh 94:5-6"),
        Verse(arabic: "وَجَعَلْنَا نَوْمَكُمْ سُبَاتًا",
              english: "And We made your sleep a means for rest.",
              reference: "An-Naba 78:9"),
        Verse(arabic: "يَا أَيُّهَا الَّذِينَ آمَنُوا اصْبِرُوا وَصَابِرُوا وَرَابِطُوا وَاتَّقُوا اللَّهَ لَعَلَّكُمْ تُفْلِحُونَ",
              english: "O you who have believed, persevere and endure and remain stationed and fear Allah that you may be successful.",
              reference: "Al Imran 3:200"),
        Verse(arabic: "اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ",
              english: "Guide us to the straight path.",
              reference: "Al-Fatihah 1:6"),
        Verse(arabic: "وَوَجَدَكَ ضَالًّا فَهَدَىٰ",
              english: "And He found you lost and guided you.",
              reference: "Ad-Duha 93:7"),
        Verse(arabic: "وَالَّذِينَ جَاهَدُوا فِينَا لَنَهْدِيَنَّهُمْ سُبُلَنَا",
              english: "And those who strive for Us — We will surely guide them to Our ways.",
              reference: "Al-Ankabut 29:69"),
        Verse(arabic: "فَمَن يُرِدِ اللَّهُ أَن يَهْدِيَهُ يَشْرَحْ صَدْرَهُ لِلْإِسْلَامِ",
              english: "So whoever Allah wants to guide — He expands his breast to Islam.",
              reference: "Al-An'am 6:125"),
        Verse(arabic: "رَبَّنَا آتِنَا مِن لَّدُنكَ رَحْمَةً وَهَيِّئْ لَنَا مِنْ أَمْرِنَا رَشَدًا",
              english: "Our Lord, grant us from Yourself mercy and prepare for us from our affair right guidance.",
              reference: "Al-Kahf 18:10"),
        Verse(arabic: "رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا",
              english: "Our Lord, let not our hearts deviate after You have guided us.",
              reference: "Al Imran 3:8"),
        Verse(arabic: "وَاعْبُدْ رَبَّكَ حَتَّىٰ يَأْتِيَكَ الْيَقِينُ",
              english: "And worship your Lord until there comes to you the certainty.",
              reference: "Al-Hijr 15:99"),
        Verse(arabic: "الْحَقُّ مِن رَّبِّكَ ۖ فَلَا تَكُونَنَّ مِنَ الْمُمْتَرِينَ",
              english: "The truth is from your Lord, so never be among the doubters.",
              reference: "Al-Baqarah 2:147"),
        Verse(arabic: "إِنَّمَا يُوَفَّى الصَّابِرُونَ أَجْرَهُم بِغَيْرِ حِسَابٍ",
              english: "Indeed, the patient will be given their reward without account.",
              reference: "Az-Zumar 39:10"),
        Verse(arabic: "إِنَّ الْحَسَنَاتِ يُذْهِبْنَ السَّيِّئَاتِ",
              english: "Indeed, good deeds do away with misdeeds.",
              reference: "Hud 11:114"),
        Verse(arabic: "إِنَّ اللَّهَ يُحِبُّ التَّوَّابِينَ",
              english: "Indeed, Allah loves those who are constantly repentant.",
              reference: "Al-Baqarah 2:222"),
        Verse(arabic: "لَئِن شَكَرْتُمْ لَأَزِيدَنَّكُمْ",
              english: "If you are grateful, I will surely increase you.",
              reference: "Ibrahim 14:7"),
        Verse(arabic: "وَأَمَّا بِنِعْمَةِ رَبِّكَ فَحَدِّثْ",
              english: "But as for the favour of your Lord, report it.",
              reference: "Ad-Duha 93:11"),
        Verse(arabic: "فَبِأَيِّ آلَاءِ رَبِّكُمَا تُكَذِّبَانِ",
              english: "So which of the favours of your Lord would you deny?",
              reference: "Ar-Rahman 55:13"),
        Verse(arabic: "وَمَن يَشْكُرْ فَإِنَّمَا يَشْكُرُ لِنَفْسِهِ",
              english: "And whoever is grateful is grateful for the benefit of himself.",
              reference: "Luqman 31:12"),
        Verse(arabic: "هَلْ جَزَاءُ الْإِحْسَانِ إِلَّا الْإِحْسَانُ",
              english: "Is the reward for good anything but good?",
              reference: "Ar-Rahman 55:60"),
        Verse(arabic: "الْحَمْدُ لِلَّهِ الَّذِي هَدَانَا لِهَٰذَا",
              english: "Praise to Allah, who has guided us to this.",
              reference: "Al-A'raf 7:43"),
        Verse(arabic: "وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ",
              english: "And your Lord is going to give you, and you will be satisfied.",
              reference: "Ad-Duha 93:5"),
        Verse(arabic: "ادْعُونِي أَسْتَجِبْ لَكُمْ",
              english: "Call upon Me; I will respond to you.",
              reference: "Ghafir 40:60"),
        Verse(arabic: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
              english: "Our Lord, give us good in this world and good in the Hereafter, and protect us from the Fire.",
              reference: "Al-Baqarah 2:201"),
        Verse(arabic: "فَاللَّهُ خَيْرٌ حَافِظًا ۖ وَهُوَ أَرْحَمُ الرَّاحِمِينَ",
              english: "Allah is the best guardian, and He is the most merciful of the merciful.",
              reference: "Yusuf 12:64"),
        Verse(arabic: "إِنَّ اللَّهَ يُحِبُّ الْمُحْسِنِينَ",
              english: "Indeed, Allah loves the doers of good.",
              reference: "Al-Baqarah 2:195"),
        Verse(arabic: "وَقُولُوا لِلنَّاسِ حُسْنًا",
              english: "And speak to people good words.",
              reference: "Al-Baqarah 2:83"),
        Verse(arabic: "وَتَعَاوَنُوا عَلَى الْبِرِّ وَالتَّقْوَىٰ",
              english: "And help one another in righteousness and piety.",
              reference: "Al-Ma'idah 5:2"),
        Verse(arabic: "وَاذْكُر رَّبَّكَ فِي نَفْسِكَ تَضَرُّعًا وَخِيفَةً",
              english: "And remember your Lord within yourself, in humility and in awe.",
              reference: "Al-A'raf 7:205"),
        Verse(arabic: "إِنَّ الصَّلَاةَ تَنْهَىٰ عَنِ الْفَحْشَاءِ وَالْمُنكَرِ ۗ وَلَذِكْرُ اللَّهِ أَكْبَرُ",
              english: "Prayer restrains from shameful and wrong deeds, and the remembrance of Allah is greater.",
              reference: "Al-Ankabut 29:45"),
        Verse(arabic: "إِنَّ اللَّهَ لَا يُغَيِّرُ مَا بِقَوْمٍ حَتَّىٰ يُغَيِّرُوا مَا بِأَنفُسِهِمْ",
              english: "Allah does not change the condition of a people until they change what is in themselves.",
              reference: "Ar-Ra'd 13:11"),
        Verse(arabic: "وَلَا تَهِنُوا وَلَا تَحْزَنُوا وَأَنتُمُ الْأَعْلَوْنَ إِن كُنتُم مُّؤْمِنِينَ",
              english: "Do not weaken and do not grieve, for you will be superior if you are believers.",
              reference: "Al Imran 3:139"),
        Verse(arabic: "وَمَا تَوْفِيقِي إِلَّا بِاللَّهِ ۚ عَلَيْهِ تَوَكَّلْتُ وَإِلَيْهِ أُنِيبُ",
              english: "My success is only through Allah. Upon Him I rely, and to Him I return.",
              reference: "Hud 11:88"),
        Verse(arabic: "إِنَّمَا الْمُؤْمِنُونَ إِخْوَةٌ",
              english: "The believers are but brothers.",
              reference: "Al-Hujurat 49:10"),
        Verse(arabic: "وَلَا تَمْشِ فِي الْأَرْضِ مَرَحًا",
              english: "And do not walk upon the earth in arrogance.",
              reference: "Al-Isra 17:37"),
        Verse(arabic: "وَقُولُوا قَوْلًا سَدِيدًا",
              english: "And speak words of appropriate justice.",
              reference: "Al-Ahzab 33:70"),
        Verse(arabic: "إِنَّ اللَّهَ مَعَ الَّذِينَ اتَّقَوا وَّالَّذِينَ هُم مُّحْسِنُونَ",
              english: "Indeed, Allah is with those who are mindful of Him and those who do good.",
              reference: "An-Nahl 16:128"),
        Verse(arabic: "وَإِن تَعُدُّوا نِعْمَةَ اللَّهِ لَا تُحْصُوهَا",
              english: "And if you should count the favours of Allah, you could not enumerate them.",
              reference: "An-Nahl 16:18"),
        Verse(arabic: "وَالْعَصْرِ ۝ إِنَّ الْإِنسَانَ لَفِي خُسْرٍ",
              english: "By time, indeed mankind is in loss.",
              reference: "Al-Asr 103:1-2"),
        Verse(arabic: "إِنَّ اللَّهَ يَأْمُرُ بِالْعَدْلِ وَالْإِحْسَانِ",
              english: "Indeed, Allah commands justice and good conduct.",
              reference: "An-Nahl 16:90"),
        Verse(arabic: "وَمَا خَلَقْتُ الْجِنَّ وَالْإِنسَ إِلَّا لِيَعْبُدُونِ",
              english: "I did not create jinn and mankind except to worship Me.",
              reference: "Adh-Dhariyat 51:56"),
        Verse(arabic: "كُلُّ نَفْسٍ ذَائِقَةُ الْمَوْتِ",
              english: "Every soul will taste death.",
              reference: "Al Imran 3:185"),
        Verse(arabic: "وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ",
              english: "Perhaps you dislike a thing and it is good for you.",
              reference: "Al-Baqarah 2:216"),
        Verse(arabic: "إِنَّ اللَّهَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ",
              english: "Indeed, Allah is over all things competent.",
              reference: "Al-Baqarah 2:20"),
        Verse(arabic: "رَبِّ اشْرَحْ لِي صَدْرِي ۝ وَيَسِّرْ لِي أَمْرِي",
              english: "My Lord, expand for me my chest, and ease for me my task.",
              reference: "Ta-Ha 20:25-26"),
        Verse(arabic: "وَهُوَ الَّذِي يُنَزِّلُ الْغَيْثَ مِن بَعْدِ مَا قَنَطُوا",
              english: "It is He who sends down the rain after they had despaired.",
              reference: "Ash-Shura 42:28"),
        Verse(arabic: "وَأَقِمِ الصَّلَاةَ لِذِكْرِي",
              english: "And establish prayer for My remembrance.",
              reference: "Ta-Ha 20:14"),
        Verse(arabic: "وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ",
              english: "And seek help through patience and prayer.",
              reference: "Al-Baqarah 2:45"),
        Verse(arabic: "إِنَّ اللَّهَ لَا يُخْلِفُ الْمِيعَادَ",
              english: "Indeed, Allah does not fail in His promise.",
              reference: "Al Imran 3:9"),
        Verse(arabic: "وَاللَّهُ يُحِبُّ الصَّابِرِينَ",
              english: "And Allah loves the steadfast.",
              reference: "Al Imran 3:146"),
        Verse(arabic: "إِنَّ اللَّهَ لَا يَظْلِمُ النَّاسَ شَيْئًا",
              english: "Indeed, Allah does not wrong the people at all.",
              reference: "Yunus 10:44"),
        Verse(arabic: "لَا تَقْنَطُوا مِن رَّحْمَةِ اللَّهِ ۚ إِنَّ اللَّهَ يَغْفِرُ الذُّنُوبَ جَمِيعًا",
              english: "Do not despair of the mercy of Allah. Indeed, Allah forgives all sins.",
              reference: "Az-Zumar 39:53"),
        Verse(arabic: "وَإِذَا سَأَلَكَ عِبَادِي عَنِّي فَإِنِّي قَرِيبٌ",
              english: "And when My servants ask you about Me, indeed I am near.",
              reference: "Al-Baqarah 2:186"),
        Verse(arabic: "فَصَبْرٌ جَمِيلٌ ۖ وَاللَّهُ الْمُسْتَعَانُ",
              english: "So patience is most fitting, and Allah is the one sought for help.",
              reference: "Yusuf 12:18"),
        Verse(arabic: "وَإِنَّكَ لَعَلَىٰ خُلُقٍ عَظِيمٍ",
              english: "And indeed, you are of a great moral character.",
              reference: "Al-Qalam 68:4"),
        Verse(arabic: "وَمَا أَرْسَلْنَاكَ إِلَّا رَحْمَةً لِّلْعَالَمِينَ",
              english: "And We have not sent you except as a mercy to the worlds.",
              reference: "Al-Anbiya 21:107"),
        Verse(arabic: "إِنَّ أَكْرَمَكُمْ عِندَ اللَّهِ أَتْقَاكُمْ",
              english: "Indeed, the most noble of you in the sight of Allah is the most mindful of Him.",
              reference: "Al-Hujurat 49:13"),
        Verse(arabic: "فَمَن يَعْمَلْ مِثْقَالَ ذَرَّةٍ خَيْرًا يَرَهُ",
              english: "Whoever does an atom's weight of good will see it.",
              reference: "Az-Zalzalah 99:7"),
        Verse(arabic: "وَتُوبُوا إِلَى اللَّهِ جَمِيعًا أَيُّهَ الْمُؤْمِنُونَ لَعَلَّكُمْ تُفْلِحُونَ",
              english: "And turn to Allah in repentance, all of you, O believers, that you might succeed.",
              reference: "An-Nur 24:31"),
        Verse(arabic: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ",
              english: "All praise is due to Allah, Lord of the worlds.",
              reference: "Al-Fatihah 1:2"),
        Verse(arabic: "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ",
              english: "You alone we worship, and You alone we ask for help.",
              reference: "Al-Fatihah 1:5"),
        Verse(arabic: "وَاللَّهُ مَعَ الصَّابِرِينَ",
              english: "And Allah is with the steadfast.",
              reference: "Al-Baqarah 2:249"),
        Verse(arabic: "وَتَوَكَّلْ عَلَى الْحَيِّ الَّذِي لَا يَمُوتُ",
              english: "And rely upon the Ever-Living who does not die.",
              reference: "Al-Furqan 25:58"),
        Verse(arabic: "إِنَّ رَبِّي قَرِيبٌ مُّجِيبٌ",
              english: "Indeed, my Lord is near and responsive.",
              reference: "Hud 11:61"),
        Verse(arabic: "وَاصْبِرْ لِحُكْمِ رَبِّكَ فَإِنَّكَ بِأَعْيُنِنَا",
              english: "And be patient for the decision of your Lord, for you are in Our eyes.",
              reference: "At-Tur 52:48"),
        Verse(arabic: "رَبَّنَا تَقَبَّلْ مِنَّا ۖ إِنَّكَ أَنتَ السَّمِيعُ الْعَلِيمُ",
              english: "Our Lord, accept this from us. Indeed You are the Hearing, the Knowing.",
              reference: "Al-Baqarah 2:127"),
        Verse(arabic: "إِنَّ اللَّهَ يُدَافِعُ عَنِ الَّذِينَ آمَنُوا",
              english: "Indeed, Allah defends those who have believed.",
              reference: "Al-Hajj 22:38"),
        Verse(arabic: "وَاللَّهُ غَالِبٌ عَلَىٰ أَمْرِهِ",
              english: "And Allah is predominant over His affair.",
              reference: "Yusuf 12:21"),
        Verse(arabic: "وَمَا عِندَ اللَّهِ خَيْرٌ وَأَبْقَىٰ",
              english: "And what is with Allah is better and more lasting.",
              reference: "Al-Qasas 28:60"),
        Verse(arabic: "وَاصْبِرْ فَإِنَّ اللَّهَ لَا يُضِيعُ أَجْرَ الْمُحْسِنِينَ",
              english: "And be patient, for indeed Allah does not let the reward of the doers of good go to waste.",
              reference: "Hud 11:115"),
    ]

    /// A new verse every twelve hours, one for the morning and one for the
    /// evening, round the list and again. Counted from 1 January 2026 so the
    /// sequence is the same on every phone.
    static func forDay(_ date: Date) -> Verse {
        let cal = Calendar.current
        let epoch = cal.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? date
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: epoch), to: cal.startOfDay(for: date)).day ?? 0
        let half = cal.component(.hour, from: date) >= 12 ? 1 : 0
        let slot = days * 2 + half
        return all[((slot % all.count) + all.count) % all.count]
    }
}

struct VerseWidgetView: View {
    let entry: NoorEntry

    @Environment(\.widgetFamily) private var family

    private var verse: Verse { Verse.forDay(entry.date) }

    var body: some View {
        if family == .accessoryRectangular {
            LockVerseView(verse: Verse.forDay(entry.date))
        } else {
            home
        }
    }

    private var home: some View {
        VStack(spacing: 0) {
            WidgetHeader(title: "Verse of the day")

            Spacer(minLength: 4)

            Text(verse.arabic)
                .font(.system(size: family == .systemSmall ? 18 : 22, weight: .medium))
                .foregroundStyle(Layl.goldSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .environment(\.layoutDirection, .rightToLeft)

            if family != .systemSmall {
                Text(verse.english)
                    .font(Layl.ui(12))
                    .foregroundStyle(Layl.cream)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 8)
            }

            Spacer(minLength: 4)

            Text(verse.reference)
                .font(Layl.ui(10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Layl.gold)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct VerseWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "LaylaVerseWidget",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            WidgetRoot {
                VerseWidgetView(entry: entry)
            } art: {
                // The mihrab, faint, rising behind the words.
                MihrabShape()
                    .fill(
                        LinearGradient(
                            colors: [Layl.gold.opacity(0.14), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
            }
        }
        .configurationDisplayName("Verse of the Day")
        .description("A short verse in Arabic, with its meaning.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}


/// The verse on the Lock Screen: the meaning in full, shrunk to fit rather
/// than cut off, and the reference tucked bottom-right. No box behind it —
/// the wallpaper is the background, as with the clock.
struct LockVerseView: View {
    let verse: Verse

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verse.english)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verse.reference)
                .font(.system(size: 10, weight: .regular))
                .opacity(0.7)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "layla://verse"))
    }
}
