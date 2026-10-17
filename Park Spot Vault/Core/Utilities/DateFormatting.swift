import Foundation

func formattedDate(_ date: Date) -> String {
    DateFormatters.mediumDate.string(from: date)
}

func formattedTime(_ date: Date) -> String {
    DateFormatters.shortTime.string(from: date)
}

private enum DateFormatters {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

func parkingDuration(since date: Date, now: Date = Date()) -> String {
    let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
    if minutes == 0 { return "Just now" }
    if minutes < 60 { return "\(minutes) min" }
    if minutes < 1440 { return "\(minutes / 60)h \(minutes % 60)m" }
    return "\(minutes / 1440)d \(minutes % 1440 / 60)h"
}

func parkingDistance(_ meters: Double?, units: String) -> String {
    guard let meters else { return "—" }
    if units == "Feet" {
        let feet = meters * 3.28084
        return feet >= 5280 ? String(format: "%.1f mi", feet / 5280) : "\(Int(feet.rounded())) ft"
    }
    return meters >= 1000 ? String(format: "%.1f km", meters / 1000) : "\(Int(meters.rounded())) m"
}
