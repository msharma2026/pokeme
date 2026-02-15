import Foundation

enum AvailabilityHelper {
    static let shortcuts: [String: [Int]] = [
        "Morning": Array(6...11),
        "Afternoon": Array(12...16),
        "Evening": Array(17...21)
    ]

    /// Expand shortcuts + hour strings to a set of hours
    static func expandSlots(_ slots: [String]) -> Set<Int> {
        var hours = Set<Int>()
        for slot in slots {
            if let range = shortcuts[slot] {
                hours.formUnion(range)
            } else if let hour = parseHour(slot) {
                hours.insert(hour)
            }
        }
        return hours
    }

    /// Parse "14:00" -> 14
    static func parseHour(_ string: String) -> Int? {
        let parts = string.split(separator: ":")
        guard let hour = parts.first.flatMap({ Int($0) }), (0...23).contains(hour) else { return nil }
        return hour
    }

    /// Format hour int to display string: 14 -> "2 PM", 9 -> "9 AM"
    static func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour) \(period)"
    }

    /// Format hour int to storage string: 14 -> "14:00"
    static func hourString(_ hour: Int) -> String {
        String(format: "%d:00", hour)
    }

    /// Group contiguous hours into ranges for display: [9,10,11,14,15] -> ["9 AM - 12 PM", "2 PM - 4 PM"]
    static func groupHoursIntoRanges(_ hours: [Int]) -> [String] {
        let sorted = hours.sorted()
        guard !sorted.isEmpty else { return [] }

        var ranges: [String] = []
        var rangeStart = sorted[0]
        var prev = sorted[0]

        for i in 1..<sorted.count {
            if sorted[i] == prev + 1 {
                prev = sorted[i]
            } else {
                ranges.append(rangeString(from: rangeStart, to: prev))
                rangeStart = sorted[i]
                prev = sorted[i]
            }
        }
        ranges.append(rangeString(from: rangeStart, to: prev))
        return ranges
    }

    private static func rangeString(from start: Int, to end: Int) -> String {
        if start == end {
            return formatHour(start)
        }
        return "\(formatHour(start)) - \(formatHour(end + 1))"
    }
}
