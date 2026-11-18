import Foundation

/// Repairs the malformed JSON that liveresultat.orientering.se sometimes serves.
///
/// Two faults have been seen in the wild, both inside string values:
///   • raw control characters,
///   • unescaped double quotes — `"name": "1. Lauf "ORIUNITE" Nikolaus-OL"` —
///     which end the string early and make the whole response undecodable.
///     One such competition anywhere in the list used to take out the entire
///     competition picker.
///
/// A quote inside a string is treated as the real closing quote only when the
/// next non-whitespace character is JSON structure (`:,}]`); otherwise it is
/// escaped and the string continues.
enum JSONRepair {
    static func sanitize(_ data: Data) -> Data {
        guard let raw = String(data: data, encoding: .utf8) else { return data }

        var out = String()
        out.reserveCapacity(raw.unicodeScalars.count + 32)

        let scalars = raw.unicodeScalars
        var index = scalars.startIndex
        var inString = false
        var escaped = false

        while index < scalars.endIndex {
            let scalar = scalars[index]

            if !inString {
                if !isStrippableControl(scalar) {
                    out.unicodeScalars.append(scalar)
                    if scalar == "\"" { inString = true }
                }
            } else if escaped {
                out.unicodeScalars.append(scalar)
                escaped = false
            } else if scalar == "\\" {
                out.unicodeScalars.append(scalar)
                escaped = true
            } else if scalar == "\"" {
                if closesString(scalars, after: index) {
                    out.unicodeScalars.append(scalar)
                    inString = false
                } else {
                    out += "\\\""
                }
            } else if !isStrippableControl(scalar) {
                out.unicodeScalars.append(scalar)
            }

            index = scalars.index(after: index)
        }

        return out.data(using: .utf8) ?? data
    }

    /// A closing quote is followed by JSON structure; anything else means the
    /// quote was part of the value.
    ///
    /// A comma needs a second look: after a real comma comes the next key or
    /// value, so `"Nisse "Kalle", IF"` — where ` IF` follows instead — tells us
    /// that quote closed nothing.
    private static func closesString(_ scalars: String.UnicodeScalarView,
                                     after index: String.UnicodeScalarView.Index) -> Bool {
        guard let next = nextSignificant(scalars, after: index) else { return true }  // end of document
        switch scalars[next] {
        case ":", "}", "]":
            return true
        case ",":
            guard let following = nextSignificant(scalars, after: next) else { return false }
            return startsKeyOrValue(scalars[following])
        default:
            return false
        }
    }

    private static func nextSignificant(_ scalars: String.UnicodeScalarView,
                                        after index: String.UnicodeScalarView.Index)
        -> String.UnicodeScalarView.Index?
    {
        var next = scalars.index(after: index)
        while next < scalars.endIndex, isWhitespace(scalars[next]) {
            next = scalars.index(after: next)
        }
        return next < scalars.endIndex ? next : nil
    }

    /// What a key or a value may legally begin with.
    private static func startsKeyOrValue(_ scalar: Unicode.Scalar) -> Bool {
        if scalar == "\"" || scalar == "{" || scalar == "[" || scalar == "-" { return true }
        if scalar.value >= 48, scalar.value <= 57 { return true }   // 0–9
        return scalar == "t" || scalar == "f" || scalar == "n"      // true / false / null
    }

    private static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r"
    }

    /// Control characters are illegal inside JSON strings; tab, newline and
    /// carriage return are left alone since they are valid between tokens.
    private static func isStrippableControl(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value < 0x20 && scalar != "\n" && scalar != "\r" && scalar != "\t"
    }
}
