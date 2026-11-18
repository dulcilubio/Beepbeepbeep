import Foundation
import Network

/// Lightweight NTP v3 client. Queries pool.ntp.org:123 over UDP and returns
/// the estimated offset between NTP/true time and the device clock (seconds).
/// A positive offset means the device is running behind true time.
///
/// This is the only time source on a device without GNSS (a Wi-Fi iPad has no
/// GPS at all), so a single bad reply must not be able to move the clock: the
/// reply is validated, three samples are taken, and the one with the shortest
/// round trip — the least smeared by network delay — wins.
enum NTPClient {
    private static let ntpEpochOffset: TimeInterval = 2_208_988_800  // Jan 1900 → Jan 1970
    private static let sampleCount = 3

    /// Returns estimated offset (server time − device time) or nil on failure.
    static func measureOffset() async -> TimeInterval? {
        var best: (offset: TimeInterval, rtt: TimeInterval)?
        for _ in 0..<sampleCount {
            guard let sample = await query() else { continue }
            if best == nil || sample.rtt < best!.rtt { best = sample }
        }
        return best?.offset
    }

    /// One NTP exchange. Returns the offset and the round-trip time it came with.
    private static func query() async -> (offset: TimeInterval, rtt: TimeInterval)? {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: "pool.ntp.org",
                port: 123,
                using: .udp
            )

            var finished = false
            func finish(_ value: (offset: TimeInterval, rtt: TimeInterval)?) {
                guard !finished else { return }
                finished = true
                continuation.resume(returning: value)
                connection.cancel()
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    var packet = [UInt8](repeating: 0, count: 48)
                    packet[0] = 0x1B  // LI=0, VN=3, Mode=3 (client)
                    let t1 = Date()
                    connection.send(content: Data(packet), completion: .contentProcessed { error in
                        guard error == nil else { finish(nil); return }
                        connection.receive(minimumIncompleteLength: 48, maximumLength: 512) { data, _, _, _ in
                            let t4 = Date()
                            guard let data, data.count >= 48 else { finish(nil); return }

                            // Reject anything that isn't a usable server reply:
                            // LI=3 means the server itself is unsynchronised,
                            // mode must be 4 (server), stratum 0 is a kiss-o'-death.
                            let leapIndicator = data[0] >> 6
                            let mode          = data[0] & 0b111
                            let stratum       = data[1]
                            guard leapIndicator != 3, mode == 4, stratum >= 1, stratum <= 15 else {
                                finish(nil); return
                            }

                            // Transmit timestamp is at bytes 40–47 (seconds + fraction, big-endian)
                            let sec  = data.withUnsafeBytes { $0.load(fromByteOffset: 40, as: UInt32.self) }.bigEndian
                            let frac = data.withUnsafeBytes { $0.load(fromByteOffset: 44, as: UInt32.self) }.bigEndian
                            guard sec > 0 else { finish(nil); return }

                            let serverTransmit = TimeInterval(sec) - NTPClient.ntpEpochOffset
                                              + TimeInterval(frac) / 4_294_967_296.0
                            // Apply round-trip correction: offset ≈ serverTransmit − t4 + rtt/2
                            let rtt    = t4.timeIntervalSince(t1)
                            let offset = serverTransmit - t4.timeIntervalSince1970 + rtt / 2
                            finish((offset: offset, rtt: rtt))
                        }
                    })
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .utility))

            // 5-second timeout
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) { finish(nil) }
        }
    }
}
