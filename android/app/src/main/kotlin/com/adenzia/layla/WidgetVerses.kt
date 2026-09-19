package com.adenzia.layla

import java.util.Calendar
import java.util.Date

/**
 * The verses the Verse widget shows, and which one is showing now.
 *
 * Generated from `ios/NoorWidgets/VerseWidget.swift`. Bundled rather than
 * fetched, for the reason the Swift gives: a widget that needs the network to
 * say something true is a widget that is sometimes blank.
 *
 * The rotation is arithmetic from a fixed epoch, not random and not stored,
 * so the iPhone and the Android phone in the same pocket show the same verse
 * at the same moment.
 */
internal data class Verse(
    val arabic: String,
    val english: String,
    val reference: String,
)

internal object Verses {
    val all: List<Verse> = listOf(
        Verse("لَا تَحْزَنْ إِنَّ اللَّهَ مَعَنَا", "Do not grieve; indeed Allah is with us.", "At-Tawbah 9:40"),
        Verse("فَإِنَّ مَعَ الْعُسْرِ يُسْرًا", "For indeed, with hardship comes ease.", "Ash-Sharh 94:5"),
        Verse("أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ", "Truly, in the remembrance of Allah do hearts find rest.", "Ar-Ra'd 13:28"),
        Verse("وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ", "And He is with you wherever you are.", "Al-Hadid 57:4"),
        Verse("إِنَّ اللَّهَ مَعَ الصَّابِرِينَ", "Indeed, Allah is with the patient.", "Al-Baqarah 2:153"),
        Verse("وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ", "And whoever relies upon Allah, He is enough for him.", "At-Talaq 65:3"),
        Verse("رَّبِّ زِدْنِي عِلْمًا", "My Lord, increase me in knowledge.", "Ta-Ha 20:114"),
        Verse("حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ", "Allah is sufficient for us, and He is the best Guardian.", "Aal 'Imran 3:173"),
        Verse("إِنَّ رَحْمَتَ اللَّهِ قَرِيبٌ مِّنَ الْمُحْسِنِينَ", "Indeed, the mercy of Allah is near to those who do good.", "Al-A'raf 7:56"),
        Verse("فَاذْكُرُونِي أَذْكُرْكُمْ", "So remember Me; I will remember you.", "Al-Baqarah 2:152"),
        Verse("لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا", "Allah does not burden a soul beyond what it can bear.", "Al-Baqarah 2:286"),
        Verse("وَقُل رَّبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا", "And say: My Lord, have mercy upon them as they raised me when I was small.", "Al-Isra 17:24"),
        Verse("إِنَّ اللَّهَ لَا يُضِيعُ أَجْرَ الْمُحْسِنِينَ", "Indeed, Allah does not let the reward of those who do good be lost.", "At-Tawbah 9:120"),
        Verse("وَبَشِّرِ الصَّابِرِينَ", "And give good tidings to the patient.", "Al-Baqarah 2:155"),
        Verse("حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ", "Sufficient for us is Allah, and He is the best Disposer of affairs.", "Al Imran 3:173"),
        Verse("وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا", "And whoever fears Allah — He will make for him a way out.", "At-Talaq 65:2"),
        Verse("إِنَّمَا أَشْكُو بَثِّي وَحُزْنِي إِلَى اللَّهِ", "I only complain of my suffering and my grief to Allah.", "Yusuf 12:86"),
        Verse("وَلَا تَيْأَسُوا مِن رَّوْحِ اللَّهِ", "And do not despair of relief from Allah.", "Yusuf 12:87"),
        Verse("إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ", "Indeed we belong to Allah, and indeed to Him we will return.", "Al-Baqarah 2:156"),
        Verse("يَا أَيُّهَا النَّاسُ قَدْ جَاءَتْكُم مَّوْعِظَةٌ مِّن رَّبِّكُمْ وَشِفَاءٌ لِّمَا فِي الصُّدُورِ", "O mankind, there has come to you instruction from your Lord and healing for what is in the breasts.", "Yunus 10:57"),
        Verse("لَا تَخَافَا ۖ إِنَّنِي مَعَكُمَا أَسْمَعُ وَأَرَىٰ", "Fear not. Indeed, I am with you both; I hear and I see.", "Ta-Ha 20:46"),
        Verse("قُلْ حَسْبِيَ اللَّهُ ۖ عَلَيْهِ يَتَوَكَّلُ الْمُتَوَكِّلُونَ", "Say: Sufficient for me is Allah; upon Him rely the reliers.", "Az-Zumar 39:38"),
        Verse("فَلَا تَخَافُوهُمْ وَخَافُونِ إِن كُنتُم مُّؤْمِنِينَ", "So fear them not, but fear Me, if you are believers.", "Al Imran 3:175"),
        Verse("وَتَوَكَّلْ عَلَى اللَّهِ ۚ وَكَفَىٰ بِاللَّهِ وَكِيلًا", "And rely upon Allah; and sufficient is Allah as Disposer of affairs.", "Al-Ahzab 33:3"),
        Verse("أَلَّا تَخَافُوا وَلَا تَحْزَنُوا وَأَبْشِرُوا بِالْجَنَّةِ الَّتِي كُنتُمْ تُوعَدُونَ", "Do not fear and do not grieve, but receive good tidings of Paradise, which you were promised.", "Fussilat 41:30"),
        Verse("إِن يَنصُرْكُمُ اللَّهُ فَلَا غَالِبَ لَكُمْ", "If Allah should aid you, no one can overcome you.", "Al Imran 3:160"),
        Verse("وَنَحْنُ أَقْرَبُ إِلَيْهِ مِنْ حَبْلِ الْوَرِيدِ", "And We are closer to him than his jugular vein.", "Qaf 50:16"),
        Verse("أَلَيْسَ اللَّهُ بِكَافٍ عَبْدَهُ", "Is not Allah sufficient for His servant?", "Az-Zumar 39:36"),
        Verse("اللَّهُ وَلِيُّ الَّذِينَ آمَنُوا يُخْرِجُهُم مِّنَ الظُّلُمَاتِ إِلَى النُّورِ", "Allah is the ally of those who believe. He brings them out from darknesses into the light.", "Al-Baqarah 2:257"),
        Verse("وَلَمْ أَكُن بِدُعَائِكَ رَبِّ شَقِيًّا", "And never have I been in my supplication to You, my Lord, unhappy.", "Maryam 19:4"),
        Verse("وَإِذَا مَا غَضِبُوا هُمْ يَغْفِرُونَ", "…and when they are angry, they forgive.", "Ash-Shura 42:37"),
        Verse("وَلْيَعْفُوا وَلْيَصْفَحُوا ۗ أَلَا تُحِبُّونَ أَن يَغْفِرَ اللَّهُ لَكُمْ", "And let them pardon and overlook. Would you not like that Allah should forgive you?", "An-Nur 24:22"),
        Verse("وَمَن يَقْنَطُ مِن رَّحْمَةِ رَبِّهِ إِلَّا الضَّالُّونَ", "And who despairs of the mercy of his Lord except for those astray?", "Al-Hijr 15:56"),
        Verse("أَلَا إِنَّ نَصْرَ اللَّهِ قَرِيبٌ", "Unquestionably, the help of Allah is near.", "Al-Baqarah 2:214"),
        Verse("فَاصْبِرْ إِنَّ وَعْدَ اللَّهِ حَقٌّ", "So be patient. Indeed, the promise of Allah is truth.", "Ar-Rum 30:60"),
        Verse("فَاسْتَجَبْنَا لَهُ وَنَجَّيْنَاهُ مِنَ الْغَمِّ ۚ وَكَذَٰلِكَ نُنجِي الْمُؤْمِنِينَ", "So We responded to him and saved him from the distress. And thus do We save the believers.", "Al-Anbiya 21:88"),
        Verse("سَيَجْعَلُ اللَّهُ بَعْدَ عُسْرٍ يُسْرًا", "Allah will bring about, after hardship, ease.", "At-Talaq 65:7"),
        Verse("وَمَن يُؤْمِن بِاللَّهِ يَهْدِ قَلْبَهُ", "And whoever believes in Allah — He will guide his heart.", "At-Taghabun 64:11"),
        Verse("فَإِنَّ مَعَ الْعُسْرِ يُسْرًا ۝ إِنَّ مَعَ الْعُسْرِ يُسْرًا", "For indeed, with hardship will be ease. Indeed, with hardship will be ease.", "Ash-Sharh 94:5-6"),
        Verse("وَجَعَلْنَا نَوْمَكُمْ سُبَاتًا", "And We made your sleep a means for rest.", "An-Naba 78:9"),
        Verse("يَا أَيُّهَا الَّذِينَ آمَنُوا اصْبِرُوا وَصَابِرُوا وَرَابِطُوا وَاتَّقُوا اللَّهَ لَعَلَّكُمْ تُفْلِحُونَ", "O you who have believed, persevere and endure and remain stationed and fear Allah that you may be successful.", "Al Imran 3:200"),
        Verse("اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ", "Guide us to the straight path.", "Al-Fatihah 1:6"),
        Verse("وَوَجَدَكَ ضَالًّا فَهَدَىٰ", "And He found you lost and guided you.", "Ad-Duha 93:7"),
        Verse("وَالَّذِينَ جَاهَدُوا فِينَا لَنَهْدِيَنَّهُمْ سُبُلَنَا", "And those who strive for Us — We will surely guide them to Our ways.", "Al-Ankabut 29:69"),
        Verse("فَمَن يُرِدِ اللَّهُ أَن يَهْدِيَهُ يَشْرَحْ صَدْرَهُ لِلْإِسْلَامِ", "So whoever Allah wants to guide — He expands his breast to Islam.", "Al-An'am 6:125"),
        Verse("رَبَّنَا آتِنَا مِن لَّدُنكَ رَحْمَةً وَهَيِّئْ لَنَا مِنْ أَمْرِنَا رَشَدًا", "Our Lord, grant us from Yourself mercy and prepare for us from our affair right guidance.", "Al-Kahf 18:10"),
        Verse("رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا", "Our Lord, let not our hearts deviate after You have guided us.", "Al Imran 3:8"),
        Verse("وَاعْبُدْ رَبَّكَ حَتَّىٰ يَأْتِيَكَ الْيَقِينُ", "And worship your Lord until there comes to you the certainty.", "Al-Hijr 15:99"),
        Verse("الْحَقُّ مِن رَّبِّكَ ۖ فَلَا تَكُونَنَّ مِنَ الْمُمْتَرِينَ", "The truth is from your Lord, so never be among the doubters.", "Al-Baqarah 2:147"),
        Verse("إِنَّمَا يُوَفَّى الصَّابِرُونَ أَجْرَهُم بِغَيْرِ حِسَابٍ", "Indeed, the patient will be given their reward without account.", "Az-Zumar 39:10"),
        Verse("إِنَّ الْحَسَنَاتِ يُذْهِبْنَ السَّيِّئَاتِ", "Indeed, good deeds do away with misdeeds.", "Hud 11:114"),
        Verse("إِنَّ اللَّهَ يُحِبُّ التَّوَّابِينَ", "Indeed, Allah loves those who are constantly repentant.", "Al-Baqarah 2:222"),
        Verse("لَئِن شَكَرْتُمْ لَأَزِيدَنَّكُمْ", "If you are grateful, I will surely increase you.", "Ibrahim 14:7"),
        Verse("وَأَمَّا بِنِعْمَةِ رَبِّكَ فَحَدِّثْ", "But as for the favour of your Lord, report it.", "Ad-Duha 93:11"),
        Verse("فَبِأَيِّ آلَاءِ رَبِّكُمَا تُكَذِّبَانِ", "So which of the favours of your Lord would you deny?", "Ar-Rahman 55:13"),
        Verse("وَمَن يَشْكُرْ فَإِنَّمَا يَشْكُرُ لِنَفْسِهِ", "And whoever is grateful is grateful for the benefit of himself.", "Luqman 31:12"),
        Verse("هَلْ جَزَاءُ الْإِحْسَانِ إِلَّا الْإِحْسَانُ", "Is the reward for good anything but good?", "Ar-Rahman 55:60"),
        Verse("الْحَمْدُ لِلَّهِ الَّذِي هَدَانَا لِهَٰذَا", "Praise to Allah, who has guided us to this.", "Al-A'raf 7:43"),
        Verse("وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ", "And your Lord is going to give you, and you will be satisfied.", "Ad-Duha 93:5"),
        Verse("ادْعُونِي أَسْتَجِبْ لَكُمْ", "Call upon Me; I will respond to you.", "Ghafir 40:60"),
        Verse("رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ", "Our Lord, give us good in this world and good in the Hereafter, and protect us from the Fire.", "Al-Baqarah 2:201"),
        Verse("فَاللَّهُ خَيْرٌ حَافِظًا ۖ وَهُوَ أَرْحَمُ الرَّاحِمِينَ", "Allah is the best guardian, and He is the most merciful of the merciful.", "Yusuf 12:64"),
        Verse("إِنَّ اللَّهَ يُحِبُّ الْمُحْسِنِينَ", "Indeed, Allah loves the doers of good.", "Al-Baqarah 2:195"),
        Verse("وَقُولُوا لِلنَّاسِ حُسْنًا", "And speak to people good words.", "Al-Baqarah 2:83"),
        Verse("وَتَعَاوَنُوا عَلَى الْبِرِّ وَالتَّقْوَىٰ", "And help one another in righteousness and piety.", "Al-Ma'idah 5:2"),
        Verse("وَاذْكُر رَّبَّكَ فِي نَفْسِكَ تَضَرُّعًا وَخِيفَةً", "And remember your Lord within yourself, in humility and in awe.", "Al-A'raf 7:205"),
        Verse("إِنَّ الصَّلَاةَ تَنْهَىٰ عَنِ الْفَحْشَاءِ وَالْمُنكَرِ ۗ وَلَذِكْرُ اللَّهِ أَكْبَرُ", "Prayer restrains from shameful and wrong deeds, and the remembrance of Allah is greater.", "Al-Ankabut 29:45"),
        Verse("إِنَّ اللَّهَ لَا يُغَيِّرُ مَا بِقَوْمٍ حَتَّىٰ يُغَيِّرُوا مَا بِأَنفُسِهِمْ", "Allah does not change the condition of a people until they change what is in themselves.", "Ar-Ra'd 13:11"),
        Verse("وَلَا تَهِنُوا وَلَا تَحْزَنُوا وَأَنتُمُ الْأَعْلَوْنَ إِن كُنتُم مُّؤْمِنِينَ", "Do not weaken and do not grieve, for you will be superior if you are believers.", "Al Imran 3:139"),
        Verse("وَمَا تَوْفِيقِي إِلَّا بِاللَّهِ ۚ عَلَيْهِ تَوَكَّلْتُ وَإِلَيْهِ أُنِيبُ", "My success is only through Allah. Upon Him I rely, and to Him I return.", "Hud 11:88"),
        Verse("إِنَّمَا الْمُؤْمِنُونَ إِخْوَةٌ", "The believers are but brothers.", "Al-Hujurat 49:10"),
        Verse("وَلَا تَمْشِ فِي الْأَرْضِ مَرَحًا", "And do not walk upon the earth in arrogance.", "Al-Isra 17:37"),
        Verse("وَقُولُوا قَوْلًا سَدِيدًا", "And speak words of appropriate justice.", "Al-Ahzab 33:70"),
        Verse("إِنَّ اللَّهَ مَعَ الَّذِينَ اتَّقَوا وَّالَّذِينَ هُم مُّحْسِنُونَ", "Indeed, Allah is with those who are mindful of Him and those who do good.", "An-Nahl 16:128"),
        Verse("وَإِن تَعُدُّوا نِعْمَةَ اللَّهِ لَا تُحْصُوهَا", "And if you should count the favours of Allah, you could not enumerate them.", "An-Nahl 16:18"),
        Verse("وَالْعَصْرِ ۝ إِنَّ الْإِنسَانَ لَفِي خُسْرٍ", "By time, indeed mankind is in loss.", "Al-Asr 103:1-2"),
        Verse("إِنَّ اللَّهَ يَأْمُرُ بِالْعَدْلِ وَالْإِحْسَانِ", "Indeed, Allah commands justice and good conduct.", "An-Nahl 16:90"),
        Verse("وَمَا خَلَقْتُ الْجِنَّ وَالْإِنسَ إِلَّا لِيَعْبُدُونِ", "I did not create jinn and mankind except to worship Me.", "Adh-Dhariyat 51:56"),
        Verse("كُلُّ نَفْسٍ ذَائِقَةُ الْمَوْتِ", "Every soul will taste death.", "Al Imran 3:185"),
        Verse("وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ", "Perhaps you dislike a thing and it is good for you.", "Al-Baqarah 2:216"),
        Verse("إِنَّ اللَّهَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ", "Indeed, Allah is over all things competent.", "Al-Baqarah 2:20"),
        Verse("رَبِّ اشْرَحْ لِي صَدْرِي ۝ وَيَسِّرْ لِي أَمْرِي", "My Lord, expand for me my chest, and ease for me my task.", "Ta-Ha 20:25-26"),
        Verse("وَهُوَ الَّذِي يُنَزِّلُ الْغَيْثَ مِن بَعْدِ مَا قَنَطُوا", "It is He who sends down the rain after they had despaired.", "Ash-Shura 42:28"),
        Verse("وَأَقِمِ الصَّلَاةَ لِذِكْرِي", "And establish prayer for My remembrance.", "Ta-Ha 20:14"),
        Verse("وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ", "And seek help through patience and prayer.", "Al-Baqarah 2:45"),
        Verse("إِنَّ اللَّهَ لَا يُخْلِفُ الْمِيعَادَ", "Indeed, Allah does not fail in His promise.", "Al Imran 3:9"),
        Verse("وَاللَّهُ يُحِبُّ الصَّابِرِينَ", "And Allah loves the steadfast.", "Al Imran 3:146"),
        Verse("إِنَّ اللَّهَ لَا يَظْلِمُ النَّاسَ شَيْئًا", "Indeed, Allah does not wrong the people at all.", "Yunus 10:44"),
        Verse("لَا تَقْنَطُوا مِن رَّحْمَةِ اللَّهِ ۚ إِنَّ اللَّهَ يَغْفِرُ الذُّنُوبَ جَمِيعًا", "Do not despair of the mercy of Allah. Indeed, Allah forgives all sins.", "Az-Zumar 39:53"),
        Verse("وَإِذَا سَأَلَكَ عِبَادِي عَنِّي فَإِنِّي قَرِيبٌ", "And when My servants ask you about Me, indeed I am near.", "Al-Baqarah 2:186"),
        Verse("فَصَبْرٌ جَمِيلٌ ۖ وَاللَّهُ الْمُسْتَعَانُ", "So patience is most fitting, and Allah is the one sought for help.", "Yusuf 12:18"),
        Verse("وَإِنَّكَ لَعَلَىٰ خُلُقٍ عَظِيمٍ", "And indeed, you are of a great moral character.", "Al-Qalam 68:4"),
        Verse("وَمَا أَرْسَلْنَاكَ إِلَّا رَحْمَةً لِّلْعَالَمِينَ", "And We have not sent you except as a mercy to the worlds.", "Al-Anbiya 21:107"),
        Verse("إِنَّ أَكْرَمَكُمْ عِندَ اللَّهِ أَتْقَاكُمْ", "Indeed, the most noble of you in the sight of Allah is the most mindful of Him.", "Al-Hujurat 49:13"),
        Verse("فَمَن يَعْمَلْ مِثْقَالَ ذَرَّةٍ خَيْرًا يَرَهُ", "Whoever does an atom's weight of good will see it.", "Az-Zalzalah 99:7"),
        Verse("وَتُوبُوا إِلَى اللَّهِ جَمِيعًا أَيُّهَ الْمُؤْمِنُونَ لَعَلَّكُمْ تُفْلِحُونَ", "And turn to Allah in repentance, all of you, O believers, that you might succeed.", "An-Nur 24:31"),
        Verse("الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ", "All praise is due to Allah, Lord of the worlds.", "Al-Fatihah 1:2"),
        Verse("إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ", "You alone we worship, and You alone we ask for help.", "Al-Fatihah 1:5"),
        Verse("وَاللَّهُ مَعَ الصَّابِرِينَ", "And Allah is with the steadfast.", "Al-Baqarah 2:249"),
        Verse("وَتَوَكَّلْ عَلَى الْحَيِّ الَّذِي لَا يَمُوتُ", "And rely upon the Ever-Living who does not die.", "Al-Furqan 25:58"),
        Verse("إِنَّ رَبِّي قَرِيبٌ مُّجِيبٌ", "Indeed, my Lord is near and responsive.", "Hud 11:61"),
        Verse("وَاصْبِرْ لِحُكْمِ رَبِّكَ فَإِنَّكَ بِأَعْيُنِنَا", "And be patient for the decision of your Lord, for you are in Our eyes.", "At-Tur 52:48"),
        Verse("رَبَّنَا تَقَبَّلْ مِنَّا ۖ إِنَّكَ أَنتَ السَّمِيعُ الْعَلِيمُ", "Our Lord, accept this from us. Indeed You are the Hearing, the Knowing.", "Al-Baqarah 2:127"),
        Verse("إِنَّ اللَّهَ يُدَافِعُ عَنِ الَّذِينَ آمَنُوا", "Indeed, Allah defends those who have believed.", "Al-Hajj 22:38"),
        Verse("وَاللَّهُ غَالِبٌ عَلَىٰ أَمْرِهِ", "And Allah is predominant over His affair.", "Yusuf 12:21"),
        Verse("وَمَا عِندَ اللَّهِ خَيْرٌ وَأَبْقَىٰ", "And what is with Allah is better and more lasting.", "Al-Qasas 28:60"),
        Verse("وَاصْبِرْ فَإِنَّ اللَّهَ لَا يُضِيعُ أَجْرَ الْمُحْسِنِينَ", "And be patient, for indeed Allah does not let the reward of the doers of good go to waste.", "Hud 11:115"),
    )

