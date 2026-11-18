import Foundation

/// The clock faces the user can pick from.
///
/// Raw values are the strings already written to AppStorage, so they must not
/// change — `ClockStyleTests` guards that.
enum ClockStyle: String, CaseIterable, Identifiable {
    case sfpro
    case sfCondensed
    case sfCompressed
    case newYork
    case courierNew
    case digital
    case flapBoard
    case analog
    case analogSeconds
    case hourOnly
    case minuteOnly
    case secondOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sfpro:         return "SF Pro"
        case .sfCondensed:   return "Condensed"
        case .sfCompressed:  return "Compressed"
        case .newYork:       return "New York"
        case .courierNew:    return "Courier New"
        case .digital:       return "Digital"
        case .flapBoard:     return "Flap Board"
        case .analog:        return "Analog"
        case .analogSeconds: return "Analog (seconds)"
        case .hourOnly:      return "Hour only"
        case .minuteOnly:    return "Minute only"
        case .secondOnly:    return "Second only"
        }
    }

    /// Faces drawn as artwork rather than text ignore the bold setting.
    var usesBold: Bool {
        switch self {
        case .digital, .flapBoard, .analog, .analogSeconds: return false
        default:                                            return true
        }
    }

    /// The analog faces need room in both directions; the rest are wide and short.
    var prefersSquarePreview: Bool {
        self == .analog || self == .analogSeconds
    }
}
