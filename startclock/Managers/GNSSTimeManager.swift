import CoreLocation
import UIKit
import Combine

enum TimeSource { case gnss, ntp, device }
enum SyncStatus { case acquiring, synced, driftWarning, unavailable }

class GNSSTimeManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var timeSource: TimeSource = .device
    @Published var syncStatus: SyncStatus = .acquiring
    @Published var locationPermissionDenied: Bool = false

    private let locationManager = CLLocationManager()
    private var offset: TimeInterval = 0   // corrected time − system time (seconds)
    private var hasFix = false
    private var acquisitionTimer: Timer?
    private var resyncTimer: Timer?
    private var resyncIntervalMin: Int = 10

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
    private func applyGNSSFix(offset newOffset: TimeInterval) {
        let delta = abs(newOffset - offset)
        // Flag drift warning if correction is large (> 200 ms) after the first fix.
        // The clock continues uninterrupted on the new offset.
        syncStatus = (hasFix && delta > 0.200) ? .driftWarning : .synced
        offset = newOffset
        timeSource = .gnss
        hasFix = true
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
            self.timeSource = .ntp
            self.syncStatus = .synced
            self.scheduleResync()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        applyGNSSFix(offset: location.timestamp.timeIntervalSinceNow)
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
