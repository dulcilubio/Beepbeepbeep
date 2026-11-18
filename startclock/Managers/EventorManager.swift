import Foundation

struct StartListSource: Identifiable, Hashable {
    let id: String
    let name: String
    let startURL: URL
    let eventPagePattern: String  // regex matching any page that represents a selectable event

    static let all: [StartListSource] = [
        StartListSource(
            id: "eventor.se",
            name: "Eventor SE",
            startURL: URL(string: "https://eventor.se/events")!,
            // matches /event/123, /event/123/start-list, /Events/StartList?..., /Events/Show/...
            eventPagePattern: #"eventor\.se/(event/\d+|Events/(StartList|Show))"#
        ),
        StartListSource(
            id: "eventor.sport",
            name: "Eventor World",
            startURL: URL(string: "https://eventor.orienteering.sport/events")!,
            eventPagePattern: #"eventor\.orienteering\.sport/(event/\d+|Events/(StartList|Show))"#
        ),
    ]
}

struct OfflineStartList: Codable, Equatable {
    var name: String
    var importedAt: Date
    var entries: [StartEntry]
}

@MainActor
class EventorManager: ObservableObject {
    @Published var importedList: OfflineStartList? {
        didSet { refreshUsesSecondStarts() }
    }
    /// Whether this start list uses second-level starts.
    @Published private(set) var usesSecondStarts = false
    @Published var isLoading = false
    @Published var error: String?
    /// Set when a background refresh could not produce a usable list — the old
    /// list is kept, but the user is told it may be out of date.
    @Published private(set) var lastRefreshFailed = false

    /// Empty set = all classes; otherwise the classes to show.
    @Published var classFilters: Set<String> = EventorManager.loadClassFilters() {
        didSet {
            UserDefaults.standard.set(classFilters.sorted(), forKey: Self.classFiltersKey)
            refreshUsesSecondStarts()
        }
    }

    private static let listKey         = "eventorOfflineList"
    private static let urlKey          = "eventorURL"
    private static let classFiltersKey = "eventorClassFilters"
    private static let legacyClassFilterKey = "eventorClassFilter"
    private static let pollInterval: Double = 5 * 60

    private(set) var savedURL: String = UserDefaults.standard.string(forKey: EventorManager.urlKey) ?? ""
    private var pollTask: Task<Void, Never>?

    var hasActiveList: Bool { importedList != nil }

    /// Every class present in the imported list, sorted, blanks excluded.
    var availableClasses: [String] {
        Array(Set((importedList?.entries ?? []).map(\.className)))
            .filter { !$0.isEmpty }
            .sorted()
    }

    /// The imported entries after applying `classFilters`.
    var filteredEntries: [StartEntry] {
        let all = importedList?.entries ?? []
        guard !classFilters.isEmpty else { return all }
        return all.filter { classFilters.contains($0.className) }
    }

    var classFilterLabel: String {
        switch classFilters.count {
        case 0:  return "All classes"
        case 1:  return classFilters.first ?? "All classes"
        default: return "\(classFilters.count) classes"
        }
    }

    /// Reads the saved selection, migrating the pre-multi-select single class.
    private static func loadClassFilters() -> Set<String> {
        let defaults = UserDefaults.standard
        if let saved = defaults.array(forKey: classFiltersKey) as? [String] {
            return Set(saved)
        }
        if let legacy = defaults.string(forKey: legacyClassFilterKey), !legacy.isEmpty {
            return [legacy]
        }
        return []
    }

    var detectedInterval: Int? {
        let secs = filteredEntries.compactMap(\.startSeconds).sorted()
        guard secs.count > 2 else { return nil }
        var gaps: [Int] = []
        for i in 1..<secs.count {
            let g = secs[i] - secs[i-1]
            if g > 0, g <= 300 { gaps.append(g) }
        }
        guard !gaps.isEmpty else { return nil }
        return Dictionary(gaps.map { ($0, 1) }, uniquingKeysWith: +)
            .max(by: { $0.value < $1.value })?.key
    }

    init() {
        load()
        refreshUsesSecondStarts()   // property observers don't fire during init
        if hasActiveList && !savedURL.isEmpty {
            Task { await silentRefresh() }
            startPolling()
        }
    }

