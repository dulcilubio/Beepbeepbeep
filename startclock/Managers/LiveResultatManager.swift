import Foundation

@MainActor
class LiveResultatManager: ObservableObject {
    private static let base = "https://liveresultat.orientering.se/api.php"
    private static let pollInterval: Double = 5 * 60  // 5 minutes

    @Published var competitions: [Competition] = []
    @Published var classes: [StartClass] = []
    @Published var startEntries: [StartEntry] = []
    @Published var isLoadingCompetitions = false
    @Published var isLoadingClasses = false
    @Published var isLoadingStartList = false
    @Published var error: String?

    // Persisted selection
    @Published private(set) var savedCompId: Int = UserDefaults.standard.integer(forKey: "lrCompId")
    @Published private(set) var savedCompName: String = UserDefaults.standard.string(forKey: "lrCompName") ?? ""
    // Empty set = all classes; otherwise the classes to load
    @Published private(set) var savedClassNames: Set<String> = LiveResultatManager.loadSavedClassNames()

    // Hash cache per className for efficient polling
    private var classHashes: [String: String] = [:]

    private var pollTask: Task<Void, Never>?

    @Published var lastUpdated: Date?
    /// Whether this competition starts runners at second precision.
    @Published private(set) var usesSecondStarts = false

    var hasActiveCompetition: Bool { savedCompId > 0 }

    var classFilterLabel: String {
        switch savedClassNames.count {
        case 0:  return "All classes"
        case 1:  return savedClassNames.first ?? "All classes"
        default: return "\(savedClassNames.count) classes"
        }
    }

    /// Reads the saved selection, migrating the pre-multi-select single class.
    private static func loadSavedClassNames() -> Set<String> {
        let defaults = UserDefaults.standard
        if let saved = defaults.array(forKey: "lrClassNames") as? [String] {
            return Set(saved)
        }
        if let legacy = defaults.string(forKey: "lrClassName"), !legacy.isEmpty {
            return [legacy]
        }
        return []
    }

    /// Most common gap (seconds) between consecutive start times. Nil if too few entries.
    var detectedInterval: Int? {
        let secs = startEntries.compactMap(\.startSeconds).sorted()
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
        if hasActiveCompetition {
            loadPersistedEntries()
            Task { await loadStartData() }
            startPolling()
        }
    }

    // MARK: - Selection

    func selectCompetition(id: Int, name: String, classNames: Set<String>) async {
        savedCompId = id
        savedCompName = name
        savedClassNames = classNames
        UserDefaults.standard.set(id, forKey: "lrCompId")
        UserDefaults.standard.set(name, forKey: "lrCompName")
        UserDefaults.standard.set(classNames.sorted(), forKey: "lrClassNames")
        UserDefaults.standard.removeObject(forKey: "lrClassName")
        classHashes.removeAll()
        startEntries = []
        classes = []
        startPolling()
        await loadStartData()
    }

    func clearSelection() {
        savedCompId = 0
        savedCompName = ""
        savedClassNames = []
        UserDefaults.standard.set(0, forKey: "lrCompId")
        UserDefaults.standard.set("", forKey: "lrCompName")
        UserDefaults.standard.removeObject(forKey: "lrClassNames")
        UserDefaults.standard.removeObject(forKey: "lrClassName")
        UserDefaults.standard.removeObject(forKey: "lrStartEntries")
        classHashes.removeAll()
        startEntries = []
        classes = []
        usesSecondStarts = false
        lastUpdated = nil
        pollTask?.cancel()
        pollTask = nil
    }

