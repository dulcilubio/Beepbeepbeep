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
    static let departedFadeSeconds: Double = 5

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
            previous: group(entries, in: start - size ..< start),
            current:  group(entries, in: start ..< start + size),
            next:     group(entries, in: start + size ..< start + 2 * size)
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
        let departed = opacity > 0 ? group(entries, in: start ..< start + size) : []

        return BannerContent(
            departed: departed,
            departedOpacity: opacity,
            current: group(entries, in: start + size ..< start + 2 * size),
            next:    group(entries, in: start + 2 * size ..< start + 3 * size)
        )
    }

    /// Entries starting inside `range`, in start order. Sources hand us their
    /// own order — Eventor gives page order — and a banner listing 11:23:53
    /// above 11:23:31 is read as a mistake by whoever is calling runners up.
    private static func group(_ entries: [StartEntry], in range: Range<Int>) -> [StartEntry] {
        entries
            .filter { $0.starts(in: range) }
            .sorted { ($0.startSeconds ?? 0, $0.name) < ($1.startSeconds ?? 0, $1.name) }
    }

    /// How many rows of each group fit, when the text is scaled up far enough
    /// that showing everything would leave the clock no room.
    /// The group that has not started yet wins the space.
    struct RowAllocation: Equatable {
        var departed = 0
        var current  = 0
        var next     = 0
        var hiddenCurrent = 0      // runners in focus that did not fit
    }

    static let maxDepartedRows = 3
    static let maxNextRows     = 3

    static func rowAllocation(
        fitting available: Int,
        departed: Int,
        current: Int,
        next: Int
    ) -> RowAllocation {
        var remaining = max(available, 1)

        let currentShown = min(current, remaining)
        remaining -= currentShown
        let nextShown = min(next, min(maxNextRows, remaining))
        remaining -= nextShown
        let departedShown = min(departed, min(maxDepartedRows, remaining))

        return RowAllocation(
            departed: departedShown,
            current: currentShown,
            next: nextShown,
            hiddenCurrent: current - currentShown
        )
    }

    // MARK: - Fitting a whole start group on screen

    /// Metrics per 1.0 of text scale, shared with the banner so the solver and
    /// the layout cannot drift apart.
    static let rowHeightUnit:    Double = 23.5
    static let columnWidthUnit:  Double = 300
    static let bannerChromeUnit: Double = 40
    static let minBannerScale:   Double = 0.45
    static let maxBannerColumns = 3

    /// How to lay the group that is starting out so that every one of them is
    /// on screen. A mass start can put thirty runners in one minute, and a
    /// start crew calling names cannot use "+27 more" — so the banner widens
    /// into columns first, keeping the chosen text size, and only then shrinks
    /// the text. Below `minBannerScale` nothing is readable at a distance, so
    /// that is where it stops.
    struct BannerFit: Equatable {
        var columns = 1
        var rowsPerColumn = 0
        var scale: Double = 1
        /// False once the group needs the whole banner to itself.
        var showsContext = true
        var hidden = 0
    }

    /// Rows of names that fit in `availableHeight` at `scale`.
    static func rowsThatFit(height: Double, scale: Double) -> Int {
        max(0, Int(floor((height - bannerChromeUnit * scale) / (rowHeightUnit * scale))))
    }

    static func fit(
        currentCount: Int,
        requestedScale: Double,
        availableHeight: Double,
        availableWidth: Double
    ) -> BannerFit {
        func rows(at scale: Double, reserving extraRows: Int) -> Int {
            let usable = availableHeight - bannerChromeUnit * scale
            let fitting = Int(floor(usable / (rowHeightUnit * scale))) - extraRows
            return max(fitting, 0)
        }
        func columns(at scale: Double) -> Int {
            let fitting = Int(floor(availableWidth / (columnWidthUnit * scale)))
            return max(1, min(maxBannerColumns, fitting))
        }

        guard currentCount > 0 else {
            return BannerFit(rowsPerColumn: 0, scale: requestedScale)
        }

        // 1. The starting group fits in one column at the chosen size. The
        //    groups before and after share whatever is left — they are trimmed
        //    row by row, never dropped as a block.
        if currentCount <= rows(at: requestedScale, reserving: 0) {
            return BannerFit(rowsPerColumn: currentCount, scale: requestedScale)
        }

        // 2. The banner belongs to the starting group alone: add columns first,
        //    give up text size only when the width is spent.
        var scale = requestedScale
        while scale >= minBannerScale - 0.0001 {
            let rowCount = rows(at: scale, reserving: 0)
            if rowCount > 0 {
                for columnCount in 1...columns(at: scale) where rowCount * columnCount >= currentCount {
                    return BannerFit(
                        columns: columnCount,
                        rowsPerColumn: Int(ceil(Double(currentCount) / Double(columnCount))),
                        scale: scale,
                        showsContext: false
                    )
                }
            }
            scale -= 0.05
        }

        // 3. Smallest readable text, every column in use — only now is anyone
        //    left out, and the banner says how many.
        let rowCount = max(rows(at: minBannerScale, reserving: 0), 1)
        let columnCount = columns(at: minBannerScale)
        return BannerFit(
            columns: columnCount,
            rowsPerColumn: rowCount,
            scale: minBannerScale,
            showsContext: false,
            hidden: max(0, currentCount - rowCount * columnCount)
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
