import Foundation

/// Every date in the app is shown in both calendars: Gregorian, then Umm al-Qura Hijri.
enum DateText {
    static let locale = Locale(identifier: "ar@numbers=latn")

    static let gregorianCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = .current
        return calendar
    }()

    static let hijriCalendar: Calendar = {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = locale
        calendar.timeZone = .current
        return calendar
    }()

    private static func formatter(_ template: String, hijri: Bool) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = hijri ? hijriCalendar : gregorianCalendar
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private static let longGregorian = formatter("EEEEdMMMM", hijri: false)
    private static let shortGregorian = formatter("dMMMM", hijri: false)
    private static let weekdayGregorian = formatter("EEEE", hijri: false)
    private static let monthGregorian = formatter("MMMM", hijri: false)
    private static let monthYearGregorian = formatter("MMMMy", hijri: false)
    private static let shortHijri = formatter("dMMMM", hijri: true)
    private static let fullHijri = formatter("dMMMMy", hijri: true)
    private static let monthHijri = formatter("MMMM", hijri: true)
    private static let monthYearHijri = formatter("MMMMy", hijri: true)
    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter
    }()

    /// "الجمعة، 30 أكتوبر"
    static func long(_ date: Date) -> String { longGregorian.string(from: date) }
    /// "30 أكتوبر"
    static func short(_ date: Date) -> String { shortGregorian.string(from: date) }
    static func gregorianMonth(_ date: Date) -> String { monthGregorian.string(from: date) }
    /// "19 جمادى الأولى"
    static func hijri(_ date: Date) -> String { shortHijri.string(from: date) }
    /// "19 جمادى الأولى 1448 هـ"
    static func hijriFull(_ date: Date) -> String { fullHijri.string(from: date) }
    static func hijriMonth(_ date: Date) -> String { monthHijri.string(from: date) }
    static func hijriDay(_ date: Date) -> Int { hijriCalendar.component(.day, from: date) }
    /// "30 أكتوبر · 19 جمادى الأولى"
    static func both(_ date: Date) -> String { "\(short(date)) · \(hijri(date))" }

    /// "أكتوبر – نوفمبر 2026" or "جمادى الأولى – جمادى الآخرة 1448 هـ"
    static func span(from start: Date, to end: Date, hijri: Bool) -> String {
        let calendar = hijri ? hijriCalendar : gregorianCalendar
        let monthYear = hijri ? monthYearHijri : monthYearGregorian
        let month = hijri ? monthHijri : monthGregorian
        let first = monthYear.string(from: start), last = monthYear.string(from: end)
        if first == last { return first }
        if calendar.component(.year, from: start) == calendar.component(.year, from: end) {
            return "\(month.string(from: start)) – \(last)"
        }
        return "\(first) – \(last)"
    }

    /// "اليوم، 30 أكتوبر · 19 جمادى الأولى"
    static func dayHeading(_ day: String, today: String) -> String {
        let date = Days.date(day)
        let head = day == today ? "اليوم" : day == Days.adding(-1, to: today) ? "أمس" : weekdayGregorian.string(from: date)
        return "\(head)، \(both(date))"
    }

    static func when(_ date: Date, today: String) -> String {
        let day = Days.key(date)
        if day == today { return "اليوم \(clock.string(from: date))" }
        if day == Days.adding(-1, to: today) { return "أمس \(clock.string(from: date))" }
        return both(date)
    }

    static func days(_ count: Int) -> String {
        switch count {
        case 1: return "يوم واحد"
        case 2: return "يومين"
        case 3...10: return "\(count) أيام"
        default: return "\(count) يوم"
        }
    }
}
