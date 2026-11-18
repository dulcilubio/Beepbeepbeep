import Foundation

/// Which highlight the clock should use for the current instant.
/// Resolved once per tick so the colour and the beeps can never disagree.
enum ClockHighlight {
    case none      // ordinary tick
    case warning   // within 5 s before a start
    case go        // exactly on a start
}

/// The scheduling rules behind the clock: which runners belong to which
/// interval window, and what this very second means. Pure and free of SwiftUI
/// so it can be tested directly — this is the logic that decides when a start
/// is signalled, so it is the last place to find out something is wrong.
enum StartSchedule {
    /// Window size used in Auto mode, where the list itself sets the starts.
    static let autoWindowSeconds = 60
    /// How long before a start the countdown runs.
    static let countdownSeconds = 5

    /// Entries grouped into the previous, current and next interval window.
    static func windows(
        entries: [StartEntry],
        secondsFromMidnight: Int,
        interval: Int
    ) -> (previous: [StartEntry], current: [StartEntry], next: [StartEntry]) {
        guard !entries.isEmpty else { return ([], [], []) }

        let size  = interval > 0 ? interval : autoWindowSeconds
        let start = Int((Double(secondsFromMidnight) / Double(size)).rounded(.down)) * size

        func window(_ lower: Int, _ upper: Int) -> [StartEntry] {
            entries.filter { entry in
                guard let s = entry.startSeconds else { return false }
                return s >= lower && s < upper
            }
        }

        return (
            previous: window(start - size, start),
            current:  window(start, start + size),
            next:     window(start + size, start + 2 * size)
        )
    }

    /// Fixed interval: derived from epoch seconds, so the grid is independent of
    /// the loaded list. Auto (0): derived from the actual start times.
    static func highlight(
        entries: [StartEntry],
        secondsFromMidnight: Int,
        epochSeconds: Int,
        interval: Int
    ) -> ClockHighlight {
        if interval > 0 {
            let position = epochSeconds % interval
            if position == 0 { return .go }
            return interval - position <= countdownSeconds ? .warning : .none
        }

        guard !entries.isEmpty else { return .none }
        var warning = false
        for entry in entries {
            guard let start = entry.startSeconds else { continue }
            let remaining = start - secondsFromMidnight
            // A start on this exact second outranks a countdown for a later one,
            // so keep scanning instead of returning on the first match.
            if remaining == 0 { return .go }
            if remaining > 0, remaining <= countdownSeconds { warning = true }
        }
        return warning ? .warning : .none
    }
}
