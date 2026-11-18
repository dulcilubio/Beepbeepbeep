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

    /// How long a departed group lingers, fading, before the banner belongs
    /// entirely to the runners who have not gone yet.
    static let departedFadeSeconds: Double = 8

    /// What the participant banner shows right now.
    struct BannerContent: Equatable {
        var departed: [StartEntry] = []     // already gone — fading out
        var departedOpacity: Double = 0
        var current: [StartEntry] = []      // the group in focus
        var next: [StartEntry] = []         // the one after that

        var isEmpty: Bool { departed.isEmpty && current.isEmpty && next.isEmpty }
    }

    /// Entries grouped into the previous, current and next interval window.
    static func windows(
        entries: [StartEntry],
        secondsFromMidnight: Int,
        interval: Int
    ) -> (previous: [StartEntry], current: [StartEntry], next: [StartEntry]) {
        guard !entries.isEmpty else { return ([], [], []) }

        let size  = windowSize(interval)
        let start = windowStart(secondsFromMidnight, size: size)

        return (
            previous: entries.filter { $0.starts(in: start - size ..< start) },
            current:  entries.filter { $0.starts(in: start ..< start + size) },
            next:     entries.filter { $0.starts(in: start + size ..< start + 2 * size) }
        )
    }

    /// With lead time on, the clock itself runs ahead, so the current window is
    /// the group being called forward and stays in focus for the whole minute.
    ///
    /// With lead time off, the clock shows real time: the moment a group's
    /// second passes they are running, and the banner belongs to the next
    /// group. The departed names linger briefly, fading, so the start crew can
    /// still check who went.
    static func banner(
        entries: [StartEntry],
        secondsFromMidnight: Int,
        interval: Int,
        leadTimeEnabled: Bool
    ) -> BannerContent {
        guard !entries.isEmpty else { return BannerContent() }

        let size  = windowSize(interval)
        let start = windowStart(secondsFromMidnight, size: size)

        if leadTimeEnabled {
            let w = windows(entries: entries, secondsFromMidnight: secondsFromMidnight, interval: interval)
            return BannerContent(
                departed: w.previous,
                departedOpacity: 0.38,
                current: w.current,
                next: w.next
            )
        }

        let elapsed  = Double(secondsFromMidnight - start)
        let progress = min(max(elapsed / departedFadeSeconds, 0), 1)
        let opacity  = 0.7 * (1 - progress)
        let departed = opacity > 0 ? entries.filter { $0.starts(in: start ..< start + size) } : []

        return BannerContent(
            departed: departed,
            departedOpacity: opacity,
            current: entries.filter { $0.starts(in: start + size ..< start + 2 * size) },
            next:    entries.filter { $0.starts(in: start + 2 * size ..< start + 3 * size) }
        )
    }

    private static func windowSize(_ interval: Int) -> Int {
        interval > 0 ? interval : autoWindowSeconds
    }

    private static func windowStart(_ seconds: Int, size: Int) -> Int {
        Int((Double(seconds) / Double(size)).rounded(.down)) * size
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

private extension StartEntry {
    func starts(in range: Range<Int>) -> Bool {
        guard let start = startSeconds else { return false }
        return range.contains(start)
    }
}
