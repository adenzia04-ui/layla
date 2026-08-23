import AppIntents
import WidgetKit

/// Calculation settings, chosen in the widget's own edit sheet.
///
/// Long-press a widget → Edit Widget. This is how the widget learns which
/// method you use *without any shared storage* — the free Apple account cannot
/// use App Groups, so the app has no way to hand settings across. Making it a
/// widget configuration turns that constraint into an ordinary iOS pattern.
///
/// Keep the cases in step with `CalcMethod` in
/// lib/features/prayer_times/domain/prayer_settings.dart.
enum WidgetCalcMethod: String, AppEnum {
    case muslimWorldLeague
    case karachi
    case ummAlQura
    case egyptian
    case northAmerica
    case dubai
    case qatar
    case kuwait
    case singapore
    case turkey
    case moonsighting

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Calculation Method"
    }

    static var caseDisplayRepresentations:
        [WidgetCalcMethod: DisplayRepresentation] {
        [
            .muslimWorldLeague: "Muslim World League",
            .karachi: "Karachi",
            .ummAlQura: "Umm al-Qura, Makkah",
            .egyptian: "Egyptian Authority",
            .northAmerica: "ISNA (North America)",
            .dubai: "Dubai",
            .qatar: "Qatar",
            .kuwait: "Kuwait",
            .singapore: "Singapore",
            .turkey: "Diyanet (Turkey)",
            .moonsighting: "Moonsighting Committee",
        ]
    }

    var parameters: CalculationParameters {
        switch self {
        case .muslimWorldLeague: return CalculationMethod.muslimWorldLeague.params
        case .karachi: return CalculationMethod.karachi.params
        case .ummAlQura: return CalculationMethod.ummAlQura.params
        case .egyptian: return CalculationMethod.egyptian.params
        case .northAmerica: return CalculationMethod.northAmerica.params
        case .dubai: return CalculationMethod.dubai.params
        case .qatar: return CalculationMethod.qatar.params
        case .kuwait: return CalculationMethod.kuwait.params
        case .singapore: return CalculationMethod.singapore.params
        case .turkey: return CalculationMethod.turkey.params
        case .moonsighting: return CalculationMethod.moonsightingCommittee.params
        }
    }
}

enum WidgetMadhab: String, AppEnum {
    case shafi
    case hanafi

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Asr Calculation"
    }

    static var caseDisplayRepresentations: [WidgetMadhab: DisplayRepresentation] {
        [
            .shafi: "Shafi, Maliki, Hanbali",
            .hanafi: "Hanafi",
        ]
    }

    var madhab: Madhab { self == .hanafi ? .hanafi : .shafi }
}

struct NoorWidgetConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Prayer Settings" }
    static var description: IntentDescription {
        IntentDescription("Match these to Prayer Settings inside Noor.")
    }

    @Parameter(title: "Calculation method", default: .muslimWorldLeague)
    var method: WidgetCalcMethod

    @Parameter(title: "Asr calculation", default: .shafi)
    var madhab: WidgetMadhab

    /// Builds the parameters Adhan needs.
    var calculationParameters: CalculationParameters {
        var params = method.parameters
        params.madhab = madhab.madhab
        return params
    }
}
