import CoreLocation
import UIKit
import Combine

enum TimeSource { case gnss, ntp, device }
enum SyncStatus { case acquiring, synced, driftWarning, unavailable }

class GNSSTimeManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var timeSource: TimeSource = .device
    @Published var syncStatus: SyncStatus = .acquiring
    @Published var locationPermissionDenied: Bool = false

    // Diagnostics — surfaced in Settings and, when the correction is large,
    // in the status bar. A start clock that silently shifts by a minute is
    // worse than one that shows what it did.
    @Published private(set) var appliedOffset: TimeInterval = 0
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var lastAccuracy: CLLocationAccuracy?

    private let locationManager = CLLocationManager()
    private var offset: TimeInterval = 0   // corrected time − system time (seconds)
    private var hasFix = false
    private var acquisitionTimer: Timer?
    private var resyncTimer: Timer?
    private var resyncIntervalMin: Int = 10

    /// One offset measurement derived from a single location fix.
    private struct OffsetSample {
        let offset: TimeInterval
        let receivedAt: Date
        let accuracy: CLLocationAccuracy
    }

    private var samples: [OffsetSample] = []

    /// `startUpdatingLocation()` hands back the last *cached* fix straight away.
    /// Its timestamp can be minutes old, which would be read as "the device clock
    /// is minutes fast" and shift the whole clock. The age of a fix can't be
    /// trusted to detect that — measuring it uses the very clock under test — so
    /// instead we require several consecutive fixes to agree: a stale fix is
    /// contradicted by the fresh ones that follow it, a genuine clock error is not.
    private static let requiredSamples = 3
    private static let agreementTolerance: TimeInterval = 0.3
    private static let sampleWindow: TimeInterval = 20

    /// A correction this large is worth flagging — iOS keeps the system clock
    /// network-synced, so a multi-second GNSS correction is unusual.
    static let largeCorrectionThreshold: TimeInterval = 1.0

    var hasLargeCorrection: Bool { abs(appliedOffset) >= Self.largeCorrectionThreshold }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
    }

    // MARK: - Public API

    func start(resyncIntervalMin: Int = 10) {
        self.resyncIntervalMin = resyncIntervalMin  // hardcoded to 10 min; not user-configurable
        UIApplication.shared.isIdleTimerDisabled = true
        locationManager.requestWhenInUseAuthorization()
        beginAcquisition(isInitial: true)
    }

    func stop() {
        UIApplication.shared.isIdleTimerDisabled = false
        locationManager.stopUpdatingLocation()
        acquisitionTimer?.invalidate()
        resyncTimer?.invalidate()
    }

    /// Current disciplined time with optional gå-fram-tid offset applied.
    func syncedNow(gaFramTidSecs: Int = 0) -> Date {
        Date(timeIntervalSinceNow: offset + Double(gaFramTidSecs))
    }

    // MARK: - Acquisition

    /// Start location updates and arm a timeout.
    /// isInitial = true  → set status to .acquiring and use a 30 s timeout.
    /// isInitial = false → silent background re-sync, 60 s timeout.
    private func beginAcquisition(isInitial: Bool) {
        acquisitionTimer?.invalidate()
        samples.removeAll()
        if isInitial { syncStatus = .acquiring }
        locationManager.startUpdatingLocation()

        let timeout: TimeInterval = isInitial ? 30 : 60
        acquisitionTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.locationManager.stopUpdatingLocation()
            if !self.hasFix {
                // Never had a fix — fall back to NTP, then device
                Task { await self.tryNTPFallback() }
            } else {
                // Had a fix before; silent resync timed out — keep last offset, retry later
                self.scheduleResync()
            }
        }
    }

    private func scheduleResync() {
        resyncTimer?.invalidate()
        let interval = TimeInterval(resyncIntervalMin * 60)
        resyncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.beginAcquisition(isInitial: false)
        }
    }

    /// Apply a confirmed GNSS fix: update offset, stop updates, schedule next resync.
    private func applyGNSSFix(offset newOffset: TimeInterval, accuracy: CLLocationAccuracy) {
        let delta = abs(newOffset - offset)
        // Flag drift warning if correction is large (> 200 ms) after the first fix,
        // or whenever the standing correction is big enough to matter at a start.
        let suspicious = abs(newOffset) >= Self.largeCorrectionThreshold
        syncStatus = ((hasFix && delta > 0.200) || suspicious) ? .driftWarning : .synced
        offset = newOffset
        appliedOffset = newOffset
        lastSyncAt = Date()
        lastAccuracy = accuracy
        timeSource = .gnss
        hasFix = true
        samples.removeAll()
        acquisitionTimer?.invalidate()
        locationManager.stopUpdatingLocation()
        scheduleResync()
    }

    // MARK: - NTP Fallback

    private func tryNTPFallback() async {
        guard let ntpOffset = await NTPClient.measureOffset() else {
            await MainActor.run {
                if !self.hasFix {
                    self.timeSource = .device
                    self.syncStatus = .unavailable
                }
                // Even if we have an old fix, schedule another attempt later
                self.scheduleResync()
            }
            return
        }
        await MainActor.run {
            self.offset = ntpOffset
            self.appliedOffset = ntpOffset
            self.lastSyncAt = Date()
            self.lastAccuracy = nil
            self.timeSource = .ntp
            self.syncStatus = abs(ntpOffset) >= Self.largeCorrectionThreshold ? .driftWarning : .synced
            self.scheduleResync()
        }
    }

    /// The decision step, kept pure: the median of the most recent fixes, but
    /// only once they agree closely enough to rule out a stale cached fix.
    static func agreedOffset(from offsets: [TimeInterval]) -> TimeInterval? {
        guard offsets.count >= requiredSamples else { return nil }
        let recent = Array(offsets.suffix(requiredSamples)).sorted()
        guard let lowest = recent.first, let highest = recent.last,
              highest - lowest <= agreementTolerance
        else { return nil }
        return recent[recent.count / 2]
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let now = Date()
        for location in locations {
            // Negative accuracy marks an invalid fix.
            guard location.horizontalAccuracy >= 0 else { continue }
            let candidate = location.timestamp.timeIntervalSinceNow
            // Anything beyond a day apart is not a clock error worth chasing.
            guard abs(candidate) < 86_400 else { continue }
            samples.append(
                OffsetSample(offset: candidate, receivedAt: now, accuracy: location.horizontalAccuracy)
            )
        }

        samples.removeAll { $0.receivedAt.timeIntervalSinceNow < -Self.sampleWindow }
        guard samples.count >= Self.requiredSamples else { return }

        // Only the most recent fixes count, so a stale one ages out of the window.
        let recent = Array(samples.suffix(Self.requiredSamples))
        guard let agreed = Self.agreedOffset(from: recent.map(\.offset)) else { return }

        applyGNSSFix(offset: agreed, accuracy: recent.map(\.accuracy).min() ?? -1)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !hasFix else { return }
        locationManager.stopUpdatingLocation()
        acquisitionTimer?.invalidate()
        Task { await tryNTPFallback() }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            locationPermissionDenied = true
            locationManager.stopUpdatingLocation()
            acquisitionTimer?.invalidate()
            if !hasFix {
                Task { await tryNTPFallback() }
            }
        case .authorizedWhenInUse, .authorizedAlways:
            locationPermissionDenied = false
            // Ensure updates are running if we're still in the initial acquisition phase
            if !hasFix && syncStatus == .acquiring {
                locationManager.startUpdatingLocation()
            }
        default:
            break
        }
    }
}
