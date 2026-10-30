import Foundation

/// Calendar days are kept as "yyyy-MM-dd" in the Gregorian calendar and the phone's time zone,
/// so comparing two days is a plain string comparison.
enum Days {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    static func key(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 2000, parts.month ?? 1, parts.day ?? 1)
    }

    static func key(year: Int, month: Int, day: Int) -> String {
        key(date(year: year, month: month, day: day))
    }

    static func today(_ now: Date = Date()) -> String {
        key(now)
    }

    /// Noon, so day arithmetic stays clear of daylight-saving jumps.
    static func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    static func date(_ day: String) -> Date {
        let p = parts(day)
        return date(year: p.year, month: p.month, day: p.day)
    }

    static func parts(_ day: String) -> (year: Int, month: Int, day: Int) {
        let numbers = day.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return (2000, 1, 1) }
        return (numbers[0], numbers[1], numbers[2])
    }

    static func adding(_ count: Int, to day: String) -> String {
        let start = date(day)
        return key(calendar.date(byAdding: .day, value: count, to: start) ?? start)
    }

    /// Whole days from `a` to `b`; negative when `b` comes first.
    static func between(_ a: String, _ b: String) -> Int {
        calendar.dateComponents([.day], from: date(a), to: date(b)).day ?? 0
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        calendar.range(of: .day, in: .month, for: date(year: year, month: month, day: 1))?.count ?? 30
    }

    /// 0 is Sunday, the first column of a Saudi week.
    static func weekday(_ day: String) -> Int {
        calendar.component(.weekday, from: date(day)) - 1
    }
}

enum EndMode: String, Codable, CaseIterable {
    case month, salary, nextMonth, custom
}

struct Bill: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var amount: Double
}

struct Expense: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case daily
        /// A set-aside bill that was paid; it never counts against the daily limit.
        case bill
    }

    var id = UUID()
    var amount: Double
    var note: String
    /// The day the money was spent.
    var day: String
    /// When it was written down. Only entries after `BudgetState.balanceAt` come off the balance.
    var at: Date
    var kind: Kind = .daily
    /// What was in the basket, when the expense came from the scanner.
    var items: [BasketItem]? = nil
}

struct BudgetState: Codable, Equatable {
    var isExample = false
    /// The money the person had when they last typed it in.
    var balance: Double = 0
    var balanceAt = Date()
    /// The last day the money has to cover.
    var endDate: String
    var endMode: EndMode
    var salaryDay = 27
    var savings: Double = 0
    var bills: [Bill] = []
    var expenses: [Expense] = []

    static func blank(today: String, now: Date = Date()) -> BudgetState {
        let end = BudgetMath.defaultEnd(today: today)
        return BudgetState(balanceAt: now, endDate: end.date, endMode: end.mode)
    }

    static func example(today: String, now: Date = Date()) -> BudgetState {
        let yesterday = Days.adding(-1, to: today)
        let end = BudgetMath.defaultEnd(today: today)
        let morning = Days.date(yesterday).addingTimeInterval(-4 * 3600)
        return BudgetState(
            isExample: true,
            balance: 3200,
            balanceAt: morning,
            endDate: end.date,
            endMode: end.mode,
            savings: 300,
            bills: [
                Bill(name: "فاتورة الجوال", amount: 230),
                Bill(name: "اشتراك النادي", amount: 180),
            ],
            expenses: [
                Expense(amount: 86, note: "بقالة", day: yesterday, at: morning.addingTimeInterval(4 * 3600)),
                Expense(amount: 45, note: "بنزين", day: yesterday, at: morning.addingTimeInterval(10 * 3600)),
                Expense(amount: 18, note: "قهوة", day: today, at: now.addingTimeInterval(-60)),
            ]
        )
    }

    mutating func leaveExample(now: Date = Date()) {
        isExample = false
        balance = 0
        balanceAt = now
        savings = 0
        bills = []
        expenses = []
    }
}

enum BudgetMath {
    struct Summary: Equatable {
        var daysLeft: Int
        var ended: Bool
        var spentBefore: Double
        var spentToday: Double
        var spentAll: Double
        var reserved: Double
        var onHand: Double
        var free: Double
        /// What can still be spent, counted at the start of today.
        var poolStart: Double
        var allowance: Double
        var leftToday: Double
        /// Each later day's limit if today ends at its limit (or past it, when already over).
        var futureDaily: Double
        /// Each later day's limit if nothing more is spent today.
        var ifStopNow: Double
    }

    enum Status: Equatable {
        case empty
        case ended
        case short(Double)
        case over(Double)
        case onTrack(left: Double, nearLimit: Bool)
    }

