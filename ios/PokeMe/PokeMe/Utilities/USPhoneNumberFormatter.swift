import Foundation

enum USPhoneNumberFormatter {
    static func normalize(_ value: String) -> String {
        var digits = value.filter(\.isNumber)

        if digits.count == 11, digits.hasPrefix("1") {
            digits.removeFirst()
        }

        return String(digits.prefix(10))
    }

    static func format(_ value: String) -> String {
        let digits = normalize(value)
        guard !digits.isEmpty else { return "" }

        var result = "("
        let count = digits.count
        result += String(digits.prefix(3))

        if count >= 3 { result += ") " }
        if count > 3 { result += String(digits.dropFirst(3).prefix(3)) }
        if count >= 6 { result += "-" }
        if count > 6 { result += String(digits.dropFirst(6)) }

        return result
    }
}
