import SwiftUI
import WidgetKit

/// One of the ninety-nine, as the widget shows it. The same list and the same
/// day-by-day rotation as the app (lib/features/soul/domain/names_of_allah.dart),
/// so the widget and the Soul tab always agree on today's name.
struct DivineName {
    let arabic: String
    let transliteration: String
    let meaning: String

    static let all: [DivineName] = [
        DivineName(arabic: "الرَّحْمَنُ", transliteration: "Ar-Rahman", meaning: "The Most Merciful"),
        DivineName(arabic: "الرَّحِيمُ", transliteration: "Ar-Rahim", meaning: "The Especially Merciful"),
        DivineName(arabic: "الْمَلِكُ", transliteration: "Al-Malik", meaning: "The King"),
        DivineName(arabic: "الْقُدُّوسُ", transliteration: "Al-Quddus", meaning: "The Most Holy"),
        DivineName(arabic: "السَّلَامُ", transliteration: "As-Salam", meaning: "The Source of Peace"),
        DivineName(arabic: "الْمُؤْمِنُ", transliteration: "Al-Mu'min", meaning: "The Giver of Security"),
        DivineName(arabic: "الْمُهَيْمِنُ", transliteration: "Al-Muhaymin", meaning: "The Guardian over all"),
        DivineName(arabic: "الْعَزِيزُ", transliteration: "Al-'Aziz", meaning: "The Almighty"),
        DivineName(arabic: "الْجَبَّارُ", transliteration: "Al-Jabbar", meaning: "The Compeller, the Restorer"),
        DivineName(arabic: "الْمُتَكَبِّرُ", transliteration: "Al-Mutakabbir", meaning: "The Supreme in greatness"),
        DivineName(arabic: "الْخَالِقُ", transliteration: "Al-Khaliq", meaning: "The Creator"),
        DivineName(arabic: "الْبَارِئُ", transliteration: "Al-Bari'", meaning: "The Maker from nothing"),
        DivineName(arabic: "الْمُصَوِّرُ", transliteration: "Al-Musawwir", meaning: "The Fashioner of forms"),
        DivineName(arabic: "الْغَفَّارُ", transliteration: "Al-Ghaffar", meaning: "The Ever-Forgiving"),
        DivineName(arabic: "الْقَهَّارُ", transliteration: "Al-Qahhar", meaning: "The Subduer"),
        DivineName(arabic: "الْوَهَّابُ", transliteration: "Al-Wahhab", meaning: "The Bestower"),
        DivineName(arabic: "الرَّزَّاقُ", transliteration: "Ar-Razzaq", meaning: "The Provider"),
        DivineName(arabic: "الْفَتَّاحُ", transliteration: "Al-Fattah", meaning: "The Opener, the Judge"),
        DivineName(arabic: "الْعَلِيمُ", transliteration: "Al-'Alim", meaning: "The All-Knowing"),
        DivineName(arabic: "الْقَابِضُ", transliteration: "Al-Qabid", meaning: "The Withholder"),
        DivineName(arabic: "الْبَاسِطُ", transliteration: "Al-Basit", meaning: "The Extender"),
        DivineName(arabic: "الْخَافِضُ", transliteration: "Al-Khafid", meaning: "The Abaser"),
        DivineName(arabic: "الرَّافِعُ", transliteration: "Ar-Rafi'", meaning: "The Exalter"),
        DivineName(arabic: "الْمُعِزُّ", transliteration: "Al-Mu'izz", meaning: "The Giver of honour"),
        DivineName(arabic: "الْمُذِلُّ", transliteration: "Al-Mudhill", meaning: "The Giver of dishonour"),
        DivineName(arabic: "السَّمِيعُ", transliteration: "As-Sami'", meaning: "The All-Hearing"),
        DivineName(arabic: "الْبَصِيرُ", transliteration: "Al-Basir", meaning: "The All-Seeing"),
        DivineName(arabic: "الْحَكَمُ", transliteration: "Al-Hakam", meaning: "The Judge"),
        DivineName(arabic: "الْعَدْلُ", transliteration: "Al-'Adl", meaning: "The Utterly Just"),
        DivineName(arabic: "اللَّطِيفُ", transliteration: "Al-Latif", meaning: "The Subtle, the Kind"),
        DivineName(arabic: "الْخَبِيرُ", transliteration: "Al-Khabir", meaning: "The All-Aware"),
        DivineName(arabic: "الْحَلِيمُ", transliteration: "Al-Halim", meaning: "The Forbearing"),
        DivineName(arabic: "الْعَظِيمُ", transliteration: "Al-'Azim", meaning: "The Magnificent"),
        DivineName(arabic: "الْغَفُورُ", transliteration: "Al-Ghafur", meaning: "The All-Forgiving"),
        DivineName(arabic: "الشَّكُورُ", transliteration: "Ash-Shakur", meaning: "The Appreciative"),
        DivineName(arabic: "الْعَلِيُّ", transliteration: "Al-'Aliyy", meaning: "The Most High"),
        DivineName(arabic: "الْكَبِيرُ", transliteration: "Al-Kabir", meaning: "The Most Great"),
        DivineName(arabic: "الْحَفِيظُ", transliteration: "Al-Hafiz", meaning: "The Preserver"),
        DivineName(arabic: "الْمُقِيتُ", transliteration: "Al-Muqit", meaning: "The Sustainer"),
        DivineName(arabic: "الْحَسِيبُ", transliteration: "Al-Hasib", meaning: "The Reckoner"),
        DivineName(arabic: "الْجَلِيلُ", transliteration: "Al-Jalil", meaning: "The Majestic"),
        DivineName(arabic: "الْكَرِيمُ", transliteration: "Al-Karim", meaning: "The Generous"),
        DivineName(arabic: "الرَّقِيبُ", transliteration: "Ar-Raqib", meaning: "The Watchful"),
        DivineName(arabic: "الْمُجِيبُ", transliteration: "Al-Mujib", meaning: "The Responsive"),
        DivineName(arabic: "الْوَاسِعُ", transliteration: "Al-Wasi'", meaning: "The All-Encompassing"),
        DivineName(arabic: "الْحَكِيمُ", transliteration: "Al-Hakim", meaning: "The All-Wise"),
        DivineName(arabic: "الْوَدُودُ", transliteration: "Al-Wadud", meaning: "The Loving"),
        DivineName(arabic: "الْمَجِيدُ", transliteration: "Al-Majid", meaning: "The Glorious"),
        DivineName(arabic: "الْبَاعِثُ", transliteration: "Al-Ba'ith", meaning: "The Resurrector"),
        DivineName(arabic: "الشَّهِيدُ", transliteration: "Ash-Shahid", meaning: "The Witness"),
        DivineName(arabic: "الْحَقُّ", transliteration: "Al-Haqq", meaning: "The Truth"),
        DivineName(arabic: "الْوَكِيلُ", transliteration: "Al-Wakil", meaning: "The Trustee"),
        DivineName(arabic: "الْقَوِيُّ", transliteration: "Al-Qawiyy", meaning: "The All-Strong"),
        DivineName(arabic: "الْمَتِينُ", transliteration: "Al-Matin", meaning: "The Firm"),
        DivineName(arabic: "الْوَلِيُّ", transliteration: "Al-Waliyy", meaning: "The Protecting Friend"),
        DivineName(arabic: "الْحَمِيدُ", transliteration: "Al-Hamid", meaning: "The Praiseworthy"),
        DivineName(arabic: "الْمُحْصِي", transliteration: "Al-Muhsi", meaning: "The Counter of all things"),
        DivineName(arabic: "الْمُبْدِئُ", transliteration: "Al-Mubdi'", meaning: "The Originator"),
        DivineName(arabic: "الْمُعِيدُ", transliteration: "Al-Mu'id", meaning: "The Restorer"),
        DivineName(arabic: "الْمُحْيِي", transliteration: "Al-Muhyi", meaning: "The Giver of life"),
        DivineName(arabic: "الْمُمِيتُ", transliteration: "Al-Mumit", meaning: "The Bringer of death"),
        DivineName(arabic: "الْحَيُّ", transliteration: "Al-Hayy", meaning: "The Ever-Living"),
        DivineName(arabic: "الْقَيُّومُ", transliteration: "Al-Qayyum", meaning: "The Sustainer of all"),
        DivineName(arabic: "الْوَاجِدُ", transliteration: "Al-Wajid", meaning: "The Finder"),
        DivineName(arabic: "الْمَاجِدُ", transliteration: "Al-Majid", meaning: "The Noble"),
        DivineName(arabic: "الْوَاحِدُ", transliteration: "Al-Wahid", meaning: "The One"),
        DivineName(arabic: "الْأَحَدُ", transliteration: "Al-Ahad", meaning: "The Unique"),
        DivineName(arabic: "الصَّمَدُ", transliteration: "As-Samad", meaning: "The Eternal Refuge"),
        DivineName(arabic: "الْقَادِرُ", transliteration: "Al-Qadir", meaning: "The Able"),
        DivineName(arabic: "الْمُقْتَدِرُ", transliteration: "Al-Muqtadir", meaning: "The Omnipotent"),
        DivineName(arabic: "الْمُقَدِّمُ", transliteration: "Al-Muqaddim", meaning: "The Bringer forward"),
        DivineName(arabic: "الْمُؤَخِّرُ", transliteration: "Al-Mu'akhkhir", meaning: "The Delayer"),
        DivineName(arabic: "الْأَوَّلُ", transliteration: "Al-Awwal", meaning: "The First"),
        DivineName(arabic: "الْآخِرُ", transliteration: "Al-Akhir", meaning: "The Last"),
        DivineName(arabic: "الظَّاهِرُ", transliteration: "Az-Zahir", meaning: "The Manifest"),
        DivineName(arabic: "الْبَاطِنُ", transliteration: "Al-Batin", meaning: "The Hidden"),
        DivineName(arabic: "الْوَالِي", transliteration: "Al-Wali", meaning: "The Governor"),
        DivineName(arabic: "الْمُتَعَالِي", transliteration: "Al-Muta'ali", meaning: "The Supremely Exalted"),
        DivineName(arabic: "الْبَرُّ", transliteration: "Al-Barr", meaning: "The Source of goodness"),
        DivineName(arabic: "التَّوَّابُ", transliteration: "At-Tawwab", meaning: "The Accepter of repentance"),
        DivineName(arabic: "الْمُنْتَقِمُ", transliteration: "Al-Muntaqim", meaning: "The Avenger"),
        DivineName(arabic: "الْعَفُوُّ", transliteration: "Al-'Afuww", meaning: "The Pardoner"),
        DivineName(arabic: "الرَّءُوفُ", transliteration: "Ar-Ra'uf", meaning: "The Kind"),
        DivineName(arabic: "مَالِكُ الْمُلْكِ", transliteration: "Malik al-Mulk", meaning: "Owner of all sovereignty"),
        DivineName(arabic: "ذُو الْجَلَالِ وَالْإِكْرَامِ", transliteration: "Dhul-Jalali wal-Ikram", meaning: "Lord of majesty and honour"),
        DivineName(arabic: "الْمُقْسِطُ", transliteration: "Al-Muqsit", meaning: "The Equitable"),
        DivineName(arabic: "الْجَامِعُ", transliteration: "Al-Jami'", meaning: "The Gatherer"),
        DivineName(arabic: "الْغَنِيُّ", transliteration: "Al-Ghaniyy", meaning: "The Self-Sufficient"),
        DivineName(arabic: "الْمُغْنِي", transliteration: "Al-Mughni", meaning: "The Enricher"),
        DivineName(arabic: "الْمَانِعُ", transliteration: "Al-Mani'", meaning: "The Preventer"),
        DivineName(arabic: "الضَّارُّ", transliteration: "Ad-Darr", meaning: "The Bringer of harm, by His wisdom"),
        DivineName(arabic: "النَّافِعُ", transliteration: "An-Nafi'", meaning: "The Bringer of benefit"),
        DivineName(arabic: "النُّورُ", transliteration: "An-Nur", meaning: "The Light"),
        DivineName(arabic: "الْهَادِي", transliteration: "Al-Hadi", meaning: "The Guide"),
        DivineName(arabic: "الْبَدِيعُ", transliteration: "Al-Badi'", meaning: "The Incomparable Originator"),
        DivineName(arabic: "الْبَاقِي", transliteration: "Al-Baqi", meaning: "The Everlasting"),
        DivineName(arabic: "الْوَارِثُ", transliteration: "Al-Warith", meaning: "The Inheritor of all"),
        DivineName(arabic: "الرَّشِيدُ", transliteration: "Ar-Rashid", meaning: "The Guide to the right way"),
        DivineName(arabic: "الصَّبُورُ", transliteration: "As-Sabur", meaning: "The Patient")
    ]