    func refreshNow() {
        Task { await loadStartData() }
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.pollInterval))
                guard !Task.isCancelled else { return }
                await loadStartData()
            }
        }
    }

    // MARK: - Load orchestration

    private func loadStartData() async {
        guard savedCompId > 0 else { return }
        guard !isLoadingStartList else { return }
        isLoadingStartList = true
        defer { isLoadingStartList = false }

        let wanted: [String]
        if savedClassNames.isEmpty {
            // Only fetch classes once — they don't change mid-competition
            if classes.isEmpty {
                await fetchClasses(for: savedCompId)
            }
            guard !classes.isEmpty else { return }
            wanted = classes.map(\.className)
        } else {
            wanted = savedClassNames.sorted()
            // Drop anything left over from a previous, wider selection.
            startEntries.removeAll { !savedClassNames.contains($0.className) }
        }

        await withTaskGroup(of: Void.self) { group in
            for className in wanted {
                group.addTask { @MainActor in
                    await self.fetchAndMergeClass(className)
                }
            }
        }

        // Deduplicate as a safety net against any residual interleaving
        var seen = Set<String>()
        startEntries = startEntries.filter { e in
            let key = "\(e.name)|\(e.start ?? -1)|\(e.className)"
            return seen.insert(key).inserted
        }

        startEntries.sort { ($0.start ?? 0) < ($1.start ?? 0) }
        usesSecondStarts = startEntries.usesSecondStarts
        persistEntries()
        lastUpdated = Date()
    }

    private func persistEntries() {
        guard let data = try? JSONEncoder().encode(startEntries) else { return }
        UserDefaults.standard.set(data, forKey: "lrStartEntries")
        UserDefaults.standard.set(Date(), forKey: "lrLastUpdated")
    }

    private func loadPersistedEntries() {
        guard let data = UserDefaults.standard.data(forKey: "lrStartEntries"),
              let entries = try? JSONDecoder().decode([StartEntry].self, from: data)
        else { return }
        startEntries = entries
        usesSecondStarts = entries.usesSecondStarts
        lastUpdated = UserDefaults.standard.object(forKey: "lrLastUpdated") as? Date
    }

    // MARK: - API

    func fetchCompetitions() async {
        isLoadingCompetitions = true
        error = nil
        defer { isLoadingCompetitions = false }

        guard let url = URL(string: "\(Self.base)?method=getcompetitions") else { return }
        do {
            let (rawData, _) = try await URLSession.shared.data(from: url)
            let data = Self.sanitizeJSON(rawData)
            print("[LR] getcompetitions raw:", String(data: data, encoding: .utf8)?.prefix(300) ?? "nil")
            let response = try JSONDecoder().decode(CompetitionsResponse.self, from: data)
            let today = Self.todayString()
            competitions = response.competitions
                .filter { $0.date == today }
                .sorted { $0.name < $1.name }
            print("[LR] competitions today (\(today)):", competitions.count)
        } catch {
            print("[LR] fetchCompetitions error:", error)
            self.error = error.localizedDescription
        }
    }

    private static func sanitizeJSON(_ data: Data) -> Data {
        // Strip unescaped control characters (0x00–0x1F) except tab/newline/CR which
        // the liveresultat API occasionally embeds in string values.
        let allowed = CharacterSet.controlCharacters.subtracting(
            CharacterSet(charactersIn: "\n\r")
        )
        guard let str = String(data: data, encoding: .utf8),
              str.unicodeScalars.contains(where: { allowed.contains($0) }) else {
            return data
        }
        let cleaned = String(str.unicodeScalars.filter { !allowed.contains($0) })
        return cleaned.data(using: .utf8) ?? data
    }

    private static func todayString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Europe/Stockholm")
        return fmt.string(from: Date())
    }

    func fetchClasses(for compId: Int) async {
        isLoadingClasses = true
        defer { isLoadingClasses = false }

        guard let url = URL(string: "\(Self.base)?comp=\(compId)&method=getclasses") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ClassesResponse.self, from: data)
            classes = response.classes
        } catch {
            // silently skip; classes may be stale
        }
    }

    private func fetchAndMergeClass(_ className: String) async {
        let lastHash = classHashes[className]
        let encoded = className.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? className
        var urlStr = "\(Self.base)?comp=\(savedCompId)&class=\(encoded)&method=getclassresults&unformattedTimes=true"
        if let h = lastHash { urlStr += "&last_hash=\(h)" }

        guard let url = URL(string: urlStr) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else {
            print("[LR] network error for class:", className)
            return
        }

        // Check for NOT MODIFIED
        if let statusOnly = try? JSONDecoder().decode(StatusResponse.self, from: data),
           statusOnly.status == "NOT MODIFIED" {
            print("[LR] NOT MODIFIED:", className)
            return
        }

        guard let response = try? JSONDecoder().decode(ClassResultsResponse.self, from: data) else {
            print("[LR] decode error for class:", className, String(data: data, encoding: .utf8)?.prefix(200) ?? "nil")
            return
        }
        if let hash = response.hash { classHashes[className] = hash }

        // Replace this class's entries
        startEntries.removeAll { $0.className == className }
        let newEntries: [StartEntry] = (response.results ?? []).compactMap { raw in
            guard (raw.start ?? 0) > 0 else { return nil }
            var e = raw
            e.className = className
            return e
        }
        startEntries.append(contentsOf: newEntries)
        print("[LR] loaded class:", className, "entries with start:", newEntries.count)
    }

}