    /**
     * A new verse every twelve hours, one for the morning and one for the
     * evening, round the list and again. Counted from 1 January 2026 so the
     * sequence is the same on every phone.
     */
    fun forDay(now: Date = Date()): Verse {
        val cal = Calendar.getInstance()
        cal.time = now
        val half = if (cal.get(Calendar.HOUR_OF_DAY) >= 12) 1 else 0
        val slot = daysSinceEpoch(now) * 2 + half
        return all[((slot % all.size) + all.size) % all.size]
    }
}

/**
 * Whole days from 1 January 2026 to the given moment, in the phone's own
 * time zone.
 *
 * Deliberately not `millis / 86_400_000`: that counts UTC days, so for
 * anyone east or west of London the verse and the name would turn over in
 * the middle of the afternoon or the middle of the night.
 */
internal fun daysSinceEpoch(now: Date): Int {
    val cal = Calendar.getInstance()
    cal.time = now
    val today = startOfDay(cal)
    cal.clear()
    cal.set(2026, Calendar.JANUARY, 1)
    val epoch = startOfDay(cal)
    return Math.round((today - epoch) / 86_400_000.0).toInt()
}

private fun startOfDay(cal: Calendar): Long {
    cal.set(Calendar.HOUR_OF_DAY, 0)
    cal.set(Calendar.MINUTE, 0)
    cal.set(Calendar.SECOND, 0)
    cal.set(Calendar.MILLISECOND, 0)
    return cal.timeInMillis
}