    /// The same name all day, the next tomorrow, round the list and again.
    /// Counted from 1 January 2026, as the app counts.
    static func forDay(_ date: Date) -> (name: DivineName, number: Int) {
        let cal = Calendar.current
        let epoch = cal.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? date
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: epoch), to: cal.startOfDay(for: date)).day ?? 0
        let index = ((days % all.count) + all.count) % all.count
        return (all[index], index + 1)
    }
}

struct NamesWidgetView: View {
    let entry: NoorEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let today = DivineName.forDay(entry.date)
        VStack(spacing: 0) {
            WidgetHeader(title: "Name of Allah", trailing: "\(today.number) of 99")
            Spacer(minLength: 4)
            Text(today.name.arabic)
                .font(.custom("Amiri Quran", size: family == .systemSmall ? 30 : 38))
                .foregroundStyle(Layl.goldSoft)
                .shadow(color: Layl.gold.opacity(0.45), radius: 10)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(today.name.transliteration)
                .font(Layl.display(family == .systemSmall ? 15 : 18, weight: .semibold))
                .foregroundStyle(Layl.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(today.name.meaning)
                .font(Layl.ui(family == .systemSmall ? 11 : 13))
                .foregroundStyle(Layl.mist)
                .lineLimit(family == .systemSmall ? 2 : 1)
                .multilineTextAlignment(.center)
            Spacer(minLength: 4)
        }
        .widgetURL(URL(string: "layla://names"))
    }
}

struct NamesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "LaylaNamesWidget",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            NamesWidgetView(entry: entry)
                .containerBackground(for: .widget) { NightBackground() }
        }
        .configurationDisplayName("Name of Allah")
        .description("One of the Ninety-Nine, a new one each day.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
