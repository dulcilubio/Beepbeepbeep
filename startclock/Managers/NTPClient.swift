import Foundation
import Network

/// Lightweight NTP v3 client. Queries pool.ntp.org:123 over UDP and returns
/// the estimated offset between NTP/true time and the device clock (seconds).
/// A positive offset means the device is running behind true time.
enum NTPClient {
    private static let ntpEpochOffset: TimeInterval = 2_208_988_800  // Jan 1900 → Jan 1970

    /// Returns estimated offset (server time − device time) or nil on failure.
    static func measureOffset() async -> TimeInterval? {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: "pool.ntp.org",
                port: 123,
                using: .udp
            )

            var finished = false
            func finish(_ value: TimeInterval?) {
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
                            // Transmit timestamp is at bytes 40–47 (seconds + fraction, big-endian)
                            let sec  = data.withUnsafeBytes { $0.load(fromByteOffset: 40, as: UInt32.self) }.bigEndian
                            let frac = data.withUnsafeBytes { $0.load(fromByteOffset: 44, as: UInt32.self) }.bigEndian
                            let serverTransmit = TimeInterval(sec) - NTPClient.ntpEpochOffset
                                              + TimeInterval(frac) / 4_294_967_296.0
                            // Apply round-trip correction: offset ≈ serverTransmit − t4 + rtt/2
                            let rtt    = t4.timeIntervalSince(t1)
                            let offset = serverTransmit - t4.timeIntervalSince1970 + rtt / 2
                            finish(offset)
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
