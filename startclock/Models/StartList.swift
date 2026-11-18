import Foundation

struct Competition: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let date: String?
    let organizer: String?
    let timediff: Int?  // hours offset from CET (0 for most Swedish competitions)
}

struct StartClass: Codable, Identifiable {
    let className: String
    var id: String { className }
}

// Raw entry decoded from getclassresults
struct StartEntry: Codable, Equatable {
    let name: String
    let club: String?
    let start: Int?         // centiseconds from midnight (local competition timezone)
    let startnumber: String?
    var className: String = ""

    // Convenience: seconds from midnight
    var startSeconds: Int? { start.map { $0 / 100 } }

    /// Starts almost always fall on a whole minute, where the seconds are just
    /// noise — so the format is decided once per start list (see
    /// `usesSecondStarts`) and applied to every row, keeping the column aligned.
    func startTimeString(showSeconds: Bool) -> String {
        guard let s = startSeconds else { return showSeconds ? "--:--:--" : "--:--" }
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return showSeconds
            ? String(format: "%02d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", h, m)
    }

    enum CodingKeys: String, CodingKey {
        case name, club, start, startnumber
    }
}

struct CompetitionsResponse: Codable {
    // No "status" key in getcompetitions — only "competitions"
    let competitions: [Competition]
}

struct ClassesResponse: Codable {
    let status: String
    let classes: [StartClass]
}

struct ClassResultsResponse: Codable {
    let status: String
    let results: [StartEntry]?
    let hash: String?
}

struct StatusResponse: Codable {
    let status: String
}

extension Collection where Element == StartEntry {
    /// True when at least one start does not land on a whole minute — i.e. the
    /// competition uses second-level starts and the banner must show seconds.
    /// `start` is centiseconds from midnight, so a whole minute is a multiple of 6000.
    var usesSecondStarts: Bool {
        contains { ($0.start ?? 0) % 6000 != 0 }
    }
}