    /// (money on hand − bills − savings) ÷ days left including today.
    static func summary(_ s: BudgetState, today: String) -> Summary {
        let daysLeft = Days.between(today, s.endDate) + 1
        var spentBefore = 0.0, spentToday = 0.0, spentAll = 0.0
        for expense in s.expenses where expense.at > s.balanceAt {
            spentAll += expense.amount
            if expense.kind == .daily && expense.day == today {
                spentToday += expense.amount
            } else {
                spentBefore += expense.amount
            }
        }
        let reserved = s.bills.reduce(0) { $0 + $1.amount } + s.savings
        let onHand = s.balance - spentAll
        let poolStart = s.balance - spentBefore - reserved
        let ended = daysLeft < 1
        let allowance = ended ? 0 : max(0, poolStart) / Double(daysLeft)
        let rest = daysLeft - 1
        let futureDaily = rest > 0 ? max(0, poolStart - max(spentToday, allowance)) / Double(rest) : 0
        let ifStopNow = rest > 0 ? max(0, poolStart - spentToday) / Double(rest) : 0
        return Summary(
            daysLeft: daysLeft, ended: ended,
            spentBefore: spentBefore, spentToday: spentToday, spentAll: spentAll,
            reserved: reserved, onHand: onHand, free: onHand - reserved,
            poolStart: poolStart, allowance: allowance, leftToday: allowance - spentToday,
            futureDaily: futureDaily, ifStopNow: ifStopNow
        )
    }

    static func status(_ s: BudgetState, _ m: Summary) -> Status {
        if s.balance <= 0 && s.expenses.isEmpty && s.bills.isEmpty { return .empty }
        if m.ended { return .ended }
        if m.poolStart <= 0 || m.free < 0 { return .short(max(0, -m.free)) }
        if m.spentToday > m.allowance { return .over(m.spentToday - m.allowance) }
        return .onTrack(left: m.leftToday, nearLimit: m.spentToday > 0 && m.spentToday >= 0.8 * m.allowance)
    }

    static func endDate(for mode: EndMode, salaryDay: Int, from today: String) -> String {
        let t = Days.parts(today)
        let next = t.month == 12 ? (year: t.year + 1, month: 1) : (year: t.year, month: t.month + 1)
        switch mode {
        case .month, .custom:
            return Days.key(year: t.year, month: t.month, day: Days.daysInMonth(year: t.year, month: t.month))
        case .nextMonth:
            return Days.key(year: next.year, month: next.month, day: Days.daysInMonth(year: next.year, month: next.month))
        case .salary:
            let day = min(max(1, salaryDay), 31)
            func payday(_ year: Int, _ month: Int) -> String {
                Days.key(year: year, month: month, day: min(day, Days.daysInMonth(year: year, month: month)))
            }
            var pay = payday(t.year, t.month)
            if today >= pay { pay = payday(next.year, next.month) }
            // The money has to last until the day before the salary arrives.
            return Days.adding(-1, to: pay)
        }
    }

    static func defaultEnd(today: String) -> (mode: EndMode, date: String) {
        let monthEnd = endDate(for: .month, salaryDay: 27, from: today)
        // With under a week left in this month, plan to the end of next month.
        if Days.between(today, monthEnd) + 1 < 7 {
            return (.nextMonth, endDate(for: .nextMonth, salaryDay: 27, from: today))
        }
        return (.month, monthEnd)
    }
}

enum Money {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static func text(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: (value * 100).rounded() / 100)) ?? "0"
    }

    /// Daily limits are rounded down, so keeping to them never overspends.
    static func whole(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: floor(max(0, value) + 1e-9))) ?? "0"
    }

    /// The amount as it goes back into a text field: no thousands separators.
    static func plain(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }

    /// Reads amounts typed with Western or Arabic-Indic digits, "٫" or "." for decimals,
    /// and "٬" or "," between thousands ("12,5" with one comma and up to two digits after it is a decimal).
    static func parse(_ text: String) -> Double {
        var cleaned = ""
        var commas = 0
        for character in text {
            if character.isNumber, let value = character.wholeNumberValue {
                cleaned.append(String(value))
            } else if character == "." || character == "٫" {
                cleaned.append(".")
            } else if character == "," {
                cleaned.append(",")
                commas += 1
            }
        }
        if !cleaned.contains("."), commas == 1, let comma = cleaned.firstIndex(of: ",") {
            let after = cleaned.distance(from: comma, to: cleaned.endIndex) - 1
            cleaned = cleaned.replacingOccurrences(of: ",", with: (1...2).contains(after) ? "." : "")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }
        guard let number = Double(cleaned), number.isFinite, number > 0 else { return 0 }
        return (number * 100).rounded() / 100
    }
}