    func refreshNow() {
        guard !savedURL.isEmpty else { return }
        Task { await fetchAndParse(urlString: savedURL) }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.listKey),
              let list = try? JSONDecoder().decode(OfflineStartList.self, from: data)
        else { return }
        importedList = list
    }

    private func persist() {
        guard let list = importedList,
              let data = try? JSONEncoder().encode(list)
        else { return }
        UserDefaults.standard.set(data, forKey: Self.listKey)
    }

    func clearList() {
        importedList = nil
        savedURL = ""
        classFilters = []
        lastRefreshFailed = false
        UserDefaults.standard.removeObject(forKey: Self.listKey)
        UserDefaults.standard.removeObject(forKey: Self.urlKey)
        UserDefaults.standard.removeObject(forKey: Self.classFiltersKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyClassFilterKey)
        pollTask?.cancel()
        pollTask = nil
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.pollInterval))
                guard !Task.isCancelled, !savedURL.isEmpty else { return }
                await silentRefresh()
            }
        }
    }

    /// Background poll. The saved URL is fetched as plain HTML, which only works
    /// for server-rendered Eventor pages — a list imported from a script-rendered
    /// page will not refresh this way. Rather than failing silently, flag it so
    /// Settings can warn that the list may be stale.
    private func silentRefresh() async {
        guard !savedURL.isEmpty, let url = URL(string: savedURL) else {
            lastRefreshFailed = true
            return
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8) else {
            lastRefreshFailed = true
            return
        }
        var name = importedList?.name ?? "Eventor"
        let entries = Self.parseStartList(html: html, name: &name)
        guard Self.acceptsRefresh(entries, replacing: importedList?.entries ?? []) else {
            lastRefreshFailed = true
            return
        }
        importedList = OfflineStartList(name: name, importedAt: Date(), entries: entries)
        pruneClassFilter()
        lastRefreshFailed = false
        persist()
    }

    private func refreshUsesSecondStarts() {
        usesSecondStarts = filteredEntries.usesSecondStarts
    }

    /// Whether a background refresh is an improvement on what is already loaded.
    ///
    /// The browser import reads the rendered page and comes back with class
    /// names; the plain HTML fetch behind the five-minute poll can parse the
    /// same event into fewer runners and no classes at all. Replacing a good
    /// list with that is not news, it is a worse parse — and the class column
    /// vanishing mid-competition is exactly how it shows up at a start.
    nonisolated static func acceptsRefresh(
        _ refreshed: [StartEntry],
        replacing current: [StartEntry]
    ) -> Bool {
        guard !refreshed.isEmpty else { return false }
        guard !current.isEmpty else { return true }
        guard refreshed.count >= current.count else { return false }

        let hadClasses = current.contains { !$0.className.isEmpty }
        let hasClasses = refreshed.contains { !$0.className.isEmpty }
        return !(hadClasses && !hasClasses)
    }

    /// Drops selected classes that no longer exist in the current list.
    private func pruneClassFilter() {
        guard !classFilters.isEmpty else { return }
        let pruned = classFilters.intersection(availableClasses)
        if pruned != classFilters { classFilters = pruned }
    }

    /// Import from the JS DOM extraction result (browser flow).
    /// `json` is {"name":"…","entries":[{"time":"…","name":"…","club":"…","className":"…"}]}
    func importFromBrowser(url: String, json: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        struct Payload: Decodable {
            let name: String
            let entries: [JSEntry]
        }
        struct JSEntry: Decodable {
            let time: String
            let name: String
            let club: String
            let className: String
        }

        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            self.error = "Failed to read extracted data."
            return
        }

        print("[Eventor] importFromBrowser entries:", payload.entries.count)

        let entries: [StartEntry] = payload.entries.compactMap { e in
            guard let cs = Self.timeToCentisecs(e.time) else { return nil }
            var entry = StartEntry(name: e.name, club: e.club.isEmpty ? nil : e.club, start: cs, startnumber: nil)
            entry.className = e.className
            return entry
        }

        guard !entries.isEmpty else {
            self.error = "No valid start entries found — make sure the start list is visible on screen."
            return
        }

        var refreshURL = url
        if let q = refreshURL.firstIndex(of: "?") { refreshURL = String(refreshURL[..<q]) }
        refreshURL = refreshURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !refreshURL.hasSuffix("start-list") { refreshURL += "/start-list" }

        savedURL = refreshURL
        UserDefaults.standard.set(savedURL, forKey: Self.urlKey)
        importedList = OfflineStartList(name: payload.name, importedAt: Date(), entries: entries)
        pruneClassFilter()
        lastRefreshFailed = false
        persist()
        startPolling()
    }

    func fetchAndParse(urlString: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // Strip query string and fragment — server renders all classes without params
        var stripped = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let q = stripped.firstIndex(of: "?") { stripped = String(stripped[..<q]) }
        if let h = stripped.firstIndex(of: "#") { stripped = String(stripped[..<h]) }
        var normalized = stripped.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !normalized.hasSuffix("start-list") {
            normalized += "/start-list"
        }

        guard let url = URL(string: normalized) else {
            self.error = "Invalid URL"
            return
        }

        do {
            var request = URLRequest(url: url, timeoutInterval: 30)
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                forHTTPHeaderField: "User-Agent"
            )
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                self.error = "Invalid page encoding"
                return
            }

            var name = "Eventor"
            let entries = Self.parseStartList(html: html, name: &name)

            guard !entries.isEmpty else {
                self.error = "No start entries found — make sure this is an Eventor start list URL."
                lastRefreshFailed = importedList != nil
                return
            }

            savedURL = normalized
            UserDefaults.standard.set(normalized, forKey: Self.urlKey)
            importedList = OfflineStartList(name: name, importedAt: Date(), entries: entries)
            pruneClassFilter()
            lastRefreshFailed = false
            persist()
            startPolling()
        } catch {
            self.error = error.localizedDescription
            lastRefreshFailed = importedList != nil
        }
    }

    // MARK: - HTML parsing

    /// Internal and nonisolated so the HTML parsing can be tested directly.
    nonisolated static func parseStartList(html: String, name: inout String) -> [StartEntry] {
        // Extract <title>
        if let m = try? NSRegularExpression(pattern: "<title>([^<]+)</title>", options: .caseInsensitive)
            .firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let r = Range(m.range(at: 1), in: html) {
            name = stripTags(String(html[r])).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let timeRegex = try! NSRegularExpression(pattern: #"^\d{1,2}:\d{2}(:\d{2})?$"#)
        let headingRegex = try! NSRegularExpression(
            pattern: #"<h[1-6][^>]*>(.*?)</h[1-6]>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
        let rowRegex = try! NSRegularExpression(
            pattern: #"<tr[^>]*>(.*?)</tr>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )

        struct Event {
            let pos: Int
            let isHeading: Bool
            let content: String
        }

        let full = NSRange(html.startIndex..., in: html)
        var events: [Event] = []

        for m in headingRegex.matches(in: html, range: full) {
            if let r = Range(m.range(at: 1), in: html) {
                events.append(Event(pos: m.range.location, isHeading: true, content: String(html[r])))
            }
        }
        for m in rowRegex.matches(in: html, range: full) {
            if let r = Range(m.range(at: 1), in: html) {
                events.append(Event(pos: m.range.location, isHeading: false, content: String(html[r])))
            }
        }
        events.sort { $0.pos < $1.pos }

        var entries: [StartEntry] = []
        var currentClass = ""

        for event in events {
            if event.isHeading {
                let text = stripTags(event.content).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty, text.count < 80 { currentClass = text }
                continue
            }

            // Skip header rows (<th> cells)
            if event.content.lowercased().contains("<th") { continue }

            let cells = extractCells(from: event.content)
            guard !cells.isEmpty else { continue }

            var startCs: Int? = nil
            var others: [String] = []

            for cell in cells {
                let t = cell.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { continue }
                if startCs == nil,
                   timeRegex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil {
                    startCs = timeToCentisecs(t)
                } else if !t.allSatisfy(\.isNumber) {
                    others.append(t)
                }
            }

            guard let start = startCs, !others.isEmpty else { continue }

            var entry = StartEntry(
                name: others[0],
                club: others.count > 1 ? others[1] : nil,
                start: start,
                startnumber: nil
            )
            entry.className = currentClass
            entries.append(entry)
        }

        return entries
    }

    nonisolated private static func extractCells(from rowHTML: String) -> [String] {
        let pattern = try! NSRegularExpression(
            pattern: #"<td[^>]*>(.*?)</td>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
        return pattern.matches(in: rowHTML, range: NSRange(rowHTML.startIndex..., in: rowHTML))
            .compactMap { m -> String? in
                guard let r = Range(m.range(at: 1), in: rowHTML) else { return nil }
                return stripTags(String(rowHTML[r]))
            }
    }

    nonisolated private static func stripTags(_ html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&nbsp;": " ", "&#160;": " ", "&apos;": "'", "&quot;": "\""
        ]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func timeToCentisecs(_ t: String) -> Int? {
        let parts = t.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        let h = parts[0], m = parts[1], s = parts.count > 2 ? parts[2] : 0
        guard h < 24, m < 60, s < 60 else { return nil }
        return (h * 3600 + m * 60 + s) * 100
    }
}
